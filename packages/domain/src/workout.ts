import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

export const problemReasonSchema = z.enum([
  "schmerz",
  "geraet_passt_nicht",
  "zu_schwer",
  "sonstiges",
]);

export type ProblemReason = z.infer<typeof problemReasonSchema>;

/**
 * Eingabe des Satz-PUT.
 *
 * `studioId` steht bewusst NICHT drin: es wird serverseitig aus dem Geraet
 * abgeleitet. Ein Client, der es mitschickt, wird ignoriert -- sonst haetten
 * wir eine Mandantengrenze, die von der App behauptet statt geprueft wird.
 */
export const recordSetInputSchema = z
  .object({
    sessionId: z.string().uuid(),
    setId: z.string().uuid(),
    machineId: z.string().uuid(),
    exerciseId: z.string().uuid(),
    setIndex: z.number().int().min(1),
    weightKg: z.number().min(0).max(9999),
    reps: z.number().int().min(1).max(1000),
    rir: z.number().min(0).max(10).nullish(),
    problemFlag: z.boolean().default(false),
    problemReason: problemReasonSchema.nullish(),
    performedAt: z.string().datetime().optional(),
  })
  .refine((value) => !value.problemReason || value.problemFlag, {
    path: ["problemReason"],
    message: "Eine Problemursache setzt das Problemkennzeichen voraus.",
  });

export type RecordSetInput = z.infer<typeof recordSetInputSchema>;

export type RecordedSet = {
  id: string;
  studioId: string;
  userId: string;
  sessionId: string;
  machineId: string;
  exerciseId: string;
  setIndex: number;
  weightKg: number;
  reps: number;
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
  machine_id: string;
  exercise_id: string;
  set_index: number;
  weight_kg: number | string;
  reps: number;
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
    exerciseId: row.exercise_id,
    setIndex: row.set_index,
    // numeric kommt je nach Treiber als Zeichenkette zurueck.
    weightKg: Number(row.weight_kg),
    reps: row.reps,
    rir: row.rir === null ? null : Number(row.rir),
    problemFlag: row.problem_flag,
    problemReason: row.problem_reason,
    performedAt: row.performed_at,
  };
}

/**
 * Speichert einen bestaetigten Satz.
 *
 * Idempotent durch die clientseitig erzeugten UUIDs: derselbe Aufruf zweimal
 * ergibt dieselbe Zeile (Spec 6.3). Die Session entsteht dabei implizit --
 * es gibt keinen Startknopf und keinen Endpoint dafuer (Spec 5.2).
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

  // Das Studio kommt aus dem Geraet. RLS macht ein fremdes Geraet unsichtbar,
  // der Aufruf endet dann hier statt an einer Policy weiter unten.
  const { data: machine } = await client
    .from("machines")
    .select("studio_id")
    .eq("id", input.machineId)
    .maybeSingle<{ studio_id: string }>();
  if (!machine) {
    throw new DomainError("not_found", "Geraet nicht gefunden.");
  }
  const studioId = machine.studio_id;

  const { data: exercise } = await client
    .from("exercises")
    .select("id")
    .eq("id", input.exerciseId)
    .eq("studio_id", studioId)
    .maybeSingle<{ id: string }>();
  if (!exercise) {
    throw new DomainError("not_found", "Uebung nicht gefunden.");
  }

  // `ignoreDuplicates` macht daraus ON CONFLICT DO NOTHING: ein zweiter Satz
  // in derselben Session verschiebt deren Startzeitpunkt nicht.
  const { error: sessionError } = await client.from("workout_sessions").upsert(
    { id: input.sessionId, studio_id: studioId, user_id: userId },
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
      machine_id: input.machineId,
      exercise_id: input.exerciseId,
      set_index: input.setIndex,
      weight_kg: input.weightKg,
      reps: input.reps,
      rir: input.rir ?? null,
      problem_flag: input.problemFlag,
      problem_reason: input.problemReason ?? null,
      // performed_at bleibt beim erneuten Senden unangetastet, weil es hier
      // nur mitgeschickt wird, wenn der Client es ausdruecklich setzt.
      ...(input.performedAt ? { performed_at: input.performedAt } : {}),
    })
    .select(
      "id, studio_id, user_id, session_id, machine_id, exercise_id, set_index, weight_kg, reps, rir, problem_flag, problem_reason, performed_at",
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
    return {
      id: existing.id,
      startedAt: existing.started_at,
      completedAt: existing.completed_at,
      completedReason: existing.completed_reason,
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
  };
}
