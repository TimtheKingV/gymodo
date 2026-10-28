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
// Ohne Wochenfelder gesendet, kommen leere Listen zurueck.
const leereWoche = { kursTage: [], cardioTage: [], cardioArten: [], kraftTage: [] };

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
    expect(await get.json()).toEqual({ ...profil, ...leereWoche });

    const neu = { minutes: 45, experience: "neu", focus: [] };
    await PUT(req("PUT", a, neu));
    expect(await (await GET(req("GET", a))).json()).toEqual({ ...neu, ...leereWoche });
  });

  it("speichert das Wochenraster, und ein PUT ohne die Felder laesst es unveraendert", async () => {
    const woche = { kursTage: [1], cardioTage: [7], cardioArten: ["laufen"], kraftTage: [3, 5] };
    const put = await PUT(req("PUT", a, { ...profil, ...woche }));
    expect(put.status).toBe(200);
    expect(await (await GET(req("GET", a))).json()).toEqual({ ...profil, ...woche });

    const ohne = { minutes: 45, experience: "neu", focus: [] };
    expect((await PUT(req("PUT", a, ohne))).status).toBe(200);
    expect(await (await GET(req("GET", a))).json()).toEqual({ ...ohne, ...woche });

    // Ein Feld allein senden: nur dieses aendert sich.
    expect((await PUT(req("PUT", a, { ...ohne, kraftTage: [2] }))).status).toBe(200);
    expect(await (await GET(req("GET", a))).json()).toEqual({ ...ohne, ...woche, kraftTage: [2] });
  });

  it("422 bei Wochenraster-Ueberschneidung, auch mit gespeicherten Werten", async () => {
    expect((await PUT(req("PUT", a, { ...profil, cardioArten: ["joggen"] }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { ...profil, kursTage: [2], kraftTage: [2] }))).status).toBe(422);
    // gespeichert ist kursTage [1] -- ein Krafttag am Montag ueberschneidet sich damit
    expect((await PUT(req("PUT", a, { ...profil, kraftTage: [1] }))).status).toBe(422);
  });

  it("422 bei ungueltigen Werten", async () => {
    expect((await PUT(req("PUT", a, { ...profil, minutes: 50 }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { ...profil, focus: ["po", "po"] }))).status).toBe(422);
  });

  it("ein zweiter Nutzer sieht die Daten nicht", async () => {
    expect((await GET(req("GET", b))).status).toBe(404);
  });
});
