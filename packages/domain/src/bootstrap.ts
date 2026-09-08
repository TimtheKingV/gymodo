import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";

/**
 * Obergrenze fuer die Satzhistorie, aus der die letzten Werte je Kombination
 * abgeleitet werden. "Letzter Satz je Gruppe" laesst sich ueber PostgREST
 * nicht in einer Abfrage ausdruecken, ohne eine Sicht oder Funktion
 * anzulegen; fuer die Groessenordnung eines Studios reicht Lesen und
 * Zusammenfassen. Kommt die Grenze je in Sicht, gehoert das in eine Sicht.
 */
const SET_SCAN_LIMIT = 2000;

export type Bootstrap = {
  studios: Array<{ id: string; name: string; timezone: string }>;
  machines: Array<{
    id: string;
    studioId: string;
    label: string;
    locationNote: string | null;
    status: string;
    tokenHashes: string[];
    /**
     * Unterschiedliche Sessions mit mindestens einem Satz an diesem Geraet.
     * Der Einstieg (designsystem.md SS8) wertet davon nur 0 / 1 / >= 2 aus,
     * deshalb ist die Deckelung durch SET_SCAN_LIMIT unkritisch.
     */
    visitCount: number;
    equipmentModel: {
      id: string;
      name: string;
      manufacturer: string | null;
      photoPath: string | null;
      weightStepKg: number;
      minWeightKg: number;
      maxWeightKg: number | null;
      /**
       * Beschriftungen der Einstellparameter. Ohne sie zeigt der
       * Offline-Zustand den rohen Schluessel ("sitz 4") statt "Sitz 4" --
       * GeraetOffline.dc.html verlangt die Beschriftung.
       */
      settingDefinitions: Array<{
        key: string;
        label: string;
        kind: string;
        minValue: number | null;
        maxValue: number | null;
        stepValue: number | null;
        unit: string | null;
        allowedValues: string[] | null;
      }>;
    };
    exercises: Array<{
      id: string;
      name: string;
      targetRepsMin: number;
      targetRepsMax: number;
    }>;
  }>;
  calibrations: Array<{
    machineId: string;
    exerciseId: string;
    settingValues: unknown;
    schemaVersion: number;
    createdAt: string;
  }>;
  lastSets: Array<{
    machineId: string;
    exerciseId: string;
    weightKg: number;
    reps: number;
    rir: number | null;
    performedAt: string;
  }>;
};

function key(machineId: string, exerciseId: string): string {
  return `${machineId}:${exerciseId}`;
}

/**
 * Besuche je Geraet: unterschiedliche Sessions mit mindestens einem Satz.
 *
 * Ausgelagert, weil `designsystem.md` SS8 daraus den Einstieg ableitet
 * (Erstkontakt / erkannt / direkt zum Satz) und diese Regel testbar sein
 * muss, ohne eine Datenbank zu stellen.
 */
export function zaehleBesucheJeGeraet(
  rows: Array<{ machine_id: string; session_id: string }>,
): Map<string, number> {
  const sessionsJeGeraet = new Map<string, Set<string>>();
  for (const row of rows) {
    const menge = sessionsJeGeraet.get(row.machine_id) ?? new Set<string>();
    menge.add(row.session_id);
    sessionsJeGeraet.set(row.machine_id, menge);
  }
  return new Map(
    [...sessionsJeGeraet].map(([machineId, menge]) => [machineId, menge.size]),
  );
}

/**
 * Alles, was die App beim Start braucht, um danach ohne Empfang zu
 * funktionieren (Spec 6.6).
 *
 * Enthaelt bewusst die Tag-Hashes: die App hasht einen getappten Token
 * lokal und findet das Geraet damit im Cache, noch bevor das Netz antwortet
 * (Spec 8.1, Schritt 3). Unbedenklich, weil Hashes keine Tokens verraten --
 * der Token selbst wird nirgends gespeichert.
 */
