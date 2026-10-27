import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { GET, POST } from "@/app/api/v1/me/plans/route";
import { POST as acceptPOST } from "@/app/api/v1/me/plans/[id]/accept/route";
import { POST as swapPOST } from "@/app/api/v1/me/plans/[id]/swap/route";
import { POST as completePOST } from "@/app/api/v1/workout-sessions/[sessionId]/complete/route";
import { fromDomainError } from "@/lib/api/respond";
import { DomainError, zielSchluessel } from "@fitretro/domain";
import { accessTokenFor, serviceClient } from "./helpers/clients.js";
import { GYMTAVO, legeMitgliedAn, legePlanStudiosAn, type PlanStudios } from "./helpers/plan-studio.js";

const BASIS = "http://localhost/api/v1/me/plans";
const kopf = (auth?: string) => (auth ? { authorization: `Bearer ${auth}` } : {});
const post = (auth: string | undefined, rumpf: unknown) =>
  POST(new Request(BASIS, { method: "POST", headers: kopf(auth), body: JSON.stringify(rumpf) }));
const get = (auth: string | undefined) => GET(new Request(BASIS, { headers: kopf(auth) }));
const accept = (auth: string | undefined, id: string) =>
  acceptPOST(new Request(`${BASIS}/${id}/accept`, { method: "POST", headers: kopf(auth) }), {
    params: Promise.resolve({ id }),
  });

const swap = (auth: string | undefined, id: string, rumpf: unknown) =>
  swapPOST(new Request(`${BASIS}/${id}/swap`, { method: "POST", headers: kopf(auth), body: JSON.stringify(rumpf) }), {
    params: Promise.resolve({ id }),
  });

type Fehler = { error: { code: string; message: string; detail?: Record<string, unknown> } };

let s: PlanStudios;
let bearer: string;
let userId: string;
let fremd: string;

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
  const m = await legeMitgliedAn("api-plan", { studios: [s.voll] });
  bearer = await accessTokenFor(m.email);
  userId = m.userId;
  const f = await legeMitgliedAn("api-plan-fremd", { studios: [s.voll] });
  fremd = await accessTokenFor(f.email);
});

