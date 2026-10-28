import { beforeAll, describe, expect, it } from "vitest";
import { PUT } from "@/app/api/v1/workout-sessions/[sessionId]/sets/[setId]/route";
import { DELETE } from "@/app/api/v1/workout-sessions/[sessionId]/route";
import { accessTokenFor, serviceClient } from "./helpers/clients.js";
import {
  aktiverKatalogPlan,
  erzeugeKatalogPlan,
  legeMitgliedAn,
  legePlanStudiosAn,
  machineVon,
  nimmKatalogPlanAn,
  type KatalogPlan,
  type Mitglied,
  type PlanStudios,
} from "./helpers/plan-studio.js";

// Seit 0066 gehoert der Plan dem Katalog-Studio (Positionen nennen modelId); die
// Session laeuft im Studio des Mitglieds, der Satz nennt das Geraet dort.
//
// Etappe 3, Task 4: jeder Satz-PUT traegt eine Momentaufnahme des Plans der
// laufenden Einheit. Der Server haelt sie je Session fest (Status je
// Position, gebunden an die Planeinheit), damit spaeter "Einheit zaehlt",
// Zaehler und naechste Einheit daraus folgen. Aufbau wie
// domain-trainingsplan.test.ts, die Saetze laufen ueber die echte Route.
const admin = serviceClient();
let s: PlanStudios;
let ich: Mitglied;
let token: string;
let plan: KatalogPlan;
let fremderPlan: KatalogPlan;
let geraet: { id: string; equipment_model_id: string };

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
  ich = await legeMitgliedAn("sess-plan", { studios: [s.voll] });
  token = await accessTokenFor(ich.email);
  geraet = await machineVon(s.voll);
  plan = await aktiverKatalogPlan(ich, s);

  const anderer = await legeMitgliedAn("sess-plan-fremd", { studios: [s.voll] });
  fremderPlan = await aktiverKatalogPlan(anderer, s);
});

const einheit = () => plan.einheiten[0]!;
const pos = (i: number) => einheit().positionen[i]!;

function satz(sessionId: string, setId: string, rumpf: Record<string, unknown>, bearer = token) {
  return PUT(
    new Request("http://localhost/api/v1/workout-sessions/x/sets/y", {
      method: "PUT",
      headers: { "content-type": "application/json", authorization: `Bearer ${bearer}` },
      body: JSON.stringify(rumpf),
    }),
    { params: Promise.resolve({ sessionId, setId }) },
  );
}

function rumpf(extra: Record<string, unknown> = {}) {
  return { machineId: geraet.id, exerciseId: pos(0).exerciseId, setIndex: 1, load: 80, volume: 10, ...extra };
}

function planRumpf(stand: number, positionen: Array<Record<string, unknown>>, p: KatalogPlan = plan) {
  return { planId: p.id, einheitKey: p.einheiten[0]!.key, stand, positionen };
}

async function session(id: string) {
  const { data, error } = await admin
    .from("workout_sessions")
    .select("plan_id, plan_einheit_key, plan_stand")
    .eq("id", id)
    .single();
  if (error) throw error;
  return data as { plan_id: string | null; plan_einheit_key: string | null; plan_stand: number };
}

async function status(sessionId: string) {
  const { data, error } = await admin
    .from("session_plan_status")
    .select("position_key, status, exercise_id, user_id")
    .eq("session_id", sessionId)
    .order("position_key");
  if (error) throw error;
  return data as Array<{ position_key: string; status: string; exercise_id: string | null; user_id: string }>;
}

async function satzDa(setId: string): Promise<boolean> {
  const { data, error } = await admin.from("workout_sets").select("id").eq("id", setId).maybeSingle();
  if (error) throw error;
  return data !== null;
}

async function uebernommen(antwort: Response): Promise<unknown> {
  expect(antwort.status).toBe(200);
  return ((await antwort.json()) as { planUebernommen?: boolean }).planUebernommen;
}

const LEER = { plan_id: null, plan_einheit_key: null, plan_stand: 0 };

const sortiert = <T extends { position_key: string }>(z: T[]) =>
  [...z].sort((a, b) => a.position_key.localeCompare(b.position_key));

