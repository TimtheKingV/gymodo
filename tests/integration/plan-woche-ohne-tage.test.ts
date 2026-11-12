import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";
import { legeMitgliedAn, legePlanStudiosAn, type Mitglied, type PlanStudios } from "./helpers/plan-studio.js";

// Wochenplan ohne feste Tage (Task 1, Migration 0072): Zaehler im Profil und
// Cardio-Haken mit id. Alle Mitglieds-Aufrufe laufen mit dem Client des
// Mitglieds, damit RLS und Rechte wirklich greifen. Nutzer, Plaene und Haken
// haengen per cascade an auth.users; die Studios bleiben wie in den anderen
// Plan-Tests stehen.
const admin = serviceClient();
const kennung = crypto.randomUUID();
let s: PlanStudios;

const MIGRATION = new URL("../../supabase/migrations/0072_woche_ohne_tage.sql", import.meta.url);

/** Die Befuellungs-Anweisung der Migration (zwischen den Markern), unveraendert. */
function befuellenSql(): string {
  const text = readFileSync(MIGRATION, "utf8");
  const m = /-- befuellen:start\n([\s\S]*?)-- befuellen:end/.exec(text);
  if (!m) throw new Error("Marker befuellen:start/end fehlen in 0072");
  return m[1]!;
}

/** Fuehrt SQL im lokalen Supabase-Postgres aus (die Testdatenbank ist ein Docker-Container). */
function psql(sql: string): void {
  execFileSync(
    "docker",
    ["exec", "-i", "supabase_db_m0-fundament", "psql", "-U", "postgres", "-v", "ON_ERROR_STOP=1", "-q"],
    { input: sql },
  );
}

async function profil(userId: string) {
  const { data, error } = await admin
    .from("training_profiles")
    .select("kraft_pro_woche, cardio_pro_woche, cardio_minuten")
    .eq("user_id", userId)
    .single();
  if (error) throw error;
  return data as { kraft_pro_woche: number | null; cardio_pro_woche: number; cardio_minuten: number };
}

async function leereZaehler(userId: string) {
  const { error } = await admin
    .from("training_profiles")
    .update({ kraft_pro_woche: null, cardio_pro_woche: 0, cardio_minuten: 30 })
    .eq("user_id", userId);
  if (error) throw error;
}

const basis = { minutes: 60, experience: "regelmaessig", focus: [] as string[] };

beforeAll(async () => {
  s = await legePlanStudiosAn(kennung);
});

describe("Befuellung der Zaehler", () => {
  it("befuellt kraft_pro_woche aus kraft_tage", async () => {
    const m = await legeMitgliedAn("wot-kt", { studios: [s.voll], profil: { ...basis, kraft_tage: [2, 5] } });
    await leereZaehler(m.userId);
    psql(befuellenSql());
    expect((await profil(m.userId)).kraft_pro_woche).toBe(2);
  });

  it("befuellt aus dem wochenraster des aktiven Plans, wenn kraft_tage leer", async () => {
    const m = await legeMitgliedAn("wot-raster", { studios: [s.voll], profil: { ...basis } });
    const { error } = await admin.from("training_plans").insert({
      user_id: m.userId,
      studio_id: s.voll,
      version: 1,
      status: "aktiv",
      regel_version: "1.3.0",
      eingabe: {},
      struktur: "ganzkoerper",
      einheiten: [],
      gruende: [],
      wochenraster: [
        { tag: 1, art: "kraft", einheitKey: "a" },
        { tag: 2, art: "kurs" },
        { tag: 3, art: "kraft", einheitKey: "b" },
        { tag: 5, art: "kraft", einheitKey: "a" },
      ],
    });
    if (error) throw error;
    await leereZaehler(m.userId);
    psql(befuellenSql());
    expect((await profil(m.userId)).kraft_pro_woche).toBe(3);
  });

  it("laesst kraft_pro_woche null ohne Quelle", async () => {
    const m = await legeMitgliedAn("wot-leer", { studios: [s.voll], profil: { ...basis } });
    await leereZaehler(m.userId);
    psql(befuellenSql());
    expect((await profil(m.userId)).kraft_pro_woche).toBeNull();
  });

  it("cardio_pro_woche = cardinality(cardio_tage); cardio_minuten = 30", async () => {
    const m = await legeMitgliedAn("wot-cardio", { studios: [s.voll], profil: { ...basis, cardio_tage: [3, 6] } });
    await leereZaehler(m.userId);
    psql(befuellenSql());
    const p = await profil(m.userId);
    expect(p.cardio_pro_woche).toBe(2);
    expect(p.cardio_minuten).toBe(30);
  });
});

