import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import type { Category, LoadUnit, VolumeKind } from "./belastung.js";
import { aktiveZiele } from "./goals.js";
import type { AktiveZiele } from "./goals.js";
import type { Messpunkt } from "./measurements.js";
import type { Profil } from "./profil.js";
import { zuProfil } from "./profil.js";
import { stationsSchluessel } from "./station.js";

/**
 * Obergrenze fuer die Satzhistorie, aus der die letzten Werte je Kombination
 * abgeleitet werden. "Letzter Satz je Gruppe" laesst sich ueber PostgREST
 * nicht in einer Abfrage ausdruecken, ohne eine Sicht oder Funktion
 * anzulegen; fuer die Groessenordnung eines Studios reicht Lesen und
 * Zusammenfassen. Kommt die Grenze je in Sicht, gehoert das in eine Sicht.
 */
const SET_SCAN_LIMIT = 2000;

export type Bootstrap = {
  /**
   * Das Profil als Lesepfad. Alles nullable; `onboardingCompletedAt`
   * entscheidet im Client ueber das Onboarding-Gate, deshalb haengt es am
   * Abruf, der ohnehin bei jedem Start laeuft.
   */
  member: Profil & {
    /**
     * Der juengste Gewichtseintrag, damit die Gewichtskarte auf Home ohne
     * eigenen Verlaufsabruf einen Wert zeigt.
     */
    latestWeight: Messpunkt | null;
    /** Die aktiven Ziele des Mitglieds, siehe Migration 0043. */
    goals: AktiveZiele;
  };
  studios: Array<{ id: string; name: string; timezone: string }>;
  /**
   * Der Gymtavo-Katalog (Migration 0047): die Geraetetypen, die jeder sieht.
   * null nur, wenn es kein Katalog-Studio gibt -- dann hat die App schlicht
   * nichts fuer das Freie Training.
   */
  catalog: {
    studioId: string;
    equipmentTypes: Array<
      Geraetemodell & {
        exercises: Uebung[];
      }
    >;
  } | null;
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
    equipmentModel: Geraetemodell & {
      /** Der Gymtavo-Typ, dem das Studio dieses Modell zugeordnet hat. */
      catalogModelId: string | null;
    };
    /**
     * Die eigenen Uebungen des Modells, danach die Gymtavo-Uebungen des
     * zugeordneten Typs -- jede einmal (Spec 8.1). Der Server mischt, damit
     * die App die Regel nicht ein zweites Mal kennen muss.
     */
    exercises: Uebung[];
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
    load: number;
    secondaryLoad: number | null;
    volume: number;
    rir: number | null;
    performedAt: string;
  }>;
  /**
   * Letzte Saetze ohne Geraet, je Gymtavo-Typ und Uebung. Ein eigenes Feld
   * statt lastSets mit machineId null: die App vor Etappe 4 dekodiert
   * machineId als Pflichtfeld und verwuerfe sonst den ganzen Bootstrap.
   */
  lastTypeSets: Array<{
    equipmentModelId: string;
    exerciseId: string;
    load: number;
    secondaryLoad: number | null;
    volume: number;
    rir: number | null;
    performedAt: string;
  }>;
};

