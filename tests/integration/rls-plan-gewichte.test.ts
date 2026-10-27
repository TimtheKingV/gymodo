import { beforeAll, describe, expect, it } from "vitest";
import { acceptPlan, erzeugePlanVorschlag, type TrainingPlan } from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";
import { legeMitgliedAn, legePlanStudiosAn, type Mitglied, type PlanStudios } from "./helpers/plan-studio.js";

// Etappe 4, Task 3: Zielgewichte je Planposition (0064). Lesen nur die
// eigenen Zeilen; geschrieben wird ausschliesslich ueber set_plan_gewichte
// (nach einer abgeschlossenen Einheit, "nur neuerer Abschluss gewinnt") und
// init_plan_gewichte (nur Positionen ohne Zeile).
const admin = serviceClient();
let s: PlanStudios;
let ich: Mitglied;
let fremder: Mitglied;
let plan: TrainingPlan;
let fremderPlan: TrainingPlan;

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
  ich = await legeMitgliedAn("pg-ich", { studios: [s.voll] });
  fremder = await legeMitgliedAn("pg-fremd", { studios: [s.voll] });
  plan = await acceptPlan(ich.client, ich.userId, (await erzeugePlanVorschlag(ich.client, ich.userId, s.voll)).id);
  fremderPlan = await acceptPlan(
    fremder.client,
    fremder.userId,
    (await erzeugePlanVorschlag(fremder.client, fremder.userId, s.voll)).id,
  );
});

const key = (i: number, p: TrainingPlan = plan) => p.einheiten[0]!.positionen[i]!.key;
const zeile = (i: number, load: number, extra: Record<string, unknown> = {}, p: TrainingPlan = plan) => ({
  einheitKey: p.einheiten[0]!.key,
  positionKey: key(i, p),
  load,
  secondaryLoad: null,
  grund: "im_korridor",
  algoVersion: "v1",
  ...extra,
});

const HEUTE = Date.now();
const vor = (stunden: number) => new Date(HEUTE - stunden * 3_600_000).toISOString();

/** Session des Mitglieds; completedAt null = offen. */
async function legeSession(opts: { completedAt?: string | null; startedAt?: string; user?: Mitglied } = {}) {
  const u = opts.user ?? ich;
  const id = crypto.randomUUID();
  const startedAt = opts.startedAt ?? vor(5);
  const completedAt = opts.completedAt ?? null;
  const { error } = await admin.from("workout_sessions").insert({
    id,
    studio_id: s.voll,
    user_id: u.userId,
    started_at: startedAt,
    completed_at: completedAt,
    completed_reason: completedAt ? "manual" : null,
  });
  if (error) throw error;
  return id;
}

async function zeilen(planId: string) {
  const { data, error } = await admin
    .from("plan_gewichte")
    .select("einheit_key, position_key, user_id, load, secondary_load, grund, algo_version, stand_session_id, stand_completed_at")
    .eq("plan_id", planId)
    .order("einheit_key")
    .order("position_key");
  if (error) throw error;
  return data!;
}

async function setze(sessionId: string, z: unknown[], planId = plan.id, m: Mitglied = ich) {
  return m.client.rpc("set_plan_gewichte", { p_session_id: sessionId, p_plan_id: planId, p_zeilen: z });
}

async function leere(planId: string) {
  const { error } = await admin.from("plan_gewichte").delete().eq("plan_id", planId);
  if (error) throw error;
}

