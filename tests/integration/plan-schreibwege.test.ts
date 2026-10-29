import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { deleteTrainingLimits, tauschVorgaben } from "@fitretro/domain";
import { anonClient, serviceClient } from "./helpers/clients.js";
import {
  GYMTAVO,
  aktiverKatalogPlan,
  erzeugeKatalogPlan,
  katalogPlanParameter,
  legeMitgliedAn,
  legePlanStudiosAn,
  machineVon,
  nimmKatalogPlanAn,
  type KatalogPlan,
  type PlanStudios,
} from "./helpers/plan-studio.js";

// Etappe 3, Task 2: Plaene werden nur ueber gepruefte Funktionen geschrieben
// (0062). Das Mitglied darf training_plans lesen, aber nicht direkt einfuegen
// oder aendern -- sonst liessen sich beliebige exerciseId/modelId in
// einheiten speichern. Seit 0066 gehoert der Plan dem Katalog-Studio und die
// Positionen nennen modelId statt machineId. Alle Aufrufe mit dem Client des
// Mitglieds, damit RLS und die Rechte der Funktionen wirklich greifen.
const admin = serviceClient();
let s: PlanStudios;

/**
 * Uebungen, die ein Test unter GYMTAVO anlegt. GYMTAVO ist der gemeinsame
 * Katalog aller Testlaeufe in der geteilten lokalen Datenbank: was dort liegen
 * bleibt, sammelt sich bei jedem Lauf an und taucht in fremden Katalogabfragen
 * auf. Plaene, Sessions und Nutzer gehoeren dagegen nur diesem Lauf.
 */
const gymtavoUebungen: string[] = [];
const kennung = crypto.randomUUID();

beforeAll(async () => {
  s = await legePlanStudiosAn(kennung);
});

afterAll(async () => {
  // equipment_model_exercises haengt mit on delete cascade dran; Saetze oder
  // Planstatus mit diesen Uebungen (on delete restrict) legt diese Datei nicht an.
  if (gymtavoUebungen.length > 0) {
    const { error } = await admin.from("exercises").delete().in("id", gymtavoUebungen);
    if (error) throw error;
  }
  // Auch die zehn Uebungen aus legePlanStudiosAn tragen die Kennung im Namen.
  // Die beiden Geraetetypen unter GYMTAVO bleiben: die Studio-Typen verweisen
  // per catalog_model_id (on delete restrict) auf sie.
  const { error } = await admin.from("exercises").delete().eq("studio_id", GYMTAVO).like("name", `% ${kennung}`);
  if (error) throw error;
});

type Fehler = { code?: string; message?: string };

/** Fehler eines RPC-Aufrufs (P0001 mit dem Meldungstext der Funktion). */
async function fehlerVon(p: PromiseLike<{ error: Fehler | null }>): Promise<Fehler> {
  const { error } = await p;
  if (!error) throw new Error("Kein Fehler geworfen");
  return error;
}

async function zeile(id: string) {
  const { data, error } = await admin
    .from("training_plans")
    .select("status, studio_id, einheiten, eingabe, gruende")
    .eq("id", id)
    .single();
  if (error) throw error;
  return data as { status: string; studio_id: string; einheiten: unknown; eingabe: Record<string, unknown>; gruende: string[] };
}

/** Ruft die Funktion so auf, wie es die Fachschicht tut -- mit veraenderten Einheiten. */
function rpcErzeuge(client: SupabaseClient, s: PlanStudios, einheiten?: unknown, studioId?: string) {
  return client.rpc("create_training_plan", katalogPlanParameter(s, { einheiten, studioId }));
}

/** Die Einheiten des Plans mit einem geaenderten Feld in der ersten Position. */
function mitErsterPosition(plan: KatalogPlan, aenderung: Record<string, unknown>) {
  const kopie = structuredClone(plan.einheiten) as unknown as Array<{ positionen: Array<Record<string, unknown>> }>;
  Object.assign(kopie[0]!.positionen[0]!, aenderung);
  return kopie;
}

