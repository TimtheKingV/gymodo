import type { SupabaseClient } from "@supabase/supabase-js";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./clients.js";

// Testdaten fuer Trainingsplaene (Etappe 2, Task 7). Der echte Gymtavo-Katalog ist
// in Tests nicht geladen; die Typen legt diese Datei unter GYMTAVO selbst an, wie
// trainingsplan-kandidaten.test.ts.
export const GYMTAVO = "00000000-0000-4000-8000-000000000001";

const admin = serviceClient();

async function einfuegen<T = { id: string }>(tabelle: string, zeilen: object | object[]): Promise<T[]> {
  const { data, error } = await admin.from(tabelle).insert(zeilen).select("id");
  if (error) throw error;
  return data as T[];
}

type UebungSpec = { name: string; baustein: string; typ: "mehrgelenk" | "isolation"; bereiche: string[] };

const ALLE: UebungSpec[] = [
  { name: "Beinpresse", baustein: "beine_knie", typ: "mehrgelenk", bereiche: ["knie"] },
  { name: "Hackenschmidt", baustein: "beine_knie", typ: "mehrgelenk", bereiche: [] },
  { name: "Hip Thrust", baustein: "beine_huefte", typ: "mehrgelenk", bereiche: ["huefte"] },
  { name: "Brustpresse", baustein: "druecken", typ: "mehrgelenk", bereiche: ["schulter"] },
  { name: "Latzug", baustein: "ziehen", typ: "mehrgelenk", bereiche: [] },
  { name: "Seitheben", baustein: "schulter", typ: "isolation", bereiche: ["schulter"] },
  { name: "Bizepscurl", baustein: "arme", typ: "isolation", bereiche: ["ellenbogen_handgelenk"] },
  { name: "Bauchmaschine", baustein: "rumpf", typ: "isolation", bereiche: [] },
  { name: "Beinbeuger", baustein: "beine_ergaenzung", typ: "isolation", bereiche: ["knie"] },
  { name: "Crosstrainer", baustein: "cardio", typ: "mehrgelenk", bereiche: [] },
];

export type PlanStudios = {
  voll: string;
  voll2: string;
  ohneDruck: string;
  /** exerciseIds mit Bereich knie -- fuer die Beschwerden-Pruefung. */
  knieUebungen: string[];
  /** exerciseId je Name ohne Kennung ("Beinpresse", "Hackenschmidt", ...). */
  uebungen: Record<string, string>;
  /** Katalogmodell (unter GYMTAVO) mit allen zehn Uebungen / ohne die Druckuebung. */
  katalogModell: string;
  katalogModellOhneDruck: string;
  /** Die Studiomodelle von voll, voll2, ohneDruck (equipment_models eines normalen Studios). */
  studioModelle: { voll: string; voll2: string; ohneDruck: string };
};

