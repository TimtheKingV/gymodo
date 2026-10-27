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
  CARDIO_SELECT,
  cardioAusZeile,
  cardioListeDesModells,
  cardioPruefen,
  cardioWerteSchema,
  cardioZuSpalten,
  type CardioWert,
  type CardioWerte,
  type CardioZeile,
} from "./cardio.js";
import { herkunftPruefen, repEventsSchema, volumeSourceSchema, type VolumeSource } from "./herkunft.js";
import { aktualisierePlanGewichte, initialisierePlanGewichte, ohneAbbruch } from "./plangewichte.js";
import { aktiverPlanImStudio } from "./trainingsplan.js";
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
/** Arbeitssatz oder Aufwaermsatz (Migration 0058). */
export const setRoleSchema = z.enum(["arbeit", "aufwaermen"]);
export type SetRole = z.infer<typeof setRoleSchema>;

/** Status einer Planposition in der laufenden Einheit (Migration 0063). */
export const planPositionStatusSchema = z.enum(["offen", "erledigt", "optional", "getauscht"]);
export type PlanPositionStatus = z.infer<typeof planPositionStatusSchema>;

/**
 * Momentaufnahme des Plans der laufenden Einheit, die die App mit jedem
 * Satz schickt (Etappe 3, Task 4). `stand` zaehlt in der App monoton hoch;
 * der Server uebernimmt nur einen hoeheren als den gespeicherten, weil die
 * App aeltere Rumpfe erneut sendet. `exerciseId` ist die Ersatzuebung der
 * Position, null ohne Tausch. Was davon zum Plan passt, prueft erst
 * record_session_plan. Geparst wird erst NACH dem Satz (siehe recordSet),
 * damit ein kaputter Planteil nie einen Satz verwirft.
 */
export const sessionPlanSchema = z.object({
  planId: z.string().uuid(),
  einheitKey: z.string().min(1),
  stand: z.number().int().min(1).max(2147483647),
  positionen: z.array(
    z.object({
      key: z.string().min(1),
      status: planPositionStatusSchema,
      exerciseId: z.string().uuid().nullish(),
    })
    // Ein Tausch ohne Ersatzuebung sagt nicht, was trainiert wurde.
    .refine((p) => p.status !== "getauscht" || !!p.exerciseId, { path: ["exerciseId"] }),
  ).max(100),
});
export type SessionPlan = z.infer<typeof sessionPlanSchema>;

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
    load: z.number().min(0).max(9999).optional(),
    volume: z.number().int().min(1).max(100000).optional(),
    // Cardio-Werte (Testnotiz 14.10., 18:45 #7); ersetzen load/volume.
    cardio: cardioWerteSchema.optional(),
    secondaryLoad: z.number().min(0).max(9999).nullish(),
    rir: z.number().min(0).max(10).nullish(),
    // Aufwaermsaetze zaehlen fuer keine Regel (Trainingsplan-Spec 7). Fehlt
    // das Feld, ist es ein Arbeitssatz -- auch beim erneuten Senden: der PUT
    // ersetzt den ganzen Satz.
    setRole: setRoleSchema.default("arbeit"),
    problemFlag: z.boolean().default(false),
    problemReason: problemReasonSchema.nullish(),
    // Herkunft der Wiederholungszahl (Sensor-Spec B 6.3). Alte App-Versionen
    // senden nichts davon und landen bei 'eingegeben'.
    volumeSource: volumeSourceSchema.default("eingegeben"),
    volumeCounted: z.number().int().min(1).max(1000).nullish(),
    repEvents: repEventsSchema.nullish(),
    performedAt: z.string().datetime().optional(),
    // Der Beginn der Einheit, vom Client gesetzt ("Training starten",
    // Schnitt 4). Nur beim Anlegen der Session uebernommen, siehe recordSet.
    sessionStartedAt: z.string().datetime().optional(),
    // Alte App-Versionen senden kein plan; ihr Satz laeuft wie bisher.
    // Bewusst ungeprueft: ein formal kaputter Planteil darf den Satz nicht
    // ablehnen -- recordSet prueft ihn erst nach dem Speichern.
    plan: z.unknown().optional(),
  })
  .refine((value) => (value.machineId === undefined) !== (value.equipmentModelId === undefined), {
    path: ["machineId"],
    message: "Ein Satz braucht entweder ein Geraet oder einen Geraetetyp.",
  })
  .refine((v) => v.cardio !== undefined || (v.load !== undefined && v.volume !== undefined), {
    path: ["load"],
    message: "Ein Satz braucht Belastung und Umfang oder Cardio-Werte.",
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
  )
  .superRefine((value, ctx) => {
    const fehler = herkunftPruefen({ ...value, volume: value.volume ?? 0 });
    if (fehler) ctx.addIssue({ code: z.ZodIssueCode.custom, path: ["volumeSource"], message: fehler });
  }),
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
  load: number | null;
  secondaryLoad: number | null;
  volume: number | null;
  /** null bei einem Kraftsatz. */
  cardio: CardioWerte | null;
  rir: number | null;
  setRole: SetRole;
  problemFlag: boolean;
  problemReason: ProblemReason | null;
  volumeSource: VolumeSource;
  /** Zaehlerstand beim Sichern; null bei 'eingegeben'. */
  volumeCounted: number | null;
  performedAt: string;
  /**
   * Nur wenn der PUT einen Planteil trug: ob der Server ihn angenommen hat.
   * false heisst: Satz gespeichert, Planstand passte nicht (Migration 0063).
   */
  planUebernommen?: boolean;
};