/** Was ein Geraetemodell oder ein Gymtavo-Typ der App mitteilt. */
type Geraetemodell = {
  id: string;
  name: string;
  manufacturer: string | null;
  photoPath: string | null;
  /** Nur Anzeige: Gruppierung in der Geraetesuche (Cardio-Spec 3.5). */
  category: Category;
  loadUnit: LoadUnit;
  loadStep: number;
  loadMin: number;
  loadMax: number | null;
  /** Nebenbelastung, alle vier null bei Kraftgeraeten (Cardio-Spec 3.1b). */
  secondaryUnit: LoadUnit | null;
  secondaryStep: number | null;
  secondaryMin: number | null;
  secondaryMax: number | null;
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

type Uebung = {
  id: string;
  name: string;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
};

const MODELL_SPALTEN =
  "id, name, manufacturer, photo_path, category, load_unit, load_step, load_min, load_max, secondary_unit, secondary_step, secondary_min, secondary_max, catalog_model_id";

type ModellZeile = {
  id: string;
  name: string;
  manufacturer: string | null;
  photo_path: string | null;
  category: Category;
  load_unit: LoadUnit;
  load_step: number | string;
  load_min: number | string;
  load_max: number | string | null;
  secondary_unit: LoadUnit | null;
  secondary_step: number | string | null;
  secondary_min: number | string | null;
  secondary_max: number | string | null;
  catalog_model_id: string | null;
};

/**
 * Eigene Uebungen zuerst, dann die des Katalogtyps; eine Uebung, die das
 * Studio zusaetzlich selbst angehaengt hat, bleibt an ihrer eigenen Stelle.
 */
export function uebungenMitKatalog(eigene: Uebung[], katalog: Uebung[]): Uebung[] {
  const gesehen = new Set(eigene.map((uebung) => uebung.id));
  return [...eigene, ...katalog.filter((uebung) => !gesehen.has(uebung.id))];
}

function key(machineId: string, exerciseId: string): string {
  return `${machineId}:${exerciseId}`;
}

/** numeric kommt je nach Treiber als Zeichenkette zurueck. */
function zahlOderNull(wert: number | string | null): number | null {
  return wert === null ? null : Number(wert);
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

  // RLS beschraenkt diese Abfragen auf die Studios des Mitglieds -- mit
  // einer Ausnahme: den Gymtavo-Katalog liest seit 0047 jeder Angemeldete.
  // Er ist kein Studio des Mitglieds und faellt hier deshalb heraus; die
  // App bekommt ihn gesondert als catalog. Verknuepfungen und
  // Einstellungen weiter unten liefern Katalogzeilen mit; sie landen am
  // Gymtavo-Typ im Block catalog und, ueber catalog_model_id, am Geraet.
  const { data: studioRows } = await client
    .from("studios")
    .select("id, name, timezone")
    .eq("is_catalog", false)
    .order("name", { ascending: true });

  // Das Katalog-Studio ist fuer jeden lesbar; seine Modelle, Verknuepfungen
  // und Einstellungen liefern die Abfragen unten ohnehin mit (RLS seit 0047).
  const { data: katalogRow } = await client
    .from("studios")
    .select("id")
    .eq("is_catalog", true)
    .maybeSingle<{ id: string }>();

  const { data: katalogModellRows } = katalogRow
    ? await client
        .from("equipment_models")
        .select(MODELL_SPALTEN)
        .eq("studio_id", katalogRow.id)
        .order("name", { ascending: true })
    : { data: [] };

  const { data: machineRows } = await client
    .from("machines")
    .select(`id, studio_id, label, location_note, status, equipment_models (${MODELL_SPALTEN})`)
    .order("label", { ascending: true });

  const { data: tagRows } = await client
    .from("machine_tags")
    .select("machine_id, token_hash")
    .eq("status", "active");

  const { data: linkRows } = await client
    .from("equipment_model_exercises")
    .select(
      "equipment_model_id, sort_order, exercises (id, name, volume_kind, target_min, target_max)",
    )
    .order("sort_order", { ascending: true });

  const { data: calibrationRows } = await client
    .from("member_machine_calibrations")
    .select("machine_id, exercise_id, setting_values, schema_version, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  const { data: setRows } = await client
    .from("workout_sets")
    .select(
      "machine_id, equipment_model_id, exercise_id, session_id, load, secondary_load, volume, rir, performed_at",
    )
    .eq("user_id", userId)
    .order("performed_at", { ascending: false })
    .limit(SET_SCAN_LIMIT);

  const { data: settingRows } = await client
    .from("equipment_setting_definitions")
    .select(
      "equipment_model_id, key, label, kind, min_value, max_value, step_value, unit, allowed_values",
    )
    .order("sort_order", { ascending: true });

  const { data: profilRow } = await client
    .from("profiles")
    .select("display_name, sex, age_band, height_cm, training_goal, onboarding_completed_at")
    .eq("id", userId)
    .maybeSingle();

  const { data: weightRow } = await client
    .from("body_measurements")
    .select("measured_on, weight_kg")
    .eq("user_id", userId)
    .order("measured_on", { ascending: false })
    .limit(1)
    .maybeSingle();

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

  const exercisesByModel = new Map<string, Uebung[]>();
  for (const row of (linkRows ?? []) as unknown as Array<{
    equipment_model_id: string;
    exercises: {
      id: string;
      name: string;
      volume_kind: VolumeKind;
      target_min: number;
      target_max: number;
    };
  }>) {
    const list = exercisesByModel.get(row.equipment_model_id) ?? [];
    list.push({
      id: row.exercises.id,
      name: row.exercises.name,
      volumeKind: row.exercises.volume_kind,
      targetMin: row.exercises.target_min,
      targetMax: row.exercises.target_max,
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

  type SatzZeile = {
    machine_id: string | null;
    equipment_model_id: string;
    exercise_id: string;
    session_id: string;
    load: number | string;
    secondary_load: number | string | null;
    volume: number;
    rir: number | string | null;
    performed_at: string;
  };
  const saetze = (setRows ?? []) as SatzZeile[];
  const werte = (row: SatzZeile) => ({
    exerciseId: row.exercise_id,
    load: Number(row.load),
    secondaryLoad: row.secondary_load === null ? null : Number(row.secondary_load),
    volume: row.volume,
    rir: row.rir === null ? null : Number(row.rir),
    performedAt: row.performed_at,
  });

  const seenSet = new Set<string>();
  const lastSets: Bootstrap["lastSets"] = [];
  const lastTypeSets: Bootstrap["lastTypeSets"] = [];
  for (const row of saetze) {
    const id = key(stationsSchluessel(row), row.exercise_id);
    if (seenSet.has(id)) continue;
    seenSet.add(id);
    if (row.machine_id !== null) {
      lastSets.push({ machineId: row.machine_id, ...werte(row) });
    } else {
      lastTypeSets.push({ equipmentModelId: row.equipment_model_id, ...werte(row) });
    }
  }

  const besucheJeGeraet = zaehleBesucheJeGeraet(
    saetze.filter(
      (row): row is SatzZeile & { machine_id: string } => row.machine_id !== null,
    ),
  );

  const einstellungenJeModell = new Map<
    string,
    Geraetemodell["settingDefinitions"]
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

  const zuModell = (row: ModellZeile): Geraetemodell => ({
    id: row.id,
    name: row.name,
    manufacturer: row.manufacturer,
    photoPath: row.photo_path,
    category: row.category,
    loadUnit: row.load_unit,
    loadStep: Number(row.load_step),
    loadMin: Number(row.load_min),
    loadMax: zahlOderNull(row.load_max),
    secondaryUnit: row.secondary_unit,
    secondaryStep: zahlOderNull(row.secondary_step),
    secondaryMin: zahlOderNull(row.secondary_min),
    secondaryMax: zahlOderNull(row.secondary_max),
    settingDefinitions: einstellungenJeModell.get(row.id) ?? [],
  });

  const machines = ((machineRows ?? []) as unknown as Array<{
    id: string;
    studio_id: string;
    label: string;
    location_note: string | null;
    status: string;
    equipment_models: ModellZeile;
  }>).map((row) => ({
    id: row.id,
    studioId: row.studio_id,
    label: row.label,
    locationNote: row.location_note,
    status: row.status,
    tokenHashes: hashesByMachine.get(row.id) ?? [],
    visitCount: besucheJeGeraet.get(row.id) ?? 0,
    equipmentModel: {
      ...zuModell(row.equipment_models),
      catalogModelId: row.equipment_models.catalog_model_id,
    },
    exercises: uebungenMitKatalog(
      exercisesByModel.get(row.equipment_models.id) ?? [],
      row.equipment_models.catalog_model_id
        ? exercisesByModel.get(row.equipment_models.catalog_model_id) ?? []
        : [],
    ),
  }));

  const catalog: Bootstrap["catalog"] = katalogRow
    ? {
        studioId: katalogRow.id,
        equipmentTypes: ((katalogModellRows ?? []) as unknown as ModellZeile[]).map((row) => ({
          ...zuModell(row),
          exercises: exercisesByModel.get(row.id) ?? [],
        })),
      }
    : null;

  const weight = weightRow as { measured_on: string; weight_kg: number | string } | null;

  return {
    member: {
      ...zuProfil(
        (profilRow as Parameters<typeof zuProfil>[0] | null) ?? {
          display_name: null, sex: null, age_band: null, height_cm: null,
          training_goal: null, onboarding_completed_at: null,
        },
      ),
      latestWeight: weight ? { measuredOn: weight.measured_on, weightKg: Number(weight.weight_kg) } : null,
      goals: await aktiveZiele(client, userId),
    },
    studios: (studioRows ?? []) as Bootstrap["studios"],
    catalog,
    machines,
    calibrations,
    lastSets,
    lastTypeSets,
  };
}