/** Drei Studios: zwei mit allen Bausteinen, eins ohne Druckmaschine. */
export async function legePlanStudiosAn(kennung: string): Promise<PlanStudios> {
  const [voll, voll2, ohneDruck] = (
    await einfuegen("studios", [
      { name: `Plan voll ${kennung}` },
      { name: `Plan voll2 ${kennung}` },
      { name: `Plan ohne Druck ${kennung}` },
    ])
  ).map((s) => s.id) as [string, string, string];

  const [typVoll, typOhne] = (
    await einfuegen("equipment_models", [
      { studio_id: GYMTAVO, name: `Planstation ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, cardio_werte: [] },
      { studio_id: GYMTAVO, name: `Planstation ohne Druck ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, cardio_werte: [] },
    ])
  ).map((m) => m.id) as [string, string];

  const uebungen = await einfuegen(
    "exercises",
    ALLE.map((u) => ({
      studio_id: GYMTAVO,
      name: `${u.name} ${kennung}`,
      muscles: [],
      target_min: 8,
      target_max: 12,
      plan_baustein: u.baustein,
      plan_typ: u.typ,
      plan_bereiche: u.bereiche,
    })),
  );
  const ids = uebungen.map((u) => u.id);

  await einfuegen("equipment_model_exercises", [
    ...ids.map((id, i) => ({ equipment_model_id: typVoll, exercise_id: id, sort_order: i + 1 })),
    ...ids
      .filter((_, i) => ALLE[i]!.baustein !== "druecken")
      .map((id, i) => ({ equipment_model_id: typOhne, exercise_id: id, sort_order: i + 1 })),
  ]);

  const modelle = await einfuegen(
    "equipment_models",
    [
      [voll, typVoll],
      [voll2, typVoll],
      [ohneDruck, typOhne],
    ].map(([studio, typ]) => ({
      studio_id: studio,
      name: `Station ${kennung}`,
      category: "kraft",
      load_unit: "kg",
      load_step: 5,
      load_min: 5,
      cardio_werte: [],
      catalog_model_id: typ,
    })),
  );
  await einfuegen(
    "machines",
    [voll, voll2, ohneDruck].map((studio, i) => ({
      studio_id: studio,
      equipment_model_id: modelle[i]!.id,
      label: "S1",
      status: "active",
    })),
  );

  return {
    voll,
    voll2,
    ohneDruck,
    knieUebungen: ids.filter((_, i) => ALLE[i]!.bereiche.includes("knie")),
    uebungen: Object.fromEntries(ALLE.map((u, i) => [u.name, ids[i]!])),
    katalogModell: typVoll,
    katalogModellOhneDruck: typOhne,
    studioModelle: { voll: modelle[0]!.id, voll2: modelle[1]!.id, ohneDruck: modelle[2]!.id },
  };
}

// --- Plan aus dem Katalog (0066) -------------------------------------------------
// Der Plan gehoert dem Katalog-Studio (GYMTAVO); Positionen nennen exerciseId und
// modelId eines Katalogmodells. Der Generator der Fachschicht kennt das noch nicht
// (spaetere Tasks), darum bauen die Tests den Plan hier von Hand und schreiben ihn
// ueber die echten Funktionen.

export type KatalogPosition = {
  key: string;
  exerciseId: string;
  modelId: string;
  baustein: string;
  typ: "mehrgelenk" | "isolation";
  rolle: string;
  hauptmuskeln: string[];
  saetze: number;
  wdhVon: number | null;
  wdhBis: number | null;
  reserveVon: number | null;
  reserveBis: number | null;
  pauseSek: number;
  aufwaermsatz: boolean;
  dauerMin: number | null;
};
export type KatalogEinheit = { key: string; name: string; positionen: KatalogPosition[] };
export type KatalogPlan = {
  id: string;
  studioId: string;
  version: number;
  status: string;
  regelVersion: string;
  eingabe: Record<string, unknown> & { ziel: string; erfahrung: string; beschwerdenBeruecksichtigt: boolean };
  struktur: string;
  einheiten: KatalogEinheit[];
  gruende: string[];
};

const TYP_VON = Object.fromEntries(ALLE.map((u) => [u.name, u]));

function position(s: PlanStudios, key: string, name: string): KatalogPosition {
  const u = TYP_VON[name]!;
  const cardio = u.baustein === "cardio";
  const mg = u.typ === "mehrgelenk";
  return {
    key,
    exerciseId: s.uebungen[name]!,
    modelId: s.katalogModell,
    baustein: u.baustein,
    typ: u.typ,
    rolle: cardio ? "cardio" : mg ? "haupt" : "ergaenzung",
    hauptmuskeln: [],
    saetze: cardio ? 1 : 3,
    wdhVon: cardio ? null : mg ? 8 : 10,
    wdhBis: cardio ? null : mg ? 12 : 15,
    reserveVon: cardio ? null : 1,
    reserveBis: cardio ? null : 3,
    pauseSek: cardio ? 0 : mg ? 150 : 90,
    aufwaermsatz: !cardio && mg,
    dauerMin: cardio ? 10 : null,
  };
}