describe("/me/plans", () => {
  it("401 ohne Token", async () => {
    expect((await post(undefined, { studioId: s.voll })).status).toBe(401);
    expect((await get(undefined)).status).toBe(401);
    expect((await accept(undefined, crypto.randomUUID())).status).toBe(401);
  });

  it("POST -> 201 Vorschlag, accept -> 200 aktiv, GET listet", async () => {
    const antwort = await post(bearer, { studioId: s.voll });
    expect(antwort.status).toBe(201);
    const plan = (await antwort.json()) as { id: string; status: string; einheiten: Array<{ positionen: unknown[] }> };
    expect(plan.status).toBe("vorschlag");
    expect(plan.einheiten[0]!.positionen.length).toBeGreaterThan(0);

    const angenommen = await accept(bearer, plan.id);
    expect(angenommen.status).toBe(200);
    expect(((await angenommen.json()) as { status: string }).status).toBe("aktiv");

    const liste = await get(bearer);
    expect(liste.status).toBe(200);
    expect(liste.headers.get("cache-control")).toBe("private, no-store");
    const plaene = (await liste.json()) as Array<{ id: string; status: string }>;
    expect(plaene.map((p) => [p.id, p.status])).toEqual([[plan.id, "aktiv"]]);
  });

  it("accept fremder Plan -> 409, Plan bleibt Vorschlag", async () => {
    const plan = (await (await post(bearer, { studioId: s.voll })).json()) as { id: string };
    expect((await accept(fremd, plan.id)).status).toBe(409);
    const meine = (await (await get(bearer)).json()) as Array<{ id: string; status: string }>;
    expect(meine.find((p) => p.id === plan.id)!.status).toBe("vorschlag");
    expect(await (await get(fremd)).json()).toEqual([]);
  });

  it("404 fuer ein Studio ohne Mitgliedschaft", async () => {
    const antwort = await post(bearer, { studioId: s.voll2 });
    expect(antwort.status).toBe(404);
    expect(((await antwort.json()) as Fehler).error.code).toBe("not_found");
  });

  it("422 bei ungueltiger studioId oder Plan-ID", async () => {
    expect((await post(bearer, { studioId: "abc" })).status).toBe(422);
    expect((await accept(bearer, "abc")).status).toBe(422);
  });

  it("POST plans ohne studioId erzeugt im Freien Training", async () => {
    const m = await legeMitgliedAn("api-plan-frei", { studios: [] });
    const antwort = await post(await accessTokenFor(m.email), {});
    expect(antwort.status).toBe(201);
    expect(((await antwort.json()) as { studioId: string }).studioId).toBe(GYMTAVO);
  });

  it("422 profil_unvollstaendig traegt code", async () => {
    const m = await legeMitgliedAn("api-plan-unvollst", { studios: [s.voll], profil: null });
    const antwort = await post(await accessTokenFor(m.email), { studioId: s.voll });
    expect(antwort.status).toBe(422);
    const body = (await antwort.json()) as Fehler;
    expect(body.error.code).toBe("profil_unvollstaendig");
    expect(body.error.detail).toEqual({ fehlt: ["trainingsprofil"] });
  });

  it("422 plan_nicht_moeglich traegt code, baustein und grund", async () => {
    // Der Katalog ist geteilt; "kein Geraet" entsteht darum ueber die Merkliste: alle
    // Druckuebungen fehlen am Ort.
    const m = await legeMitgliedAn("api-plan-unmoeglich", { studios: [s.voll] });
    const { data: druck, error } = await admin.from("exercises").select("id").eq("plan_baustein", "druecken");
    if (error) throw error;
    const { error: e } = await admin.from("plan_merkliste").insert(
      (druck ?? []).map((u) => ({ user_id: m.userId, exercise_id: u.id, art: "nicht_vorhanden", studio_id: s.voll })),
    );
    if (e) throw e;
    const antwort = await post(await accessTokenFor(m.email), { studioId: s.voll });
    expect(antwort.status).toBe(422);
    const body = (await antwort.json()) as Fehler;
    expect(body.error.code).toBe("plan_nicht_moeglich");
    expect(body.error.detail).toEqual({ baustein: "druecken", grund: "kein_geraet" });
    expect(body.error.message).not.toContain("druecken");
  });
});

describe("fromDomainError", () => {
  it("laesst die Huelle ohne detail unveraendert", async () => {
    const antwort = fromDomainError(new DomainError("conflict", "Nein."));
    expect(antwort.status).toBe(409);
    expect(await antwort.json()).toEqual({ error: { code: "conflict", message: "Nein." } });
  });
});