type SetRow = CardioZeile & {
  id: string;
  studio_id: string;
  user_id: string;
  session_id: string;
  machine_id: string | null;
  equipment_model_id: string;
  exercise_id: string;
  set_index: number;
  load: number | string | null;
  secondary_load: number | string | null;
  volume: number | null;
  rir: number | string | null;
  set_role: SetRole;
  problem_flag: boolean;
  problem_reason: ProblemReason | null;
  volume_source: VolumeSource;
  volume_counted: number | null;
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
    load: row.load === null ? null : Number(row.load),
    secondaryLoad: row.secondary_load === null ? null : Number(row.secondary_load),
    volume: row.volume,
    cardio: cardioAusZeile(row),
    rir: row.rir === null ? null : Number(row.rir),
    setRole: row.set_role,
    problemFlag: row.problem_flag,
    problemReason: row.problem_reason,
    volumeSource: row.volume_source,
    volumeCounted: row.volume_counted,
    performedAt: row.performed_at,
  };
}

type Nebenbelastung = {
  secondary_unit: LoadUnit | null;
  secondary_step: number | string | null;
  secondary_min: number | string | null;
  secondary_max: number | string | null;
  load_unit: LoadUnit;
  cardio_werte: string[];
  catalog_model_id: string | null;
};

const NEBEN_SPALTEN = "secondary_unit, secondary_step, secondary_min, secondary_max, load_unit, cardio_werte, catalog_model_id";

