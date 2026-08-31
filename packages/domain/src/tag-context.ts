import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { hashTagToken, isValidTagToken } from "./tags.js";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
  type BlockInput,
  type ProgressionSuggestion,
} from "./progression.js";

/** So viele Trainingstage schaut die Progressionsregel zurueck. */
const HISTORY_DAYS = 6;

export type TagContext = {
  machine: { id: string; label: string; locationNote: string | null };
  equipmentModel: {
    id: string;
    name: string;
    manufacturer: string | null;
    photoPath: string | null;
    weightStepKg: number;
    minWeightKg: number;
    maxWeightKg: number | null;
  };
  settingDefinitions: Array<{
    key: string;
    label: string;
    kind: string;
    minValue: number | null;
    maxValue: number | null;
    stepValue: number | null;
    unit: string | null;
    /** Nur bei kind = 'enum' gesetzt; sonst null (Constraint aus 0017). */
    allowedValues: string[] | null;
  }>;
  exercises: Array<{
    id: string;
    name: string;
    description: string | null;
    targetRepsMin: number;
    targetRepsMax: number;
    instructionVideoPath: string | null;
  }>;
  selectedExerciseId: string | null;
  calibration: {
    settingValues: unknown;
    schemaVersion: number;
    source: string;
    createdAt: string;
  } | null;
  history: Array<{
    performedOn: string;
    weightKg: number;
    reps: number[];
  }>;
  suggestion: ProgressionSuggestion;
};

type SetRow = {
  exercise_id: string;
  weight_kg: number | string;
  reps: number;
  rir: number | string | null;
  problem_flag: boolean;
  performed_at: string;
};

/** Saetze zu Bloecken je Trainingstag gruppieren, neuester zuerst. */
function toBlocks(rows: SetRow[]): BlockInput[] {
  const byDay = new Map<string, BlockInput>();
  for (const row of rows) {
    const day = row.performed_at.slice(0, 10);
    let block = byDay.get(day);
    if (!block) {
      block = { performedOn: day, sets: [] };
      byDay.set(day, block);
    }
    block.sets.push({
      weightKg: Number(row.weight_kg),
      reps: row.reps,
      rir: row.rir === null ? null : Number(row.rir),
      problemFlag: row.problem_flag,
    });
  }
  // Innerhalb eines Tages chronologisch, damit "letzter Satz" stimmt.
  for (const block of byDay.values()) block.sets.reverse();
  return [...byDay.values()];
}

/**
 * Alles, was der Geraete-Screen nach einem Tap braucht -- in einer Anfrage.
 *
 * Screenorientiert statt ressourcenorientiert (Spec 6.3): Geraet, Uebungen
 * mit Vorauswahl, Einstellparameter, eigene Kalibrierung, eigene Historie
 * und der Vorschlag kommen zusammen, statt in fuenf Roundtrips.
 *
 * Der Vorschlag wird hier berechnet UND festgehalten (Spec 8.4) -- damit ist
 * die Nachvollziehbarkeit aus Blueprint 16.8.2 ohne Queue erfuellt.
 *
 * Der Token wird nur gehasht verwendet und nie protokolliert (Spec 10.4).
 */
