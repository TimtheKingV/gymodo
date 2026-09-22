import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import type { LoadUnit, VolumeKind } from "./belastung.js";
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
  topLoad: number;
  volume: number;
};

export type ExerciseProgress = {
  exerciseId: string;
  exerciseName: string;
  /**
   * Das Geraet des juengsten Satzes. Die Uebung allein ("Beidbeinig")
   * traegt keine Bedeutung -- exercises haengt am Studio, nicht am
   * Geraetemodell (0005_exercises.sql).
   */
  machineLabel: string;
  /** Einheit des Geraets des juengsten Satzes -- wie machineLabel. */
  loadUnit: LoadUnit;
  volumeKind: VolumeKind;
  firstLoad: number;
  currentLoad: number;
  changeLoad: number;
  points: ProgressPoint[];
};

export type Progress = { exercises: ExerciseProgress[] };

type SetRow = {
  exercise_id: string;
  load: number | string;
  volume: number;
  performed_at: string;
  exercises: { name: string; volume_kind: VolumeKind };
  machines: { label: string; equipment_models: { load_unit: LoadUnit } };
};

/**
 * Der Gewichtsverlauf je Uebung, serverseitig zusammengefasst (Spec 5.5).
 *
 * Ausgeliefert werden Aggregate je Uebung und Trainingstag, nie die
 * Rohsatzliste: so bleibt die Nutzlast auch nach einem Jahr Training klein
 * und die Auswertungslogik auf dem Server.
 *
 * Je Tag zaehlt der Satz mit der hoechsten Belastung. Ein Mittelwert waere
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
    .select(
      "exercise_id, load, volume, performed_at, exercises (name, volume_kind), machines (label, equipment_models (load_unit))",
    )
    .eq("user_id", userId)
    .order("performed_at", { ascending: true })
    .limit(SET_SCAN_LIMIT);

  if (parsed.data.since) {
    query = query.gte("performed_at", `${parsed.data.since}T00:00:00Z`);
  }

  const { data: setRows } = await query;

  // Je (Uebung, Tag) den Satz mit der hoechsten Belastung behalten.
  const byExercise = new Map<
    string,
    {
      name: string;
      machineLabel: string;
      loadUnit: LoadUnit;
      volumeKind: VolumeKind;
      days: Map<string, ProgressPoint>;
    }
  >();
  for (const row of (setRows ?? []) as unknown as SetRow[]) {
    const entry = byExercise.get(row.exercise_id) ?? {
      name: row.exercises.name,
      machineLabel: row.machines.label,
      loadUnit: row.machines.equipment_models.load_unit,
      volumeKind: row.exercises.volume_kind,
      days: new Map<string, ProgressPoint>(),
    };
    // Aufsteigend sortiert -- die letzte Zeile ist die juengste. Mit dem
    // Geraet wandert die Einheit mit: dieselbe Uebung an einem anderen
    // Modell (Watt statt Level) ist ein Grenzfall, den der Trainer durch
    // getrennte Uebungen vermeidet.
    entry.machineLabel = row.machines.label;
    entry.loadUnit = row.machines.equipment_models.load_unit;
    byExercise.set(row.exercise_id, entry);

    const day = row.performed_at.slice(0, 10);
    const load = Number(row.load);
    const current = entry.days.get(day);
    if (!current || load > current.topLoad) {
      entry.days.set(day, {
        performedOn: day,
        topLoad: load,
        volume: row.volume,
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
      machineLabel: entry.machineLabel,
      loadUnit: entry.loadUnit,
      volumeKind: entry.volumeKind,
      firstLoad: first.topLoad,
      currentLoad: last.topLoad,
      changeLoad: Number((last.topLoad - first.topLoad).toFixed(2)),
      points,
    });
  }

  exercises.sort((a, b) => a.exerciseName.localeCompare(b.exerciseName, "de"));
  return { exercises };
}
