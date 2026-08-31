import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";

/**
 * Obergrenze der gelesenen Saetze. Ausgeliefert werden nur Aggregate; die
 * Grenze schuetzt den Server, nicht die Nutzlast.
 */
const SET_SCAN_LIMIT = 5000;

export const progressOptionsSchema = z.object({
  /** Frueheste Datum (YYYY-MM-DD), das noch beruecksichtigt wird. */
  since: z
    .string()
    .regex(/^\d{4}-\d{2}-\d{2}$/, "Datum im Format YYYY-MM-DD erwartet.")
    .optional(),
});

export type ProgressOptions = z.infer<typeof progressOptionsSchema>;

export type ProgressPoint = {
  performedOn: string;
  topWeightKg: number;
  reps: number;
};

export type ExerciseProgress = {
  exerciseId: string;
  exerciseName: string;
  firstWeightKg: number;
  currentWeightKg: number;
  changeKg: number;
  points: ProgressPoint[];
};

export type Progress = { exercises: ExerciseProgress[] };

type SetRow = {
  exercise_id: string;
  weight_kg: number | string;
  reps: number;
  performed_at: string;
  exercises: { name: string };
};

/**
 * Der Gewichtsverlauf je Uebung, serverseitig zusammengefasst (Spec 5.5).
 *
 * Ausgeliefert werden Aggregate je Uebung und Trainingstag, nie die
 * Rohsatzliste: so bleibt die Nutzlast auch nach einem Jahr Training klein
 * und die Auswertungslogik auf dem Server.
 *
 * Je Tag zaehlt der schwerste bestaetigte Satz. Ein Mittelwert waere
 * irrefuehrend -- er faellt, sobald jemand einen leichten Zusatzsatz anhaengt.
 */
export async function getProgress(
  client: SupabaseClient,
  rawOptions: unknown = {},
): Promise<Progress> {
  const parsed = progressOptionsSchema.safeParse(rawOptions);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }
  const userId = await requireUserId(client);

  let query = client
    .from("workout_sets")
    .select("exercise_id, weight_kg, reps, performed_at, exercises (name)")
    .eq("user_id", userId)
    .order("performed_at", { ascending: true })
    .limit(SET_SCAN_LIMIT);

  if (parsed.data.since) {
    query = query.gte("performed_at", `${parsed.data.since}T00:00:00Z`);
  }

  const { data: setRows } = await query;

  // Je (Uebung, Tag) den schwersten Satz behalten.
  const byExercise = new Map<
    string,
    { name: string; days: Map<string, ProgressPoint> }
  >();
  for (const row of (setRows ?? []) as unknown as SetRow[]) {
    const entry = byExercise.get(row.exercise_id) ?? {
      name: row.exercises.name,
      days: new Map<string, ProgressPoint>(),
    };
    byExercise.set(row.exercise_id, entry);

    const day = row.performed_at.slice(0, 10);
    const weightKg = Number(row.weight_kg);
    const current = entry.days.get(day);
    if (!current || weightKg > current.topWeightKg) {
      entry.days.set(day, {
        performedOn: day,
        topWeightKg: weightKg,
        reps: row.reps,
      });
    }
  }

  const exercises: ExerciseProgress[] = [];
  for (const [exerciseId, entry] of byExercise) {
    const points = [...entry.days.values()].sort((a, b) =>
      a.performedOn.localeCompare(b.performedOn),
    );
    const first = points[0];
    const last = points[points.length - 1];
    if (!first || !last) continue;
    exercises.push({
      exerciseId,
      exerciseName: entry.name,
      firstWeightKg: first.topWeightKg,
      currentWeightKg: last.topWeightKg,
      changeKg: last.topWeightKg - first.topWeightKg,
      points,
    });
  }

  exercises.sort((a, b) => a.exerciseName.localeCompare(b.exerciseName, "de"));
  return { exercises };
}
