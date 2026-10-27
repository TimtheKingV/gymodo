import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import {
  acceptPlan,
  aktualisierePlanGewichte,
  completeSession,
  erzeugePlanVorschlag,
  getBootstrap,
  getMachineContext,
  initialisierePlanGewichte,
  PLANGEWICHT_ALGO_VERSION,
  ladeZielgewichte,
  tauschePlanPosition,
  zielSchluessel,
  type TrainingPlan,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";
import { GYMTAVO, legeMitgliedAn, legePlanStudiosAn, machineVon, type Mitglied, type PlanStudios } from "./helpers/plan-studio.js";
import type { SupabaseClient } from "@supabase/supabase-js";

// Etappe 4, Task 4: Zielgewichte nach einer abgeschlossenen Einheit neu
// rechnen (G2-G5, G9, G12-G16, G21). Jeder Test baut ein eigenes Studio mit
// eigenen Geraeten, ein eigenes Katalogmodell und einen direkt eingefuegten Plan
// (Eigentuemer ist das Katalog-Studio, 0066), damit Historie und Zielgewichte sich
// zwischen den Tests nicht beruehren. Die Zielgewichte haengen an der Uebung, nicht am
// Geraet (Trainingsplan aus dem Katalog, Task 4). Ein Mitglied fuer alle
// Tests: der lokale Auth-Dienst ist langsam.
const admin = serviceClient();
let userId: string;
let client: SupabaseClient;

beforeAll(async () => {
  const email = uniqueEmail("plangewichte");
  userId = await createTestUser(email);
  const { error } = await admin.from("profiles").upsert({ id: userId, training_goal: "build_muscle" }, { onConflict: "id" });
  if (error) throw error;
  client = await userClient(email);
});

async function einfuegen(tabelle: string, zeilen: object | object[]): Promise<Array<{ id: string }>> {
  const { data, error } = await admin.from(tabelle).insert(zeilen).select("id");
  if (error) throw error;
  return data as Array<{ id: string }>;
}

type Uebung = "bank" | "rudern" | "fly" | "bein" | "cardio";
const MUSKEL: Record<Uebung, string> = { bank: "brust", rudern: "ruecken", fly: "brust", bein: "quads", cardio: "herz" };

type Welt = {
  studioId: string;
  /** Modell des Studios (an ihm haengen die Geraete und Saetze). */
  modellId: string;
  /** Katalogmodell (unter GYMTAVO) mit denselben Grenzen; ihm gehoeren die Planpositionen. */
  katalogModellId: string;
  ex: Record<Uebung, string>;
  m: Record<Uebung, string>;
};

async function neuesKatalogModell(kennung: string): Promise<string> {
  const [modell] = await einfuegen("equipment_models", {
    studio_id: GYMTAVO,
    name: `Katalog ${kennung}`,
    category: "kraft",
    load_unit: "kg",
    load_step: 2.5,
    load_min: 5,
    load_max: 100,
    load_start: 40,
    cardio_werte: [],
  });
  return modell!.id;
}

// Der Katalog ist geteilt und waechst mit jedem Testlauf; darum ein Katalogmodell fuer
// alle Tests, ausser dort, wo ein Test dessen Grenzen aendert.
let geteilt: Promise<string> | undefined;
function geteiltesKatalogModell(): Promise<string> {
  return (geteilt ??= neuesKatalogModell(crypto.randomUUID().slice(0, 8)));
}

/** Studio mit je einem Geraet je Uebung; Stufe 2,5, 5..100 kg, Startwert 40. */
async function welt(eigenesKatalogModell = false): Promise<Welt> {
  const kennung = crypto.randomUUID().slice(0, 8);
  const [studio] = await einfuegen("studios", { name: `Plangewichte ${kennung}` });
  const studioId = studio!.id;
  await einfuegen("studio_memberships", { studio_id: studioId, user_id: userId, role: "member" });
  const [modell] = await einfuegen("equipment_models", {
    studio_id: studioId,
    name: `Station ${kennung}`,
    category: "kraft",
    load_unit: "kg",
    load_step: 2.5,
    load_min: 5,
    load_max: 100,
    load_start: 40,
    cardio_werte: [],
  });
  const katalogModellId = eigenesKatalogModell ? await neuesKatalogModell(kennung) : await geteiltesKatalogModell();
  const namen: Uebung[] = ["bank", "rudern", "fly", "bein", "cardio"];
  const uebungen = await einfuegen(
    "exercises",
    namen.map((n) => ({
      studio_id: studioId,
      name: `${n} ${kennung}`,
      muscles: [{ key: MUSKEL[n], name: MUSKEL[n], role: "primary" }],
      target_min: 8,
      target_max: 12,
    })),
  );
  const maschinen = await einfuegen(
    "machines",
    namen.map((n) => ({ studio_id: studioId, equipment_model_id: modell!.id, label: n, status: "active" })),
  );
  const ex = Object.fromEntries(namen.map((n, i) => [n, uebungen[i]!.id])) as Record<Uebung, string>;
  const m = Object.fromEntries(namen.map((n, i) => [n, maschinen[i]!.id])) as Record<Uebung, string>;
  return { studioId, modellId: modell!.id, katalogModellId, ex, m };
}

/** Planposition; Schluessel = Einheit + Uebung. */
function pos(w: Welt, einheit: string, u: Uebung, bereich: [number, number] = [8, 12]) {
  const cardio = u === "cardio";
  return {
    key: `${einheit}-${u}`,
    baustein: cardio ? "cardio" : u === "bein" ? "beine_knie" : u === "rudern" ? "ziehen" : "druecken",
    rolle: cardio ? "cardio" : "pflicht",
    exerciseId: w.ex[u],
    modelId: w.katalogModellId,
    typ: "mehrgelenk",
    saetze: 3,
    wdhVon: cardio ? null : bereich[0],
    wdhBis: cardio ? null : bereich[1],
    reserveVon: 2,
    reserveBis: 3,
    pauseSek: 90,
    aufwaermsatz: false,
    dauerMin: cardio ? 10 : null,
    hauptmuskeln: [MUSKEL[u]],
  };
}

/** Aktiver Plan, direkt eingefuegt (Struktur frei waehlbar). */
/** `nummeriert`: Positionsschluessel je Einheit "0", "1", ... wie der Generator. */
async function plan(w: Welt, einheiten: Record<string, Uebung[]>, nummeriert = false): Promise<TrainingPlan> {
  const liste = Object.entries(einheiten).map(([key, us]) => ({
    key,
    positionen: us.map((u, i) => ({ ...pos(w, key, u), ...(nummeriert ? { key: String(i) } : {}) })),
    geschaetzteMinuten: 45,
  }));
  const eingabe = {
    ziel: "muskelaufbau",
    tage: 3,
    minuten: 60,
    fokus: [],
    erfahrung: "regelmaessig",
    anfaengerBeendet: false,
    beschwerdenBeruecksichtigt: false,
  };
  // Ein Plan je Mitglied: der Plan des vorigen Tests wird abgeloest, seine Ziele bleiben.
  const { error: abloesen } = await admin
    .from("training_plans")
    .update({ status: "ersetzt" })
    .eq("user_id", userId)
    .eq("status", "aktiv");
  if (abloesen) throw abloesen;
  // Einheiten frueherer Tests (ein Mitglied fuer alle) duerfen weder als "laeuft gerade" (G15)
  // noch als juengste gezaehlte Einheit (naechste Einheit) mitspielen: weit zurueckdatieren.
  const { error: beenden } = await admin
    .from("workout_sessions")
    .update({ started_at: "2020-01-01T10:00:00Z", completed_at: "2020-01-01T11:00:00Z", completed_reason: "manual" })
    .eq("user_id", userId);
  if (beenden) throw beenden;
  const { data: bisher, error: zaehlen } = await admin.from("training_plans").select("version").eq("user_id", userId);
  if (zaehlen) throw zaehlen;
  const version = Math.max(0, ...(bisher ?? []).map((z) => z.version as number)) + 1;
  const { data, error } = await admin
    .from("training_plans")
    .insert({
      user_id: userId,
      studio_id: GYMTAVO,
      version,
      status: "aktiv",
      regel_version: "test",
      eingabe,
      struktur: "gk_abc",
      einheiten: liste,
      gruende: [],
      accepted_at: new Date().toISOString(),
    })
    .select("id, created_at, accepted_at")
    .single();
  if (error) throw error;
  return {
    id: data.id,
    studioId: GYMTAVO,
    version,
    status: "aktiv",
    regelVersion: "test",
    eingabe: eingabe as unknown as TrainingPlan["eingabe"],
    struktur: "gk_abc",
    einheiten: liste as unknown as TrainingPlan["einheiten"],
    gruende: [],
    createdAt: data.created_at,
    acceptedAt: data.accepted_at,
  };
}

const JETZT = Date.now();
const vorStunden = (h: number) => new Date(JETZT - h * 3_600_000);

type Satz = {
  u: Uebung;
  load: number;
  volume: number;
  rir?: number | null;
  rolle?: "arbeit" | "aufwaermen";
  /** Freies Training: der Satz hat kein Geraet (machine_id null). */
  ohneGeraet?: boolean;
};

/**
 * Session einer Planeinheit mit Saetzen; completedAt null = offen. Die Saetze
 * liegen im Minutenabstand ab startedAt.
 */
async function einheit(
  w: Welt,
  p: TrainingPlan,
  einheitKey: string,
  o: { startedAt: Date; completedAt?: Date | null; saetze?: Satz[]; status?: Array<{ key: string; status: string; exerciseId?: string }> },
): Promise<string> {
  const id = crypto.randomUUID();
  const completedAt = o.completedAt === undefined ? new Date(o.startedAt.getTime() + 3_600_000) : o.completedAt;
  const { error } = await admin.from("workout_sessions").insert({
    id,
    studio_id: w.studioId,
    user_id: userId,
    started_at: o.startedAt.toISOString(),
    completed_at: completedAt?.toISOString() ?? null,
    completed_reason: completedAt ? "manual" : null,
    plan_id: p.id,
    plan_einheit_key: einheitKey,
    plan_stand: 1,
  });
  if (error) throw error;
  const index = new Map<string, number>();
  const saetze = (o.saetze ?? []).map((s, i) => {
    const n = (index.get(s.u) ?? 0) + 1;
    index.set(s.u, n);
    return {
      id: crypto.randomUUID(),
      studio_id: w.studioId,
      user_id: userId,
      session_id: id,
      machine_id: s.ohneGeraet ? null : w.m[s.u],
      equipment_model_id: w.modellId,
      exercise_id: w.ex[s.u],
      set_index: n,
      load: s.load,
      volume: s.volume,
      rir: s.rir ?? null,
      set_role: s.rolle ?? "arbeit",
      performed_at: new Date(o.startedAt.getTime() + (i + 1) * 60_000).toISOString(),
    };
  });
  if (saetze.length > 0) {
    const { error: e } = await admin.from("workout_sets").insert(saetze);
    if (e) throw e;
  }
  if (o.status?.length) {
    const { error: e } = await admin.from("session_plan_status").insert(
      o.status.map((s) => ({
        session_id: id,
        position_key: s.key,
        user_id: userId,
        status: s.status,
        exercise_id: s.exerciseId ?? null,
      })),
    );
    if (e) throw e;
  }
  return id;
}

/** Drei Arbeitssaetze; der letzte traegt die Reserve. */
const block = (u: Uebung, load: number, volume: number, rir: number | null = 2): Satz[] => [
  { u, load, volume },
  { u, load, volume },
  { u, load, volume, rir },
];

async function ziele(planId: string) {
  const { data, error } = await admin
    .from("plan_gewichte")
    .select("einheit_key, position_key, load, secondary_load, grund, algo_version, stand_session_id")
    .eq("plan_id", planId)
    .order("einheit_key")
    .order("position_key");
  if (error) throw error;
  return Object.fromEntries(
    (data ?? []).map((z) => [zielSchluessel(z.einheit_key as string, z.position_key as string), { ...z, load: Number(z.load) }]),
  ) as Record<string, { load: number; grund: string | null; stand_session_id: string | null; algo_version: string }>;
}

/** Startzeile wie aus init_plan_gewichte (Stand leer). */
async function startziel(p: TrainingPlan, key: string, load: number, einheitKey = key.split("-")[0]!) {
  const { error } = await admin.from("plan_gewichte").insert({
    plan_id: p.id,
    einheit_key: einheitKey,
    position_key: key,
    user_id: userId,
    load,
    grund: "startschaetzung",
    algo_version: "1.0.0",
  });
  if (error) throw error;
}

describe("Schluessel (Einheit, Position)", () => {
  it("zielSchluessel verbindet Einheit und Position", () => {
    expect(zielSchluessel("A", "0")).toBe("A:0");
  });

  it("gleicher Positionsschluessel in zwei Einheiten: zwei Ziele (G14)", async () => {
    const w = await welt();
    // Wie der Generator: jede Einheit nummeriert ab "0".
    const p = await plan(w, { A: ["bank", "rudern"], B: ["bank", "bein"] }, true);

    await initialisierePlanGewichte(client, userId, p);
    expect(Object.keys(await ziele(p.id)).sort()).toEqual(["A:0", "A:1", "B:0", "B:1"]);

    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });
    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["A:0"]).toMatchObject({ load: 42.5, stand_session_id: sid });
    expect(z["B:0"]).toMatchObject({ load: 42.5, stand_session_id: sid });
    // B:1 (Bein) hat keine Historie, aber keinen gemeinsamen Muskel mit Bank: Startwert.
    expect(z["B:1"]).toMatchObject({ grund: "startschaetzung", stand_session_id: null });
    // A:1 (Rudern) teilt keinen Muskel mit Bank.
    expect(z["A:1"]).toMatchObject({ grund: "startschaetzung" });

    const ziel = await ladeZielgewichte(client, userId, p);
    expect(Object.keys(ziel).sort()).toEqual(["A:0", "A:1", "B:0", "B:1"]);
    expect(ziel["B:0"]).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht", aenderung: 2.5 });
  });
});