describe("direkte Schreibwege", () => {
  it("direktes Insert in training_plans scheitert", async () => {
    const m = await legeMitgliedAn("schreib-insert", { studios: [] });
    const { error } = await m.client.from("training_plans").insert({
      user_id: m.userId,
      studio_id: GYMTAVO,
      version: 1,
      status: "aktiv",
      regel_version: "1.2.0",
      eingabe: {},
      struktur: "gk_ab",
      einheiten: [],
      gruende: [],
    });
    expect(error).not.toBeNull();
    const { data } = await admin.from("training_plans").select("id").eq("user_id", m.userId);
    expect(data).toEqual([]);
  });

  it("direktes Update (status, einheiten) scheitert", async () => {
    const m = await legeMitgliedAn("schreib-update", { studios: [] });
    const plan = await erzeugeKatalogPlan(m, s);
    const status = await m.client.from("training_plans").update({ status: "aktiv" }).eq("id", plan.id).select("id");
    expect(status.error !== null || (status.data ?? []).length === 0).toBe(true);
    const einheiten = await m.client
      .from("training_plans")
      .update({ einheiten: mitErsterPosition(plan, { modelId: crypto.randomUUID() }) })
      .eq("id", plan.id)
      .select("id");
    expect(einheiten.error !== null || (einheiten.data ?? []).length === 0).toBe(true);
    const z = await zeile(plan.id);
    expect(z.status).toBe("vorschlag");
    expect(z.einheiten).toEqual(plan.einheiten);
  });
});

describe("create_training_plan", () => {
  it("alte API ohne p_wochenraster funktioniert und ergibt ein leeres Raster", async () => {
    const m = await legeMitgliedAn("schreib-altapi", { studios: [] });
    const { p_wochenraster: _weg, ...alt } = katalogPlanParameter(s);
    const { data, error } = await m.client.rpc("create_training_plan", alt).single();
    expect(error).toBeNull();
    expect((data as { wochenraster: unknown }).wochenraster).toEqual([]);
  });

  it("speichert einen Plan mit Cardio-Position", async () => {
    const m = await legeMitgliedAn("schreib-cardio", { studios: [] });
    const plan = await erzeugeKatalogPlan(m, s);
    expect(plan.einheiten.flatMap((e) => e.positionen).some((p) => p.baustein === "cardio")).toBe(true);
    const { data, error } = await rpcErzeuge(m.client, s).single();
    expect(error).toBeNull();
    expect(data).toMatchObject({ user_id: m.userId, studio_id: GYMTAVO, version: 2, status: "vorschlag" });
    expect((await zeile(plan.id)).status).toBe("verworfen");
  });

  it("mit Modell eines normalen Studios wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-fremd", { studios: [s.voll] });
    const plan = await erzeugeKatalogPlan(m, s);
    const { error } = await rpcErzeuge(m.client, s, mitErsterPosition(plan, { modelId: s.studioModelle.voll }));
    expect(error?.code).toBe("P0001");
    expect(error?.message).toBe("plan_ungueltig");
    // Der alte Vorschlag bleibt: verworfen wird erst nach der Pruefung.
    expect((await zeile(plan.id)).status).toBe("vorschlag");
  });

  it("mit Uebung, die das Modell nicht hat, wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-uebung", { studios: [] });
    const plan = await erzeugeKatalogPlan(m, s);
    const { data: u, error: e } = await admin
      .from("exercises")
      .insert({ studio_id: GYMTAVO, name: `Lose ${crypto.randomUUID()}`, muscles: [], target_min: 8, target_max: 12 })
      .select("id")
      .single();
    if (e) throw e;
    gymtavoUebungen.push(u!.id as string);
    const { error } = await rpcErzeuge(m.client, s, mitErsterPosition(plan, { exerciseId: u!.id as string }));
    expect(error?.code).toBe("P0001");
    expect(error?.message).toBe("plan_ungueltig");
  });

  it("mit machineId statt modelId wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-machine", { studios: [s.voll] });
    const plan = await erzeugeKatalogPlan(m, s);
    const geraet = await machineVon(s.voll);
    const ohneModell = mitErsterPosition(plan, { machineId: geraet.id });
    delete (ohneModell[0]!.positionen[0] as Record<string, unknown>).modelId;
    const { error } = await rpcErzeuge(m.client, s, ohneModell);
    expect(error?.message).toBe("plan_ungueltig");
    // Auch zusaetzlich zu einem gueltigen modelId ist ein machineId nicht erlaubt.
    const beides = await rpcErzeuge(m.client, s, mitErsterPosition(plan, { machineId: geraet.id }));
    expect(beides.error?.message).toBe("plan_ungueltig");
  });

  it("ohne Positionsliste wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-form", { studios: [] });
    const plan = await erzeugeKatalogPlan(m, s);
    const { error } = await rpcErzeuge(m.client, s, [{ key: "A" }]);
    expect(error?.message).toBe("plan_ungueltig");
    const kaputt = await rpcErzeuge(m.client, s, mitErsterPosition(plan, { modelId: "kein-uuid" }));
    expect(kaputt.error?.message).toBe("plan_ungueltig");
  });

  it("fuer ein normales Studio wird nichts gespeichert, auch mit Mitgliedschaft", async () => {
    const n = await legeMitgliedAn("schreib-ohne", { studios: [s.voll] });
    const { error } = await rpcErzeuge(n.client, s, undefined, s.voll);
    expect(error?.message).toBe("plan_ungueltig");
    const { data } = await admin.from("training_plans").select("id").eq("user_id", n.userId);
    expect(data).toEqual([]);
  });

  it("ohne Anmeldung nicht aufrufbar", async () => {
    const m = await legeMitgliedAn("schreib-anon", { studios: [] });
    const plan = await erzeugeKatalogPlan(m, s);
    const { error } = await rpcErzeuge(anonClient(), s);
    expect(error).not.toBeNull();
    const pruefen = await anonClient().rpc("training_plan_pruefen", { p_studio_id: GYMTAVO, p_einheiten: [] });
    expect(pruefen.error).not.toBeNull();
    // Die Pruefhilfe ist nicht fuer Mitglieder gedacht; auch sie rufen sie nicht direkt.
    const direkt = await m.client.rpc("training_plan_pruefen", { p_studio_id: GYMTAVO, p_einheiten: plan.einheiten });
    expect(direkt.error).not.toBeNull();
  });

  it("zwei parallele create_training_plan lassen genau einen Vorschlag stehen", async () => {
    const m = await legeMitgliedAn("schreib-parallel", { studios: [] });
    const ergebnisse = await Promise.allSettled([erzeugeKatalogPlan(m, s), erzeugeKatalogPlan(m, s)]);
    // Die Funktion serialisiert je Paar: beide gelingen, der spaetere verwirft den frueheren.
    expect(ergebnisse.map((r) => r.status)).toEqual(["fulfilled", "fulfilled"]);
    const { data, error } = await admin
      .from("training_plans")
      .select("version, status")
      .eq("user_id", m.userId)
      .order("version");
    if (error) throw error;
    expect(data).toEqual([
      { version: 1, status: "verworfen" },
      { version: 2, status: "vorschlag" },
    ]);
  });
});

