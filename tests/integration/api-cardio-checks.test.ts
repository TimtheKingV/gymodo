import { beforeAll, describe, expect, it } from "vitest";
import { DELETE, GET, POST, PUT } from "@/app/api/v1/me/cardio-checks/route";
import { accessTokenFor, anonClient, createTestUser, uniqueEmail, userClient } from "./helpers/clients.js";

const BASE = "http://localhost/api/v1/me/cardio-checks";
const req = (method: string, auth?: string, query = "", body?: unknown): Request =>
  new Request(`${BASE}${query}`, {
    method,
    headers: { ...(auth ? { authorization: `Bearer ${auth}` } : {}), ...(body !== undefined ? { "content-type": "application/json" } : {}) },
    body: body !== undefined ? JSON.stringify(body) : null,
  });

async function bearerFuer(prefix: string): Promise<string> {
  const email = uniqueEmail(prefix);
  await createTestUser(email);
  return accessTokenFor(email);
}

const heute = new Date().toISOString().slice(0, 10);
const gestern = new Date(Date.now() - 86_400_000).toISOString().slice(0, 10);
const inDreiTagen = new Date(Date.now() + 3 * 86_400_000).toISOString().slice(0, 10);

describe("/me/cardio-checks", () => {
  let a: string;
  let b: string;
  beforeAll(async () => {
    a = await bearerFuer("cc-a");
    b = await bearerFuer("cc-b");
  });

  it("401 ohne Token", async () => {
    expect((await GET(req("GET", undefined, "?from=2026-01-01&to=2026-01-31"))).status).toBe(401);
    expect((await PUT(req("PUT", undefined, `?day=${heute}`))).status).toBe(401);
    expect((await DELETE(req("DELETE", undefined, `?day=${heute}`))).status).toBe(401);
  });

  it("doppeltes PUT ergibt eine Zeile", async () => {
    expect((await PUT(req("PUT", a, `?day=${gestern}`))).status).toBe(204);
    expect((await PUT(req("PUT", a, `?day=${gestern}`))).status).toBe(204);
    const get = await GET(req("GET", a, `?from=${gestern}&to=${heute}`));
    expect(get.status).toBe(200);
    expect(get.headers.get("cache-control")).toBe("private, no-store");
    expect(await get.json()).toMatchObject({ days: [gestern] });
  });

  it("Zukunft ist 422 validation_failed", async () => {
    const antwort = await PUT(req("PUT", a, `?day=${inDreiTagen}`));
    expect(antwort.status).toBe(422);
    expect((await antwort.json()).error.code).toBe("validation_failed");
  });

  it("ungueltiges Format oder fehlende Parameter sind 422", async () => {
    expect((await PUT(req("PUT", a, "?day=morgen"))).status).toBe(422);
    expect((await PUT(req("PUT", a))).status).toBe(422);
    expect((await GET(req("GET", a, "?from=2026-01-01"))).status).toBe(422);
    expect((await DELETE(req("DELETE", a, "?day=x"))).status).toBe(422);
  });

  it("DELETE entfernt den Tag, DELETE eines fehlenden Tags ist 204", async () => {
    expect((await DELETE(req("DELETE", a, `?day=${gestern}`))).status).toBe(204);
    expect((await DELETE(req("DELETE", a, `?day=${gestern}`))).status).toBe(204);
    expect(await (await GET(req("GET", a, `?from=${gestern}&to=${heute}`))).json()).toMatchObject({ days: [] });
  });

  it("fremde Zeilen sind per RLS unsichtbar und nicht loeschbar", async () => {
    await PUT(req("PUT", a, `?day=${heute}`));
    expect(await (await GET(req("GET", b, `?from=${gestern}&to=${heute}`))).json()).toMatchObject({ days: [] });
    expect((await DELETE(req("DELETE", b, `?day=${heute}`))).status).toBe(204);
    expect(await (await GET(req("GET", a, `?from=${gestern}&to=${heute}`))).json()).toMatchObject({ days: [heute] });
  });
});

