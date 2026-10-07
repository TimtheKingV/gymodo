import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import {
  MAX_VOLUME,
  snapToStep,
  volumeZuGross,
  type LoadUnit,
  type VolumeKind,
} from "./belastung.js";
import { DomainError } from "./errors.js";
import {
  gespeicherteVorschlaege,
  vorschlaegeFuerAbschluss,
  type Blockvorschlag,
} from "./abschluss.js";

export const problemReasonSchema = z.enum([
  "schmerz",
  "geraet_passt_nicht",
  "zu_schwer",
  "sonstiges",
]);

export type ProblemReason = z.infer<typeof problemReasonSchema>;

/**
 * Alte Feldnamen fuer EINEN Release annehmen.
 *
 * `PendingWriteStore` auf einem Geraet, das vor dem App-Update offline
 * trainiert hat, schickt seine Saetze noch als weightKg/reps. Ohne diesen
 * Alias gingen genau die Saetze verloren, die das Mitglied am laengsten
 * mit sich herumtraegt. Der Alias faellt mit dem uebernaechsten Release
 * (Cardio-Spec Abschnitt 5.1); der Test in workout.test.ts haelt fest,
 * dass er bis dahin da ist.
 */
function aliasAufloesen(roh: unknown): unknown {
  if (typeof roh !== "object" || roh === null || Array.isArray(roh)) return roh;
  const eingabe = roh as Record<string, unknown>;
  const { weightKg, reps, ...rest } = eingabe;
  const ergebnis: Record<string, unknown> = { ...rest };
  if (!("load" in rest) && weightKg !== undefined) ergebnis.load = weightKg;
  if (!("volume" in rest) && reps !== undefined) ergebnis.volume = reps;
  return ergebnis;
}

/**
 * Eingabe des Satz-PUT.
 *
 * Ein Satz haengt an einer Station (station.ts): an einem Geraet ODER an
 * einem Geraetetyp ohne QR-Code. Am Geraet kommt das Studio aus dem Geraet;
 * ein mitgeschicktes `studioId` wird dann ignoriert -- sonst haetten wir eine
 * Mandantengrenze, die von der App behauptet statt geprueft wird. Am Typ
 * nennt `studioId` den Ort; ohne es laeuft der Satz im Gymtavo-Studio
 * (Freies Training). Ob der Nutzer dort schreiben darf, prueft recordSet
 * gegen das, was RLS ihn lesen laesst.
 *
 * `load` und `volume` sind Zahlen ohne Einheit; was sie bedeuten, sagen
 * das Geraetemodell (load_unit) und die Uebung (volume_kind). Die
 * Obergrenze hier ist die Datenbankschranke; die fachliche je Umfangsart
 * prueft recordSet gegen die Uebung. `secondaryLoad` ist Pflicht genau
 * dann, wenn das Modell eine Nebenbelastung hat -- auch das weiss erst
 * recordSet.
 */
export const recordSetInputSchema = z.preprocess(
  aliasAufloesen,
  z
  .object({
    sessionId: z.string().uuid(),
    setId: z.string().uuid(),
    machineId: z.string().uuid().optional(),
    equipmentModelId: z.string().uuid().optional(),
    studioId: z.string().uuid().optional(),
    exerciseId: z.string().uuid(),
    setIndex: z.number().int().min(1),
    load: z.number().min(0).max(9999),
    volume: z.number().int().min(1).max(100000),
    secondaryLoad: z.number().min(0).max(9999).nullish(),
    rir: z.number().min(0).max(10).nullish(),
    problemFlag: z.boolean().default(false),
    problemReason: problemReasonSchema.nullish(),
    performedAt: z.string().datetime().optional(),
    // Der Beginn der Einheit, vom Client gesetzt ("Training starten",
    // Schnitt 4). Nur beim Anlegen der Session uebernommen, siehe recordSet.
    sessionStartedAt: z.string().datetime().optional(),
  })
  .refine((value) => (value.machineId === undefined) !== (value.equipmentModelId === undefined), {
    path: ["machineId"],
    message: "Ein Satz braucht entweder ein Geraet oder einen Geraetetyp.",
  })
  .refine((value) => !value.problemReason || value.problemFlag, {
    path: ["problemReason"],
    message: "Eine Problemursache setzt das Problemkennzeichen voraus.",
  })
  .refine(
    (value) =>
      !value.sessionStartedAt ||
      !value.performedAt ||
      Date.parse(value.sessionStartedAt) <= Date.parse(value.performedAt),
    { path: ["sessionStartedAt"], message: "Der Beginn der Einheit liegt nach dem Satz." },
  ),
);