/** Die Cardio-Liste des Modells, vom Katalog-Typ geerbt, wenn es keine eigene hat. */
async function cardioListe(client: SupabaseClient, modell: Nebenbelastung): Promise<CardioWert[]> {
  if (modell.cardio_werte.length > 0 || !modell.catalog_model_id) {
    return cardioListeDesModells({ eigene: modell.cardio_werte, katalog: null });
  }
  const { data, error } = await client
    .from("equipment_models")
    .select("cardio_werte")
    .eq("id", modell.catalog_model_id)
    .maybeSingle<{ cardio_werte: string[] }>();
  if (error) throw new DomainError("internal", error.message);
  return cardioListeDesModells({ eigene: [], katalog: data?.cardio_werte ?? [] });
}

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
  cardioWerte: CardioWert[];
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
      cardioWerte: await cardioListe(client, machine.equipment_models),
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
  return { studioId, equipmentModelId: modell.id, katalogStudioId, modell, cardioWerte: await cardioListe(client, modell) };
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

  // Cardio (Testnotiz 14.10., 18:45 #7): eine nicht-leere Liste am Geraet.
  // Schickt eine App von vor E2 load/volume an ein Cardio-Geraet, speichert
  // der Satz wie vor E2 und wird genauso geprueft (Final-Review A; Spec 8:
  // die alte App liest load/volume als Pflichtfelder). Die Lesewege leiten
  // die Cardio-Werte daraus ab (cardioDesSatzes), 0055 schreibt sie spaeter um.
  let cardio: CardioWerte | null = null;
  if (input.cardio !== undefined) {
    if (station.cardioWerte.length === 0) {
      throw new DomainError("validation_failed", "Dieses Gerät hat keine Cardio-Werte.");
    }
    if (input.load !== undefined || input.volume !== undefined || (input.secondaryLoad ?? null) !== null) {
      throw new DomainError("validation_failed", "Ein Cardio-Gerät hat keine Belastung.");
    }
    const fehler = cardioPruefen(input.cardio, station.cardioWerte);
    if (fehler) throw new DomainError("validation_failed", fehler);
    cardio = input.cardio;
  }

  let secondaryLoad: number | null = null;
  if (cardio === null) {
    // Die fachliche Obergrenze kennt nur die Uebung: 1000 Wiederholungen,
    // vier Stunden, 100 km. Die Datenbank prueft nur die Schranke gegen
    // Unsinn (Migration 0046).
    if (input.volume! > MAX_VOLUME[exercise.volume_kind]) {
      throw new DomainError("validation_failed", volumeZuGross(exercise.volume_kind));
    }

    // Gezaehlt werden nur Wiederholungen (Sensor-Spec B 6.4). Eine
    // "gemessene" Sekundenzahl waere eine Messung, die nie stattfand.
    if (input.volumeSource !== "eingegeben" && exercise.volume_kind !== "reps") {
      throw new DomainError(
        "validation_failed",
        "Nur Wiederholungen koennen gezaehlt sein.",
      );
    }

    // Nebenbelastung: Pflicht genau dann, wenn das Modell eine hat. Ein Satz
    // am Laufband ohne Neigung waere fuer die Regel eine andere Bedingung als
    // jeder Satz davor; ein Satz an der Beinpresse MIT Neigung ein Wert, den
    // niemand je liest.
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
      load: cardio ? null : input.load,
      secondary_load: cardio ? null : secondaryLoad,
      volume: cardio ? null : input.volume,
      ...cardioZuSpalten(cardio ?? {}),
      rir: input.rir ?? null,
      set_role: input.setRole,
      problem_flag: input.problemFlag,
      problem_reason: input.problemReason ?? null,
      // Ein Cardio-Satz zaehlt nichts: Zaehlerdaten eines fehlerhaften Clients
      // fallen weg, statt die Herkunfts-Check zu reissen -- ein 500 liesse die
      // Warteschlange den Satz ewig wiederholen (Final-Review C).
      volume_source: cardio ? "eingegeben" : input.volumeSource,
      volume_counted: cardio ? null : input.volumeCounted ?? null,
      rep_events: cardio ? null : input.repEvents ?? null,
      // performed_at bleibt beim erneuten Senden unangetastet, weil es hier
      // nur mitgeschickt wird, wenn der Client es ausdruecklich setzt.
      ...(input.performedAt ? { performed_at: input.performedAt } : {}),
    })
    .select(
      `id, studio_id, user_id, session_id, machine_id, equipment_model_id, exercise_id, set_index, load, secondary_load, volume, rir, set_role, problem_flag, problem_reason, volume_source, volume_counted, performed_at, ${CARDIO_SELECT}`,
    )
    .single<SetRow>();

  if (error || !row) {
    throw new DomainError(
      "internal",
      error?.message ?? "Satz konnte nicht gespeichert werden.",
    );
  }

  const satz = toRecordedSet(row);
  if (input.plan === undefined) return satz;
  return { ...satz, planUebernommen: await planUebernehmen(client, input.sessionId, input.plan) };
}

/**
 * Uebernimmt den Planteil eines Satz-PUT -- erst nach dem Satz, denn der
 * Satz ist die eigentliche Leistung, der Planstatus nur eine Ableitung, die
 * der naechste PUT mit hoeherem stand nachholt. Ein Planteil, der nicht passt
 * (Form oder plan_ungueltig), ergibt false statt eines Fehlers: ein 4xx liesse
 * die App einen gespeicherten Satz fuer verloren halten. Jeder andere Fehler
 * ist voruebergehend (Sperre, Verbindung) und wird internal -- die
 * Warteschlange wiederholt den PUT, und der ist idempotent.
 */
async function planUebernehmen(client: SupabaseClient, sessionId: string, roh: unknown): Promise<boolean> {
  const parsed = sessionPlanSchema.safeParse(roh);
  if (!parsed.success) return false;
  const plan = parsed.data;
  const { error } = await client.rpc("record_session_plan", {
    p_session_id: sessionId,
    p_plan_id: plan.planId,
    p_einheit_key: plan.einheitKey,
    p_stand: plan.stand,
    p_positionen: plan.positionen.map((p) => ({ key: p.key, status: p.status, exerciseId: p.exerciseId ?? null })),
  });
  if (!error) return true;
  if (error.code === "P0001" && error.message === "plan_ungueltig") return false;
  throw new DomainError("internal", "Der Planstand konnte nicht gespeichert werden.");
}

