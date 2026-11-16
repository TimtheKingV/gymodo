import { beforeAll, describe, expect, it } from "vitest";
import { GET, PUT } from "@/app/api/v1/me/training-profile/route";
import { accessTokenFor, createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

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
const zaehler0 = { kraftProWoche: null, cardioProWoche: 0, cardioMinuten: 30 };
const leereWoche = { kursTage: [], cardioTage: [], cardioArten: [], kraftTage: [], ...zaehler0 };

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
    // Tagesfelder ohne Zaehler (alte App): die Zaehler folgen der Anzahl der Tage.
    const abgeleitet = { ...zaehler0, kraftProWoche: 2, cardioProWoche: 1 };
    expect(await (await GET(req("GET", a))).json()).toEqual({ ...profil, ...woche, ...abgeleitet });

    const ohne = { minutes: 45, experience: "neu", focus: [] };
    expect((await PUT(req("PUT", a, ohne))).status).toBe(200);
    expect(await (await GET(req("GET", a))).json()).toEqual({ ...ohne, ...woche, ...abgeleitet });

    // Ein Feld allein senden: nur dieses (und sein Zaehler) aendert sich.
    expect((await PUT(req("PUT", a, { ...ohne, kraftTage: [2] }))).status).toBe(200);
    expect(await (await GET(req("GET", a))).json()).toEqual({
      ...ohne, ...woche, ...abgeleitet, kraftTage: [2], kraftProWoche: 1,
    });
  });

  it("422 bei Wochenraster-Ueberschneidung, auch mit gespeicherten Werten", async () => {
    expect((await PUT(req("PUT", a, { ...profil, cardioArten: ["joggen"] }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { ...profil, kursTage: [2], kraftTage: [2] }))).status).toBe(422);
    // gespeichert ist kursTage [1] -- ein Krafttag am Montag ueberschneidet sich damit
    expect((await PUT(req("PUT", a, { ...profil, kraftTage: [1] }))).status).toBe(422);
  });

  it("422 wenn Kurse und Cardio alle sieben Tage belegen", async () => {
    const antwort = await PUT(req("PUT", a, { ...profil, kursTage: [1, 2, 3, 4], cardioTage: [5, 6, 7], kraftTage: [] }));
    expect(antwort.status).toBe(422);
  });

  it("422 bei ungueltigen Werten", async () => {
    expect((await PUT(req("PUT", a, { ...profil, minutes: 50 }))).status).toBe(422);
    expect((await PUT(req("PUT", a, { ...profil, focus: ["po", "po"] }))).status).toBe(422);
  });

  it("speichert die Zaehler und gleicht das weekly_days-Ziel ab", async () => {
    const email = uniqueEmail("tp-c");
    const uid = await createTestUser(email);
    const c = await accessTokenFor(email);
    const ziel = async (): Promise<number | undefined> => {
      const { data } = await serviceClient()
        .from("member_goals")
        .select("target_value")
        .eq("user_id", uid)
        .eq("kind", "weekly_days")
        .eq("status", "active");
      return data?.[0]?.target_value;
    };
    const basis = { minutes: 60, experience: "neu", focus: [] };
    expect((await PUT(req("PUT", c, { ...basis, kraftProWoche: 3, cardioProWoche: 1 }))).status).toBe(200);
    expect(await (await GET(req("GET", c))).json()).toMatchObject({ kraftProWoche: 3, cardioProWoche: 1, cardioMinuten: 30 });
    expect(await ziel()).toBe(4);

    // nur minutes: Zaehler und Ziel unveraendert
    expect((await PUT(req("PUT", c, { ...basis, minutes: 45 }))).status).toBe(200);
    expect(await (await GET(req("GET", c))).json()).toMatchObject({ kraftProWoche: 3, cardioProWoche: 1 });
    expect(await ziel()).toBe(4);

    // Summe wird bei 7 gedeckelt
    expect((await PUT(req("PUT", c, { ...basis, kraftProWoche: 6, cardioProWoche: 3 }))).status).toBe(200);
    expect(await ziel()).toBe(7);
  });

  it("alte App nach der Migration: Tages-PUT ohne Zaehler aktualisiert die Zaehler, weekly_days bleibt", async () => {
    const email = uniqueEmail("tp-d");
    const uid = await createTestUser(email);
    const d = await accessTokenFor(email);
    const basis = { minutes: 60, experience: "neu", focus: [] };
    // neue App hat Zaehler gesetzt (weekly_days = 3 + 1)
    expect((await PUT(req("PUT", d, { ...basis, kraftProWoche: 3, cardioProWoche: 1 }))).status).toBe(200);
    // alte App schreibt nur Tage
    expect((await PUT(req("PUT", d, { ...basis, kraftTage: [1, 3], cardioTage: [5, 6] }))).status).toBe(200);
    expect(await (await GET(req("GET", d))).json()).toMatchObject({ kraftProWoche: 2, cardioProWoche: 2 });
    // leere Krafttage ("Generator verteilt") lassen kraftProWoche stehen
    expect((await PUT(req("PUT", d, { ...basis, kraftTage: [], cardioTage: [] }))).status).toBe(200);
    expect(await (await GET(req("GET", d))).json()).toMatchObject({ kraftProWoche: 2, cardioProWoche: 0 });
    const { data } = await serviceClient()
      .from("member_goals").select("target_value").eq("user_id", uid).eq("kind", "weekly_days").eq("status", "active");
    expect(data?.[0]?.target_value).toBe(4);
  });

  it("PUT mit nur Zaehlern scheitert nicht an gespeicherten Alt-Tagen, die pruefeWoche verletzen", async () => {
    const email = uniqueEmail("tp-e");
    const uid = await createTestUser(email);
    const e = await accessTokenFor(email);
    const basis = { minutes: 60, experience: "neu", focus: [] };
    expect((await PUT(req("PUT", e, basis))).status).toBe(200);
    // Alt-Bestand, den pruefeWoche ablehnt: Kurse und Cardio belegen alle sieben Tage
    const { error } = await serviceClient()
      .from("training_profiles")
      .update({ kurs_tage: [1, 2, 3, 4], cardio_tage: [5, 6, 7], kraft_tage: [] })
      .eq("user_id", uid);
    expect(error).toBeNull();
    expect((await PUT(req("PUT", e, { ...basis, kraftProWoche: 2, cardioProWoche: 1 }))).status).toBe(200);
    expect(await (await GET(req("GET", e))).json()).toMatchObject({ kraftProWoche: 2, cardioProWoche: 1 });
  });

  it("ein zweiter Nutzer sieht die Daten nicht", async () => {
    expect((await GET(req("GET", b))).status).toBe(404);
  });
});