export type RecordSetInput = z.infer<typeof recordSetInputSchema>;

export type RecordedSet = {
  id: string;
  studioId: string;
  userId: string;
  sessionId: string;
  /** null an einem Geraetetyp ohne QR-Code (Spec 8.1). */
  machineId: string | null;
  equipmentModelId: string;
  exerciseId: string;
  setIndex: number;
  load: number;
  secondaryLoad: number | null;
  volume: number;
  rir: number | null;
  problemFlag: boolean;
  problemReason: ProblemReason | null;
  performedAt: string;
};

type SetRow = {
  id: string;
  studio_id: string;
  user_id: string;
  session_id: string;
  machine_id: string | null;
  equipment_model_id: string;
  exercise_id: string;
  set_index: number;
  load: number | string;
  secondary_load: number | string | null;
  volume: number;
  rir: number | string | null;
  problem_flag: boolean;
  problem_reason: ProblemReason | null;
  performed_at: string;
};

function toRecordedSet(row: SetRow): RecordedSet {
  return {
    id: row.id,
    studioId: row.studio_id,
    userId: row.user_id,
    sessionId: row.session_id,
    machineId: row.machine_id,
    equipmentModelId: row.equipment_model_id,
    exerciseId: row.exercise_id,
    setIndex: row.set_index,
    // numeric kommt je nach Treiber als Zeichenkette zurueck.
    load: Number(row.load),
    secondaryLoad: row.secondary_load === null ? null : Number(row.secondary_load),
    volume: row.volume,
    rir: row.rir === null ? null : Number(row.rir),
    problemFlag: row.problem_flag,
    problemReason: row.problem_reason,
    performedAt: row.performed_at,
  };
}

type Nebenbelastung = {
  secondary_unit: LoadUnit | null;
  secondary_step: number | string | null;
  secondary_min: number | string | null;
  secondary_max: number | string | null;
};

const NEBEN_SPALTEN = "secondary_unit, secondary_step, secondary_min, secondary_max";

/**
 * Studio und Modell eines Satzes, serverseitig bestimmt.
 *
 * Alle Absagen sind not_found und gleich formuliert: RLS macht fremde
 * Geraete, Modelle und Studios unsichtbar, und die Antwort soll nicht
 * verraten, ob es sie gibt.
 */