describe("aktualisierePlanGewichte", () => {
  it("rechnet dieselbe Uebung in den naechsten drei Einheiten neu, andere Uebungen und Cardio bleiben", async () => {
    const w = await welt();
    const p = await plan(w, {
      A: ["bank", "bein"],
      B: ["rudern"],
      C: ["bank", "cardio"],
      D: ["bank"],
      E: ["bank"],
    });
    await startziel(p, "B-rudern", 30);
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["C:C-bank"]).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht", stand_session_id: sid, algo_version: PLANGEWICHT_ALGO_VERSION });
    expect(z["D:D-bank"]).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht" });
    // E liegt hinter der Vorausschau (B, C, D).
    expect(z["E:E-bank"]).toBeUndefined();
    // Einheit B ohne dieselbe Uebung: unveraendert.
    expect(z["B:B-rudern"]).toMatchObject({ load: 30, grund: "startschaetzung", stand_session_id: null });
    // Bein hatte in der Session keinen Satz, Cardio hat kein Zielgewicht.
    expect(z["A:A-bein"]).toBeUndefined();
    expect(z["C:C-cardio"]).toBeUndefined();
    const { data } = await admin.from("workout_sessions").select("gewichte_berechnet_at").eq("id", sid).single();
    expect(data!.gewichte_berechnet_at).not.toBeNull();
  });

  it("laesst eine Einheit mit offener Session unveraendert (G15)", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["bank"], D: ["bank"] });
    await startziel(p, "C-bank", 40);
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });
    // C laeuft gerade (vor 10 Minuten begonnen, nie beendet).
    await einheit(w, p, "C", { startedAt: new Date(JETZT - 10 * 60_000), completedAt: null });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["C:C-bank"]).toMatchObject({ load: 40, stand_session_id: null });
    expect(z["D:D-bank"]).toMatchObject({ load: 42.5 });
  });

  it("nur Aufwaermsaetze aendern nichts", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    await startziel(p, "B-bank", 40);
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: [
        { u: "bank", load: 20, volume: 12, rolle: "aufwaermen" },
        { u: "bank", load: 30, volume: 12, rir: 4, rolle: "aufwaermen" },
      ],
    });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(Object.keys(z)).toEqual(["B:B-bank"]);
    expect(z["B:B-bank"]).toMatchObject({ load: 40, stand_session_id: null });
  });

  it("rechnet vom tatsaechlichen Satz (45 statt Ziel 40)", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["bank"] });
    await startziel(p, "A-bank", 40);
    await startziel(p, "C-bank", 40);
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 45, 12, 3) });

    await aktualisierePlanGewichte(client, userId, sid);

    expect((await ziele(p.id))["C:C-bank"]).toMatchObject({ load: 47.5, grund: "korridor_oben_erreicht" });
  });

  it("zweimal aufgerufen ergibt dieselben Zeilen", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["bank"] });
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });

    await aktualisierePlanGewichte(client, userId, sid);
    const erste = await ziele(p.id);
    await aktualisierePlanGewichte(client, userId, sid);

    expect(await ziele(p.id)).toEqual(erste);
    expect(erste["C:C-bank"]).toMatchObject({ load: 42.5 });
  });

  it("der verspaetete Abschluss einer aelteren Session aendert nichts", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern"], B: ["bein"], C: ["bank", "rudern"] });
    const alt = await einheit(w, p, "A", {
      startedAt: vorStunden(50),
      saetze: [...block("bank", 40, 12, 2), ...block("rudern", 30, 12, 2)],
    });
    const neu = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 45, 9, 1) });

    await aktualisierePlanGewichte(client, userId, neu);
    const nachNeu = await ziele(p.id);
    expect(nachNeu["C:C-bank"]).toMatchObject({ load: 45, grund: "im_korridor", stand_session_id: neu });

    await aktualisierePlanGewichte(client, userId, alt);

    const z = await ziele(p.id);
    expect(z["C:C-bank"]).toEqual(nachNeu["C:C-bank"]);
    // Rudern gab es nur in der alten Einheit; die neuere hat dort nichts entschieden.
    expect(z["C:C-rudern"]).toMatchObject({ load: 32.5, stand_session_id: alt });
  });

  it("eine getauschte Position gibt ihr Ziel nicht an die Ersatzuebung weiter", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["bank"], D: ["fly"] });
    // Bankdruecken hat eigene Historie, damit keine Uebertragung greift.
    await einheit(w, p, "A", { startedAt: vorStunden(100), saetze: block("bank", 40, 10, 1) });
    await startziel(p, "C-bank", 40);
    await startziel(p, "D-fly", 40);
    // A: Bankdruecken getauscht gegen Fly, Fly oben erreicht.
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: block("fly", 30, 12, 2),
      status: [{ key: "A-bank", status: "getauscht", exerciseId: w.ex.fly }],
    });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["C:C-bank"]).toMatchObject({ load: 40, stand_session_id: null });
    // Fly rechnet aus seinen eigenen Saetzen (30 -> 32,5), nicht aus den 40 kg der Bank.
    // 30 statt 20 kg: bei 20 kg waere die 2,5-kg-Stufe grob (F13) und haelte die Last.
    expect(z["D:D-fly"]).toMatchObject({ load: 32.5, grund: "korridor_oben_erreicht" });
    expect(z["A:A-bank"]).toBeUndefined();
  });

  it("bei weniger als drei Folgeeinheiten werden alle angepasst", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["B:B-bank"]).toMatchObject({ load: 42.5 });
    expect(z["A:A-bank"]).toMatchObject({ load: 42.5 });
  });

  it("uebertraegt die Reserve auf Uebungen ohne eigene Historie mit gemeinsamem Hauptmuskel (G5, G16)", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["fly", "bein"] });
    // 12 Wdh. + Reserve 4 = 16 gegen Mitte 10 + Zielreserve 2 = 12 -> +12 %.
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 4) });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    // Startschaetzung 40 * 1,12 = 44,8 -> abgerundet 42,5.
    expect(z["C:C-fly"]).toMatchObject({ load: 42.5, grund: "uebertragung" });
    // Bein teilt keinen Hauptmuskel, Rudern auch nicht.
    expect(z["C:C-bein"]).toBeUndefined();
    expect(z["B:B-rudern"]).toBeUndefined();
  });
});