describe("/me/plans/[id]/swap", () => {
  async function aktiverPlan() {
    const plan = (await (await post(bearer, { studioId: s.voll })).json()) as { id: string };
    const angenommen = await accept(bearer, plan.id);
    return (await angenommen.json()) as {
      id: string;
      version: number;
      einheiten: Array<{ key: string; positionen: Array<{ key: string; baustein: string; exerciseId: string; modelId: string }> }>;
    };
  }

  it("401 ohne Token", async () => {
    expect((await swap(undefined, crypto.randomUUID(), {})).status).toBe(401);
  });

  it("200 mit status aktiv und version +1", async () => {
    const plan = await aktiverPlan();
    const pos = plan.einheiten[0]!.positionen[0]!;
    const antwort = await swap(bearer, plan.id, {
      einheitKey: plan.einheiten[0]!.key,
      positionKey: pos.key,
      exerciseId: pos.exerciseId,
      modelId: pos.modelId,
    });
    expect(antwort.status).toBe(200);
    const neu = (await antwort.json()) as { id: string; status: string; version: number };
    expect(neu).toMatchObject({ status: "aktiv", version: plan.version + 1 });
    expect(neu.id).not.toBe(plan.id);
  });

  it("422 bei unbekanntem positionKey und bei kaputtem Rumpf", async () => {
    const plan = await aktiverPlan();
    const pos = plan.einheiten[0]!.positionen[0]!;
    const antwort = await swap(bearer, plan.id, {
      einheitKey: plan.einheiten[0]!.key,
      positionKey: "gibt-es-nicht",
      exerciseId: pos.exerciseId,
      modelId: pos.modelId,
    });
    expect(antwort.status).toBe(422);
    expect(((await antwort.json()) as Fehler).error.code).toBe("validation_failed");
    expect((await swap(bearer, plan.id, { einheitKey: "A" })).status).toBe(422);
    expect((await swap(bearer, "abc", {})).status).toBe(422);
  });

  it("409 fuer fremden Plan", async () => {
    const plan = await aktiverPlan();
    const pos = plan.einheiten[0]!.positionen[0]!;
    const antwort = await swap(fremd, plan.id, {
      einheitKey: plan.einheiten[0]!.key,
      positionKey: pos.key,
      exerciseId: pos.exerciseId,
      modelId: pos.modelId,
    });
    expect(antwort.status).toBe(409);
  });

  // Eine Beinposition und eine andere Uebung desselben Bausteins aus dem Katalogmodell der Tests
  // (der Katalog ist geteilt, die Position kann auch eine Uebung anderer Tests tragen).
  async function beinTausch(plan: Awaited<ReturnType<typeof aktiverPlan>>) {
    const alle = plan.einheiten.flatMap((e) => e.positionen.map((p) => ({ ...p, einheitKey: e.key })));
    const pos = alle.find((p) => p.baustein === "beine_knie")!;
    const neueUebung = [s.uebungen["Beinpresse"], s.uebungen["Hackenschmidt"]].find((id) => id !== pos.exerciseId)!;
    return {
      pos,
      rumpf: { einheitKey: pos.einheitKey, positionKey: pos.key, exerciseId: neueUebung, modelId: s.katalogModell },
    };
  }
  const merkliste = async () => {
    const { data, error } = await admin.from("plan_merkliste").select("exercise_id, art, studio_id").eq("user_id", userId);
    if (error) throw error;
    return data ?? [];
  };
  afterEach(async () => {
    vi.restoreAllMocks();
    await admin.from("plan_merkliste").delete().eq("user_id", userId);
  });

  it("swap mit grund nicht_vorhanden tauscht und merkt die alte Uebung am Ort", async () => {
    const plan = await aktiverPlan();
    const { pos, rumpf } = await beinTausch(plan);
    const antwort = await swap(bearer, plan.id, { ...rumpf, grund: "nicht_vorhanden", ortId: s.voll });
    expect(antwort.status).toBe(200);
    expect(await merkliste()).toEqual([{ exercise_id: pos.exerciseId, art: "nicht_vorhanden", studio_id: s.voll }]);
  });

  it("swap mit grund nicht_vorhanden ohne ortId merkt am Katalog-Studio", async () => {
    const plan = await aktiverPlan();
    const { pos, rumpf } = await beinTausch(plan);
    expect((await swap(bearer, plan.id, { ...rumpf, grund: "nicht_vorhanden" })).status).toBe(200);
    expect(await merkliste()).toEqual([{ exercise_id: pos.exerciseId, art: "nicht_vorhanden", studio_id: GYMTAVO }]);
  });

  it("swap mit grund gefaellt_nicht merkt ohne Ort", async () => {
    const plan = await aktiverPlan();
    const { pos, rumpf } = await beinTausch(plan);
    expect((await swap(bearer, plan.id, { ...rumpf, grund: "gefaellt_nicht", ortId: s.voll })).status).toBe(200);
    expect(await merkliste()).toEqual([{ exercise_id: pos.exerciseId, art: "gefaellt_nicht", studio_id: null }]);
  });

  it("swap ohne grund merkt nichts; ein unbekannter grund ist 422", async () => {
    const plan = await aktiverPlan();
    const { rumpf } = await beinTausch(plan);
    expect((await swap(bearer, plan.id, { ...rumpf, grund: "egal" })).status).toBe(422);
    expect((await swap(bearer, plan.id, rumpf)).status).toBe(200);
    expect(await merkliste()).toEqual([]);
  });

  it("Eintragsfehler bricht den Tausch nicht ab und wird ohne Grund oder Uebung protokolliert", async () => {
    const plan = await aktiverPlan();
    const { pos, rumpf } = await beinTausch(plan);
    const fehler = vi.spyOn(console, "error").mockImplementation(() => {});
    // Ein Studio ohne Mitgliedschaft: die Policy lehnt den Eintrag ab.
    const antwort = await swap(bearer, plan.id, { ...rumpf, grund: "nicht_vorhanden", ortId: s.voll2 });
    expect(antwort.status).toBe(200);
    expect(((await antwort.json()) as { version: number }).version).toBe(plan.version + 1);
    expect(await merkliste()).toEqual([]);
    expect(fehler).toHaveBeenCalledTimes(1);
    const text = String(fehler.mock.calls[0]![0]);
    expect(text).toContain("Merkliste");
    for (const nicht of [pos.exerciseId, "nicht_vorhanden", "gefaellt_nicht", s.voll2]) expect(text).not.toContain(nicht);
  });
});

