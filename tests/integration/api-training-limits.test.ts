import { beforeAll, describe, expect, it } from "vitest";
import { DELETE, GET, PUT } from "@/app/api/v1/me/training-limits/route";
import { accessTokenFor, createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

const URL_ = "http://localhost/api/v1/me/training-limits";
const req = (method: string, auth?: string, rumpf?: unknown): Request =>
  new Request(URL_, {
    method,
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
    body: rumpf === undefined ? undefined : JSON.stringify(rumpf),
  });

async function bearerFuer(prefix: string): Promise<string> {
  const email = uniqueEmail(prefix);
  await createTestUser(email);
  return accessTokenFor(email);
}

describe("/me/training-limits", () => {
  let a: string;
  let b: string;
  beforeAll(async () => {
    a = await bearerFuer("tl-a");
    b = await bearerFuer("tl-b");
  });

  it("401 ohne Token", async () => {
    expect((await GET(req("GET"))).status).toBe(401);
    expect((await PUT(req("PUT", undefined, { einwilligung: true, areas: {} }))).status).toBe(401);
    expect((await DELETE(req("DELETE"))).status).toBe(401);
  });

  it("GET ohne Eintrag antwortet 404", async () => {
    expect((await GET(req("GET", b))).status).toBe(404);
  });

  it("PUT dann GET, consent_at gesetzt, zweites PUT ueberschreibt", async () => {
    const vorher = Date.now();
    const put = await PUT(req("PUT", a, { einwilligung: true, areas: { knie: "meiden" } }));
    expect(put.status).toBe(200);
    const get = await GET(req("GET", a));
    expect(get.headers.get("cache-control")).toBe("private, no-store");
    const body = (await get.json()) as { consentAt: string; areas: Record<string, string> };
    expect(body.areas).toEqual({ knie: "meiden" });
    expect(Date.parse(body.consentAt)).toBeGreaterThanOrEqual(vorher - 5000);

    await PUT(req("PUT", a, { einwilligung: true, areas: { schulter: "vorsichtig" } }));
    const neu = (await (await GET(req("GET", a))).json()) as { areas: Record<string, string> };
    expect(neu.areas).toEqual({ schulter: "vorsichtig" });
  });

  it("consent_at ist vom Client nicht steuerbar", async () => {
    const c = await bearerFuer("tl-c");
    await PUT(req("PUT", c, { einwilligung: true, areas: {}, consentAt: "2001-01-01T00:00:00Z", consent_at: "2001-01-01T00:00:00Z" }));
    const body = (await (await GET(req("GET", c))).json()) as { consentAt: string };
    expect(Date.parse(body.consentAt)).toBeGreaterThan(Date.parse("2020-01-01"));
  });

  it("422 ohne Einwilligung und bei ungueltigen Werten", async () => {
    expect((await PUT(req("PUT", a, { areas: {} }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { einwilligung: false, areas: {} }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { einwilligung: true, areas: { fuss: "meiden" } }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { einwilligung: true, areas: { knie: "egal" } }))).status).toBe(422);
  });

  it("ein zweiter Nutzer sieht die Daten nicht", async () => {
    expect((await GET(req("GET", b))).status).toBe(404);
  });

  it("DELETE entfernt (idempotent), GET danach 404", async () => {
    const d = await bearerFuer("tl-d");
    await PUT(req("PUT", d, { einwilligung: true, areas: { knie: "meiden" } }));
    expect((await DELETE(req("DELETE", d))).status).toBe(204);
    expect((await GET(req("GET", d))).status).toBe(404);
    expect((await DELETE(req("DELETE", d))).status).toBe(204);
  });
});

describe("training_limits: Datenbank-Check auf areas", () => {
  // Netz unter der Fachschicht: auch ein direkter Service-Role-Schreibzugriff darf keine
  // fremden Schluessel oder Stufen ablegen (Gesundheitsdaten nur in festen Feldern).
  it("lehnt unbekannte Bereiche und Stufen ab, nimmt gueltige an", async () => {
    const admin = serviceClient();
    const userId = await createTestUser(uniqueEmail("tl-check"));
    const schreibe = (areas: unknown) =>
      admin.from("training_limits").upsert({ user_id: userId, consent_at: new Date().toISOString(), areas });
    for (const ungueltig of [{ foo: "meiden" }, { knie: "x" }, { knie: 1 }, { knie: { a: "meiden" } }]) {
      const { error } = await schreibe(ungueltig);
      expect(error?.code, JSON.stringify(ungueltig)).toBe("23514");
    }
    expect((await schreibe({})).error).toBeNull();
    expect((await schreibe({ knie: "meiden", ellenbogen_handgelenk: "vorsichtig" })).error).toBeNull();
  });
});