describe("/me/cardio-checks: mehrere Haken pro Tag", () => {
  let c: string;
  let d: string;
  beforeAll(async () => {
    c = await bearerFuer("cc-c");
    d = await bearerFuer("cc-d");
  });
  const liste = async (tok: string) => (await GET(req("GET", tok, `?from=${gestern}&to=${heute}`))).json();

  it("zwei POST am selben Tag: checks 2, days 1; DELETE ?id entfernt genau einen", async () => {
    const p1 = await POST(req("POST", c, "", { day: gestern, minuten: 25 }));
    expect(p1.status).toBe(201);
    const k1 = await p1.json();
    expect(k1).toEqual({ id: expect.any(String), day: gestern, minuten: 25 });
    const p2 = await POST(req("POST", c, "", { day: gestern }));
    expect(p2.status).toBe(201);
    expect((await p2.json()).minuten).toBeNull();
    const l = await liste(c);
    expect(l.checks).toHaveLength(2);
    expect(l.days).toEqual([gestern]);
    expect((await DELETE(req("DELETE", c, `?id=${k1.id}`))).status).toBe(204);
    const l2 = await liste(c);
    expect(l2.checks).toHaveLength(1);
    expect(l2.checks[0].minuten).toBeNull();
  });

  it("altes PUT ?day legt bei vorhandenem Haken keinen zweiten an, altes DELETE ?day entfernt alle", async () => {
    expect((await PUT(req("PUT", c, `?day=${gestern}`))).status).toBe(204);
    expect((await liste(c)).checks).toHaveLength(1);
    await POST(req("POST", c, "", { day: gestern }));
    expect((await liste(c)).checks).toHaveLength(2);
    expect((await DELETE(req("DELETE", c, `?day=${gestern}`))).status).toBe(204);
    expect(await liste(c)).toEqual({ checks: [], days: [] });
  });

  it("fremde id loeschen ist 204, die eigene Zeile bleibt", async () => {
    const k = await (await POST(req("POST", c, "", { day: heute }))).json();
    expect((await DELETE(req("DELETE", d, `?id=${k.id}`))).status).toBe(204);
    expect((await liste(c)).checks).toHaveLength(1);
  });

  it("Validierung: Zukunft, minuten, kaputtes JSON, id ohne UUID sind 422; ohne Token 401", async () => {
    expect((await POST(req("POST", c, "", { day: inDreiTagen }))).status).toBe(422);
    expect((await POST(req("POST", c, "", { day: heute, minuten: 0 }))).status).toBe(422);
    expect((await POST(req("POST", c, "", { day: heute, minuten: 601 }))).status).toBe(422);
    expect((await POST(req("POST", c, "", { minuten: 5 }))).status).toBe(422);
    expect((await POST(new Request(BASE, { method: "POST", headers: { authorization: `Bearer ${c}` }, body: "{x" }))).status).toBe(422);
    expect((await DELETE(req("DELETE", c, "?id=abc"))).status).toBe(422);
    expect((await POST(req("POST", undefined, "", { day: heute }))).status).toBe(401);
  });
});

describe("cardio_checks: Rechte (0071)", () => {
  it("anon darf nichts", async () => {
    const { data, error } = await anonClient().from("cardio_checks").select("*");
    expect(error?.code === "42501" || (data ?? []).length === 0).toBe(true);
    const { error: e } = await anonClient().from("cardio_checks").insert({ user_id: crypto.randomUUID(), day: heute });
    expect(e).not.toBeNull();
  });

  it("authenticated hat kein update (Recht entzogen, nicht nur durch RLS gesperrt)", async () => {
    const email = uniqueEmail("cc-recht");
    await createTestUser(email);
    const client = await userClient(email);
    // 42501 = permission denied: ohne UPDATE-Recht scheitert schon die Rechtepruefung, vor RLS.
    const { error } = await client.from("cardio_checks").update({ day: gestern }).eq("day", heute);
    expect(error?.code).toBe("42501");
  });
});