describe("Zielgewichte je Planposition (0064)", () => {
  it("set_plan_gewichte schreibt Zeilen mit Stand der Session", async () => {
    await leere(plan.id);
    const abgeschlossen = vor(1);
    const sid = await legeSession({ completedAt: abgeschlossen });
    const { error } = await setze(sid, [zeile(0, 40), zeile(1, 25, { secondaryLoad: 5, grund: null })]);
    expect(error).toBeNull();
    const z = await zeilen(plan.id);
    expect(z).toHaveLength(2);
    const a = z.find((r) => r.position_key === key(0))!;
    expect(a).toMatchObject({ user_id: ich.userId, load: 40, secondary_load: null, grund: "im_korridor", algo_version: "v1", stand_session_id: sid });
    expect(Date.parse(a.stand_completed_at)).toBe(Date.parse(abgeschlossen));
    expect(z.find((r) => r.position_key === key(1))).toMatchObject({ load: 25, secondary_load: 5, grund: null });
    const { data } = await admin.from("workout_sessions").select("gewichte_berechnet_at").eq("id", sid).single();
    expect(data!.gewichte_berechnet_at).not.toBeNull();
  });

  it("fremdes Mitglied sieht keine Zeilen", async () => {
    await leere(plan.id);
    await setze(await legeSession({ completedAt: vor(1) }), [zeile(0, 40)]);
    const eigene = await ich.client.from("plan_gewichte").select("position_key").eq("plan_id", plan.id);
    expect(eigene.data).toHaveLength(1);
    const fremd = await fremder.client.from("plan_gewichte").select("position_key").eq("plan_id", plan.id);
    expect(fremd.error).toBeNull();
    expect(fremd.data).toEqual([]);
  });

  it("direktes Insert, Update und Delete scheitern", async () => {
    await leere(plan.id);
    await setze(await legeSession({ completedAt: vor(1) }), [zeile(0, 40)]);
    const insert = await ich.client.from("plan_gewichte").insert({
      plan_id: plan.id, einheit_key: plan.einheiten[0]!.key, position_key: key(1), user_id: ich.userId, load: 99, algo_version: "v1",
    });
    expect(insert.error).not.toBeNull();
    await ich.client.from("plan_gewichte").update({ load: 99 }).eq("plan_id", plan.id);
    await ich.client.from("plan_gewichte").delete().eq("plan_id", plan.id);
    const z = await zeilen(plan.id);
    expect(z).toHaveLength(1);
    expect(z[0]!.load).toBe(40);
  });

  it("aeltere Session ueberschreibt neuere nicht, neuere ersetzt auch mit sinkendem Gewicht", async () => {
    await leere(plan.id);
    const neu = await legeSession({ completedAt: vor(1) });
    const alt = await legeSession({ completedAt: vor(3), startedAt: vor(4) });
    expect((await setze(neu, [zeile(0, 50)])).error).toBeNull();
    expect((await setze(alt, [zeile(0, 99)])).error).toBeNull();
    expect((await zeilen(plan.id))[0]).toMatchObject({ load: 50, stand_session_id: neu });
    const neuer = await legeSession({ completedAt: vor(0.5) });
    expect((await setze(neuer, [zeile(0, 45)])).error).toBeNull();
    expect((await zeilen(plan.id))[0]).toMatchObject({ load: 45, stand_session_id: neuer });
  });

  it("dieselbe Session zweimal ist idempotent", async () => {
    await leere(plan.id);
    const sid = await legeSession({ completedAt: vor(1) });
    await setze(sid, [zeile(0, 40)]);
    const erste = await zeilen(plan.id);
    expect((await setze(sid, [zeile(0, 40)])).error).toBeNull();
    expect(await zeilen(plan.id)).toEqual(erste);
    // Gleicher Stand mit anderem Gewicht aendert nichts (nur NEUERER Abschluss gewinnt).
    await setze(sid, [zeile(0, 77)]);
    expect(await zeilen(plan.id)).toEqual(erste);
  });

  it("Position eines anderen Plans -> plan_ungueltig, nichts geschrieben", async () => {
    await leere(plan.id);
    const sid = await legeSession({ completedAt: vor(1) });
    const { error } = await setze(sid, [zeile(0, 40), zeile(1, 40, { positionKey: "gibt-es-nicht" })]);
    expect(error?.message).toContain("plan_ungueltig");
    expect(await zeilen(plan.id)).toEqual([]);
    const { data } = await admin.from("workout_sessions").select("gewichte_berechnet_at").eq("id", sid).single();
    expect(data!.gewichte_berechnet_at).toBeNull();
  });

  it("Session nicht abgeschlossen -> plan_ungueltig; 4 h Leerlauf zaehlt als abgeschlossen", async () => {
    await leere(plan.id);
    const offen = await legeSession({ startedAt: vor(1) });
    expect((await setze(offen, [zeile(0, 40)])).error?.message).toContain("plan_ungueltig");
    expect(await zeilen(plan.id)).toEqual([]);

    const leerlauf = await legeSession({ startedAt: vor(5) });
    expect((await setze(leerlauf, [zeile(0, 40)])).error).toBeNull();
    const z = await zeilen(plan.id);
    expect(z).toHaveLength(1);
    expect(Date.parse(z[0]!.stand_completed_at)).toBe(Date.parse(vor(5)));
  });

  it("fremde und unbekannte Session/Plan antworten gleich", async () => {
    const fremdeSession = await legeSession({ completedAt: vor(1), user: fremder });
    const a = await setze(fremdeSession, [zeile(0, 40)]);
    const b = await setze(crypto.randomUUID(), [zeile(0, 40)]);
    const sid = await legeSession({ completedAt: vor(1) });
    const c = await setze(sid, [zeile(0, 40, {}, fremderPlan)], fremderPlan.id);
    const d = await setze(sid, [zeile(0, 40)], crypto.randomUUID());
    for (const r of [a, b, c, d]) expect(r.error?.message).toContain("plan_ungueltig");
    expect(new Set([a, b, c, d].map((r) => r.error?.code)).size).toBe(1);
  });

  it("gewichte_berechnet_at laesst sich nicht direkt setzen", async () => {
    const sid = await legeSession({ completedAt: vor(1) });
    const update = await ich.client.from("workout_sessions").update({ gewichte_berechnet_at: new Date().toISOString() }).eq("id", sid);
    expect(update.error?.code).toBe("42501");
    const insert = await ich.client.from("workout_sessions").insert({
      id: crypto.randomUUID(), studio_id: s.voll, user_id: ich.userId, gewichte_berechnet_at: new Date().toISOString(),
    });
    expect(insert.error?.code).toBe("42501");
    const { data } = await admin.from("workout_sessions").select("gewichte_berechnet_at").eq("id", sid).single();
    expect(data!.gewichte_berechnet_at).toBeNull();
  });

  it("init_plan_gewichte schreibt nur Positionen ohne Zeile", async () => {
    await leere(plan.id);
    await setze(await legeSession({ completedAt: vor(1) }), [zeile(0, 40)]);
    const { error } = await ich.client.rpc("init_plan_gewichte", {
      p_plan_id: plan.id,
      p_zeilen: [zeile(0, 10, { grund: "startschaetzung" }), zeile(1, 20, { grund: "startschaetzung" })],
    });
    expect(error).toBeNull();
    const z = await zeilen(plan.id);
    expect(z.find((r) => r.position_key === key(0))).toMatchObject({ load: 40 });
    expect(z.find((r) => r.position_key === key(1))).toMatchObject({
      load: 20, grund: "startschaetzung", stand_session_id: null, stand_completed_at: null,
    });
    // Eine spaetere Einheit ersetzt auch eine Initialzeile.
    await setze(await legeSession({ completedAt: vor(0.5) }), [zeile(1, 22)]);
    expect((await zeilen(plan.id)).find((r) => r.position_key === key(1))).toMatchObject({ load: 22 });
  });

  it("init_plan_gewichte: fremder, unbekannter Plan und fremde Position -> plan_ungueltig", async () => {
    const a = await ich.client.rpc("init_plan_gewichte", { p_plan_id: fremderPlan.id, p_zeilen: [zeile(0, 10, {}, fremderPlan)] });
    const b = await ich.client.rpc("init_plan_gewichte", { p_plan_id: crypto.randomUUID(), p_zeilen: [zeile(0, 10)] });
    const c = await ich.client.rpc("init_plan_gewichte", { p_plan_id: plan.id, p_zeilen: [zeile(0, 10, { positionKey: "gibt-es-nicht" })] });
    for (const r of [a, b, c]) expect(r.error?.message).toContain("plan_ungueltig");
  });

  it("anon darf die Funktionen nicht aufrufen", async () => {
    const { anonClient } = await import("./helpers/clients.js");
    const r = await anonClient().rpc("init_plan_gewichte", { p_plan_id: plan.id, p_zeilen: [] });
    expect(r.error).not.toBeNull();
  });

  it.each(["einheitKey", "positionKey", "load", "algoVersion"])("fehlendes %s in einer Zeile -> plan_ungueltig", async (fehlt) => {
    await leere(plan.id);
    const sid = await legeSession({ completedAt: vor(1) });
    const z: Record<string, unknown> = zeile(0, 40);
    delete z[fehlt];
    const a = await setze(sid, [z]);
    expect(a.error?.message).toContain("plan_ungueltig");
    const b = await ich.client.rpc("init_plan_gewichte", { p_plan_id: plan.id, p_zeilen: [z] });
    expect(b.error?.message).toContain("plan_ungueltig");
    expect(await zeilen(plan.id)).toEqual([]);
  });

  it("Abschluss in der Zukunft -> plan_ungueltig", async () => {
    await leere(plan.id);
    const sid = await legeSession({
      startedAt: vor(1),
      completedAt: new Date(Date.now() + 3_600_000).toISOString(),
    });
    expect((await setze(sid, [zeile(0, 40)])).error?.message).toContain("plan_ungueltig");
    expect(await zeilen(plan.id)).toEqual([]);
  });

  it("Session vor ueber 4 h gestartet, letzter Satz aber juenger -> plan_ungueltig", async () => {
    await leere(plan.id);
    const sid = await legeSession({ startedAt: vor(6) });
    const p = plan.einheiten[0]!.positionen[0]!;
    const { data: m } = await admin.from("machines").select("equipment_model_id").eq("id", p.machineId).single();
    const { error } = await admin.from("workout_sets").insert({
      id: crypto.randomUUID(), studio_id: s.voll, user_id: ich.userId, session_id: sid,
      machine_id: p.machineId, equipment_model_id: m!.equipment_model_id, exercise_id: p.exerciseId,
      set_index: 1, load: 40, volume: 10, performed_at: vor(1),
    });
    expect(error).toBeNull();
    expect((await setze(sid, [zeile(0, 40)])).error?.message).toContain("plan_ungueltig");
    expect(await zeilen(plan.id)).toEqual([]);
  });

  it("derselbe Positionsschluessel in zwei Einheiten sind zwei Zeilen (G14)", async () => {
    await leere(plan.id);
    const [a, b] = plan.einheiten as [TrainingPlan["einheiten"][number], TrainingPlan["einheiten"][number]];
    expect(b).toBeDefined();
    // Der Generator nummeriert je Einheit: beide haben eine Position "0".
    expect(a.positionen[0]!.key).toBe(b.positionen[0]!.key);
    const sid = await legeSession({ completedAt: vor(1) });
    const { error } = await setze(sid, [
      zeile(0, 40),
      { ...zeile(0, 60), einheitKey: b.key },
    ]);
    expect(error).toBeNull();
    const z = await zeilen(plan.id);
    expect(z.map((r) => [r.einheit_key, r.position_key, r.load])).toEqual(
      [[a.key, a.positionen[0]!.key, 40], [b.key, b.positionen[0]!.key, 60]].sort((x, y) => String(x[0]).localeCompare(String(y[0]))),
    );
    // init ebenso: je Paar eine Zeile.
    await leere(plan.id);
    const init = await ich.client.rpc("init_plan_gewichte", {
      p_plan_id: plan.id,
      p_zeilen: [zeile(0, 10), { ...zeile(0, 20), einheitKey: b.key }],
    });
    expect(init.error).toBeNull();
    expect(await zeilen(plan.id)).toHaveLength(2);
  });

  it("ein Paar, das es im Plan nicht gibt, und ein doppeltes Paar -> plan_ungueltig", async () => {
    await leere(plan.id);
    const sid = await legeSession({ completedAt: vor(1) });
    const fehlt = await setze(sid, [zeile(0, 40, { einheitKey: "gibt-es-nicht" })]);
    expect(fehlt.error?.message).toContain("plan_ungueltig");
    // Schluessel aus Einheit 0, den Einheit 1 nicht hat.
    const b = plan.einheiten[1]!;
    const fremdePos = plan.einheiten[0]!.positionen.find((p) => !b.positionen.some((q) => q.key === p.key));
    if (fremdePos) {
      const r = await setze(sid, [{ ...zeile(0, 40), einheitKey: b.key, positionKey: fremdePos.key }]);
      expect(r.error?.message).toContain("plan_ungueltig");
    }
    const doppelt = await setze(sid, [zeile(0, 40), zeile(0, 50)]);
    expect(doppelt.error?.message).toContain("plan_ungueltig");
    const initDoppelt = await ich.client.rpc("init_plan_gewichte", { p_plan_id: plan.id, p_zeilen: [zeile(0, 10), zeile(0, 20)] });
    expect(initDoppelt.error?.message).toContain("plan_ungueltig");
    expect(await zeilen(plan.id)).toEqual([]);
  });

  it("anon darf set_plan_gewichte nicht aufrufen", async () => {
    const { anonClient } = await import("./helpers/clients.js");
    const r = await anonClient().rpc("set_plan_gewichte", { p_session_id: crypto.randomUUID(), p_plan_id: plan.id, p_zeilen: [] });
    expect(r.error).not.toBeNull();
  });
});
