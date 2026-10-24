import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { muskelnAusSpalte, type UebungsMuskel } from "./muskeln.js";
import { cardioGeraeteLaden } from "./cardio-geraete.js";
import {
  CARDIO_SELECT,
  cardioDesSatzes,
  cardioListeDesModells,
  type CardioGeraet,
  type CardioWert,
  type CardioWerte,
  type CardioZeile,
} from "./cardio.js";
import type { Category, Group, LoadUnit, VolumeKind } from "./belastung.js";
import { aktiveZiele } from "./goals.js";
import type { AktiveZiele } from "./goals.js";
import type { Messpunkt } from "./measurements.js";
import type { Profil } from "./profil.js";
import { zuProfil } from "./profil.js";
import { stationsSchluessel } from "./station.js";
import { aktivePlaeneDerMitgliedschaften } from "./trainingsplan.js";
import { ladePlaeneFuerApp, type PlanFuerApp } from "./trainingsplan-bootstrap.js";
import { DomainError } from "./errors.js";
import { getTrainingLimits, getTrainingProfile, type TrainingProfile } from "./trainingsprofil.js";

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
    /** Dauer, Erfahrung und Fokus (0060); null, solange das Mitglied keins angelegt hat. */
    trainingProfile: TrainingProfile | null;
    /**
     * Der aktive Plan je Studio, in dem das Mitglied jetzt ist, mit Zaehler und naechster
     * Einheit (Etappe 3). Die Beschwerden selbst stehen bewusst nicht im Bootstrap
     * (Gesundheitsdaten); sie wirken nur auf die Auswahl in alternativen.
     */
    plans: PlanFuerApp[];
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
    load: number | null;
    secondaryLoad: number | null;
    volume: number | null;
    /** Cardio-Werte des Satzes; null bei Kraft (Testnotiz 14.10., 18:45 #7). */
    cardio: CardioWerte | null;
    rir: number | null;
    performedAt: string;
    /**
     * In wie vielen Einheiten die Uebung an dieser Station vorkommt (im
     * Fenster der letzten SET_SCAN_LIMIT Saetze). Die App sortiert danach
     * die Uebungsliste am Geraet (Testnotiz 14.10., 18:25).
     */
    sessionCount: number;
  }>;
  /**
   * Letzte Saetze ohne Geraet, je Gymtavo-Typ und Uebung. Ein eigenes Feld
   * statt lastSets mit machineId null: die App vor Etappe 4 dekodiert
   * machineId als Pflichtfeld und verwuerfe sonst den ganzen Bootstrap.
   */
  lastTypeSets: Array<{
    equipmentModelId: string;
    exerciseId: string;
    load: number | null;
    secondaryLoad: number | null;
    volume: number | null;
    /** Cardio-Werte des Satzes; null bei Kraft (Testnotiz 14.10., 18:45 #7). */
    cardio: CardioWerte | null;
    rir: number | null;
    performedAt: string;
    /**
     * In wie vielen Einheiten die Uebung an dieser Station vorkommt (im
     * Fenster der letzten SET_SCAN_LIMIT Saetze). Die App sortiert danach
     * die Uebungsliste am Geraet (Testnotiz 14.10., 18:25).
     */
    sessionCount: number;
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
  /**
   * Die Kachel in "Geraet waehlen" (Testnotiz 12.10., #3). Immer gesetzt:
   * am Studio-Modell aufgeloest nach `gruppeDesModells`.
   */
  equipmentGroup: Group;
  /**
   * Abgeloest (Testnotiz 12.10., #1): in Listen ausblenden, aber weiter
   * aufloesen -- alte Bloecke und Saetze zeigen noch auf den Typ.
   */
  retired: boolean;
  /**
   * Welche Cardio-Werte das Geraet anbietet; leer bei Kraft. Am Studio-Modell
   * vom Typ geerbt (Testnotiz 14.10., 18:45 #7).
   */
  cardioWerte: CardioWert[];
  loadUnit: LoadUnit;
  loadStep: number;
  loadMin: number;
  loadMax: number | null;
  /**
   * Wo das Rad ohne Historie steht (Testnotiz 12.10. abends, #3). Am
   * Studio-Modell aufgeloest nach `startDesModells`; null heisst Minimum.
   */
  loadStart: number | null;
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
  /** "Worauf du achten musst" -- im Bootstrap, damit die Einweisung offline lesbar ist (Offline-Spec 3b). */
  description: string | null;
  volumeKind: VolumeKind;
  targetMin: number;
  targetMax: number;
  /** Muskeln fuer das Muskelmodell der Einweisung; nie null, ohne Pflege []. */
  muscles: UebungsMuskel[];
};

type UebungZeile = {
  id: string;
  name: string;
  description: string | null;
  volume_kind: VolumeKind;
  target_min: number;
  target_max: number;
  muscles?: UebungsMuskel[] | null;
};

export function uebungAusZeile(z: UebungZeile): Uebung {
  return {
    id: z.id,
    name: z.name,
    description: z.description,
    volumeKind: z.volume_kind,
    targetMin: z.target_min,
    targetMax: z.target_max,
    muscles: muskelnAusSpalte(z.muscles),
  };
}