describe("Zielgewichte je Uebung, mit und ohne Geraet", () => {
  it("Satz im Freien Training (machine_id null) fuehrt zum Ziel der naechsten Einheit", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    // Freies Training: Bank mit 50 kg ohne Geraet, vor drei Tagen. Vorher war er unsichtbar.
    await einheit(w, p, "A", {
      startedAt: vorStunden(72),
      saetze: [
        { u: "bank", load: 50, volume: 10, ohneGeraet: true },
        { u: "bank", load: 50, volume: 10, ohneGeraet: true },
        { u: "bank", load: 50, volume: 10, rir: 1, ohneGeraet: true },
      ],
    });

    await initialisierePlanGewichte(client, userId, p);

    const z = await ziele(p.id);
    // Start aus dem letzten Block (50), nicht aus load_start (40).
    expect(z["A:A-bank"]).toMatchObject({ load: 50 });
    expect(z["B:B-bank"]).toMatchObject({ load: 50 });
    const gelesen = await ladeZielgewichte(client, userId, p);
    expect(gelesen["B:B-bank"]).toMatchObject({ load: 50, aenderung: null });
  });

  it("Saetze ohne Geraet zaehlen beim Neuberechnen, verschiedene Geraete mischen sich nicht zu Unsinn", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: [
        { u: "bank", load: 40, volume: 12, ohneGeraet: true },
        { u: "bank", load: 40, volume: 12, ohneGeraet: true },
        { u: "bank", load: 40, volume: 12, rir: 2, ohneGeraet: true },
      ],
    });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["B:B-bank"]).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht", stand_session_id: sid });
  });
});