export async function getBootstrap(
  client: SupabaseClient,
): Promise<Bootstrap> {
  const userId = await requireUserId(client);

  // RLS beschraenkt jede dieser Abfragen auf die Studios des Mitglieds.
  const { data: studioRows } = await client
    .from("studios")
    .select("id, name, timezone")
    .order("name", { ascending: true });

  const { data: machineRows } = await client
    .from("machines")
    .select(
      "id, studio_id, label, location_note, status, equipment_models (id, name, manufacturer, photo_path, weight_step_kg, min_weight_kg, max_weight_kg)",
    )
    .order("label", { ascending: true });

  const { data: tagRows } = await client
    .from("machine_tags")
    .select("machine_id, token_hash")
    .eq("status", "active");

  const { data: linkRows } = await client
    .from("equipment_model_exercises")
    .select(
      "equipment_model_id, sort_order, exercises (id, name, target_reps_min, target_reps_max)",
    )
    .order("sort_order", { ascending: true });

  const { data: calibrationRows } = await client
    .from("member_machine_calibrations")
    .select("machine_id, exercise_id, setting_values, schema_version, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  const { data: setRows } = await client
    .from("workout_sets")
    .select("machine_id, exercise_id, session_id, weight_kg, reps, rir, performed_at")
    .eq("user_id", userId)
    .order("performed_at", { ascending: false })
    .limit(SET_SCAN_LIMIT);

  const { data: settingRows } = await client
    .from("equipment_setting_definitions")
    .select(
      "equipment_model_id, key, label, kind, min_value, max_value, step_value, unit, allowed_values",
    )
    .order("sort_order", { ascending: true });

  const hashesByMachine = new Map<string, string[]>();
  for (const row of (tagRows ?? []) as Array<{
    machine_id: string | null;
    token_hash: string;
  }>) {
    if (!row.machine_id) continue;
    const list = hashesByMachine.get(row.machine_id) ?? [];
    list.push(row.token_hash);
    hashesByMachine.set(row.machine_id, list);
  }

  const exercisesByModel = new Map<
    string,
    Bootstrap["machines"][number]["exercises"]
  >();
  for (const row of (linkRows ?? []) as unknown as Array<{
    equipment_model_id: string;
    exercises: {
      id: string;
      name: string;
      target_reps_min: number;
      target_reps_max: number;
    };
  }>) {
    const list = exercisesByModel.get(row.equipment_model_id) ?? [];
    list.push({
      id: row.exercises.id,
      name: row.exercises.name,
      targetRepsMin: row.exercises.target_reps_min,
      targetRepsMax: row.exercises.target_reps_max,
    });
    exercisesByModel.set(row.equipment_model_id, list);
  }

  // Absteigend sortiert gelesen -- der erste Treffer je Kombination ist der
  // neueste, alle weiteren sind Historie und gehoeren nicht in den Prefetch.
  const seenCalibration = new Set<string>();
  const calibrations: Bootstrap["calibrations"] = [];
  for (const row of (calibrationRows ?? []) as Array<{
    machine_id: string;
    exercise_id: string;
    setting_values: unknown;
    schema_version: number;
    created_at: string;
  }>) {
    const id = key(row.machine_id, row.exercise_id);
    if (seenCalibration.has(id)) continue;
    seenCalibration.add(id);
    calibrations.push({
      machineId: row.machine_id,
      exerciseId: row.exercise_id,
      settingValues: row.setting_values,
      schemaVersion: row.schema_version,
      createdAt: row.created_at,
    });
  }

  const seenSet = new Set<string>();
  const lastSets: Bootstrap["lastSets"] = [];
  for (const row of (setRows ?? []) as Array<{
    machine_id: string;
    exercise_id: string;
    session_id: string;
    weight_kg: number | string;
    reps: number;
    rir: number | string | null;
    performed_at: string;
  }>) {
    const id = key(row.machine_id, row.exercise_id);
    if (seenSet.has(id)) continue;
    seenSet.add(id);
    lastSets.push({
      machineId: row.machine_id,
      exerciseId: row.exercise_id,
      weightKg: Number(row.weight_kg),
      reps: row.reps,
      rir: row.rir === null ? null : Number(row.rir),
      performedAt: row.performed_at,
    });
  }

  const besucheJeGeraet = zaehleBesucheJeGeraet(
    (setRows ?? []) as Array<{ machine_id: string; session_id: string }>,
  );

  const einstellungenJeModell = new Map<
    string,
    Bootstrap["machines"][number]["equipmentModel"]["settingDefinitions"]
  >();
  for (const row of (settingRows ?? []) as Array<{
    equipment_model_id: string;
    key: string;
    label: string;
    kind: string;
    min_value: number | string | null;
    max_value: number | string | null;
    step_value: number | string | null;
    unit: string | null;
    allowed_values: string[] | null;
  }>) {
    const liste = einstellungenJeModell.get(row.equipment_model_id) ?? [];
    liste.push({
      key: row.key,
      label: row.label,
      kind: row.kind,
      minValue: row.min_value === null ? null : Number(row.min_value),
      maxValue: row.max_value === null ? null : Number(row.max_value),
      stepValue: row.step_value === null ? null : Number(row.step_value),
      unit: row.unit,
      allowedValues: row.allowed_values,
    });
    einstellungenJeModell.set(row.equipment_model_id, liste);
  }

  const machines = ((machineRows ?? []) as unknown as Array<{
    id: string;
    studio_id: string;
    label: string;
    location_note: string | null;
    status: string;
    equipment_models: {
      id: string;
      name: string;
      manufacturer: string | null;
      photo_path: string | null;
      weight_step_kg: number | string;
      min_weight_kg: number | string;
      max_weight_kg: number | string | null;
    };
  }>).map((row) => ({
    id: row.id,
    studioId: row.studio_id,
    label: row.label,
    locationNote: row.location_note,
    status: row.status,
    tokenHashes: hashesByMachine.get(row.id) ?? [],
    visitCount: besucheJeGeraet.get(row.id) ?? 0,
    equipmentModel: {
      id: row.equipment_models.id,
      name: row.equipment_models.name,
      manufacturer: row.equipment_models.manufacturer,
      photoPath: row.equipment_models.photo_path,
      weightStepKg: Number(row.equipment_models.weight_step_kg),
      minWeightKg: Number(row.equipment_models.min_weight_kg),
      maxWeightKg:
        row.equipment_models.max_weight_kg === null
          ? null
          : Number(row.equipment_models.max_weight_kg),
      settingDefinitions: einstellungenJeModell.get(row.equipment_models.id) ?? [],
    },
    exercises: exercisesByModel.get(row.equipment_models.id) ?? [],
  }));

  return {
    studios: (studioRows ?? []) as Bootstrap["studios"],
    machines,
    calibrations,
    lastSets,
  };
}