// ---------------------------------------------------------------------------
// Zielgewichte (Etappe 4, Task 5; G9, G13)
// ---------------------------------------------------------------------------

type Position = {
  key: string;
  baustein: string;
  rolle: string;
  exerciseId: string;
  modelId: string;
  wdhVon: number | null;
};
type PlanJson = { id: string; version: number; einheiten: Array<{ key: string; positionen: Position[] }> };

const admin = serviceClient();
const istKraft = (p: Position) => p.rolle !== "cardio" && p.wdhVon !== null;

/** Positionen mit Einheit und zielSchluessel. */
const stellen = (plan: PlanJson) =>
  plan.einheiten.flatMap((e) => e.positionen.map((p) => ({ ...p, einheitKey: e.key, ziel: zielSchluessel(e.key, p.key) })));

async function zieleVon(planId: string) {
  const { data, error } = await admin.from("plan_gewichte").select("einheit_key, position_key, load, grund").eq("plan_id", planId);
  if (error) throw error;
  return Object.fromEntries(
    (data ?? []).map((z) => [
      zielSchluessel(z.einheit_key as string, z.position_key as string),
      { load: Number(z.load), grund: z.grund as string | null },
    ]),
  );
}

async function setzeZiel(planId: string, p: { einheitKey: string; key: string }, load: number, grund: string) {
  const { error } = await admin
    .from("plan_gewichte")
    .update({ load, grund })
    .eq("plan_id", planId)
    .eq("einheit_key", p.einheitKey)
    .eq("position_key", p.key);
  if (error) throw error;
}

describe("Zielgewichte bei Annahme und Tausch", () => {
  async function aktiv(): Promise<PlanJson> {
    const plan = (await (await post(bearer, { studioId: s.voll })).json()) as { id: string };
    return (await (await accept(bearer, plan.id)).json()) as PlanJson;
  }

  it("accept setzt Startwerte fuer jede Kraftposition (G13)", async () => {
    const plan = await aktiv();
    const z = await zieleVon(plan.id);
    const kraft = stellen(plan).filter(istKraft);
    expect(plan.einheiten.length).toBeGreaterThan(1);
    expect(Object.keys(z).sort()).toEqual(kraft.map((p) => p.ziel).sort());
    for (const p of kraft) expect(z[p.ziel]!.grund).toBe("startschaetzung");
  });

  it("ein dauerhafter Tausch behaelt die Ziele gleicher Uebung am gleichen Modell (G9)", async () => {
    const plan = await aktiv();
    const getauscht = stellen(plan).find((p) => p.baustein === "beine_knie")!;
    const bleibt = stellen(plan).find((p) => istKraft(p) && p.ziel !== getauscht.ziel)!;
    await setzeZiel(plan.id, bleibt, 77.5, "korridor_oben_erreicht");
    await setzeZiel(plan.id, getauscht, 95, "korridor_oben_erreicht");
    const andere = [s.uebungen["Beinpresse"], s.uebungen["Hackenschmidt"]].find((id) => id !== getauscht.exerciseId)!;

    const antwort = await swap(bearer, plan.id, {
      einheitKey: getauscht.einheitKey, positionKey: getauscht.key, exerciseId: andere, modelId: s.katalogModell,
    });
    expect(antwort.status).toBe(200);
    const neu = (await antwort.json()) as PlanJson;

    const z = await zieleVon(neu.id);
    expect(Object.keys(z).sort()).toEqual(stellen(neu).filter(istKraft).map((p) => p.ziel).sort());
    expect(z[bleibt.ziel]).toEqual({ load: 77.5, grund: "korridor_oben_erreicht" });
    // Die neue Uebung bekommt ihren eigenen Startwert, nicht das Ziel der alten.
    expect(z[getauscht.ziel]).toMatchObject({ grund: "startschaetzung" });
    expect(z[getauscht.ziel]!.load).not.toBe(95);

    // Tausch auf dieselbe Uebung am selben Modell: das Ziel bleibt.
    const nochmal = await swap(bearer, neu.id, {
      einheitKey: bleibt.einheitKey, positionKey: bleibt.key, exerciseId: bleibt.exerciseId, modelId: bleibt.modelId,
    });
    expect(nochmal.status).toBe(200);
    const v3 = (await nochmal.json()) as PlanJson;
    expect((await zieleVon(v3.id))[bleibt.ziel]).toEqual({ load: 77.5, grund: "korridor_oben_erreicht" });
  });
});