describe("initialisierePlanGewichte", () => {
  it("fuellt einen Plan ohne Zeilen aus Historie, Wiedereinstieg und Schaetzung", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern", "cardio"], B: ["bein", "fly"] });
    // Bank: letzter Block vor 3 Tagen 50 kg (ein Aufwaermsatz zaehlt nicht).
    await einheit(w, p, "A", {
      startedAt: vorStunden(72),
      saetze: [{ u: "bank", load: 20, volume: 12, rolle: "aufwaermen" }, ...block("bank", 50, 10, 2)],
    });
    // Bein: letzter Block vor 20 Tagen 60 kg -> -7,5 % = 55,5 -> 55.
    await einheit(w, p, "B", { startedAt: vorStunden(20 * 24), saetze: block("bein", 60, 10, 2) });
    // Fly: letzter Block vor 10 Tagen 30 kg -> halten.
    await einheit(w, p, "B", { startedAt: vorStunden(10 * 24), saetze: block("fly", 30, 12, 3) });
    // Rudern hat schon ein Ziel; es bleibt.
    await startziel(p, "A-rudern", 33);

    await initialisierePlanGewichte(client, userId, p);

    const z = await ziele(p.id);
    expect(z["A:A-bank"]).toMatchObject({ load: 50, grund: "letztes_gewicht", stand_session_id: null });
    expect(z["B:B-bein"]).toMatchObject({ load: 55, grund: "wiedereinstieg" });
    expect(z["B:B-fly"]).toMatchObject({ load: 30, grund: "letztes_gewicht" });
    expect(z["A:A-rudern"]).toMatchObject({ load: 33 });
    expect(z["A:A-cardio"]).toBeUndefined();
  });

  it("schaetzt ohne Historie aus dem Geraetestartwert", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern"] });
    // Uber 42 Tage her: wie ohne Historie.
    await einheit(w, p, "A", { startedAt: vorStunden(60 * 24), saetze: block("rudern", 70, 10, 2) });

    await initialisierePlanGewichte(client, userId, p);

    const z = await ziele(p.id);
    // regelmaessig, ohne Geschlecht/Alter/Koerpergewicht: Faktor 1 -> load_start 40.
    expect(z["A:A-bank"]).toMatchObject({ load: 40, grund: "startschaetzung" });
    expect(z["A:A-rudern"]).toMatchObject({ load: 40, grund: "startschaetzung" });
  });
});

describe("ladeZielgewichte", () => {
  it("liefert Ziel, Aenderung zum letzten benutzten Gewicht und Grund", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern", "bein"], B: ["bank"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: [...block("bank", 40, 12, 2), ...block("rudern", 30, 10, 2)],
    });
    await aktualisierePlanGewichte(client, userId, sid);
    await startziel(p, "A-bein", 25);

    const ziel = await ladeZielgewichte(client, userId, p);

    expect(ziel["B:B-bank"]).toEqual({ load: 42.5, secondaryLoad: null, aenderung: 2.5, grund: "korridor_oben_erreicht" });
    // Gleich wie zuletzt: keine Aenderung.
    expect(ziel["A:A-rudern"]).toEqual({ load: 30, secondaryLoad: null, aenderung: null, grund: "im_korridor" });
    // Ohne Vorgaenger: keine Aenderung.
    expect(ziel["A:A-bein"]).toEqual({ load: 25, secondaryLoad: null, aenderung: null, grund: "startschaetzung" });
  });
});

describe("Wiedereinstieg beim Lesen (F18, Final-Fix I2)", () => {
  // Ziel 62,5 (vorgemerkte Steigerung), letzter Block 60 kg vor `tage` Tagen.
  async function pause(tage: number) {
    const w = await welt();
    const p = await plan(w, { A: ["bank"] });
    await einheit(w, p, "A", { startedAt: vorStunden(tage * 24 + 2), saetze: block("bank", 60, 12, 2) });
    const { error } = await admin.from("plan_gewichte").insert({
      plan_id: p.id,
      einheit_key: "A",
      position_key: "A-bank",
      user_id: userId,
      load: 62.5,
      grund: "korridor_oben_erreicht",
      algo_version: "1.0.0",
    });
    if (error) throw error;
    const ziel = await ladeZielgewichte(client, userId, p);
    // Die gespeicherte Zeile bleibt unberuehrt.
    expect((await ziele(p.id))["A:A-bank"]).toMatchObject({ load: 62.5, grund: "korridor_oben_erreicht" });
    return ziel["A:A-bank"];
  }

  it("ohne Pause (3 Tage) bleibt das Ziel samt Steigerung", async () => {
    expect(await pause(3)).toEqual({ load: 62.5, secondaryLoad: null, aenderung: 2.5, grund: "korridor_oben_erreicht" });
  });

  it("10 Tage: nicht ueber dem letzten Gewicht, die Steigerung verfaellt", async () => {
    expect(await pause(10)).toEqual({ load: 60, secondaryLoad: null, aenderung: null, grund: "wiedereinstieg" });
  });

  it("20 Tage: -7,5 % vom letzten Gewicht, abgerundet", async () => {
    // 60 * 0,925 = 55,5 -> 55
    expect(await pause(20)).toEqual({ load: 55, secondaryLoad: null, aenderung: -5, grund: "wiedereinstieg" });
  });

  it("35 Tage: -12,5 % vom letzten Gewicht", async () => {
    // 60 * 0,875 = 52,5
    expect(await pause(35)).toEqual({ load: 52.5, secondaryLoad: null, aenderung: -7.5, grund: "wiedereinstieg" });
  });

  it("50 Tage: Startschaetzung, Aenderung trotzdem gegen das letzte Gewicht", async () => {
    // regelmaessig, ohne weitere Angaben: load_start 40.
    expect(await pause(50)).toEqual({ load: 40, secondaryLoad: null, aenderung: -20, grund: "startschaetzung" });
  });
});

