import { beforeAll, describe, expect, it } from "vitest";
import { GET, POST } from "@/app/api/v1/me/plans/route";
import { POST as acceptPOST } from "@/app/api/v1/me/plans/[id]/accept/route";
import { POST as swapPOST } from "@/app/api/v1/me/plans/[id]/swap/route";
import { fromDomainError } from "@/lib/api/respond";
import { DomainError } from "@fitretro/domain";
import { accessTokenFor } from "./helpers/clients.js";
import { legeMitgliedAn, legePlanStudiosAn, type PlanStudios } from "./helpers/plan-studio.js";

const BASIS = "http://localhost/api/v1/me/plans";
const kopf = (auth?: string) => (auth ? { authorization: `Bearer ${auth}` } : {});
const post = (auth: string | undefined, rumpf: unknown) =>
  POST(new Request(BASIS, { method: "POST", headers: kopf(auth), body: JSON.stringify(rumpf) }));
const get = (auth: string | undefined, studioId?: string) =>
  GET(new Request(studioId ? `${BASIS}?studioId=${studioId}` : BASIS, { headers: kopf(auth) }));
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
let fremd: string;

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
  const m = await legeMitgliedAn("api-plan", { studios: [s.voll] });
  bearer = await accessTokenFor(m.email);
  const f = await legeMitgliedAn("api-plan-fremd", { studios: [s.voll] });
  fremd = await accessTokenFor(f.email);
});

describe("/me/plans", () => {
  it("401 ohne Token", async () => {
    expect((await post(undefined, { studioId: s.voll })).status).toBe(401);
    expect((await get(undefined, s.voll)).status).toBe(401);
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

    const liste = await get(bearer, s.voll);
    expect(liste.status).toBe(200);
    expect(liste.headers.get("cache-control")).toBe("private, no-store");
    const plaene = (await liste.json()) as Array<{ id: string; status: string }>;
    expect(plaene.map((p) => [p.id, p.status])).toEqual([[plan.id, "aktiv"]]);
  });

  it("accept fremder Plan -> 409, Plan bleibt Vorschlag", async () => {
    const plan = (await (await post(bearer, { studioId: s.voll })).json()) as { id: string };
    expect((await accept(fremd, plan.id)).status).toBe(409);
    const meine = (await (await get(bearer, s.voll)).json()) as Array<{ id: string; status: string }>;
    expect(meine.find((p) => p.id === plan.id)!.status).toBe("vorschlag");
    expect(await (await get(fremd, s.voll)).json()).toEqual([]);
  });

  it("404 fuer ein Studio ohne Mitgliedschaft", async () => {
    const antwort = await post(bearer, { studioId: s.voll2 });
    expect(antwort.status).toBe(404);
    expect(((await antwort.json()) as Fehler).error.code).toBe("not_found");
  });

  it("422 bei fehlender oder ungueltiger studioId", async () => {
    expect((await post(bearer, {})).status).toBe(422);
    expect((await post(bearer, { studioId: "abc" })).status).toBe(422);
    expect((await get(bearer)).status).toBe(422);
    expect((await accept(bearer, "abc")).status).toBe(422);
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
    const m = await legeMitgliedAn("api-plan-unmoeglich", { studios: [s.ohneDruck] });
    const antwort = await post(await accessTokenFor(m.email), { studioId: s.ohneDruck });
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
      einheiten: Array<{ key: string; positionen: Array<{ key: string; exerciseId: string; machineId: string }> }>;
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
      machineId: pos.machineId,
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
      machineId: pos.machineId,
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
      machineId: pos.machineId,
    });
    expect(antwort.status).toBe(409);
  });
});
