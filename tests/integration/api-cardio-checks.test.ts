import { beforeAll, describe, expect, it } from "vitest";
import { DELETE, GET, PUT } from "@/app/api/v1/me/cardio-checks/route";
import { accessTokenFor, createTestUser, uniqueEmail } from "./helpers/clients.js";

const BASE = "http://localhost/api/v1/me/cardio-checks";
const req = (method: string, auth?: string, query = ""): Request =>
  new Request(`${BASE}${query}`, { method, headers: auth ? { authorization: `Bearer ${auth}` } : {} });

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
    expect(await get.json()).toEqual({ days: [gestern] });
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
    expect(await (await GET(req("GET", a, `?from=${gestern}&to=${heute}`))).json()).toEqual({ days: [] });
  });

  it("fremde Zeilen sind per RLS unsichtbar und nicht loeschbar", async () => {
    await PUT(req("PUT", a, `?day=${heute}`));
    expect(await (await GET(req("GET", b, `?from=${gestern}&to=${heute}`))).json()).toEqual({ days: [] });
    expect((await DELETE(req("DELETE", b, `?day=${heute}`))).status).toBe(204);
    expect(await (await GET(req("GET", a, `?from=${gestern}&to=${heute}`))).json()).toEqual({ days: [heute] });
  });
});
