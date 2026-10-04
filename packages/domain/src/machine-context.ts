import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import {
  MEDIA_URL_TTL_SECONDS,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
} from "./media.js";
import { signMediaUrl, signMediaUrls } from "./media-store.js";
import type { LoadUnit, VolumeKind } from "./belastung.js";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextLoad,
  toBlocks,
  type BlockInput,
  type ProgressionSuggestion,
} from "./progression.js";

/** So viele Trainingstage schaut die Progressionsregel zurueck. */
const HISTORY_DAYS = 6;

export type MachineContext = {
  machine: { id: string; label: string; locationNote: string | null };
  equipmentModel: {
    id: string;
    name: string;
    manufacturer: string | null;
    /**
     * Kurzlebige signierte URL, kein Speicherpfad: der Bucket ist privat,
     * mit einem Pfad allein koennte der Screen nichts laden.
     */
    photoUrl: string | null;
    /** Was am Geraet gedreht wird, und in welcher Einheit (Cardio-Spec 3.1). */
    loadUnit: LoadUnit;
    loadStep: number;
    loadMin: number;
    loadMax: number | null;
    /**
     * Der zweite Intensitaetsregler, wenn das Modell einen hat (Cardio-Spec
     * 3.1b). Alle vier null bei Kraftgeraeten -- dann gibt es kein drittes
     * Rad und keinen Wert im Satz.
     */
    secondaryUnit: LoadUnit | null;
    secondaryStep: number | null;
    secondaryMin: number | null;
    secondaryMax: number | null;
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
    /** Woran der Korridor gemessen wird: Wiederholungen, Sekunden, Meter. */
    volumeKind: VolumeKind;
    targetMin: number;
    targetMax: number;
    /** Ebenfalls signiert; null, solange kein Video da ist (Spec 6.8). */
    instructionVideoUrl: string | null;
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
    load: number;
    secondaryLoad: number | null;
    volume: number[];
  }>;
  suggestion: ProgressionSuggestion;
};

type SetRow = {
  exercise_id: string;
  load: number | string;
  secondary_load: number | string | null;
  volume: number;
  rir: number | string | null;
  problem_flag: boolean;
  performed_at: string;
};

/**
 * Alles, was der Geraete-Screen braucht -- in einer Anfrage.
 *
 * Screenorientiert statt ressourcenorientiert (Spec 6.3): Geraet, Uebungen
 * mit Vorauswahl, Einstellparameter, eigene Kalibrierung, eigene Historie
 * und der Vorschlag kommen zusammen, statt in fuenf Roundtrips.
 *
 * Diese Funktion trug frueher den Namen getTagContext und begann mit einem
 * Tag-Lookup. Seit ein Geraet auch aus einer Liste gewaehlt werden kann,
 * haengt der Rumpf nur noch an der machineId -- getTagContext ist zum
 * Aufloeser geschrumpft und ruft hier herein.
 *
 * Die Autorisierung kommt von RLS: `machines` ist auf die Studios des
 * Mitglieds beschraenkt, ein fremdes Geraet liefert deshalb null. Die
 * Antwort darauf unterscheidet nicht zwischen "gibt es nicht" und "gehoert
 * dir nicht" -- eine machineId ist erratbar, anders als ein Tag-Token, das
 * man am Geraet ablesen muss.
 */
export async function getMachineContext(
  client: SupabaseClient,
  machineId: string,
): Promise<MachineContext> {
  const userId = await requireUserId(client);
  return resolveMachineContext(client, userId, machineId);
}

/**
 * Der Rumpf, sobald die Anmeldung schon steht.
 *
 * requireUserId ist kein lokales Token-Decodieren, sondern ein
 * Netzwerksprung zum Auth-Service (siehe auth.ts) -- auf dem heissesten Pfad
 * im Produkt (jeder Geraete-Scan) darf er nicht doppelt laufen. getTagContext
 * loest den userId deshalb selbst auf, bevor der Tag-Lookup ueberhaupt
 * beginnt, und reicht ihn hier herein statt getMachineContext aufzurufen.
 */
