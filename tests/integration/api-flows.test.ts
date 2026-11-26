import { beforeAll, describe, expect, it } from "vitest";
import { GET } from "@/app/api/v1/me/flows/route";
import { PUT } from "@/app/api/v1/me/flow-runs/[runId]/route";
import { accessTokenFor, createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

const get = (auth?: string): Request =>
  new Request("http://localhost/api/v1/me/flows", { method: "GET", headers: auth ? { authorization: `Bearer ${auth}` } : {} });

const put = (runId: string, auth?: string, body?: unknown): [Request, { params: Promise<{ runId: string }> }] => [
  new Request(`http://localhost/api/v1/me/flow-runs/${runId}`, {
    method: "PUT",
    headers: { ...(auth ? { authorization: `Bearer ${auth}` } : {}), "content-type": "application/json" },
    body: body !== undefined ? JSON.stringify(body) : null,
  }),
  { params: Promise.resolve({ runId }) },
];

let studioA: string;
let studioB: string;
let flowA: string;
let flowB: string;
let tokenA: string;
let tokenOhne: string;

async function neuesStudio(name: string): Promise<string> {
  const { data, error } = await serviceClient().from("studios").insert({ name, timezone: "Europe/Berlin" }).select("id").single();
  if (error) throw error;
  return data!.id;
}

async function neuerFlow(studioId: string, key: string): Promise<string> {
  const admin = serviceClient();
  const { data, error } = await admin.from("flows").insert({ studio_id: studioId, key, titel: `Flow ${key}` }).select("id").single();
  if (error) throw error;
  const { error: e2 } = await admin.from("flow_steps").insert([
    { flow_id: data!.id, position: 2, name: "Kniebeuge", work_s: 40, rest_s: 20, is_warmup: false },
    { flow_id: data!.id, position: 1, name: "Aufwaermen", work_s: 30, rest_s: 10, is_warmup: true },
  ]);
  if (e2) throw e2;
  return data!.id;
}

beforeAll(async () => {
  studioA = await neuesStudio("API Flows A");
  studioB = await neuesStudio("API Flows B");
  flowA = await neuerFlow(studioA, "api-flow-a");
  flowB = await neuerFlow(studioB, "api-flow-b");
  const email = uniqueEmail("api-flows-a");
  const id = await createTestUser(email);
  const { error } = await serviceClient().from("studio_memberships").insert({ studio_id: studioA, user_id: id, role: "member" });
  if (error) throw error;
  tokenA = await accessTokenFor(email);
  const email2 = uniqueEmail("api-flows-x");
  await createTestUser(email2);
  tokenOhne = await accessTokenFor(email2);
});

const lauf = (over: Record<string, unknown> = {}) => ({
  flowId: flowA,
  startedAt: "2026-11-26T10:00:00Z",
  endedAt: "2026-11-26T10:10:00Z",
  lastStep: 2,
  outcome: "finished",
  ...over,
});

describe("/me/flows", () => {
  it("401 ohne Token", async () => {
    expect((await GET(get())).status).toBe(401);
    expect((await PUT(...put(crypto.randomUUID(), undefined, lauf()))).status).toBe(401);
  });

  it("GET liefert den Flow des eigenen Studios mit sortierten Schritten und dauerS", async () => {
    const antwort = await GET(get(tokenA));
    expect(antwort.status).toBe(200);
    expect(antwort.headers.get("cache-control")).toBe("private, no-store");
    const { flows } = await antwort.json();
    expect(flows).toHaveLength(1);
    expect(flows[0].id).toBe(flowA);
    expect(flows[0].schritte.map((s: { position: number }) => s.position)).toEqual([1, 2]);
    expect(flows[0].dauerS).toBe(100);
  });

  it("ohne Mitgliedschaft: flows []", async () => {
    expect(await (await GET(get(tokenOhne))).json()).toEqual({ flows: [] });
  });
});

describe("/me/flow-runs/{runId}", () => {
  it("PUT zweimal mit gleicher runId: beide 204, eine Zeile", async () => {
    const runId = crypto.randomUUID();
    expect((await PUT(...put(runId, tokenA, lauf()))).status).toBe(204);
    expect((await PUT(...put(runId, tokenA, lauf()))).status).toBe(204);
    const { data } = await serviceClient().from("flow_runs").select("id").eq("id", runId);
    expect(data).toHaveLength(1);
  });

  it("fremder Flow ist 404", async () => {
    const antwort = await PUT(...put(crypto.randomUUID(), tokenA, lauf({ flowId: flowB })));
    expect(antwort.status).toBe(404);
  });

  it("lastStep 0 ist 422 validation_failed", async () => {
    const antwort = await PUT(...put(crypto.randomUUID(), tokenA, lauf({ lastStep: 0 })));
    expect(antwort.status).toBe(422);
    expect((await antwort.json()).error.code).toBe("validation_failed");
  });

  it("runId ohne UUID-Form ist 422", async () => {
    expect((await PUT(...put("abc", tokenA, lauf()))).status).toBe(422);
  });

  it("kaputter Rumpf oder falsche Feldtypen sind 422", async () => {
    const [r, ctx] = put(crypto.randomUUID(), tokenA);
    expect((await PUT(new Request(r.url, { method: "PUT", headers: { authorization: `Bearer ${tokenA}` }, body: "{x" }), ctx)).status).toBe(422);
    expect((await PUT(...put(crypto.randomUUID(), tokenA, lauf({ lastStep: "2" })))).status).toBe(422);
    expect((await PUT(...put(crypto.randomUUID(), tokenA, lauf({ outcome: "x" })))).status).toBe(422);
    expect((await PUT(...put(crypto.randomUUID(), tokenA, lauf({ flowId: undefined })))).status).toBe(422);
  });
});