describe("accept_training_plan", () => {
  it("fremder Vorschlag und Vorschlag eines normalen Studios: nicht annehmbar", async () => {
    const m = await legeMitgliedAn("schreib-accept", { studios: [] });
    const plan = await erzeugeKatalogPlan(m, s);
    const anderer = await legeMitgliedAn("schreib-accept-anderer", { studios: [] });
    const fremd = await fehlerVon(anderer.client.rpc("accept_training_plan", { p_plan_id: plan.id }));
    expect(fremd).toMatchObject({ code: "P0001", message: "plan_nicht_annehmbar" });
    // Ein Plan eines normalen Studios (aus der Zeit vor 0066) wird nicht mehr angenommen.
    const { data: alt, error } = await admin
      .from("training_plans")
      .insert({
        user_id: m.userId, studio_id: s.voll, version: 1, status: "vorschlag", regel_version: "1.2.0",
        eingabe: {}, struktur: "gk_ab", einheiten: [], gruende: [],
      })
      .select("id")
      .single();
    if (error) throw error;
    const abgelehnt = await fehlerVon(m.client.rpc("accept_training_plan", { p_plan_id: alt!.id }));
    expect(abgelehnt).toMatchObject({ code: "P0001", message: "plan_nicht_annehmbar" });
    expect((await zeile(plan.id)).status).toBe("vorschlag");
  });
});