export async function resolveMachineContext(
  client: SupabaseClient,
  userId: string,
  machineId: string,
): Promise<MachineContext> {
  const { data: machine } = await client
    .from("machines")
    .select(
      "id, label, location_note, studio_id, equipment_models (id, name, manufacturer, photo_path, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max)",
    )
    .eq("id", machineId)
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
        load_unit: LoadUnit;
        load_step: number | string;
        load_min: number | string;
        load_max: number | string | null;
        secondary_unit: LoadUnit | null;
        secondary_step: number | string | null;
        secondary_min: number | string | null;
        secondary_max: number | string | null;
      };
    }>();
  if (!machine) {
    throw new DomainError("not_found", "Dieses Geraet ist nicht verfuegbar.");
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
      "sort_order, exercises (id, name, description, volume_kind, target_min, target_max), instruction_assets (storage_path)",
    )
    .eq("equipment_model_id", model.id)
    .order("sort_order", { ascending: true });

  type LinkRow = {
    exercises: {
      id: string;
      name: string;
      description: string | null;
      volume_kind: VolumeKind;
      target_min: number;
      target_max: number;
    };
    instruction_assets: Array<{ storage_path: string }>;
  };
  const linkRows = (links ?? []) as unknown as LinkRow[];

  // Alle Videopfade in einem Aufruf signieren statt je Uebung einzeln --
  // der Screen soll mit einer Anfrage auskommen (Spec 6.3).
  const videoPfade = linkRows
    .map((row) => row.instruction_assets[0]?.storage_path)
    .filter((pfad): pfad is string => Boolean(pfad));
  const [videoUrls, photoUrl] = await Promise.all([
    signMediaUrls(client, VIDEO_BUCKET, videoPfade, MEDIA_URL_TTL_SECONDS),
    model.photo_path
      ? signMediaUrl(client, PHOTO_BUCKET, model.photo_path, MEDIA_URL_TTL_SECONDS)
      : Promise.resolve(null),
  ]);

  const exercises = linkRows.map((row) => {
    const pfad = row.instruction_assets[0]?.storage_path;
    return {
      id: row.exercises.id,
      name: row.exercises.name,
      description: row.exercises.description,
      volumeKind: row.exercises.volume_kind,
      targetMin: row.exercises.target_min,
      targetMax: row.exercises.target_max,
      instructionVideoUrl: (pfad && videoUrls.get(pfad)) || null,
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

  const selectedExerciseId = lastUsed?.exercise_id ?? exercises[0]?.id ?? null;

  let calibration: MachineContext["calibration"] = null;
  let blocks: BlockInput[] = [];
  let suggestion: ProgressionSuggestion = suggestNextLoad({
    targetMin: 0,
    targetMax: 0,
    loadStep: Number(model.load_step),
    loadMin: Number(model.load_min),
    loadMax: Number(model.load_max ?? 9999),
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
      .select("exercise_id, load, secondary_load, volume, rir, problem_flag, performed_at")
      .eq("user_id", userId)
      .eq("machine_id", machine.id)
      .eq("exercise_id", selectedExerciseId)
      .order("performed_at", { ascending: false })
      .limit(HISTORY_DAYS * 6);

    blocks = toBlocks((setRows ?? []) as SetRow[]);

    suggestion = suggestNextLoad({
      targetMin: selected?.targetMin ?? 8,
      targetMax: selected?.targetMax ?? 12,
      loadStep: Number(model.load_step),
      loadMin: Number(model.load_min),
      loadMax: Number(model.load_max ?? 9999),
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
      result_load: suggestion.resultLoad,
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
      photoUrl,
      loadUnit: model.load_unit,
      loadStep: Number(model.load_step),
      loadMin: Number(model.load_min),
      loadMax: model.load_max === null ? null : Number(model.load_max),
      secondaryUnit: model.secondary_unit,
      secondaryStep: model.secondary_step === null ? null : Number(model.secondary_step),
      secondaryMin: model.secondary_min === null ? null : Number(model.secondary_min),
      secondaryMax: model.secondary_max === null ? null : Number(model.secondary_max),
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
      load: block.sets[0]?.load ?? 0,
      secondaryLoad: block.sets[0]?.secondaryLoad ?? null,
      volume: block.sets.map((set) => set.volume),
    })),
    suggestion,
  };
}
