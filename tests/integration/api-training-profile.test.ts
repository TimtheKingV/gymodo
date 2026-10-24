import { beforeAll, describe, expect, it } from "vitest";
import { GET, PUT } from "@/app/api/v1/me/training-profile/route";
import { accessTokenFor, createTestUser, uniqueEmail } from "./helpers/clients.js";

const URL_ = "http://localhost/api/v1/me/training-profile";
const req = (method: string, auth?: string, rumpf?: unknown): Request =>
  new Request(URL_, {
    method,
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
    // exactOptionalPropertyTypes: ein fehlender Body darf nicht als undefined uebergeben werden
    ...(rumpf === undefined ? {} : { body: JSON.stringify(rumpf) }),
  });

async function bearerFuer(prefix: string): Promise<string> {
  const email = uniqueEmail(prefix);
  await createTestUser(email);
  return accessTokenFor(email);
}

const profil = { minutes: 60, experience: "unregelmaessig", focus: ["po", "beine"] };

describe("/me/training-profile", () => {
  let a: string;
  let b: string;
  beforeAll(async () => {
    a = await bearerFuer("tp-a");
    b = await bearerFuer("tp-b");
  });

  it("401 ohne Token", async () => {
    expect((await GET(req("GET"))).status).toBe(401);
    expect((await PUT(req("PUT", undefined, profil))).status).toBe(401);
  });

  it("GET ohne Profil antwortet 404", async () => {
    expect((await GET(req("GET", b))).status).toBe(404);
  });

  it("PUT dann GET gibt dasselbe zurueck, zweites PUT ueberschreibt", async () => {
    const put = await PUT(req("PUT", a, profil));
    expect(put.status).toBe(200);
    const get = await GET(req("GET", a));
    expect(get.headers.get("cache-control")).toBe("private, no-store");
    expect(await get.json()).toEqual(profil);

    const neu = { minutes: 45, experience: "neu", focus: [] };
    await PUT(req("PUT", a, neu));
    expect(await (await GET(req("GET", a))).json()).toEqual(neu);
  });

  it("422 bei ungueltigen Werten", async () => {
    expect((await PUT(req("PUT", a, { ...profil, minutes: 50 }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { ...profil, focus: ["po", "po"] }))).status).toBe(422);
  });

  it("ein zweiter Nutzer sieht die Daten nicht", async () => {
    expect((await GET(req("GET", b))).status).toBe(404);
  });
});