describe("Session und Planeinheit (0063)", () => {
  it("erster Satz mit plan setzt plan_id, plan_einheit_key und die Statuszeilen", async () => {
    const sessionId = crypto.randomUUID();
    const ersatz = pos(2).exerciseId;
    const antwort = await satz(sessionId, crypto.randomUUID(), rumpf({
      plan: planRumpf(1, [
        { key: pos(0).key, status: "erledigt" },
        { key: pos(1).key, status: "offen", exerciseId: null },
        { key: pos(2).key, status: "getauscht", exerciseId: ersatz },
      ]),
    }));
    expect(await uebernommen(antwort)).toBe(true);
    expect(await session(sessionId)).toEqual({ plan_id: plan.id, plan_einheit_key: einheit().key, plan_stand: 1 });
    expect(await status(sessionId)).toEqual(sortiert([
      { position_key: pos(0).key, status: "erledigt", exercise_id: null, user_id: ich.userId },
      { position_key: pos(1).key, status: "offen", exercise_id: null, user_id: ich.userId },
      { position_key: pos(2).key, status: "getauscht", exercise_id: ersatz, user_id: ich.userId },
    ]));
    // Das Mitglied liest seine eigenen Statuszeilen (select_own).
    const { data } = await ich.client.from("session_plan_status").select("position_key").eq("session_id", sessionId);
    expect(data).toHaveLength(3);
  });

  it("Satz ohne plan laesst alles wie bisher", async () => {
    const sessionId = crypto.randomUUID();
    expect((await satz(sessionId, crypto.randomUUID(), rumpf())).status).toBe(200);
    expect(await session(sessionId)).toEqual({ plan_id: null, plan_einheit_key: null, plan_stand: 0 });
    expect(await status(sessionId)).toEqual([]);
  });

  it("aelterer stand ueberschreibt keinen neueren", async () => {
    const sessionId = crypto.randomUUID();
    const satz1 = crypto.randomUUID();
    const satz2 = crypto.randomUUID();
    expect((await satz(sessionId, satz1, rumpf({
      plan: planRumpf(3, [{ key: pos(0).key, status: "erledigt" }, { key: pos(1).key, status: "optional" }]),
    }))).status).toBe(200);
    // Die App sendet nach der Reserve-Frage einen aelteren Rumpf erneut.
    expect((await satz(sessionId, satz2, rumpf({
      setIndex: 2,
      plan: planRumpf(2, [{ key: pos(0).key, status: "offen" }]),
    }))).status).toBe(200);
    expect(await satzDa(satz2)).toBe(true);
    expect((await session(sessionId)).plan_stand).toBe(3);
    expect((await status(sessionId)).map((z) => [z.position_key, z.status])).toEqual(
      sortiert([
        { position_key: pos(0).key, status: "erledigt" },
        { position_key: pos(1).key, status: "optional" },
      ]).map((z) => [z.position_key, z.status]),
    );
  });

  it("neuerer stand ersetzt alle Zeilen der Session", async () => {
    const sessionId = crypto.randomUUID();
    await satz(sessionId, crypto.randomUUID(), rumpf({
      plan: planRumpf(1, [{ key: pos(0).key, status: "offen" }, { key: pos(1).key, status: "offen" }]),
    }));
    await satz(sessionId, crypto.randomUUID(), rumpf({
      setIndex: 2,
      plan: planRumpf(2, [{ key: pos(0).key, status: "erledigt" }]),
    }));
    expect((await session(sessionId)).plan_stand).toBe(2);
    expect((await status(sessionId)).map((z) => [z.position_key, z.status])).toEqual([[pos(0).key, "erledigt"]]);
  });

  it("Replay desselben PUT ist idempotent", async () => {
    const sessionId = crypto.randomUUID();
    const setId = crypto.randomUUID();
    const r = rumpf({ plan: planRumpf(1, [{ key: pos(0).key, status: "erledigt" }]) });
    const erste = await satz(sessionId, setId, r);
    const vorher = { session: await session(sessionId), status: await status(sessionId) };
    const zweite = await satz(sessionId, setId, r);
    expect(erste.status).toBe(200);
    expect(zweite.status).toBe(200);
    expect(await zweite.json()).toEqual(await erste.json());
    expect({ session: await session(sessionId), status: await status(sessionId) }).toEqual(vorher);
  });

  it("plan eines anderen Nutzers wird abgelehnt, der Satz bleibt gespeichert", async () => {
    const sessionId = crypto.randomUUID();
    const setId = crypto.randomUUID();
    const antwort = await satz(sessionId, setId, rumpf({
      plan: planRumpf(1, [{ key: fremderPlan.einheiten[0]!.positionen[0]!.key, status: "erledigt" }], fremderPlan),
    }));
    expect(await uebernommen(antwort)).toBe(false);
    expect(await satzDa(setId)).toBe(true);
    expect(await session(sessionId)).toEqual(LEER);
    expect(await status(sessionId)).toEqual([]);
  });

  it("unbekannter positionKey: Satz bleibt, planUebernommen false", async () => {
    const sessionId = crypto.randomUUID();
    const setId = crypto.randomUUID();
    const antwort = await satz(sessionId, setId, rumpf({
      plan: planRumpf(1, [{ key: pos(0).key, status: "erledigt" }, { key: "gibt-es-nicht", status: "offen" }]),
    }));
    expect(await uebernommen(antwort)).toBe(false);
    expect(await satzDa(setId)).toBe(true);
    expect(await status(sessionId)).toEqual([]);
    expect((await session(sessionId)).plan_stand).toBe(0);
  });

  it("unbekannter einheitKey und unbekannte Ersatzuebung: planUebernommen false", async () => {
    const sessionId = crypto.randomUUID();
    const ohneEinheit = await satz(sessionId, crypto.randomUUID(), rumpf({
      plan: { ...planRumpf(1, [{ key: pos(0).key, status: "erledigt" }]), einheitKey: "Z" },
    }));
    expect(await uebernommen(ohneEinheit)).toBe(false);
    const ohneUebung = await satz(sessionId, crypto.randomUUID(), rumpf({
      setIndex: 2,
      plan: planRumpf(1, [{ key: pos(0).key, status: "getauscht", exerciseId: crypto.randomUUID() }]),
    }));
    expect(await uebernommen(ohneUebung)).toBe(false);
    expect(await session(sessionId)).toEqual(LEER);
  });

  it("Session loeschen entfernt die Statuszeilen", async () => {
    const sessionId = crypto.randomUUID();
    await satz(sessionId, crypto.randomUUID(), rumpf({ plan: planRumpf(1, [{ key: pos(0).key, status: "erledigt" }]) }));
    expect(await status(sessionId)).toHaveLength(1);
    const antwort = await DELETE(
      new Request("http://localhost/api/v1/workout-sessions/x", {
        method: "DELETE",
        headers: { authorization: `Bearer ${token}` },
      }),
      { params: Promise.resolve({ sessionId }) },
    );
    expect(antwort.status).toBe(204);
    expect(await status(sessionId)).toEqual([]);
  });

  it("alte App (ohne plan) PUT unveraendert 200", async () => {
    const sessionId = crypto.randomUUID();
    const setId = crypto.randomUUID();
    const antwort = await satz(sessionId, setId, rumpf());
    expect(antwort.status).toBe(200);
    const satzAntwort = (await antwort.json()) as Record<string, unknown>;
    expect(satzAntwort).toMatchObject({ id: setId, sessionId, exerciseId: pos(0).exerciseId, setIndex: 1 });
    expect(Object.keys(satzAntwort).some((k) => k.toLowerCase().includes("plan"))).toBe(false);
  });

  it("das Mitglied schreibt session_plan_status nicht direkt", async () => {
    const sessionId = crypto.randomUUID();
    await satz(sessionId, crypto.randomUUID(), rumpf());
    const { error } = await ich.client
      .from("session_plan_status")
      .insert({ session_id: sessionId, position_key: pos(0).key, user_id: ich.userId, status: "erledigt" });
    expect(error).not.toBeNull();
    expect(await status(sessionId)).toEqual([]);
  });

  it("das Mitglied setzt die Plan-Spalten der Session nicht direkt", async () => {
    const sessionId = crypto.randomUUID();
    await satz(sessionId, crypto.randomUUID(), rumpf());
    const { error: bindung } = await ich.client
      .from("workout_sessions")
      .update({ plan_id: fremderPlan.id, plan_einheit_key: fremderPlan.einheiten[0]!.key })
      .eq("id", sessionId);
    expect(bindung).not.toBeNull();
    const { error: stand } = await ich.client.from("workout_sessions").update({ plan_stand: 999 }).eq("id", sessionId);
    expect(stand).not.toBeNull();
    expect(await session(sessionId)).toEqual({ plan_id: null, plan_einheit_key: null, plan_stand: 0 });
  });

  it("Ersatzuebung in Grossbuchstaben (iOS-Kodierung) wird angenommen", async () => {
    const sessionId = crypto.randomUUID();
    const ersatz = pos(1).exerciseId;
    const antwort = await satz(sessionId, crypto.randomUUID(), rumpf({
      plan: planRumpf(1, [{ key: pos(1).key, status: "getauscht", exerciseId: ersatz.toUpperCase() }]),
    }));
    expect(antwort.status).toBe(200);
    expect((await status(sessionId))[0]).toMatchObject({ status: "getauscht", exercise_id: ersatz });
  });

  // Kontrollentscheid: ein kaputter Planteil verwirft nie den Satz.
  it("formal kaputter Planteil: Satz gespeichert, planUebernommen false", async () => {
    const faelle = [
      planRumpf(0, [{ key: pos(0).key, status: "erledigt" }]),
      planRumpf(1, [{ key: pos(0).key, status: "fertig" }]),
      planRumpf(1, [{ key: pos(0).key, status: "getauscht", exerciseId: "" }]),
      planRumpf(1, [{ key: pos(0).key, status: "getauscht" }]),
    ];
    for (const kaputt of faelle) {
      const sessionId = crypto.randomUUID();
      const setId = crypto.randomUUID();
      expect(await uebernommen(await satz(sessionId, setId, rumpf({ plan: kaputt })))).toBe(false);
      expect(await satzDa(setId)).toBe(true);
      expect(await session(sessionId)).toEqual(LEER);
    }
  });

  it("getauscht ohne Ersatzuebung lehnt auch die Funktion selbst ab", async () => {
    const sessionId = crypto.randomUUID();
    await satz(sessionId, crypto.randomUUID(), rumpf());
    const { error } = await ich.client.rpc("record_session_plan", {
      p_session_id: sessionId,
      p_plan_id: plan.id,
      p_einheit_key: einheit().key,
      p_stand: 1,
      p_positionen: [{ key: pos(0).key, status: "getauscht", exerciseId: null }],
    });
    expect(error?.message).toBe("plan_ungueltig");
    expect(await session(sessionId)).toEqual(LEER);
  });

  it("Katalogplan gilt in jedem Studio, ein Plan eines normalen Studios wird abgelehnt", async () => {
    const m = await legeMitgliedAn("sess-plan-zwei", { studios: [s.voll, s.voll2] });
    const t = await accessTokenFor(m.email);
    const katalog = await aktiverKatalogPlan(m, s);
    // Ein Plan aus der Zeit vor 0066 (Studioplan, aktiv): nicht mehr verknuepfbar.
    const { data: alt, error } = await admin
      .from("training_plans")
      .insert({
        user_id: m.userId, studio_id: s.voll, version: 1, status: "aktiv", regel_version: "1.2.0",
        eingabe: katalog.eingabe, struktur: "gk_ab", einheiten: katalog.einheiten, gruende: [],
        accepted_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (error) throw error;
    const studioPlan = { ...katalog, id: alt!.id as string };
    const dort = await machineVon(s.voll2);
    const r = (p: KatalogPlan, stand: number, setIndex: number, maschine = geraet.id) => ({
      machineId: maschine,
      exerciseId: katalog.einheiten[0]!.positionen[0]!.exerciseId,
      setIndex, load: 80, volume: 10,
      plan: planRumpf(stand, [{ key: p.einheiten[0]!.positionen[0]!.key, status: "erledigt" }], p),
    });
    const ungebunden = crypto.randomUUID();
    const setId = crypto.randomUUID();
    expect(await uebernommen(await satz(ungebunden, setId, r(studioPlan, 1, 1), t))).toBe(false);
    expect(await satzDa(setId)).toBe(true);
    expect(await session(ungebunden)).toEqual(LEER);

    // Derselbe Katalogplan in beiden Studios.
    const gebunden = crypto.randomUUID();
    expect(await uebernommen(await satz(gebunden, crypto.randomUUID(), r(katalog, 1, 1), t))).toBe(true);
    expect(await uebernommen(await satz(gebunden, crypto.randomUUID(), r(studioPlan, 2, 2), t))).toBe(false);
    expect(await session(gebunden)).toEqual({ plan_id: katalog.id, plan_einheit_key: katalog.einheiten[0]!.key, plan_stand: 1 });

    const anderswo = crypto.randomUUID();
    expect(await uebernommen(await satz(anderswo, crypto.randomUUID(), r(katalog, 1, 1, dort.id), t))).toBe(true);
    expect(await session(anderswo)).toEqual({ plan_id: katalog.id, plan_einheit_key: katalog.einheiten[0]!.key, plan_stand: 1 });
  });

  it("Vorschlag (nicht angenommen) wird abgelehnt", async () => {
    const m = await legeMitgliedAn("sess-plan-vorschlag", { studios: [s.voll] });
    const vorschlag = await erzeugeKatalogPlan(m, s);
    const sessionId = crypto.randomUUID();
    const setId = crypto.randomUUID();
    const antwort = await satz(sessionId, setId, {
      machineId: geraet.id,
      exerciseId: vorschlag.einheiten[0]!.positionen[0]!.exerciseId,
      setIndex: 1, load: 80, volume: 10,
      plan: planRumpf(1, [{ key: vorschlag.einheiten[0]!.positionen[0]!.key, status: "erledigt" }], vorschlag),
    }, await accessTokenFor(m.email));
    expect(await uebernommen(antwort)).toBe(false);
    expect(await satzDa(setId)).toBe(true);
    expect(await session(sessionId)).toEqual(LEER);
  });

  it("nach der Bindung: andere Einheit abgelehnt, neuere Version derselben Reihe angenommen", async () => {
    const m = await legeMitgliedAn("sess-plan-reihe", { studios: [s.voll] });
    const t = await accessTokenFor(m.email);
    const v1 = await aktiverKatalogPlan(m, s);
    expect(v1.einheiten.length).toBeGreaterThan(1);
    const [a, b] = v1.einheiten as [KatalogPlan["einheiten"][number], KatalogPlan["einheiten"][number]];
    const r = (p: KatalogPlan, einheitKey: string, key: string, stand: number, setIndex: number) => ({
      machineId: geraet.id,
      exerciseId: a.positionen[0]!.exerciseId,
      setIndex, load: 80, volume: 10,
      plan: { planId: p.id, einheitKey, stand, positionen: [{ key, status: "erledigt" }] },
    });
    const sessionId = crypto.randomUUID();
    expect(await uebernommen(await satz(sessionId, crypto.randomUUID(), r(v1, a.key, a.positionen[0]!.key, 1, 1), t))).toBe(true);
    // Zeilen der Einheit B an einer Session der Einheit A: abgelehnt.
    expect(await uebernommen(await satz(sessionId, crypto.randomUUID(), r(v1, b.key, b.positionen[0]!.key, 2, 2), t))).toBe(false);
    expect((await status(sessionId)).map((z) => z.position_key)).toEqual([a.positionen[0]!.key]);

    // Neue Version derselben Reihe (wie nach einem dauerhaften Tausch): angenommen, Bindung bleibt.
    const v2 = await nimmKatalogPlanAn(m, (await erzeugeKatalogPlan(m, s)).id);
    expect(v2.version).toBeGreaterThan(v1.version);
    const a2 = v2.einheiten.find((e) => e.key === a.key)!;
    expect(await uebernommen(await satz(sessionId, crypto.randomUUID(), r(v2, a.key, a2.positionen[1]!.key, 3, 3), t))).toBe(true);
    expect(await session(sessionId)).toEqual({ plan_id: v1.id, plan_einheit_key: a.key, plan_stand: 3 });
    expect((await status(sessionId)).map((z) => z.position_key)).toEqual([a2.positionen[1]!.key]);

    // Eine aeltere Version nach einer neueren ist keine Fortsetzung der Reihe.
    const andere = crypto.randomUUID();
    expect(await uebernommen(await satz(andere, crypto.randomUUID(), r(v2, a.key, a2.positionen[0]!.key, 1, 1), t))).toBe(true);
    expect(await uebernommen(await satz(andere, crypto.randomUUID(), r(v1, a.key, a.positionen[0]!.key, 2, 2), t))).toBe(false);
  });

  it("veraltetes erneutes Senden wird ignoriert statt abgelehnt", async () => {
    const sessionId = crypto.randomUUID();
    expect(await uebernommen(
      await satz(sessionId, crypto.randomUUID(), rumpf({ plan: planRumpf(3, [{ key: pos(0).key, status: "erledigt" }]) })),
    )).toBe(true);
    const antwort = await satz(sessionId, crypto.randomUUID(), rumpf({
      setIndex: 2,
      plan: planRumpf(2, [{ key: "gibt-es-nicht", status: "offen" }]),
    }));
    expect(await uebernommen(antwort)).toBe(true);
    expect((await status(sessionId)).map((z) => [z.position_key, z.status])).toEqual([[pos(0).key, "erledigt"]]);
  });
});