describe("Widerruf der Beschwerden", () => {
  it("Widerruf (DELETE training_limits) bereinigt aktiven Plan und Vorschlag", async () => {
    const m = await legeMitgliedAn("schreib-widerruf", {
      studios: [],
      limits: { knie: "meiden", schulter: "vorsichtig" },
    });
    const aktiv = await nimmKatalogPlanAn(m, (await erzeugeKatalogPlan(m, s, { limits: true })).id);
    const vorschlag = await erzeugeKatalogPlan(m, s, { limits: true });
    expect(aktiv.gruende).toEqual(expect.arrayContaining(["beschwerden_meiden", "beschwerden_vorsichtig"]));

    await deleteTrainingLimits(m.client, m.userId);

    for (const plan of [aktiv, vorschlag]) {
      const z = await zeile(plan.id);
      expect(z.eingabe).toEqual({ ...plan.eingabe, beschwerdenBeruecksichtigt: false });
      expect(z.gruende).toEqual(plan.gruende.filter((g) => !g.startsWith("beschwerden_")));
      expect(z.einheiten).toEqual(plan.einheiten);
    }
    expect((await zeile(aktiv.id)).status).toBe("aktiv");
  });

  it("Loeschen des Nutzers mit Beschwerden und Plaenen gelingt", async () => {
    const m = await legeMitgliedAn("schreib-konto", { studios: [], limits: { knie: "meiden" } });
    await erzeugeKatalogPlan(m, s, { limits: true });
    const { error } = await admin.auth.admin.deleteUser(m.userId);
    expect(error).toBeNull();
    const { data } = await admin.from("training_plans").select("id").eq("user_id", m.userId);
    expect(data).toEqual([]);
  });
});