const MODELL_SPALTEN =
  "id, name, manufacturer, photo_path, category, equipment_group, retired, load_unit, load_step, load_min, load_max, load_start, secondary_unit, secondary_step, secondary_min, secondary_max, catalog_model_id, cardio_werte";

type ModellZeile = {
  id: string;
  name: string;
  manufacturer: string | null;
  photo_path: string | null;
  category: Category;
  equipment_group: Group | null;
  retired: boolean;
  load_unit: LoadUnit;
  load_step: number | string;
  load_min: number | string;
  load_start: number | string | null;
  load_max: number | string | null;
  secondary_unit: LoadUnit | null;
  secondary_step: number | string | null;
  secondary_min: number | string | null;
  secondary_max: number | string | null;
  catalog_model_id: string | null;
  cardio_werte: string[];
};

/**
 * Generisch, damit auch der Plan-Kandidatenlader dieselbe Regel nutzt.
 * Eigene Uebungen zuerst, dann die des Katalogtyps; eine Uebung, die das
 * Studio zusaetzlich selbst angehaengt hat, bleibt an ihrer eigenen Stelle.
 */
export function uebungenMitKatalog<T extends { id: string }>(eigene: T[], katalog: T[]): T[] {
  const gesehen = new Set(eigene.map((uebung) => uebung.id));
  return [...eigene, ...katalog.filter((uebung) => !gesehen.has(uebung.id))];
}

/**
 * Unter welcher Kachel ein Modell steht (Testnotiz 12.10., #3). Ein
 * Studio-Modell traegt keine eigene Gruppe und erbt die seines Gymtavo-Typs;
 * ohne Zuordnung entscheidet die Kategorie. Der Server loest das auf, wie
 * er auch die Uebungen mischt -- die App soll die Regel nicht kennen.
 */
export function gruppeDesModells(m: { eigene: Group | null; katalog: Group | null; category: Category }): Group {
  return m.eigene ?? m.katalog ?? (m.category === "cardio" ? "cardio" : "geraete");
}

/**
 * Wo das Rad eines Modells ohne Historie steht (Testnotiz 12.10. abends,
 * #3). Ein Studio-Modell traegt keinen eigenen Startwert und erbt den
 * seines Gymtavo-Typs -- aber nur bei gleicher Einheit: 20 kg sind an
 * einem Geraet in Level kein Startwert. null heisst: das Minimum.
 */