export const completeSessionInputSchema = z.object({
  sessionId: z.string().uuid(),
  /** Summe aller Pausen in Sekunden (Testnotiz 14.10., 18:45 #3/#4). Fehlt bei alten Apps. */
  pausedSeconds: z.number().int().min(0).optional(),
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
      ...(parsed.data.pausedSeconds !== undefined
        ? { paused_seconds: parsed.data.pausedSeconds }
        : {}),
    })
    .eq("id", parsed.data.sessionId)
    .select("id, studio_id, started_at, completed_at, completed_reason")
    .single<SessionRow & { studio_id: string }>();

  if (error || !row || !row.completed_at || !row.completed_reason) {
    throw new DomainError(
      "internal",
      error?.message ?? "Training konnte nicht beendet werden.",
    );
  }
  // Erst die Ziele, dann die Vorschlaege: sie lesen die frisch gerechneten Ziele (G17).
  await zielgewichteNachAbschluss(client, userId, row.id, row.studio_id);
  const vorschlaege = await vorschlaegeFuerAbschluss(client, parsed.data.sessionId, userId);
  return {
    id: row.id,
    startedAt: row.started_at,
    completedAt: row.completed_at,
    completedReason: row.completed_reason,
    vorschlaege,
  };
}

/**
 * Zielgewichte nach dem Abschluss (G2): neu rechnen, dann fehlende Ziele des aktiven Plans
 * setzen (G13, spaetestens beim naechsten Abschluss). Wirft nie -- die Einheit ist beendet,
 * egal was hier scheitert. Liegengebliebenes (gewichte_berechnet_at leer oder aelter als
 * der Abschluss) holt der naechste Bootstrap nach, auch ein plan_ungueltig, weil die Uhr
 * des App-Servers vor der Datenbank laeuft.
 */
async function zielgewichteNachAbschluss(
  client: SupabaseClient,
  userId: string,
  sessionId: string,
  studioId: string,
): Promise<void> {
  await ohneAbbruch("Neuberechnung nach Abschluss", () => aktualisierePlanGewichte(client, userId, sessionId));
  await ohneAbbruch("Startwerte nach Abschluss", async () => {
    const plan = await aktiverPlanImStudio(client, userId, studioId);
    if (plan) await initialisierePlanGewichte(client, userId, plan);
  });
}

/** Wie lange nach "Training beenden" ein Fortsetzen geht (Testnotiz 14.10., 18:45 #3). */
export const REOPEN_FENSTER_MS = 30 * 60 * 1000;

export const reopenSessionInputSchema = z.object({
  sessionId: z.string().uuid(),
});

/**
 * Die Regel hinter reopenSession, ohne Datenbank pruefbar. "offen" ist kein
 * Fehler: ein Doppeltipp oder ein Wiederholer nach Netzabbruch trifft eine
 * schon geoeffnete Einheit und soll trotzdem gelingen.
 */
export function wiederoeffnenEntscheidung(
  row: Pick<SessionRow, "completed_at" | "completed_reason">,
  jetzt: Date,
): "offen" | "oeffnen" | { fehler: string } {
  if (row.completed_at === null) return "offen";
  if (row.completed_reason === "auto") {
    return { fehler: "Dieses Training wurde automatisch beendet." };
  }
  if (jetzt.getTime() - Date.parse(row.completed_at) > REOPEN_FENSTER_MS) {
    return { fehler: "Zu spät zum Fortsetzen." };
  }
  return "oeffnen";
}

/**
 * Oeffnet eine von Hand beendete Einheit wieder (Testnotiz 14.10., 18:45
 * #3/#4). paused_seconds bleibt stehen: der naechste Abschluss schreibt die
 * neue Gesamtsumme. Die Vorschlaege des ersten Abschlusses bleiben als
 * Protokoll; beim zweiten Abschluss gilt je Block die juengere Zeile
 * (ausGespeichertenZeilen nimmt die aelteste AB completed_at).
 */
export async function reopenSession(
  client: SupabaseClient,
  rawInput: unknown,
  jetzt: Date = new Date(),
): Promise<{ id: string; startedAt: string }> {
  const parsed = reopenSessionInputSchema.safeParse(rawInput);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  const { data: existing } = await client
    .from("workout_sessions")
    .select("id, started_at, completed_at, completed_reason")
    .eq("id", parsed.data.sessionId)
    .eq("user_id", userId)
    .maybeSingle<SessionRow>();
  if (!existing) {
    throw new DomainError("not_found", "Training nicht gefunden.");
  }

  const entscheidung = wiederoeffnenEntscheidung(existing, jetzt);
  if (typeof entscheidung === "object") {
    throw new DomainError("conflict", entscheidung.fehler);
  }
  if (entscheidung === "oeffnen") {
    const { error } = await client
      .from("workout_sessions")
      .update({ completed_at: null, completed_reason: null })
      .eq("id", existing.id);
    if (error) throw new DomainError("internal", error.message);
  }
  return { id: existing.id, startedAt: existing.started_at };
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