describe("swap_training_plan_position", () => {
  /** Mitglied ohne Studiomitgliedschaft mit aktivem Katalogplan. */
  async function mitAktivemPlan(prefix: string, limits?: Record<string, "meiden" | "vorsichtig">) {
    const m = await legeMitgliedAn(prefix, { studios: [], ...(limits ? { limits } : {}) });
    const plan = await aktiverKatalogPlan(m, s);
    return { m, plan };
  }

  /** Neue Uebung im selben Baustein, am Katalogmodell verfuegbar. */
  async function ersatzUebung(
    baustein: string,
    bereiche: string[] = [],
    typ: "mehrgelenk" | "isolation" = "isolation",
  ): Promise<string> {
    const { data, error } = await admin
      .from("exercises")
      .insert({
        studio_id: GYMTAVO,
        name: `Tausch ${crypto.randomUUID()}`,
        muscles: [
          { key: "quadrizeps", role: "primary" },
          { key: "gluteus", role: "secondary" },
        ],
        target_min: 8,
        target_max: 12,
        plan_baustein: baustein,
        plan_typ: typ,
        plan_bereiche: bereiche,
      })
      .select("id")
      .single();
    if (error) throw error;
    gymtavoUebungen.push(data!.id as string);
    const { error: e2 } = await admin
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: s.katalogModell, exercise_id: data!.id, sort_order: 99 });
    if (e2) throw e2;
    return data!.id as string;
  }

  type Tausch = { einheitKey: string; positionKey: string; exerciseId: string; modelId: string };

  /** Tausch wie die Fachschicht: Vorgaben beider Typen aus dem Ziel des Plans. */
  function tausche(client: SupabaseClient, plan: KatalogPlan, t: Tausch) {
    return client
      .rpc("swap_training_plan_position", {
        p_plan_id: plan.id,
        p_einheit_key: t.einheitKey,
        p_position_key: t.positionKey,
        p_exercise_id: t.exerciseId,
        p_model_id: t.modelId,
        p_vorgaben: tauschVorgaben(plan.eingabe as never),
      })
      .single();
  }

  function ersteStelle(plan: KatalogPlan) {
    const einheit = plan.einheiten[0]!;
    return { einheitKey: einheit.key, position: einheit.positionen[0]! };
  }

  type Pos = KatalogPlan["einheiten"][number]["positionen"][number];
  type NeuerPlan = { id: string; version: number; status: string; studio_id: string; einheiten: KatalogPlan["einheiten"]; accepted_at: string | null; eingabe: unknown; gruende: string[]; struktur: string; regel_version: string };

  it("Tausch erzeugt Version +1, aktiv, alter Plan ersetzt, nur die gewaehlte Position aendert sich", async () => {
    const { m, plan } = await mitAktivemPlan("swap-ok");
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein);

    const { data, error } = await tausche(m.client, plan, {
      einheitKey,
      positionKey: position.key,
      exerciseId,
      modelId: s.katalogModell,
    });
    expect(error).toBeNull();
    const neu = data as NeuerPlan;

    expect(neu).toMatchObject({ version: plan.version + 1, status: "aktiv", studio_id: GYMTAVO });
    expect(neu.id).not.toBe(plan.id);
    expect(neu.accepted_at).not.toBeNull();
    expect(neu.eingabe).toEqual(plan.eingabe);
    expect(neu.gruende).toEqual(plan.gruende);
    expect(neu.struktur).toBe(plan.struktur);
    expect(neu.regel_version).toBe(plan.regelVersion);
    expect((await zeile(plan.id)).status).toBe("ersetzt");

    const erwartet = structuredClone(plan.einheiten);
    // Die erste Position ist eine Mehrgelenkuebung, die Ersatzuebung Isolation: Bereich,
    // Pause und Aufwaermsatz kommen aus dem Zielprofil des neuen Typs (Uebergabe Punkt 2).
    expect(position.typ).toBe("mehrgelenk");
    Object.assign(erwartet[0]!.positionen[0]!, {
      exerciseId,
      modelId: s.katalogModell,
      hauptmuskeln: ["quadrizeps"],
      typ: "isolation",
      wdhVon: 10,
      wdhBis: 15,
      pauseSek: 90,
      aufwaermsatz: false,
    });
    expect(neu.einheiten).toEqual(erwartet);
    const { data: aktiv } = await admin
      .from("training_plans")
      .select("status")
      .eq("user_id", m.userId)
      .eq("status", "aktiv");
    expect(aktiv).toHaveLength(1);
  });

  /** Die Felder, die vom Typ der Uebung abhaengen. */
  function vorgabenVon(p: Pos) {
    const { typ, wdhVon, wdhBis, reserveVon, reserveBis, pauseSek, aufwaermsatz } = p;
    return { typ, wdhVon, wdhBis, reserveVon, reserveBis, pauseSek, aufwaermsatz };
  }

  it("Tausch Mehrgelenk -> Isolation: Bereich, Pause und Reserve der neuen Uebung (Uebergabe Punkt 2)", async () => {
    const { m, plan } = await mitAktivemPlan("swap-typ-iso");
    // Muskelaufbau, regelmaessig: Mehrgelenk 8-12 / 150 s, Isolation 10-15 / 90 s, Reserve 1-3.
    expect(plan.eingabe).toMatchObject({ ziel: "muskelaufbau", erfahrung: "regelmaessig" });
    const einheit = plan.einheiten[0]!;
    const alt = einheit.positionen.find((p) => p.typ === "mehrgelenk" && p.rolle !== "cardio")!;
    expect(vorgabenVon(alt)).toEqual({
      typ: "mehrgelenk", wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 3, pauseSek: 150, aufwaermsatz: true,
    });
    const exerciseId = await ersatzUebung(alt.baustein, [], "isolation");

    const { data, error } = await tausche(m.client, plan, {
      einheitKey: einheit.key,
      positionKey: alt.key,
      exerciseId,
      modelId: s.katalogModell,
    });
    expect(error).toBeNull();
    const neu = data as NeuerPlan;

    const getauscht = neu.einheiten[0]!.positionen.find((p) => p.key === alt.key)!;
    expect(getauscht).toMatchObject({ exerciseId, saetze: alt.saetze, dauerMin: null, rolle: alt.rolle });
    expect(vorgabenVon(getauscht)).toEqual({
      typ: "isolation", wdhVon: 10, wdhBis: 15, reserveVon: 1, reserveBis: 3, pauseSek: 90, aufwaermsatz: false,
    });
  });

  it("Tausch Isolation -> Mehrgelenk: Bereich und Pause der neuen Uebung", async () => {
    const { m, plan } = await mitAktivemPlan("swap-typ-mg");
    const stelle = plan.einheiten
      .flatMap((e) => e.positionen.map((p) => ({ einheitKey: e.key, p })))
      .find(({ p }) => p.typ === "isolation" && p.rolle !== "cardio")!;
    expect(stelle).toBeDefined();
    const exerciseId = await ersatzUebung(stelle.p.baustein, [], "mehrgelenk");

    const { data, error } = await tausche(m.client, plan, {
      einheitKey: stelle.einheitKey,
      positionKey: stelle.p.key,
      exerciseId,
      modelId: s.katalogModell,
    });
    expect(error).toBeNull();
    const neu = data as NeuerPlan;

    const getauscht = neu.einheiten.find((e) => e.key === stelle.einheitKey)!.positionen.find((p) => p.key === stelle.p.key)!;
    expect(vorgabenVon(getauscht)).toEqual({
      typ: "mehrgelenk", wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 3, pauseSek: 150, aufwaermsatz: true,
    });
    // Alle anderen Positionen bleiben unveraendert.
    const ohne = (einheiten: KatalogPlan["einheiten"]) =>
      einheiten.map((e) => e.positionen.filter((p) => !(e.key === stelle.einheitKey && p.key === stelle.p.key)));
    expect(ohne(neu.einheiten)).toEqual(ohne(plan.einheiten));
  });

  it("die Funktion lehnt unsinnige Vorgaben ab (plan_ungueltig)", async () => {
    const { m, plan } = await mitAktivemPlan("swap-vorgaben");
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein, [], "isolation");
    const gut = tauschVorgaben(plan.eingabe as never);
    const aufruf = (vorgaben: unknown) =>
      m.client.rpc("swap_training_plan_position", {
        p_plan_id: plan.id,
        p_einheit_key: einheitKey,
        p_position_key: position.key,
        p_exercise_id: exerciseId,
        p_model_id: s.katalogModell,
        p_vorgaben: vorgaben,
      });
    const iso = gut.isolation;
    const schlecht: unknown[] = [
      null,
      [],
      "x",
      { mehrgelenk: gut.mehrgelenk },
      { ...gut, isolation: { ...iso, wdhVon: 0 } },
      { ...gut, isolation: { ...iso, wdhBis: 51 } },
      { ...gut, isolation: { ...iso, wdhVon: 16, wdhBis: 15 } },
      { ...gut, isolation: { ...iso, wdhVon: 10.5 } },
      { ...gut, isolation: { ...iso, wdhVon: "10" } },
      { ...gut, isolation: { ...iso, reserveVon: -1 } },
      { ...gut, isolation: { ...iso, reserveVon: 4, reserveBis: 3 } },
      { ...gut, isolation: { ...iso, reserveBis: 11 } },
      { ...gut, isolation: { ...iso, pauseSek: -1 } },
      { ...gut, isolation: { ...iso, pauseSek: 601 } },
      { ...gut, isolation: { ...iso, aufwaermsatz: "nein" } },
      // Der Typ im Eintrag muss zum Schluessel passen.
      { ...gut, isolation: { ...iso, typ: "mehrgelenk" } },
    ];
    for (const v of schlecht) {
      const { error } = await aufruf(v);
      expect(error, JSON.stringify(v)).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    }
    expect((await zeile(plan.id)).status).toBe("aktiv");
    // Der alte Aufruf ohne Vorgaben ist entfernt: er uebernaehme die Werte der alten Position.
    const { error: alt } = await m.client.rpc("swap_training_plan_position", {
      p_plan_id: plan.id,
      p_einheit_key: einheitKey,
      p_position_key: position.key,
      p_exercise_id: exerciseId,
      p_model_id: s.katalogModell,
    });
    expect(alt).not.toBeNull();
    expect((await zeile(plan.id)).status).toBe("aktiv");
    // Kontrolle: mit gueltigen Vorgaben klappt derselbe Aufruf.
    const { error: ok } = await aufruf(gut);
    expect(ok).toBeNull();
  });

  it("anderer Baustein wird abgelehnt", async () => {
    const { m, plan } = await mitAktivemPlan("swap-baustein");
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein === "ziehen" ? "druecken" : "ziehen");
    const e = await fehlerVon(
      tausche(m.client, plan, { einheitKey, positionKey: position.key, exerciseId, modelId: s.katalogModell }),
    );
    expect(e).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    expect((await zeile(plan.id)).status).toBe("aktiv");
  });

  it("Uebung mit gemiedenem Bereich wird abgelehnt", async () => {
    const { m, plan } = await mitAktivemPlan("swap-meiden", { knie: "meiden", schulter: "vorsichtig" });
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein, ["knie"]);
    const e = await fehlerVon(
      tausche(m.client, plan, { einheitKey, positionKey: position.key, exerciseId, modelId: s.katalogModell }),
    );
    expect(e).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    // Kontrolle: schulter ist nur "vorsichtig" und sperrt nicht, nur "meiden" sperrt.
    const ok = await ersatzUebung(position.baustein, ["schulter"]);
    const { data, error } = await tausche(m.client, plan, {
      einheitKey, positionKey: position.key, exerciseId: ok, modelId: s.katalogModell,
    });
    expect(error).toBeNull();
    expect(data).toMatchObject({ status: "aktiv" });
  });

  it("Modell eines normalen Studios wird abgelehnt", async () => {
    const { m, plan } = await mitAktivemPlan("swap-fremd");
    const { einheitKey, position } = ersteStelle(plan);
    // Die Uebung der Position haengt auch am Studiotyp (catalog_model_id), das Modell
    // selbst gehoert aber einem normalen Studio: nur das Modell ist fremd.
    const e = await fehlerVon(
      tausche(m.client, plan, {
        einheitKey,
        positionKey: position.key,
        exerciseId: position.exerciseId,
        modelId: s.studioModelle.voll,
      }),
    );
    expect(e).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    expect((await zeile(plan.id)).status).toBe("aktiv");
  });

  it("Tausch auf nicht aktiven Plan: nicht annehmbar", async () => {
    const m = await legeMitgliedAn("swap-vorschlag", { studios: [] });
    const vorschlag = await erzeugeKatalogPlan(m, s);
    const { einheitKey, position } = ersteStelle(vorschlag);
    const e = await fehlerVon(
      tausche(m.client, vorschlag, {
        einheitKey,
        positionKey: position.key,
        exerciseId: position.exerciseId,
        modelId: s.katalogModell,
      }),
    );
    expect(e).toMatchObject({ code: "P0001", message: "plan_nicht_annehmbar" });
  });

  it("fremder Plan und unbekannte Position", async () => {
    const { m, plan } = await mitAktivemPlan("swap-grenzen");
    const { einheitKey, position } = ersteStelle(plan);
    const eingabe = { einheitKey, positionKey: position.key, exerciseId: position.exerciseId, modelId: s.katalogModell };
    const anderer = await legeMitgliedAn("swap-anderer", { studios: [] });
    expect(await fehlerVon(tausche(anderer.client, plan, eingabe))).toMatchObject({ message: "plan_nicht_annehmbar" });
    expect(await fehlerVon(tausche(m.client, plan, { ...eingabe, positionKey: "gibt-es-nicht" }))).toMatchObject({
      message: "plan_ungueltig",
    });
    expect((await zeile(plan.id)).status).toBe("aktiv");
  });

  it("Plan eines normalen Studios (vor 0066) laesst sich nicht tauschen", async () => {
    const m = await legeMitgliedAn("swap-altstudio", { studios: [s.voll] });
    const katalog = await aktiverKatalogPlan(m, s);
    const { data: alt, error } = await admin
      .from("training_plans")
      .insert({
        user_id: m.userId, studio_id: s.voll, version: 1, status: "aktiv", regel_version: "1.2.0",
        eingabe: katalog.eingabe, struktur: "gk_ab", einheiten: katalog.einheiten, gruende: [], accepted_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (error) throw error;
    const { einheitKey, position } = ersteStelle(katalog);
    const e = await fehlerVon(
      tausche(m.client, { ...katalog, id: alt!.id as string }, {
        einheitKey,
        positionKey: position.key,
        exerciseId: position.exerciseId,
        modelId: s.katalogModell,
      }),
    );
    expect(e).toMatchObject({ code: "P0001", message: "plan_nicht_annehmbar" });
  });

  it("ohne Anmeldung nicht aufrufbar", async () => {
    const { error } = await anonClient().rpc("swap_training_plan_position", {
      p_plan_id: crypto.randomUUID(),
      p_einheit_key: "A",
      p_position_key: "x",
      p_exercise_id: crypto.randomUUID(),
      p_model_id: crypto.randomUUID(),
      p_vorgaben: tauschVorgaben({ ziel: "muskelaufbau", erfahrung: "regelmaessig" } as never),
    });
    expect(error).not.toBeNull();
  });
});