export async function getTagContext(
  client: SupabaseClient,
  token: string,
): Promise<TagContext> {
  if (!isValidTagToken(token)) {
    throw new DomainError("validation_failed", "Ungueltiges Tokenformat.");
  }
  const userId = await requireUserId(client);

  // RLS blendet Tags fremder Studios aus. Unbekannt, ungueltig und gesperrt
  // liefern deshalb dieselbe Antwort -- sonst liessen sich gueltige Tokens
  // durch Ausprobieren unterscheiden.
  const { data: tag } = await client
    .from("machine_tags")
    .select("machine_id, studio_id")
    .eq("token_hash", hashTagToken(token))
    .eq("status", "active")
    .maybeSingle<{ machine_id: string | null; studio_id: string }>();
  if (!tag?.machine_id) {
    throw new DomainError("not_found", "Dieser Code ist nicht aktiv.");
  }

  const { data: machine } = await client
    .from("machines")
    .select(
      "id, label, location_note, studio_id, equipment_models (id, name, manufacturer, photo_path, weight_step_kg, min_weight_kg, max_weight_kg)",
    )
    .eq("id", tag.machine_id)
    .maybeSingle<{
      id: string;
      label: string;
      location_note: string | null;
      studio_id: string;
      equipment_models: {
        id: string;
        name: string;
        manufacturer: string | null;
        photo_path: string | null;
        weight_step_kg: number | string;
        min_weight_kg: number | string;
        max_weight_kg: number | string | null;
      };
    }>();
  if (!machine) {
    throw new DomainError("not_found", "Dieser Code ist nicht aktiv.");
  }
  const model = machine.equipment_models;

  const { data: settings } = await client
    .from("equipment_setting_definitions")
    .select(
      "key, label, kind, min_value, max_value, step_value, unit, allowed_values",
    )
    .eq("equipment_model_id", model.id)
    .order("sort_order", { ascending: true });

  const { data: links } = await client
    .from("equipment_model_exercises")
    .select(
      "sort_order, exercises (id, name, description, target_reps_min, target_reps_max), instruction_assets (storage_path)",
    )
    .eq("equipment_model_id", model.id)
    .order("sort_order", { ascending: true });

  const exercises = (links ?? []).map((link) => {
    const row = link as unknown as {
      exercises: {
        id: string;
        name: string;
        description: string | null;
        target_reps_min: number;
        target_reps_max: number;
      };
      instruction_assets: Array<{ storage_path: string }>;
    };
    return {
      id: row.exercises.id,
      name: row.exercises.name,
      description: row.exercises.description,
      targetRepsMin: row.exercises.target_reps_min,
      targetRepsMax: row.exercises.target_reps_max,
      // Signierte URLs kommen mit dem Medien-Upload; bis dahin der Pfad.
      instructionVideoPath: row.instruction_assets[0]?.storage_path ?? null,
    };
  });

  // Vorauswahl: zuletzt an diesem Geraet genutzte Uebung, sonst die erste
  // aus der vom Studio gepflegten Reihenfolge (Spec 5.7).
  const { data: lastUsed } = await client
    .from("workout_sets")
    .select("exercise_id")
    .eq("user_id", userId)
    .eq("machine_id", machine.id)
    .order("performed_at", { ascending: false })
    .limit(1)
    .maybeSingle<{ exercise_id: string }>();

  const selectedExerciseId =
    lastUsed?.exercise_id ?? exercises[0]?.id ?? null;

  let calibration: TagContext["calibration"] = null;
  let blocks: BlockInput[] = [];
  let suggestion: ProgressionSuggestion = suggestNextWeight({
    targetRepsMin: 0,
    targetRepsMax: 0,
    weightStepKg: Number(model.weight_step_kg),
    minWeightKg: Number(model.min_weight_kg),
    maxWeightKg: Number(model.max_weight_kg ?? 9999),
    history: [],
  });

  if (selectedExerciseId) {
    const selected = exercises.find((e) => e.id === selectedExerciseId);

    const { data: calibrationRow } = await client
      .from("member_machine_calibrations")
      .select("setting_values, schema_version, source, created_at")
      .eq("user_id", userId)
      .eq("machine_id", machine.id)
      .eq("exercise_id", selectedExerciseId)
      .order("created_at", { ascending: false })
      .limit(1)
      .maybeSingle<{
        setting_values: unknown;
        schema_version: number;
        source: string;
        created_at: string;
      }>();
    if (calibrationRow) {
      calibration = {
        settingValues: calibrationRow.setting_values,
        schemaVersion: calibrationRow.schema_version,
        source: calibrationRow.source,
        createdAt: calibrationRow.created_at,
      };
    }

    const { data: setRows } = await client
      .from("workout_sets")
      .select("exercise_id, weight_kg, reps, rir, problem_flag, performed_at")
      .eq("user_id", userId)
      .eq("machine_id", machine.id)
      .eq("exercise_id", selectedExerciseId)
      .order("performed_at", { ascending: false })
      .limit(HISTORY_DAYS * 6);

    blocks = toBlocks((setRows ?? []) as SetRow[]);

    suggestion = suggestNextWeight({
      targetRepsMin: selected?.targetRepsMin ?? 8,
      targetRepsMax: selected?.targetRepsMax ?? 12,
      weightStepKg: Number(model.weight_step_kg),
      minWeightKg: Number(model.min_weight_kg),
      maxWeightKg: Number(model.max_weight_kg ?? 9999),
      history: blocks,
    });

    // In derselben Anfrage festhalten -- Nachvollziehbarkeit ohne Queue.
    await client.from("progression_suggestions").insert({
      studio_id: machine.studio_id,
      user_id: userId,
      machine_id: machine.id,
      exercise_id: selectedExerciseId,
      algo_version: PROGRESSION_ALGO_VERSION,
      inputs: suggestion.inputs,
      result_weight_kg: suggestion.resultWeightKg,
      reason_code: suggestion.reasonCode,
    });
  }

  return {
    machine: {
      id: machine.id,
      label: machine.label,
      locationNote: machine.location_note,
    },
    equipmentModel: {
      id: model.id,
      name: model.name,
      manufacturer: model.manufacturer,
      photoPath: model.photo_path,
      weightStepKg: Number(model.weight_step_kg),
      minWeightKg: Number(model.min_weight_kg),
      maxWeightKg:
        model.max_weight_kg === null ? null : Number(model.max_weight_kg),
    },
    settingDefinitions: (settings ?? []).map((setting) => {
      const row = setting as unknown as {
        key: string;
        label: string;
        kind: string;
        min_value: number | string | null;
        max_value: number | string | null;
        step_value: number | string | null;
        unit: string | null;
        allowed_values: string[] | null;
      };
      return {
        key: row.key,
        label: row.label,
        kind: row.kind,
        minValue: row.min_value === null ? null : Number(row.min_value),
        maxValue: row.max_value === null ? null : Number(row.max_value),
        stepValue: row.step_value === null ? null : Number(row.step_value),
        unit: row.unit,
        allowedValues: row.allowed_values,
      };
    }),
    exercises,
    selectedExerciseId,
    calibration,
    history: blocks.map((block) => ({
      performedOn: block.performedOn,
      weightKg: block.sets[0]?.weightKg ?? 0,
      reps: block.sets.map((set) => set.reps),
    })),
    suggestion,
  };
}