describe("Ziele in den aktuellen Geraetegrenzen (Final-Fix M1)", () => {
  it("geaenderte Stufe, Ober- und Untergrenze: das gelesene Ziel passt aufs Geraet, die Zeile bleibt", async () => {
    const w = await welt(true);
    const p = await plan(w, { A: ["bank"] });
    await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });
    await startziel(p, "A-bank", 42.5);
    const modell = async (werte: object) => {
      const { error } = await admin.from("equipment_models").update(werte).eq("id", w.katalogModellId);
      if (error) throw error;
      return (await ladeZielgewichte(client, userId, p))["A:A-bank"];
    };

    // Stufe 5 ab 0: 42,5 ist nicht einstellbar -> abgerundet 40, gleich wie zuletzt.
    expect(await modell({ load_step: 5, load_min: 0 })).toMatchObject({ load: 40, aenderung: null });
    // Obergrenze 35.
    expect(await modell({ load_step: 2.5, load_min: 5, load_max: 35, load_start: 30 })).toMatchObject({ load: 35, aenderung: -5 });
    // Untergrenze 45.
    expect(await modell({ load_min: 45, load_max: 100, load_start: 50 })).toMatchObject({ load: 45, aenderung: 5 });
    expect((await ziele(p.id))["A:A-bank"]).toMatchObject({ load: 42.5 });
  });
});

describe("Fix-Runde 1", () => {
  it("ladeZielgewichte vergleicht nicht mit der gerade laufenden Einheit (G17)", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(30), saetze: block("bank", 40, 12, 2) });
    await aktualisierePlanGewichte(client, userId, sid);
    // Das Mitglied steht gerade an B und hat schon einen Satz mit 42,5 kg.
    await einheit(w, p, "B", {
      startedAt: new Date(JETZT - 10 * 60_000),
      completedAt: null,
      saetze: [{ u: "bank", load: 42.5, volume: 10 }],
    });

    const ziel = await ladeZielgewichte(client, userId, p);

    expect(ziel["B:B-bank"]).toMatchObject({ load: 42.5, aenderung: 2.5 });
  });

  it("ladeZielgewichte erfindet keinen Grund", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"] });
    const { error } = await admin
      .from("plan_gewichte")
      .insert({ plan_id: p.id, einheit_key: "A", position_key: "A-bank", user_id: userId, load: 30, grund: null, algo_version: "1.0.0" });
    if (error) throw error;

    const ziel = await ladeZielgewichte(client, userId, p);

    expect(ziel["A:A-bank"]).toEqual({ load: 30, secondaryLoad: null, aenderung: null, grund: null });
  });

  it("lange Historie (>1000 Saetze) fuehrt nicht zu Abfragen je Paar", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern", "bein"], B: ["bank", "rudern", "bein"] });
    // Ein langjaehriges Mitglied: 1100 alte Rudersaetze vor 100 Tagen.
    await einheit(w, p, "A", {
      startedAt: vorStunden(100 * 24),
      saetze: Array.from({ length: 1100 }, () => ({ u: "rudern" as const, load: 70, volume: 10 })),
    });

    const zaehler = new Map<string, number>();
    const zaehlend = new Proxy(client, {
      get(ziel, name) {
        if (name === "from") {
          return (tabelle: string) => {
            zaehler.set(tabelle, (zaehler.get(tabelle) ?? 0) + 1);
            return ziel.from(tabelle);
          };
        }
        const wert = Reflect.get(ziel, name);
        return typeof wert === "function" ? wert.bind(ziel) : wert;
      },
    }) as SupabaseClient;
    const saetzeAbfragen = () => {
      const n = zaehler.get("workout_sets") ?? 0;
      zaehler.clear();
      return n;
    };

    await initialisierePlanGewichte(zaehlend, userId, p);
    expect(saetzeAbfragen()).toBeLessThanOrEqual(1);
    // Ruderhistorie liegt ueber 42 Tage zurueck: wie ohne Historie.
    expect((await ziele(p.id))["A:A-rudern"]).toMatchObject({ load: 40, grund: "startschaetzung" });

    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: [...block("bank", 40, 12, 2), ...block("rudern", 30, 10, 2), ...block("bein", 50, 12, 2)],
    });
    await aktualisierePlanGewichte(zaehlend, userId, sid);
    expect(saetzeAbfragen()).toBeLessThanOrEqual(3);
    const z = await ziele(p.id);
    expect(z["B:B-bank"]).toMatchObject({ load: 42.5, stand_session_id: sid });
    expect(z["B:B-rudern"]).toMatchObject({ load: 30, grund: "im_korridor" });
    expect(z["B:B-bein"]).toMatchObject({ load: 52.5 });

    const ziel = await ladeZielgewichte(zaehlend, userId, p);
    expect(saetzeAbfragen()).toBeLessThanOrEqual(2);
    expect(ziel["B:B-bank"]).toMatchObject({ aenderung: 2.5 });
    expect(ziel["B:B-rudern"]).toMatchObject({ aenderung: null });
  });

  it("ueber 1000 Saetze im Fenster: blaettert statt zu scheitern oder Paare auszulassen", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern"], B: ["bank", "rudern"] });
    // Bank vor 12 Tagen (halten), danach 1100 Rudersaetze vor 10 Tagen -- beide im Fenster.
    await einheit(w, p, "A", { startedAt: vorStunden(12 * 24), saetze: block("bank", 50, 10, 2) });
    await einheit(w, p, "A", {
      startedAt: vorStunden(10 * 24),
      saetze: Array.from({ length: 1100 }, () => ({ u: "rudern" as const, load: 70, volume: 10 })),
    });

    await initialisierePlanGewichte(client, userId, p);
    const start = await ziele(p.id);
    expect(start["A:A-bank"]).toMatchObject({ load: 50, grund: "letztes_gewicht" });
    expect(start["A:A-rudern"]).toMatchObject({ load: 70, grund: "letztes_gewicht" });

    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: [...block("bank", 50, 12, 2), ...block("rudern", 70, 10, 2)],
    });
    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["B:B-bank"]).toMatchObject({ load: 52.5, stand_session_id: sid });
    expect(z["B:B-rudern"]).toMatchObject({ load: 70, grund: "im_korridor", stand_session_id: sid });
    const ziel = await ladeZielgewichte(client, userId, p);
    expect(ziel["B:B-bank"]).toMatchObject({ aenderung: 2.5 });
  });
});

// ---------------------------------------------------------------------------
// Task 5: Ausloeser mit einem ERZEUGTEN Plan. Die Positionen tragen hier die
// Hauptmuskeln, die der Generator aus exercises.muscles uebernimmt -- die
// Uebertragung muss damit greifen, sonst passen die Schluesselraeume von
// position.hauptmuskeln und exercises.muscles nicht zusammen.
// ---------------------------------------------------------------------------