export function startDesModells(m: {
  eigener: number | null;
  katalog: { start: number | null; einheit: LoadUnit } | null;
  einheit: LoadUnit;
}): number | null {
  if (m.eigener !== null) return m.eigener;
  if (m.katalog && m.katalog.einheit === m.einheit) return m.katalog.start;
  return null;
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

type SatzZeile = CardioZeile & {
  machine_id: string | null;
  equipment_model_id: string;
  exercise_id: string;
  session_id: string;
  load: number | string | null;
  secondary_load: number | string | null;
  volume: number | null;
  rir: number | string | null;
  performed_at: string;
  /** Fuer die Umfangsart eines alten Cardio-Satzes; null nach einem Austritt. */
  exercises?: { volume_kind: VolumeKind } | null;
};

/**
 * Der juengste Satz je Station und Uebung, dazu die Zahl der Einheiten mit
 * dieser Uebung dort. `saetze` kommt absteigend nach performed_at, der
 * erste Satz je Paar ist also der juengste.
 */
export function letzteSaetze(
  saetze: SatzZeile[],
  geraete: Map<string, CardioGeraet> = new Map(),
): Pick<Bootstrap, "lastSets" | "lastTypeSets"> {
  const einheiten = new Map<string, Set<string>>();
  for (const row of saetze) {
    const id = key(stationsSchluessel(row), row.exercise_id);
    const menge = einheiten.get(id) ?? new Set<string>();
    menge.add(row.session_id);
    einheiten.set(id, menge);
  }
  const werte = (row: SatzZeile, id: string) => ({
    exerciseId: row.exercise_id,
    load: row.load === null ? null : Number(row.load),
    secondaryLoad: row.secondary_load === null ? null : Number(row.secondary_load),
    volume: row.volume,
    // Ein alter Satz an einem Cardio-Geraet traegt load/volume UND die daraus
    // abgeleiteten Werte (Final-Review A).
    cardio: cardioDesSatzes(row, geraete.get(row.equipment_model_id), row.exercises?.volume_kind ?? null),
    rir: row.rir === null ? null : Number(row.rir),
    performedAt: row.performed_at,
    sessionCount: einheiten.get(id)?.size ?? 0,
  });

  const seenSet = new Set<string>();
  const lastSets: Bootstrap["lastSets"] = [];
  const lastTypeSets: Bootstrap["lastTypeSets"] = [];
  for (const row of saetze) {
    const id = key(stationsSchluessel(row), row.exercise_id);
    if (seenSet.has(id)) continue;
    seenSet.add(id);
    if (row.machine_id !== null) {
      lastSets.push({ machineId: row.machine_id, ...werte(row, id) });
    } else {
      lastTypeSets.push({ equipmentModelId: row.equipment_model_id, ...werte(row, id) });
    }
  }
  return { lastSets, lastTypeSets };
}

/**
 * Trainingsprofil und Plaene fuer den Bootstrap. Darf den App-Start nie blockieren: der
 * Bootstrap ist der Prefetch fuer das Training ohne Empfang, ein voruebergehender Fehler
 * hier wuerde das Mitglied aussperren. Deshalb faellt jeder Teil still auf einen leeren
 * Stand zurueck, wie die uebrigen Bootstrap-Abfragen.
 *
 * Die Beschwerden werden INNERHALB des Plan-Blocks gelesen: scheitert das Lesen, gibt es
 * plans: [] -- nie Plaene mit ungefilterten alternativen, sonst stuenden gemiedene
 * Uebungen zur Auswahl. Geloggt wird nur Code und feste Meldung, nie Gesundheitsdaten.
 */
export async function ladeTrainingsteil(
  client: SupabaseClient,
  userId: string,
  jetzt: Date,
  melde: (nachricht: string) => void = (n) => console.error(n),
): Promise<{ trainingProfile: TrainingProfile | null; plans: PlanFuerApp[] }> {
  const grund = (e: unknown) => (e instanceof DomainError ? `${e.code}: ${e.message}` : "unerwarteter Fehler");
  const profilAnfrage = getTrainingProfile(client, userId).catch((e: unknown) => {
    melde(`bootstrap: Trainingsprofil nicht geladen (${grund(e)})`);
    return null;
  });
  const plaeneAnfrage = (async () => {
    const [profil, limits, aktive] = await Promise.all([
      profilAnfrage,
      getTrainingLimits(client, userId),
      aktivePlaeneDerMitgliedschaften(client, userId),
    ]);
    return ladePlaeneFuerApp(client, userId, aktive, profil, limits, jetzt);
  })().catch((e: unknown) => {
    melde(`bootstrap: Plaene nicht geladen (${grund(e)})`);
    return [] as PlanFuerApp[];
  });
  const [trainingProfile, plans] = await Promise.all([profilAnfrage, plaeneAnfrage]);
  return { trainingProfile, plans };
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
  // Frueh gestartet, damit seine Rundwege neben den Abfragen unten laufen; faengt selbst ab.
  const trainingsteil = ladeTrainingsteil(client, userId, new Date());

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
      "equipment_model_id, sort_order, exercises (id, name, description, volume_kind, target_min, target_max, muscles)",
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
      `machine_id, equipment_model_id, exercise_id, session_id, load, secondary_load, volume, rir, performed_at, ${CARDIO_SELECT}, exercises (volume_kind)`,
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
    exercises: UebungZeile;
  }>) {
    const list = exercisesByModel.get(row.equipment_model_id) ?? [];
    list.push(uebungAusZeile(row.exercises));
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

  const saetze = (setRows ?? []) as unknown as SatzZeile[];
  const { lastSets, lastTypeSets } = letzteSaetze(
    saetze,
    await cardioGeraeteLaden(
      client,
      saetze.filter((row) => row.load !== null).map((row) => row.equipment_model_id),
    ),
  );

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

  const katalogGruppen = new Map(
    ((katalogModellRows ?? []) as unknown as ModellZeile[]).map((row) => [row.id, row.equipment_group]),
  );
  const katalogCardio = new Map(
    ((katalogModellRows ?? []) as unknown as ModellZeile[]).map((row) => [row.id, row.cardio_werte]),
  );
  const katalogStarts = new Map(
    ((katalogModellRows ?? []) as unknown as ModellZeile[]).map((row) => [
      row.id,
      { start: zahlOderNull(row.load_start), einheit: row.load_unit },
    ]),
  );
  const zuModell = (row: ModellZeile): Geraetemodell => ({
    id: row.id,
    name: row.name,
    manufacturer: row.manufacturer,
    photoPath: row.photo_path,
    category: row.category,
    equipmentGroup: gruppeDesModells({
      eigene: row.equipment_group,
      katalog: row.catalog_model_id ? katalogGruppen.get(row.catalog_model_id) ?? null : null,
      category: row.category,
    }),
    retired: row.retired,
    cardioWerte: cardioListeDesModells({
      eigene: row.cardio_werte,
      katalog: row.catalog_model_id ? katalogCardio.get(row.catalog_model_id) ?? null : null,
    }),
    loadUnit: row.load_unit,
    loadStep: Number(row.load_step),
    loadMin: Number(row.load_min),
    loadMax: zahlOderNull(row.load_max),
    loadStart: startDesModells({
      eigener: zahlOderNull(row.load_start),
      katalog: row.catalog_model_id ? katalogStarts.get(row.catalog_model_id) ?? null : null,
      einheit: row.load_unit,
    }),
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

  const { trainingProfile, plans } = await trainingsteil;

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
      trainingProfile,
      plans,
    },
    studios: (studioRows ?? []) as Bootstrap["studios"],
    catalog,
    machines,
    calibrations,
    lastSets,
    lastTypeSets,
  };
}