describe("POST /workout-sessions/[id]/complete -- Zielgewichte", () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it("antwortet 200 und beendet die Session, auch wenn die Zielgewichte scheitern", async () => {
    const m = await legeMitgliedAn("api-plan-abschluss", { studios: [s.voll] });
    const token = await accessTokenFor(m.email);
    const { data: maschine, error: me } = await admin.from("machines").select("id").eq("studio_id", s.voll).single();
    if (me) throw me;
    // Kaputter Plan: derselbe Positionsschluessel zweimal in Einheit A. Die Datenbank
    // lehnt die Zeilen ab (plan_ungueltig) -- der Abschluss darf daran nicht haengen.
    const position = {
      key: "doppelt", baustein: "beine_knie", rolle: "pflicht", exerciseId: s.uebungen["Beinpresse"],
      modelId: s.katalogModell, typ: "mehrgelenk", saetze: 3, wdhVon: 8, wdhBis: 12, reserveVon: 2, reserveBis: 3,
      pauseSek: 90, aufwaermsatz: true, dauerMin: null, hauptmuskeln: [],
    };
    const { data: plan, error: pe } = await admin
      .from("training_plans")
      .insert({
        user_id: m.userId, studio_id: GYMTAVO, version: 1, status: "aktiv", regel_version: "test",
        eingabe: { ziel: "muskelaufbau", tage: 2, minuten: 60, fokus: [], erfahrung: "regelmaessig", anfaengerBeendet: false, beschwerdenBeruecksichtigt: false },
        struktur: "gk_ab",
        einheiten: [
          { key: "A", positionen: [position, position], geschaetzteMinuten: 45 },
          { key: "B", positionen: [position], geschaetzteMinuten: 45 },
        ],
        gruende: [], accepted_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (pe) throw pe;
    const sid = crypto.randomUUID();
    const start = Date.now() - 3_600_000;
    const { error: se } = await admin.from("workout_sessions").insert({
      id: sid, studio_id: s.voll, user_id: m.userId, started_at: new Date(start).toISOString(),
      plan_id: plan!.id, plan_einheit_key: "A", plan_stand: 1,
    });
    if (se) throw se;
    const { error: we } = await admin.from("workout_sets").insert(
      [1, 2, 3].map((n) => ({
        id: crypto.randomUUID(), studio_id: s.voll, user_id: m.userId, session_id: sid, machine_id: maschine!.id,
        exercise_id: s.uebungen["Beinpresse"], set_index: n, load: 50, volume: 12, rir: 2, set_role: "arbeit",
        performed_at: new Date(start + n * 60_000).toISOString(),
      })),
    );
    if (we) throw we;
    const fehler = vi.spyOn(console, "error").mockImplementation(() => {});

    const antwort = await completePOST(
      new Request(`http://localhost/api/v1/workout-sessions/${sid}/complete`, { method: "POST", headers: kopf(token) }),
      { params: Promise.resolve({ sessionId: sid }) },
    );

    expect(antwort.status).toBe(200);
    expect(((await antwort.json()) as { completedReason: string }).completedReason).toBe("manual");
    expect(fehler).toHaveBeenCalledWith(expect.stringContaining("plangewichte"));
    const { data: session } = await admin
      .from("workout_sessions")
      .select("completed_at, gewichte_berechnet_at")
      .eq("id", sid)
      .single();
    expect(session!.completed_at).not.toBeNull();
    expect(session!.gewichte_berechnet_at).toBeNull();
  });
});