describe("Ausloeser mit erzeugtem Plan (Task 5)", () => {
  let ps: PlanStudios;

  beforeAll(async () => {
    ps = await legePlanStudiosAn(crypto.randomUUID());
    // Muskeln im Format des Katalog-Imports ({key, name, role}). "ganzkoerper" teilen
    // alle Uebungen als Hauptmuskel, damit jede Position ohne Historie uebertragen bekommt.
    for (const [name, id] of Object.entries(ps.uebungen)) {
      const eigen = name.toLowerCase().replace(/\s+/g, "_");
      const { error } = await admin
        .from("exercises")
        .update({
          muscles: [
            { key: eigen, name, role: "primary" },
            { key: "ganzkoerper", name: "Ganzkörper", role: "primary" },
            { key: "rumpf", name: "Rumpf", role: "secondary" },
          ],
        })
        .eq("id", id);
      if (error) throw error;
    }
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  type Position = TrainingPlan["einheiten"][number]["positionen"][number];
  const istKraft = (p: Position) => p.rolle !== "cardio" && p.wdhVon !== null && p.wdhBis !== null;
  /** Positionen mit Einheit und zielSchluessel. */
  const stellen = (plan: TrainingPlan) =>
    plan.einheiten.flatMap((e) => e.positionen.map((p) => ({ ...p, einheitKey: e.key, ziel: zielSchluessel(e.key, p.key) })));

  async function mitPlan(prefix: string, weeklyDays = 3): Promise<{ m: Mitglied; plan: TrainingPlan }> {
    const m = await legeMitgliedAn(prefix, { studios: [ps.voll], weeklyDays });
    // Der Katalog ist geteilt (Reste anderer Testdateien): am Ort nur die eigenen Uebungen
    // zulassen, damit der erzeugte Plan bestimmt ist.
    const { data: katalog, error: katalogFehler } = await admin
      .from("exercises")
      .select("id")
      .eq("studio_id", GYMTAVO)
      .not("plan_baustein", "is", null);
    if (katalogFehler) throw katalogFehler;
    const eigene = new Set(Object.values(ps.uebungen));
    const { error: merkFehler } = await admin.from("plan_merkliste").insert(
      (katalog ?? [])
        .filter((u) => !eigene.has(u.id as string))
        .map((u) => ({ user_id: m.userId, exercise_id: u.id, art: "nicht_vorhanden", studio_id: ps.voll })),
    );
    if (merkFehler) throw merkFehler;
    const vorschlag = await erzeugePlanVorschlag(m.client, m.userId, ps.voll);
    return { m, plan: await acceptPlan(m.client, m.userId, vorschlag.id) };
  }

  /** Offene Session der Einheit, vor einer Stunde begonnen, drei Arbeitssaetze an `p`. */
  async function offeneEinheit(m: Mitglied, plan: TrainingPlan, einheitKey: string, p: Position): Promise<string> {
    const id = crypto.randomUUID();
    const start = Date.now() - 3_600_000;
    const { error } = await admin.from("workout_sessions").insert({
      id,
      studio_id: ps.voll,
      user_id: m.userId,
      started_at: new Date(start).toISOString(),
      plan_id: plan.id,
      plan_einheit_key: einheitKey,
      plan_stand: 1,
    });
    if (error) throw error;
    const maschine = await machineVon(ps.voll);
    const { error: e } = await admin.from("workout_sets").insert(
      [1, 2, 3].map((n) => ({
        id: crypto.randomUUID(),
        studio_id: ps.voll,
        user_id: m.userId,
        session_id: id,
        machine_id: maschine.id,
        exercise_id: p.exerciseId,
        set_index: n,
        load: 50,
        volume: 12,
        rir: n === 3 ? 2 : null,
        set_role: "arbeit",
        performed_at: new Date(start + n * 60_000).toISOString(),
      })),
    );
    if (e) throw e;
    return id;
  }

  async function zieleVon(planId: string) {
    const { data, error } = await admin
      .from("plan_gewichte")
      .select("einheit_key, position_key, load, grund, stand_session_id")
      .eq("plan_id", planId);
    if (error) throw error;
    return Object.fromEntries(
      (data ?? []).map((z) => [zielSchluessel(z.einheit_key as string, z.position_key as string), { ...z, load: Number(z.load) }]),
    ) as Record<
      string,
      { load: number; grund: string | null; stand_session_id: string | null }
    >;
  }

  async function marke(sessionId: string) {
    const { data, error } = await admin
      .from("workout_sessions")
      .select("completed_at, gewichte_berechnet_at")
      .eq("id", sessionId)
      .single();
    if (error) throw error;
    return data as { completed_at: string | null; gewichte_berechnet_at: string | null };
  }

  it("completeSession schreibt die Ziele; die Uebertragung greift ueber die Muskeln des erzeugten Plans (eine Einheit)", async () => {
    const { m, plan } = await mitPlan("pg-abschluss-eine", 1);
    expect(plan.einheiten).toHaveLength(1);
    await abschlussMitUebertragung(m, plan);
  });

  it("completeSession schreibt die Ziele; die Uebertragung greift ueber die Muskeln des erzeugten Plans (drei Einheiten)", async () => {
    const { m, plan } = await mitPlan("pg-abschluss");
    expect(plan.einheiten.length).toBeGreaterThan(1);
    await abschlussMitUebertragung(m, plan);
  });

  async function abschlussMitUebertragung(m: Mitglied, plan: TrainingPlan) {
    const kraft = stellen(plan).filter(istKraft);
    expect(kraft.length).toBeGreaterThan(1);
    // Der Generator uebernimmt die Schluessel aus exercises.muscles (role primary).
    expect(kraft.every((p) => p.hauptmuskeln.includes("ganzkoerper"))).toBe(true);
    // Annahme setzt die Startwerte (G13).
    const start = await zieleVon(plan.id);
    for (const p of kraft) expect(start[p.ziel]).toMatchObject({ grund: "startschaetzung", stand_session_id: null });

    const a = plan.einheiten[0]!;
    const p0 = stellen(plan).find((p) => p.einheitKey === a.key && istKraft(p))!;
    const sid = await offeneEinheit(m, plan, a.key, p0);

    const ergebnis = await completeSession(m.client, { sessionId: sid });

    expect(ergebnis.completedReason).toBe("manual");
    expect((await marke(sid)).gewichte_berechnet_at).not.toBeNull();
    const z = await zieleVon(plan.id);
    const gleichesPaar = (p: Position) => p.modelId === p0.modelId && p.exerciseId === p0.exerciseId;
    // Der Plan hat hoechstens drei Einheiten: alle liegen in der Vorausschau (G21).
    expect(plan.einheiten.length).toBeLessThanOrEqual(3);
    for (const p of kraft) {
      expect(z[p.ziel]!.stand_session_id).toBe(sid);
      if (gleichesPaar(p)) expect(z[p.ziel]!.grund).not.toBe("uebertragung");
      else expect(z[p.ziel]).toMatchObject({ grund: "uebertragung" });
    }
  }

  it("initialisierePlanGewichte ohne fehlende Ziele: genau eine Abfrage, kein Schreiben", async () => {
    const { m, plan } = await mitPlan("pg-init-nichts");
    // Die Annahme hat alle Ziele gesetzt.
    expect(Object.keys(await zieleVon(plan.id)).sort()).toEqual(stellen(plan).filter(istKraft).map((p) => p.ziel).sort());
    const aufrufe: string[] = [];
    const zaehlend = new Proxy(m.client, {
      get(ziel, name) {
        if (name === "from") return (tabelle: string) => (aufrufe.push(`from:${tabelle}`), ziel.from(tabelle));
        if (name === "rpc") return (fn: string, args?: object) => (aufrufe.push(`rpc:${fn}`), ziel.rpc(fn, args));
        const wert = Reflect.get(ziel, name);
        return typeof wert === "function" ? wert.bind(ziel) : wert;
      },
    }) as SupabaseClient;

    await initialisierePlanGewichte(zaehlend, m.userId, plan);

    expect(aufrufe).toEqual(["from:plan_gewichte"]);
  });

  it("scheitert die Rechnung, bleibt die Session beendet; der naechste Bootstrap holt sie nach", async () => {
    const { m, plan } = await mitPlan("pg-abschluss-fehler");
    const a = plan.einheiten[0]!;
    const p0 = stellen(plan).find((p) => p.einheitKey === a.key && istKraft(p))!;
    const sid = await offeneEinheit(m, plan, a.key, p0);
    const fehler = vi.spyOn(console, "error").mockImplementation(() => {});
    // Die Datenbank lehnt beide Schreibwege ab (wie plan_ungueltig bei Uhrenversatz).
    const abweisend = new Proxy(m.client, {
      get(ziel, name) {
        if (name === "rpc") {
          return (fn: string, args?: object) =>
            fn === "set_plan_gewichte" || fn === "init_plan_gewichte"
              ? Promise.resolve({ data: null, error: { code: "P0001", message: "plan_ungueltig" } })
              : ziel.rpc(fn, args);
        }
        const wert = Reflect.get(ziel, name);
        return typeof wert === "function" ? wert.bind(ziel) : wert;
      },
    }) as SupabaseClient;

    const ergebnis = await completeSession(abweisend, { sessionId: sid });

    expect(ergebnis.completedReason).toBe("manual");
    expect(fehler).toHaveBeenCalledWith(expect.stringContaining("plangewichte"));
    const nachher = await marke(sid);
    expect(nachher.completed_at).not.toBeNull();
    expect(nachher.gewichte_berechnet_at).toBeNull();
    expect(Object.values(await zieleVon(plan.id)).some((z) => z.stand_session_id === sid)).toBe(false);

    await getBootstrap(m.client);

    expect((await marke(sid)).gewichte_berechnet_at).not.toBeNull();
    expect((await zieleVon(plan.id))[p0.ziel]).toMatchObject({ stand_session_id: sid });
  });

  it("Session an Version N, aktiv ist N+1 (dauerhafter Tausch in der Einheit): rechnet gegen N+1 ueber Uebung und Geraet (Uebergabe Punkt 5)", async () => {
    const { m, plan } = await mitPlan("pg-version");
    const a = plan.einheiten[0]!;
    // Latzug ist die einzige Ziehen-Uebung: er steht in jeder Einheit.
    const latzug = stellen(plan).filter((p) => p.exerciseId === ps.uebungen.Latzug);
    expect(latzug.map((p) => p.einheitKey).sort()).toEqual(plan.einheiten.map((e) => e.key).sort());
    const lat0 = latzug.find((p) => p.einheitKey === a.key)!;
    // Mitten in Einheit A wird die Beinuebung dauerhaft getauscht (Beinpresse <-> Hackenschmidt).
    const bein = stellen(plan).find((p) => p.einheitKey === a.key && p.baustein === "beine_knie")!;
    const ersatz = bein.exerciseId === ps.uebungen.Beinpresse ? ps.uebungen.Hackenschmidt! : ps.uebungen.Beinpresse!;
    const sid = await offeneEinheit(m, plan, a.key, lat0);

    const neu = await tauschePlanPosition(m.client, m.userId, plan.id, {
      einheitKey: a.key,
      positionKey: bein.key,
      exerciseId: ersatz,
      modelId: bein.modelId,
    });
    expect(neu.version).toBe(plan.version + 1);
    const vorher = await zieleVon(neu.id);

    await completeSession(m.client, { sessionId: sid });

    expect((await marke(sid)).gewichte_berechnet_at).not.toBeNull();
    const z = await zieleVon(neu.id);
    // Alle Latzug-Positionen der aktiven Version N+1 rechnen aus der Session (G2).
    for (const p of stellen(neu).filter((x) => x.exerciseId === ps.uebungen.Latzug)) {
      expect(z[p.ziel]).toMatchObject({ stand_session_id: sid });
      expect(z[p.ziel]!.grund).not.toBe("uebertragung");
    }
    // Die getauschte Position zaehlt mit ihrer neuen Uebung (ohne eigene Historie: Uebertragung).
    expect(z[zielSchluessel(a.key, bein.key)]).toMatchObject({ stand_session_id: sid, grund: "uebertragung" });
    expect(vorher[zielSchluessel(a.key, bein.key)]).toMatchObject({ grund: "startschaetzung", stand_session_id: null });
    // Die ersetzte Version N bleibt unberuehrt.
    expect(Object.values(await zieleVon(plan.id)).some((x) => x.stand_session_id === sid)).toBe(false);
  });
});

describe("Vorschlaege aus Zielgewicht oder letztem Gewicht (Task 6)", () => {
  /** Das Modell der Welt kennt alle Uebungen -- der Geraetekontext liest sie von dort. */
  async function verknuepfe(w: Welt): Promise<void> {
    await einfuegen(
      "equipment_model_exercises",
      (["bank", "rudern", "fly", "bein"] as const).map((u, i) => ({
        equipment_model_id: w.modellId,
        exercise_id: w.ex[u],
        sort_order: i + 1,
      })),
    );
  }

  async function setzeLoad(planId: string, einheitKey: string, positionKey: string, load: number) {
    const { error } = await admin
      .from("plan_gewichte")
      .update({ load })
      .eq("plan_id", planId)
      .eq("einheit_key", einheitKey)
      .eq("position_key", positionKey);
    if (error) throw error;
  }

  const erledigt = (key: string, u: Uebung, w: Welt) => [{ key, status: "erledigt", exerciseId: w.ex[u] }];

  it("Geraet mit Planposition: Ziel der naechsten Einheit, Grund aus dem Ziel, Bisher = letztes Gewicht", async () => {
    const w = await welt();
    await verknuepfe(w);
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: block("bank", 40, 12, 2),
      status: erledigt("A-bank", "bank", w),
    });
    await aktualisierePlanGewichte(client, userId, sid);
    // Zwei Einheiten, zwei Ziele: die naechste Einheit (B) gilt, nicht A.
    await setzeLoad(p.id, "A", "A-bank", 50);
    await setzeLoad(p.id, "B", "B-bank", 45);

    const kontext = await getMachineContext(client, w.m.bank);

    expect(kontext.suggestion).toMatchObject({
      algoVersion: PLANGEWICHT_ALGO_VERSION,
      resultLoad: 45,
      reasonCode: "korridor_oben_erreicht",
    });
    expect(kontext.suggestion.inputs.currentLoad).toBe(40);
    const { data } = await admin
      .from("progression_suggestions")
      .select("algo_version, result_load, reason_code")
      .eq("machine_id", w.m.bank)
      .eq("user_id", userId);
    expect(data).toEqual([{ algo_version: PLANGEWICHT_ALGO_VERSION, result_load: 45, reason_code: "korridor_oben_erreicht" }]);
  });

  it("zweite Einheit zuerst dran: deren Ziel gilt (naechsteEinheitKey)", async () => {
    const w = await welt();
    await verknuepfe(w);
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "B", {
      startedAt: vorStunden(3),
      saetze: block("bank", 40, 12, 2),
      status: erledigt("B-bank", "bank", w),
    });
    await aktualisierePlanGewichte(client, userId, sid);
    await setzeLoad(p.id, "A", "A-bank", 50);
    await setzeLoad(p.id, "B", "B-bank", 45);

    expect((await getMachineContext(client, w.m.bank)).suggestion.resultLoad).toBe(50);
  });

  it("Geraet ohne Plan: letztes Gewicht, letztes_gewicht; ohne Saetze kein_verlauf", async () => {
    const w = await welt();
    await verknuepfe(w);
    expect((await getMachineContext(client, w.m.bank)).suggestion).toMatchObject({
      resultLoad: null,
      reasonCode: "kein_verlauf",
    });
    const sid = crypto.randomUUID();
    await einfuegen("workout_sessions", { id: sid, studio_id: w.studioId, user_id: userId, started_at: vorStunden(5).toISOString() });
    await einfuegen("workout_sets", [
      { id: crypto.randomUUID(), studio_id: w.studioId, user_id: userId, session_id: sid, machine_id: w.m.bank, equipment_model_id: w.modellId, exercise_id: w.ex.bank, set_index: 1, load: 37.5, volume: 12, rir: 2, performed_at: vorStunden(4).toISOString() },
    ]);

    const kontext = await getMachineContext(client, w.m.bank);

    expect(kontext.suggestion).toMatchObject({ algoVersion: PLANGEWICHT_ALGO_VERSION, resultLoad: 37.5, reasonCode: "letztes_gewicht" });
  });

  it("Abschluss: Delta = Ziel minus bisher, Zeile mit neuer algo_version, Wiederholung liest unveraendert zurueck", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "cardio"], B: ["bank"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(2),
      completedAt: null,
      saetze: block("bank", 40, 12, 2),
      status: erledigt("A-bank", "bank", w),
    });

    const erster = await completeSession(client, { sessionId: sid });

    expect(erster.vorschlaege).toEqual([
      expect.objectContaining({
        machineId: w.m.bank,
        exerciseId: w.ex.bank,
        resultLoad: 42.5,
        deltaLoad: 2.5,
        reasonCode: "korridor_oben_erreicht",
        algoVersion: PLANGEWICHT_ALGO_VERSION,
      }),
    ]);
    const { data } = await admin
      .from("progression_suggestions")
      .select("algo_version, result_load, reason_code")
      .eq("machine_id", w.m.bank)
      .eq("user_id", userId);
    expect(data).toEqual([{ algo_version: PLANGEWICHT_ALGO_VERSION, result_load: 42.5, reason_code: "korridor_oben_erreicht" }]);
    expect((await completeSession(client, { sessionId: sid })).vorschlaege).toEqual(erster.vorschlaege);
  });

  /** Client, dessen Lesen von plan_gewichte scheitert (wie eine API vor 0064). */
  const ohnePlanGewichte = () =>
    new Proxy(client, {
      get(ziel, name) {
        if (name === "from") {
          return (tabelle: string) => ziel.from(tabelle === "plan_gewichte" ? "plan_gewichte_fehlt" : tabelle);
        }
        const wert = Reflect.get(ziel, name);
        return typeof wert === "function" ? wert.bind(ziel) : wert;
      },
    }) as SupabaseClient;

  it("Final-Fix I4: Lesefehler der Ziele am Geraet faellt auf das letzte Gewicht zurueck und wird protokolliert", async () => {
    const w = await welt();
    await verknuepfe(w);
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(3),
      saetze: block("bank", 40, 12, 2),
      status: erledigt("A-bank", "bank", w),
    });
    await aktualisierePlanGewichte(client, userId, sid);
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      const kontext = await getMachineContext(ohnePlanGewichte(), w.m.bank);
      expect(kontext.suggestion).toMatchObject({ resultLoad: 40, reasonCode: "letztes_gewicht" });
      expect(log).toHaveBeenCalledWith(expect.stringMatching(/^plangewichte: .*fehlgeschlagen \(internal: /));
    } finally {
      log.mockRestore();
    }
  });

  it("Final-Fix I4: Lesefehler der Ziele im Abschluss laesst completeSession nicht scheitern", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(2),
      completedAt: null,
      saetze: block("bank", 40, 12, 2),
      status: erledigt("A-bank", "bank", w),
    });
    const log = vi.spyOn(console, "error").mockImplementation(() => {});
    try {
      const { vorschlaege } = await completeSession(ohnePlanGewichte(), { sessionId: sid });
      expect(vorschlaege).toEqual([
        expect.objectContaining({ resultLoad: 40, deltaLoad: 0, reasonCode: "letztes_gewicht" }),
      ]);
      expect(log).toHaveBeenCalledWith(expect.stringMatching(/^plangewichte: Ziele im Abschluss lesen fehlgeschlagen/));
    } finally {
      log.mockRestore();
    }
  });

  it("Abschluss ohne Planposition fuer das Geraet: letztes Gewicht, Delta 0", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["rudern"] });
    const sid = await einheit(w, p, "A", {
      startedAt: vorStunden(2),
      completedAt: null,
      saetze: [...block("rudern", 30, 10, 2), ...block("bank", 40, 12, 2)],
      status: erledigt("A-rudern", "rudern", w),
    });

    const { vorschlaege } = await completeSession(client, { sessionId: sid });

    const bank = vorschlaege.find((v) => v.exerciseId === w.ex.bank);
    expect(bank).toMatchObject({ resultLoad: 40, deltaLoad: 0, reasonCode: "letztes_gewicht", algoVersion: PLANGEWICHT_ALGO_VERSION });
  });
});
