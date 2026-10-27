import { beforeAll, describe, expect, it } from "vitest";
import {
  aktualisierePlanGewichte,
  initialisierePlanGewichte,
  ladeZielgewichte,
  type TrainingPlan,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";
import type { SupabaseClient } from "@supabase/supabase-js";

// Etappe 4, Task 4: Zielgewichte nach einer abgeschlossenen Einheit neu
// rechnen (G2-G5, G9, G12-G16, G21). Jeder Test baut ein eigenes Studio mit
// eigenen Geraeten und einem direkt eingefuegten Plan, damit Historie und
// Zielgewichte sich zwischen den Tests nicht beruehren. Ein Mitglied fuer alle
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
  modellId: string;
  ex: Record<Uebung, string>;
  m: Record<Uebung, string>;
};

/** Studio mit je einem Geraet je Uebung; Stufe 2,5, 5..100 kg, Startwert 40. */
async function welt(): Promise<Welt> {
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
  return { studioId, modellId: modell!.id, ex, m };
}

/** Planposition; Schluessel = Einheit + Uebung. */
function pos(w: Welt, einheit: string, u: Uebung, bereich: [number, number] = [8, 12]) {
  const cardio = u === "cardio";
  return {
    key: `${einheit}-${u}`,
    baustein: cardio ? "cardio" : u === "bein" ? "beine_knie" : u === "rudern" ? "ziehen" : "druecken",
    rolle: cardio ? "cardio" : "pflicht",
    exerciseId: w.ex[u],
    machineId: w.m[u],
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
async function plan(w: Welt, einheiten: Record<string, Uebung[]>): Promise<TrainingPlan> {
  const liste = Object.entries(einheiten).map(([key, us]) => ({
    key,
    positionen: us.map((u) => pos(w, key, u)),
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
  const { data, error } = await admin
    .from("training_plans")
    .insert({
      user_id: userId,
      studio_id: w.studioId,
      version: 1,
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
    studioId: w.studioId,
    version: 1,
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

type Satz = { u: Uebung; load: number; volume: number; rir?: number | null; rolle?: "arbeit" | "aufwaermen" };

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
      machine_id: w.m[s.u],
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
    .select("position_key, load, secondary_load, grund, algo_version, stand_session_id")
    .eq("plan_id", planId)
    .order("position_key");
  if (error) throw error;
  return Object.fromEntries(
    (data ?? []).map((z) => [z.position_key as string, { ...z, load: Number(z.load) }]),
  ) as Record<string, { load: number; grund: string | null; stand_session_id: string | null; algo_version: string }>;
}

/** Startzeile wie aus init_plan_gewichte (Stand leer). */
async function startziel(p: TrainingPlan, key: string, load: number) {
  const { error } = await admin.from("plan_gewichte").insert({
    plan_id: p.id,
    position_key: key,
    user_id: userId,
    load,
    grund: "startschaetzung",
    algo_version: "1.0.0",
  });
  if (error) throw error;
}

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
    expect(z["C-bank"]).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht", stand_session_id: sid, algo_version: "1.0.0" });
    expect(z["D-bank"]).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht" });
    // E liegt hinter der Vorausschau (B, C, D).
    expect(z["E-bank"]).toBeUndefined();
    // Einheit B ohne dieselbe Uebung: unveraendert.
    expect(z["B-rudern"]).toMatchObject({ load: 30, grund: "startschaetzung", stand_session_id: null });
    // Bein hatte in der Session keinen Satz, Cardio hat kein Zielgewicht.
    expect(z["A-bein"]).toBeUndefined();
    expect(z["C-cardio"]).toBeUndefined();
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
    expect(z["C-bank"]).toMatchObject({ load: 40, stand_session_id: null });
    expect(z["D-bank"]).toMatchObject({ load: 42.5 });
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
    expect(Object.keys(z)).toEqual(["B-bank"]);
    expect(z["B-bank"]).toMatchObject({ load: 40, stand_session_id: null });
  });

  it("rechnet vom tatsaechlichen Satz (45 statt Ziel 40)", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["bank"] });
    await startziel(p, "A-bank", 40);
    await startziel(p, "C-bank", 40);
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 45, 12, 3) });

    await aktualisierePlanGewichte(client, userId, sid);

    expect((await ziele(p.id))["C-bank"]).toMatchObject({ load: 47.5, grund: "korridor_oben_erreicht" });
  });

  it("zweimal aufgerufen ergibt dieselben Zeilen", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["bank"] });
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });

    await aktualisierePlanGewichte(client, userId, sid);
    const erste = await ziele(p.id);
    await aktualisierePlanGewichte(client, userId, sid);

    expect(await ziele(p.id)).toEqual(erste);
    expect(erste["C-bank"]).toMatchObject({ load: 42.5 });
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
    expect(nachNeu["C-bank"]).toMatchObject({ load: 45, grund: "im_korridor", stand_session_id: neu });

    await aktualisierePlanGewichte(client, userId, alt);

    const z = await ziele(p.id);
    expect(z["C-bank"]).toEqual(nachNeu["C-bank"]);
    // Rudern gab es nur in der alten Einheit; die neuere hat dort nichts entschieden.
    expect(z["C-rudern"]).toMatchObject({ load: 32.5, stand_session_id: alt });
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
      saetze: block("fly", 20, 12, 2),
      status: [{ key: "A-bank", status: "getauscht", exerciseId: w.ex.fly }],
    });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["C-bank"]).toMatchObject({ load: 40, stand_session_id: null });
    // Fly rechnet aus seinen eigenen Saetzen (20 -> 22,5), nicht aus den 40 kg der Bank.
    expect(z["D-fly"]).toMatchObject({ load: 22.5, grund: "korridor_oben_erreicht" });
    expect(z["A-bank"]).toBeUndefined();
  });

  it("bei weniger als drei Folgeeinheiten werden alle angepasst", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["bank"] });
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 2) });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    expect(z["B-bank"]).toMatchObject({ load: 42.5 });
    expect(z["A-bank"]).toMatchObject({ load: 42.5 });
  });

  it("uebertraegt die Reserve auf Uebungen ohne eigene Historie mit gemeinsamem Hauptmuskel (G5, G16)", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank"], B: ["rudern"], C: ["fly", "bein"] });
    // 12 Wdh. + Reserve 4 = 16 gegen Mitte 10 + Zielreserve 2 = 12 -> +12 %.
    const sid = await einheit(w, p, "A", { startedAt: vorStunden(3), saetze: block("bank", 40, 12, 4) });

    await aktualisierePlanGewichte(client, userId, sid);

    const z = await ziele(p.id);
    // Startschaetzung 40 * 1,12 = 44,8 -> abgerundet 42,5.
    expect(z["C-fly"]).toMatchObject({ load: 42.5, grund: "uebertragung" });
    // Bein teilt keinen Hauptmuskel, Rudern auch nicht.
    expect(z["C-bein"]).toBeUndefined();
    expect(z["B-rudern"]).toBeUndefined();
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
    expect(z["A-bank"]).toMatchObject({ load: 50, grund: "letztes_gewicht", stand_session_id: null });
    expect(z["B-bein"]).toMatchObject({ load: 55, grund: "wiedereinstieg" });
    expect(z["B-fly"]).toMatchObject({ load: 30, grund: "letztes_gewicht" });
    expect(z["A-rudern"]).toMatchObject({ load: 33 });
    expect(z["A-cardio"]).toBeUndefined();
  });

  it("schaetzt ohne Historie aus dem Geraetestartwert", async () => {
    const w = await welt();
    const p = await plan(w, { A: ["bank", "rudern"] });
    // Uber 42 Tage her: wie ohne Historie.
    await einheit(w, p, "A", { startedAt: vorStunden(60 * 24), saetze: block("rudern", 70, 10, 2) });

    await initialisierePlanGewichte(client, userId, p);

    const z = await ziele(p.id);
    // regelmaessig, ohne Geschlecht/Alter/Koerpergewicht: Faktor 1 -> load_start 40.
    expect(z["A-bank"]).toMatchObject({ load: 40, grund: "startschaetzung" });
    expect(z["A-rudern"]).toMatchObject({ load: 40, grund: "startschaetzung" });
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

    expect(ziel["B-bank"]).toEqual({ load: 42.5, secondaryLoad: null, aenderung: 2.5, grund: "korridor_oben_erreicht" });
    // Gleich wie zuletzt: keine Aenderung.
    expect(ziel["A-rudern"]).toEqual({ load: 30, secondaryLoad: null, aenderung: null, grund: "im_korridor" });
    // Ohne Vorgaenger: keine Aenderung.
    expect(ziel["A-bein"]).toEqual({ load: 25, secondaryLoad: null, aenderung: null, grund: "startschaetzung" });
  });
});