/** Zwei Einheiten; die erste hat Mehrgelenk, Isolation und Cardio. */
export function katalogEinheiten(s: PlanStudios): KatalogEinheit[] {
  return [
    {
      key: "A",
      name: "Einheit A",
      positionen: ["Beinpresse", "Latzug", "Seitheben", "Bizepscurl", "Crosstrainer"].map((n, i) => position(s, `p${i}`, n)),
    },
    {
      key: "B",
      name: "Einheit B",
      positionen: ["Brustpresse", "Hackenschmidt", "Bauchmaschine"].map((n, i) => position(s, `p${i}`, n)),
    },
  ];
}

type PlanZeileRoh = {
  id: string; studio_id: string; version: number; status: string; regel_version: string;
  eingabe: KatalogPlan["eingabe"]; struktur: string; einheiten: KatalogEinheit[]; gruende: string[];
};
export function zuKatalogPlan(z: PlanZeileRoh): KatalogPlan {
  return {
    id: z.id, studioId: z.studio_id, version: z.version, status: z.status, regelVersion: z.regel_version,
    eingabe: z.eingabe, struktur: z.struktur, einheiten: z.einheiten, gruende: z.gruende,
  };
}

/** Parameter von create_training_plan; Teile lassen sich fuer Negativtests ersetzen. */
export function katalogPlanParameter(s: PlanStudios, o: { limits?: boolean; einheiten?: unknown; studioId?: string | undefined } = {}) {
  return {
    p_studio_id: o.studioId ?? GYMTAVO,
    p_regel_version: "1.3.0",
    p_eingabe: { ziel: "muskelaufbau", erfahrung: "regelmaessig", beschwerdenBeruecksichtigt: o.limits ?? false },
    p_struktur: "gk_ab",
    p_einheiten: o.einheiten ?? katalogEinheiten(s),
    p_gruende: o.limits ? ["beschwerden_meiden", "beschwerden_vorsichtig", "ziel_muskelaufbau"] : ["ziel_muskelaufbau"],
    p_wochenraster: [],
  };
}

/** create_training_plan fuer das Katalog-Studio (Vorschlag). */
export async function erzeugeKatalogPlan(m: Mitglied, s: PlanStudios, o: { limits?: boolean } = {}): Promise<KatalogPlan> {
  const { data, error } = await m.client.rpc("create_training_plan", katalogPlanParameter(s, o)).single();
  if (error) throw error;
  return zuKatalogPlan(data as PlanZeileRoh);
}

export async function nimmKatalogPlanAn(m: Mitglied, planId: string): Promise<KatalogPlan> {
  const { data, error } = await m.client.rpc("accept_training_plan", { p_plan_id: planId }).single();
  if (error) throw error;
  return zuKatalogPlan(data as PlanZeileRoh);
}

/** Vorschlag erzeugen und annehmen. */
export async function aktiverKatalogPlan(m: Mitglied, s: PlanStudios): Promise<KatalogPlan> {
  return nimmKatalogPlanAn(m, (await erzeugeKatalogPlan(m, s)).id);
}

/** Ein aktives Geraet des Studios (fuer Saetze und Negativtests). */
export async function machineVon(studioId: string): Promise<{ id: string; equipment_model_id: string }> {
  const { data, error } = await admin
    .from("machines")
    .select("id, equipment_model_id")
    .eq("studio_id", studioId)
    .eq("status", "active")
    .limit(1)
    .single();
  if (error) throw error;
  return data as { id: string; equipment_model_id: string };
}

export type MitgliedOptionen = {
  studios: string[];
  trainingGoal?: string | null;
  weeklyDays?: number | null;
  profil?: {
    minutes: number;
    experience: string;
    focus: string[];
    // Wochenraster (0069): ISO-Wochentage und Cardio-Arten, Default leer.
    kurs_tage?: number[];
    cardio_tage?: number[];
    cardio_arten?: string[];
    kraft_tage?: number[];
  } | null;
  limits?: Record<string, "meiden" | "vorsichtig"> | null;
};