export async function stationAufloesen(
  client: SupabaseClient,
  input: { machineId?: string | undefined; equipmentModelId?: string | undefined; studioId?: string | undefined },
): Promise<{
  studioId: string;
  equipmentModelId: string;
  katalogStudioId: string | null;
  modell: Nebenbelastung;
}> {
  const { data: katalog } = await client
    .from("studios")
    .select("id")
    .eq("is_catalog", true)
    .maybeSingle<{ id: string }>();
  const katalogStudioId = katalog?.id ?? null;

  if (input.machineId) {
    // Das Studio kommt aus dem Geraet. Das Modell kommt mit, weil nur es
    // weiss, ob der Satz eine Nebenbelastung tragen muss und wie sie rastet.
    const { data: machine } = await client
      .from("machines")
      .select(`studio_id, equipment_model_id, equipment_models (${NEBEN_SPALTEN})`)
      .eq("id", input.machineId)
      .maybeSingle<{ studio_id: string; equipment_model_id: string; equipment_models: Nebenbelastung }>();
    if (!machine) {
      throw new DomainError("not_found", "Geraet nicht gefunden.");
    }
    return {
      studioId: machine.studio_id,
      equipmentModelId: machine.equipment_model_id,
      katalogStudioId,
      modell: machine.equipment_models,
    };
  }

  const studioId = input.studioId ?? katalogStudioId;
  if (!studioId) {
    throw new DomainError("not_found", "Studio nicht gefunden.");
  }
  // Ein Studio, das der Nutzer nicht lesen darf, ist eines, in dem er nicht
  // Mitglied ist. Ohne diese Pruefung endete der Versuch an der Policy von
  // workout_sessions -- als interner Fehler statt als not_found.
  if (studioId !== katalogStudioId) {
    const { data: studio } = await client
      .from("studios")
      .select("id")
      .eq("id", studioId)
      .maybeSingle<{ id: string }>();
    if (!studio) {
      throw new DomainError("not_found", "Studio nicht gefunden.");
    }
  }

  const { data: modell } = await client
    .from("equipment_models")
    .select(`id, studio_id, ${NEBEN_SPALTEN}`)
    .eq("id", input.equipmentModelId!)
    .maybeSingle<Nebenbelastung & { id: string; studio_id: string }>();
  if (!modell || (modell.studio_id !== studioId && modell.studio_id !== katalogStudioId)) {
    throw new DomainError("not_found", "Geraet nicht gefunden.");
  }
  return { studioId, equipmentModelId: modell.id, katalogStudioId, modell };
}

/**
 * Speichert einen bestaetigten Satz.
 *
 * Idempotent durch die clientseitig erzeugten UUIDs: derselbe Aufruf zweimal
 * ergibt dieselbe Zeile (Spec 6.3). Die Session entsteht dabei mit dem
 * ersten Satz -- einen Start-Endpoint gibt es nicht, und deshalb liegt eine
 * Einheit ohne Satz nie hier (Sammelstelle Schnitt 4, Entschieden 2). Ihren
 * Beginn setzt der Client (Spec 5.2, seit Schnitt 4).
 */