describe("Wertebereiche", () => {
  let m: Mitglied;
  beforeAll(async () => {
    m = await legeMitgliedAn("wot-bereich", { studios: [s.voll], profil: { ...basis } });
  });

  it("kraft_pro_woche 0 und 8 werden abgelehnt, 1 und 7 nicht", async () => {
    for (const wert of [0, 8]) {
      const { error } = await admin.from("training_profiles").update({ kraft_pro_woche: wert }).eq("user_id", m.userId);
      expect(error?.code, `kraft_pro_woche ${wert}`).toBe("23514");
    }
    for (const wert of [1, 7]) {
      const { error } = await admin.from("training_profiles").update({ kraft_pro_woche: wert }).eq("user_id", m.userId);
      expect(error).toBeNull();
    }
  });

  it("cardio_minuten 9 und 181 abgelehnt", async () => {
    for (const wert of [9, 181]) {
      const { error } = await admin.from("training_profiles").update({ cardio_minuten: wert }).eq("user_id", m.userId);
      expect(error?.code, `cardio_minuten ${wert}`).toBe("23514");
    }
  });

  it("cardio_pro_woche 8 abgelehnt", async () => {
    const { error } = await admin.from("training_profiles").update({ cardio_pro_woche: 8 }).eq("user_id", m.userId);
    expect(error?.code).toBe("23514");
  });
});

describe("cardio_checks", () => {
  it("erlaubt zwei Zeilen am selben Tag, beide sichtbar, id gesetzt", async () => {
    const m = await legeMitgliedAn("wot-checks", { studios: [s.voll], profil: null });
    const day = "2026-11-10";
    for (const minuten of [20, null]) {
      const { error } = await m.client.from("cardio_checks").insert({ user_id: m.userId, day, minuten });
      expect(error).toBeNull();
    }
    const { data, error } = await m.client.from("cardio_checks").select("id, day, minuten").eq("day", day);
    expect(error).toBeNull();
    expect(data).toHaveLength(2);
    expect(data!.every((z) => typeof z.id === "string" && z.id.length > 0)).toBe(true);
    expect(data!.map((z) => z.minuten).sort()).toEqual([20, null]);
  });

  it("lehnt minuten 0 und 601 ab", async () => {
    const m = await legeMitgliedAn("wot-min", { studios: [s.voll], profil: null });
    for (const minuten of [0, 601]) {
      const { error } = await m.client.from("cardio_checks").insert({ user_id: m.userId, day: "2026-11-10", minuten });
      expect(error?.code, `minuten ${minuten}`).toBe("23514");
    }
  });
});

describe("course_bookings mit course_sessions", () => {
  it("Mitglied liest eigene Buchung mit starts_at/status, keine fremde", async () => {
    const a = await legeMitgliedAn("wot-kurs-a", { studios: [s.voll], profil: null });
    const b = await legeMitgliedAn("wot-kurs-b", { studios: [s.voll], profil: null });
    const { data: vorlage, error: e1 } = await admin
      .from("course_templates")
      .insert({ studio_id: s.voll, name: `Zirkel ${kennung}`, default_duration_min: 45, default_capacity: 10 })
      .select("id")
      .single();
    if (e1) throw e1;
    const { data: termin, error: e2 } = await admin
      .from("course_sessions")
      .insert({
        studio_id: s.voll,
        course_template_id: vorlage!.id,
        starts_at: new Date(Date.now() + 2 * 86_400_000).toISOString(),
        duration_min: 45,
        capacity: 10,
      })
      .select("id")
      .single();
    if (e2) throw e2;
    for (const u of [a, b]) {
      const { error } = await admin.from("course_bookings").insert({
        id: crypto.randomUUID(),
        studio_id: s.voll,
        course_session_id: termin!.id,
        user_id: u.userId,
        status: "booked",
      });
      if (error) throw error;
    }
    const { data, error } = await a.client
      .from("course_bookings")
      .select("user_id, status, course_sessions!inner(starts_at, status)");
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data![0]!.user_id).toBe(a.userId);
    const cs = data![0]!.course_sessions as unknown as { starts_at: string; status: string };
    expect(cs.starts_at).toBeTruthy();
    expect(cs.status).toBeTruthy();
  });
});