export type Mitglied = { email: string; userId: string; client: SupabaseClient };

/** Mitglied mit vollstaendigem Profil; jedes Feld kann mit null weggelassen werden. */
export async function legeMitgliedAn(prefix: string, o: MitgliedOptionen): Promise<Mitglied> {
  const email = uniqueEmail(prefix);
  const userId = await createTestUser(email);
  for (const studio of o.studios) {
    await einfuegen("studio_memberships", { studio_id: studio, user_id: userId, role: "member" });
  }
  const goal = o.trainingGoal === undefined ? "build_muscle" : o.trainingGoal;
  const { error } = await admin.from("profiles").upsert({ id: userId, training_goal: goal }, { onConflict: "id" });
  if (error) throw error;
  const tage = o.weeklyDays === undefined ? 3 : o.weeklyDays;
  if (tage !== null) {
    await einfuegen("member_goals", { user_id: userId, kind: "weekly_days", target_value: tage });
  }
  const profil = o.profil === undefined ? { minutes: 60, experience: "regelmaessig", focus: [] } : o.profil;
  if (profil) {
    // training_profiles hat keine id-Spalte, daher ohne einfuegen().
    const { error: e } = await admin.from("training_profiles").insert({ user_id: userId, ...profil });
    if (e) throw e;
  }
  if (o.limits) {
    const { error: e } = await admin
      .from("training_limits")
      .insert({ user_id: userId, consent_at: new Date().toISOString(), areas: o.limits });
    if (e) throw e;
  }
  return { email, userId, client: await userClient(email) };
}

export type EinheitOptionen = {
  planId: string;
  einheitKey: string;
  startedAt: Date;
  /** null: nie beendet (dann entscheidet der letzte Satz). */
  completedAt?: Date | null;
  /** Status je Position; Default eine erledigte Position. */
  status?: string[];
  /** Saetze an einer Planposition, je Zeitpunkt einer. */
  saetzeAm?: Date[];
  satzAn?: { machineId: string; exerciseId: string };
};

/**
 * Legt eine Planeinheit direkt an (Etappe 3, Task 6). Ueber den Service-Client,
 * weil Startzeit und Abschluss in der Vergangenheit liegen muessen -- die Route
 * stempelt immer "jetzt". Der Schutz-Trigger aus 0063 greift nur fuer authenticated.
 */
export async function legeEinheitAn(userId: string, studioId: string, o: EinheitOptionen): Promise<string> {
  const id = crypto.randomUUID();
  const completedAt = o.completedAt === undefined ? new Date(o.startedAt.getTime() + 3_600_000) : o.completedAt;
  const { error } = await admin.from("workout_sessions").insert({
    id,
    studio_id: studioId,
    user_id: userId,
    started_at: o.startedAt.toISOString(),
    completed_at: completedAt?.toISOString() ?? null,
    completed_reason: completedAt ? "manual" : null,
    plan_id: o.planId,
    plan_einheit_key: o.einheitKey,
    plan_stand: 1,
  });
  if (error) throw error;
  const status = o.status ?? ["erledigt"];
  if (status.length > 0) {
    const { error: e } = await admin.from("session_plan_status").insert(
      status.map((s, i) => ({ session_id: id, position_key: `p${i}`, user_id: userId, status: s })),
    );
    if (e) throw e;
  }
  if (o.saetzeAm?.length) {
    if (!o.satzAn) throw new Error("satzAn fehlt");
    const { error: e } = await admin.from("workout_sets").insert(
      o.saetzeAm.map((am, i) => ({
        id: crypto.randomUUID(),
        studio_id: studioId,
        user_id: userId,
        session_id: id,
        machine_id: o.satzAn!.machineId,
        exercise_id: o.satzAn!.exerciseId,
        set_index: i + 1,
        load: 50,
        volume: 10,
        performed_at: am.toISOString(),
      })),
    );
    if (e) throw e;
  }
  return id;
}