export async function recordSet(
  client: SupabaseClient,
  rawInput: unknown,
): Promise<RecordedSet> {
  const parsed = recordSetInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const input = parsed.data;

  const userId = await requireUserId(client);

  const station = await stationAufloesen(client, input);
  const studioId = station.studioId;
  const modell = station.modell;

  // Die Uebung muss im Studio des Satzes liegen oder im Gymtavo-Katalog
  // (Verweis statt Kopie, Spec E2) -- nie in einem dritten Studio.
  const { data: exercise } = await client
    .from("exercises")
    .select("id, volume_kind, studio_id")
    .eq("id", input.exerciseId)
    .maybeSingle<{ id: string; volume_kind: VolumeKind; studio_id: string }>();
  if (
    !exercise ||
    (exercise.studio_id !== studioId && exercise.studio_id !== station.katalogStudioId)
  ) {
    throw new DomainError("not_found", "Uebung nicht gefunden.");
  }

  // Die fachliche Obergrenze kennt nur die Uebung: 1000 Wiederholungen,
  // vier Stunden, 100 km. Die Datenbank prueft nur die Schranke gegen
  // Unsinn (Migration 0046).
  if (input.volume > MAX_VOLUME[exercise.volume_kind]) {
    throw new DomainError("validation_failed", volumeZuGross(exercise.volume_kind));
  }

  // Nebenbelastung: Pflicht genau dann, wenn das Modell eine hat. Ein Satz
  // am Laufband ohne Neigung waere fuer die Regel eine andere Bedingung als
  // jeder Satz davor; ein Satz an der Beinpresse MIT Neigung ein Wert, den
  // niemand je liest.
  let secondaryLoad: number | null = null;
  if (modell.secondary_unit !== null) {
    if (input.secondaryLoad === null || input.secondaryLoad === undefined) {
      throw new DomainError(
        "validation_failed",
        "Dieses Geraet braucht einen Wert fuer die Nebenbelastung.",
      );
    }
    // Auf die Rastung des Modells, damit "82 U/min" und "85 U/min" dieselbe
    // Bedingung sind (Cardio-Spec Abschnitt 5.1).
    secondaryLoad = snapToStep(
      input.secondaryLoad,
      Number(modell.secondary_min ?? 0),
      modell.secondary_max === null ? null : Number(modell.secondary_max),
      Number(modell.secondary_step ?? 0),
    );
  } else if (input.secondaryLoad !== null && input.secondaryLoad !== undefined) {
    throw new DomainError(
      "validation_failed",
      "Dieses Geraet hat keine Nebenbelastung.",
    );
  }

  // `ignoreDuplicates` macht daraus ON CONFLICT DO NOTHING: ein zweiter Satz
  // in derselben Session verschiebt deren Startzeitpunkt nicht -- auch
  // nicht mit einem anderen sessionStartedAt.
  const { error: sessionError } = await client.from("workout_sessions").upsert(
    {
      id: input.sessionId,
      studio_id: studioId,
      user_id: userId,
      // Ohne den Wert griffe der Default now(): die Ankunft des ersten PUT,
      // nach einem Offline-Training Stunden nach dem Start. Nach oben auf
      // die Serverzeit gekappt, weil eine vorgehende Client-Uhr sonst einen
      // started_at in der Zukunft schreibt -- das reisst spaeter die
      // workout_sessions_completed_after_start-Check in completeSession
      // (started_at <= completed_at, completed_at ist now()) und verschiebt
      // Wochenzaehler/Serie/Reihenfolge in sessions.ts.
      ...(input.sessionStartedAt
        ? { started_at: new Date(Math.min(Date.parse(input.sessionStartedAt), Date.now())).toISOString() }
        : {}),
    },
    { onConflict: "id", ignoreDuplicates: true },
  );
  if (sessionError) {
    throw new DomainError("internal", sessionError.message);
  }

  const { data: row, error } = await client
    .from("workout_sets")
    .upsert({
      id: input.setId,
      studio_id: studioId,
      user_id: userId,
      session_id: input.sessionId,
      machine_id: input.machineId ?? null,
      equipment_model_id: station.equipmentModelId,
      exercise_id: input.exerciseId,
      set_index: input.setIndex,
      load: input.load,
      secondary_load: secondaryLoad,
      volume: input.volume,
      rir: input.rir ?? null,
      problem_flag: input.problemFlag,
      problem_reason: input.problemReason ?? null,
      // performed_at bleibt beim erneuten Senden unangetastet, weil es hier
      // nur mitgeschickt wird, wenn der Client es ausdruecklich setzt.
      ...(input.performedAt ? { performed_at: input.performedAt } : {}),
    })
    .select(
      "id, studio_id, user_id, session_id, machine_id, equipment_model_id, exercise_id, set_index, load, secondary_load, volume, rir, problem_flag, problem_reason, performed_at",
    )
    .single<SetRow>();

  if (error || !row) {
    throw new DomainError(
      "internal",
      error?.message ?? "Satz konnte nicht gespeichert werden.",
    );
  }
  return toRecordedSet(row);
}

export const completeSessionInputSchema = z.object({
  sessionId: z.string().uuid(),
});

export type CompletedSession = {
  id: string;
  startedAt: string;
  completedAt: string;
  completedReason: "manual" | "auto";
  /**
   * Was beim naechsten Mal an jedem Geraet dieser Einheit ansteht. Kommt
   * mit dem Abschluss statt aus einem eigenen Endpoint, weil der Screen
   * genau das rendert (M1-Spec SS6.3, screenorientiert).
   */
  vorschlaege: Blockvorschlag[];
};

