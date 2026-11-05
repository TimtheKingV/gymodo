import { beforeAll, describe, expect, it } from "vitest";
import { anonClient, serviceClient } from "./helpers/clients.js";
import { GYMTAVO, legeMitgliedAn, legePlanStudiosAn, type PlanStudios } from "./helpers/plan-studio.js";

// Merkliste (0067): Gesundheits-nahe Mitgliedsdaten, nur eigene Zeilen, kein Update.
const admin = serviceClient();
let s: PlanStudios;
let uebung: string;

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
  uebung = Object.values(s.uebungen)[0]!;
});

describe("plan_merkliste (0067)", () => {
  it("schreibt und liest eigene Zeilen", async () => {
    const m = await legeMitgliedAn("ml-eigen", { studios: [s.voll] });
    const ein = await m.client.from("plan_merkliste").insert([
      { user_id: m.userId, exercise_id: uebung, art: "nicht_vorhanden", studio_id: s.voll },
      { user_id: m.userId, exercise_id: uebung, art: "gefaellt_nicht", studio_id: null },
    ]);
    expect(ein.error).toBeNull();
    const { data, error } = await m.client.from("plan_merkliste").select("art, studio_id");
    expect(error).toBeNull();
    expect(data).toHaveLength(2);
    const del = await m.client.from("plan_merkliste").delete().eq("exercise_id", uebung).select();
    expect(del.data).toHaveLength(2);
  });

  it("liest fremde Zeilen nicht", async () => {
    const a = await legeMitgliedAn("ml-a", { studios: [s.voll] });
    const b = await legeMitgliedAn("ml-b", { studios: [s.voll] });
    expect((await a.client.from("plan_merkliste").insert({ user_id: a.userId, exercise_id: uebung, art: "gefaellt_nicht" })).error).toBeNull();
    const { data } = await b.client.from("plan_merkliste").select("*");
    expect(data).toEqual([]);
    // fremde Zeile weder anlegen noch loeschen
    const fremd = await b.client.from("plan_merkliste").insert({ user_id: a.userId, exercise_id: uebung, art: "gefaellt_nicht" });
    expect(fremd.error?.code).toBe("42501");
    const del = await b.client.from("plan_merkliste").delete().eq("user_id", a.userId).select();
    expect(del.data).toEqual([]);
    const { data: bleibt } = await admin.from("plan_merkliste").select("*").eq("user_id", a.userId);
    expect(bleibt).toHaveLength(1);
  });

  it("nicht_vorhanden ohne studio_id wird abgelehnt", async () => {
    const m = await legeMitgliedAn("ml-ohne", { studios: [s.voll] });
    const { error } = await m.client.from("plan_merkliste").insert({ user_id: m.userId, exercise_id: uebung, art: "nicht_vorhanden" });
    expect(error?.code).toBe("23514");
  });

  it("gefaellt_nicht mit studio_id wird abgelehnt", async () => {
    const m = await legeMitgliedAn("ml-mit", { studios: [s.voll] });
    const { error } = await m.client
      .from("plan_merkliste")
      .insert({ user_id: m.userId, exercise_id: uebung, art: "gefaellt_nicht", studio_id: s.voll });
    expect(error?.code).toBe("23514");
  });

  it("nicht_vorhanden fuer fremdes Studio wird abgelehnt", async () => {
    const m = await legeMitgliedAn("ml-fremd", { studios: [s.voll] });
    const { error } = await m.client
      .from("plan_merkliste")
      .insert({ user_id: m.userId, exercise_id: uebung, art: "nicht_vorhanden", studio_id: s.voll2 });
    expect(error?.code).toBe("42501");
  });

  it("nicht_vorhanden fuer das Katalog-Studio ist erlaubt", async () => {
    const m = await legeMitgliedAn("ml-katalog", { studios: [] });
    const { error } = await m.client
      .from("plan_merkliste")
      .insert({ user_id: m.userId, exercise_id: uebung, art: "nicht_vorhanden", studio_id: GYMTAVO });
    expect(error).toBeNull();
  });

  it("doppelte Zeile ergibt 23505", async () => {
    const m = await legeMitgliedAn("ml-dup", { studios: [s.voll] });
    const zeile = { user_id: m.userId, exercise_id: uebung, art: "gefaellt_nicht" };
    expect((await m.client.from("plan_merkliste").insert(zeile)).error).toBeNull();
    expect((await m.client.from("plan_merkliste").insert(zeile)).error?.code).toBe("23505");
    const nv = { user_id: m.userId, exercise_id: uebung, art: "nicht_vorhanden", studio_id: s.voll };
    expect((await m.client.from("plan_merkliste").insert(nv)).error).toBeNull();
    expect((await m.client.from("plan_merkliste").insert(nv)).error?.code).toBe("23505");
  });

  it("kein Update fuer Mitglieder", async () => {
    const m = await legeMitgliedAn("ml-upd", { studios: [s.voll] });
    await m.client.from("plan_merkliste").insert({ user_id: m.userId, exercise_id: uebung, art: "gefaellt_nicht" });
    const up = await m.client.from("plan_merkliste").update({ art: "nicht_vorhanden" }).eq("user_id", m.userId).select();
    expect(up.data ?? []).toEqual([]);
    const { data } = await admin.from("plan_merkliste").select("art").eq("user_id", m.userId);
    expect(data).toEqual([{ art: "gefaellt_nicht" }]);
  });

  it("anon sieht nichts", async () => {
    const m = await legeMitgliedAn("ml-anon", { studios: [s.voll] });
    await m.client.from("plan_merkliste").insert({ user_id: m.userId, exercise_id: uebung, art: "gefaellt_nicht" });
    const { data, error } = await anonClient().from("plan_merkliste").select("*");
    expect(error?.code === "42501" || (data ?? []).length === 0).toBe(true);
  });
});
