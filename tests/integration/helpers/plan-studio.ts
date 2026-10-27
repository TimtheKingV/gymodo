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
  };
}

export type MitgliedOptionen = {
  studios: string[];
  trainingGoal?: string | null;
  weeklyDays?: number | null;
  profil?: { minutes: number; experience: string; focus: string[] } | null;
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