type SessionRow = {
  id: string;
  started_at: string;
  completed_at: string | null;
  completed_reason: "manual" | "auto" | null;
};

/**
 * Beendet eine Trainingseinheit ausdruecklich.
 *
 * Idempotent: eine bereits beendete Session wird unveraendert
 * zurueckgegeben, statt ihren Abschlusszeitpunkt zu verschieben. Ohne diese
 * Regel wuerde ein wiederholter Aufruf -- etwa nach einem Netzwiederholer --
 * die Dauer der Einheit still verfaelschen.
 */
export async function completeSession(
  client: SupabaseClient,
  rawInput: unknown,
): Promise<CompletedSession> {
  const parsed = completeSessionInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  // RLS blendet fremde Sessions aus; "nicht gefunden" ist deshalb auch die
  // richtige Antwort auf die Session eines anderen Mitglieds.
  const { data: existing } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, completed_reason")
    .eq("id", parsed.data.sessionId)
    .eq("user_id", userId)
    .maybeSingle<SessionRow>();
  if (!existing) {
    throw new DomainError("not_found", "Training nicht gefunden.");
  }

  if (existing.completed_at && existing.completed_reason) {
    // Nur LESEN. Der Frueheinstieg ist genau dafuer da, nichts noch einmal
    // zu tun -- die Vorschlaege kommen aus dem, was der erste Abschluss
    // festgehalten hat. Sie hier neu zu rechnen hiesse, ein zweites Mal
    // nach progression_suggestions zu schreiben; die Tabelle hat keinen
    // eindeutigen Index, jeder Wiederholer erzeugte also Dubletten.
    return {
      id: existing.id,
      startedAt: existing.started_at,
      completedAt: existing.completed_at,
      completedReason: existing.completed_reason,
      vorschlaege: await gespeicherteVorschlaege(
        client,
        parsed.data.sessionId,
        userId,
        existing.completed_at,
      ),
    };
  }

  const { data: row, error } = await client
    .from("workout_sessions")
    .update({
      completed_at: new Date().toISOString(),
      completed_reason: "manual",
    })
    .eq("id", parsed.data.sessionId)
    .select("id, started_at, completed_at, completed_reason")
    .single<SessionRow>();

  if (error || !row || !row.completed_at || !row.completed_reason) {
    throw new DomainError(
      "internal",
      error?.message ?? "Training konnte nicht beendet werden.",
    );
  }
  return {
    id: row.id,
    startedAt: row.started_at,
    completedAt: row.completed_at,
    completedReason: row.completed_reason,
    vorschlaege: await vorschlaegeFuerAbschluss(
      client,
      parsed.data.sessionId,
      userId,
    ),
  };
}

export const deleteSessionInputSchema = z.object({
  sessionId: z.string().uuid("Die Kennung der Einheit ist keine gueltige UUID."),
});

/**
 * Loescht eine eigene Einheit samt Saetzen (Cascade aus 0013) --
 * Sammelstelle Punkt 19.
 *
 * Idempotent wie deleteMeasurement: eine Einheit, die es nicht (mehr) gibt,
 * ist danach genau das. RLS blendet fremde aus, der Aufruf trifft dann null
 * Zeilen und antwortet trotzdem ohne Fehler -- "nicht gefunden" verriete,
 * dass es die Kennung gibt. Der zusaetzliche Filter auf user_id sagt das
 * auch dem Leser, nicht nur der Policy.
 */
export async function deleteSession(
  client: SupabaseClient,
  rawInput: unknown,
): Promise<void> {
  const parsed = deleteSessionInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  const { error } = await client
    .from("workout_sessions")
    .delete()
    .eq("id", parsed.data.sessionId)
    .eq("user_id", userId);
  if (error) {
    throw new DomainError("internal", "Die Einheit konnte nicht geloescht werden.");
  }
}
