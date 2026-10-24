import { beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  DomainError,
  acceptPlan,
  deleteTrainingLimits,
  erzeugePlanVorschlag,
  tauschePlanPosition,
  type TrainingPlan,
} from "@fitretro/domain";
import { anonClient, serviceClient } from "./helpers/clients.js";
import { GYMTAVO, legeMitgliedAn, legePlanStudiosAn, type PlanStudios } from "./helpers/plan-studio.js";

// Etappe 3, Task 2: Plaene werden nur ueber gepruefte Funktionen geschrieben
// (0062). Das Mitglied darf training_plans lesen, aber nicht direkt einfuegen
// oder aendern -- sonst liessen sich beliebige exerciseId/machineId in
// einheiten speichern. Alle Aufrufe mit dem Client des Mitglieds, damit RLS
// und die Rechte der Funktionen wirklich greifen.
const admin = serviceClient();
let s: PlanStudios;

beforeAll(async () => {
  s = await legePlanStudiosAn(crypto.randomUUID());
});

async function fehlerVon(p: Promise<unknown>): Promise<DomainError> {
  try {
    await p;
  } catch (e) {
    expect(e).toBeInstanceOf(DomainError);
    return e as DomainError;
  }
  throw new Error("Kein Fehler geworfen");
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

async function machineVon(studioId: string): Promise<{ id: string; equipment_model_id: string }> {
  const { data, error } = await admin
    .from("machines")
    .select("id, equipment_model_id")
    .eq("studio_id", studioId)
    .eq("status", "active")
    .limit(1)
    .single();
  if (error) throw error;
  return data as { id: string; equipment_model_id: string };
}

/** Ruft die Funktion so auf, wie es die Fachschicht tut -- mit einem veraenderten Plan. */
function rpcErzeuge(client: SupabaseClient, studioId: string, plan: TrainingPlan, einheiten: unknown) {
  return client.rpc("create_training_plan", {
    p_studio_id: studioId,
    p_regel_version: plan.regelVersion,
    p_eingabe: plan.eingabe,
    p_struktur: plan.struktur,
    p_einheiten: einheiten,
    p_gruende: plan.gruende,
  });
}

/** Ersetzt in der ersten Position ein Feld. */
function mitErsterPosition(plan: TrainingPlan, aenderung: Record<string, string>) {
  const kopie = structuredClone(plan.einheiten);
  Object.assign(kopie[0]!.positionen[0]!, aenderung);
  return kopie;
}

describe("direkte Schreibwege", () => {
  it("direktes Insert in training_plans scheitert", async () => {
    const m = await legeMitgliedAn("schreib-insert", { studios: [s.voll] });
    const { error } = await m.client.from("training_plans").insert({
      user_id: m.userId,
      studio_id: s.voll,
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
    const m = await legeMitgliedAn("schreib-update", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const status = await m.client.from("training_plans").update({ status: "aktiv" }).eq("id", plan.id).select("id");
    expect(status.error !== null || (status.data ?? []).length === 0).toBe(true);
    const einheiten = await m.client
      .from("training_plans")
      .update({ einheiten: mitErsterPosition(plan, { machineId: crypto.randomUUID() }) })
      .eq("id", plan.id)
      .select("id");
    expect(einheiten.error !== null || (einheiten.data ?? []).length === 0).toBe(true);
    const z = await zeile(plan.id);
    expect(z.status).toBe("vorschlag");
    expect(z.einheiten).toEqual(plan.einheiten);
  });
});

describe("create_training_plan", () => {
  it("speichert einen Generatorplan mit Cardio-Position", async () => {
    const m = await legeMitgliedAn("schreib-cardio", { studios: [s.voll], trainingGoal: "lose_weight" });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    expect(plan.einheiten.flatMap((e) => e.positionen).some((p) => p.baustein === "cardio")).toBe(true);
    const { data, error } = await rpcErzeuge(m.client, s.voll, plan, plan.einheiten).single();
    expect(error).toBeNull();
    expect(data).toMatchObject({ user_id: m.userId, studio_id: s.voll, version: 2, status: "vorschlag" });
    expect((await zeile(plan.id)).status).toBe("verworfen");
  });

  it("mit Geraet eines fremden Studios wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-fremd", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const fremd = await machineVon(s.voll2);
    const { error } = await rpcErzeuge(m.client, s.voll, plan, mitErsterPosition(plan, { machineId: fremd.id }));
    expect(error?.code).toBe("P0001");
    expect(error?.message).toBe("plan_ungueltig");
    // Der alte Vorschlag bleibt: verworfen wird erst nach der Pruefung.
    expect((await zeile(plan.id)).status).toBe("vorschlag");
  });

  it("mit Uebung, die das Geraet nicht hat, wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-uebung", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { data: u, error: e } = await admin
      .from("exercises")
      .insert({ studio_id: GYMTAVO, name: `Lose ${crypto.randomUUID()}`, muscles: [], target_min: 8, target_max: 12 })
      .select("id")
      .single();
    if (e) throw e;
    const { error } = await rpcErzeuge(m.client, s.voll, plan, mitErsterPosition(plan, { exerciseId: u!.id as string }));
    expect(error?.code).toBe("P0001");
    expect(error?.message).toBe("plan_ungueltig");
  });

  it("mit stillgelegtem Geraet wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-still", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const aktiv = await machineVon(s.voll);
    const { data: still, error: e } = await admin
      .from("machines")
      .insert({ studio_id: s.voll, equipment_model_id: aktiv.equipment_model_id, label: "S-still", status: "inactive" })
      .select("id")
      .single();
    if (e) throw e;
    const { error } = await rpcErzeuge(m.client, s.voll, plan, mitErsterPosition(plan, { machineId: still!.id as string }));
    expect(error?.code).toBe("P0001");
    expect(error?.message).toBe("plan_ungueltig");
  });

  it("ohne Positionsliste wirft plan_ungueltig", async () => {
    const m = await legeMitgliedAn("schreib-form", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { error } = await rpcErzeuge(m.client, s.voll, plan, [{ key: "A" }]);
    expect(error?.message).toBe("plan_ungueltig");
    const kaputt = await rpcErzeuge(m.client, s.voll, plan, mitErsterPosition(plan, { machineId: "kein-uuid" }));
    expect(kaputt.error?.message).toBe("plan_ungueltig");
  });

  it("fuer ein Studio ohne Mitgliedschaft wird nichts gespeichert", async () => {
    const m = await legeMitgliedAn("schreib-ohne", { studios: [s.voll, s.voll2] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll2);
    const n = await legeMitgliedAn("schreib-ohne-n", { studios: [s.voll] });
    const { error } = await rpcErzeuge(n.client, s.voll2, plan, plan.einheiten);
    expect(error).not.toBeNull();
    const { data } = await admin.from("training_plans").select("id").eq("user_id", n.userId);
    expect(data).toEqual([]);
  });

  it("ohne Anmeldung nicht aufrufbar", async () => {
    const m = await legeMitgliedAn("schreib-anon", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { error } = await rpcErzeuge(anonClient(), s.voll, plan, plan.einheiten);
    expect(error).not.toBeNull();
    const pruefen = await anonClient().rpc("training_plan_pruefen", { p_studio_id: s.voll, p_einheiten: [] });
    expect(pruefen.error).not.toBeNull();
    // Die Pruefhilfe verriete Geraete fremder Studios; auch Mitglieder rufen sie nicht direkt.
    const direkt = await m.client.rpc("training_plan_pruefen", { p_studio_id: s.voll2, p_einheiten: plan.einheiten });
    expect(direkt.error).not.toBeNull();
  });

  it("zwei parallele erzeugePlanVorschlag lassen genau einen Vorschlag stehen", async () => {
    const m = await legeMitgliedAn("schreib-parallel", { studios: [s.voll] });
    const ergebnisse = await Promise.allSettled([
      erzeugePlanVorschlag(m.client, m.userId, s.voll),
      erzeugePlanVorschlag(m.client, m.userId, s.voll),
    ]);
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
  it("accept eines Vorschlags im verlassenen Studio wirft Konflikt", async () => {
    const m = await legeMitgliedAn("schreib-verlassen", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { error } = await admin.from("studio_memberships").delete().eq("user_id", m.userId).eq("studio_id", s.voll);
    if (error) throw error;
    const e = await fehlerVon(acceptPlan(m.client, m.userId, plan.id));
    expect(e.code).toBe("conflict");
    expect((await zeile(plan.id)).status).toBe("vorschlag");
  });
});

describe("Widerruf der Beschwerden", () => {
  it("Widerruf (DELETE training_limits) bereinigt auch den Plan in einem verlassenen Studio", async () => {
    const m = await legeMitgliedAn("schreib-widerruf", {
      studios: [s.voll, s.voll2],
      limits: { knie: "meiden", schulter: "vorsichtig" },
    });
    const bleibt = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const verlassen = await erzeugePlanVorschlag(m.client, m.userId, s.voll2);
    await acceptPlan(m.client, m.userId, verlassen.id);
    expect(verlassen.gruende).toEqual(expect.arrayContaining(["beschwerden_meiden", "beschwerden_vorsichtig"]));
    const { error } = await admin.from("studio_memberships").delete().eq("user_id", m.userId).eq("studio_id", s.voll2);
    if (error) throw error;

    await deleteTrainingLimits(m.client, m.userId);

    for (const plan of [bleibt, verlassen]) {
      const z = await zeile(plan.id);
      expect(z.eingabe).toEqual({ ...plan.eingabe, beschwerdenBeruecksichtigt: false });
      expect(z.gruende).toEqual(plan.gruende.filter((g) => !g.startsWith("beschwerden_")));
      expect(z.einheiten).toEqual(plan.einheiten);
    }
    expect((await zeile(verlassen.id)).status).toBe("aktiv");
  });

  it("Loeschen des Nutzers mit Beschwerden und Plaenen gelingt", async () => {
    const m = await legeMitgliedAn("schreib-konto", { studios: [s.voll], limits: { knie: "meiden" } });
    await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { error } = await admin.auth.admin.deleteUser(m.userId);
    expect(error).toBeNull();
    const { data } = await admin.from("training_plans").select("id").eq("user_id", m.userId);
    expect(data).toEqual([]);
  });
});

describe("swap_training_plan_position", () => {
  /** Mitglied mit aktivem Plan im Studio voll. */
  async function mitAktivemPlan(prefix: string, limits?: Record<string, "meiden" | "vorsichtig">) {
    const m = await legeMitgliedAn(prefix, { studios: [s.voll], ...(limits ? { limits } : {}) });
    const vorschlag = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const plan = await acceptPlan(m.client, m.userId, vorschlag.id);
    return { m, plan };
  }

  /** Neue Uebung im selben Baustein, am Geraetetyp des Studios verfuegbar. */
  async function ersatzUebung(baustein: string, bereiche: string[] = []): Promise<string> {
    const geraet = await machineVon(s.voll);
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
        plan_typ: "isolation",
        plan_bereiche: bereiche,
      })
      .select("id")
      .single();
    if (error) throw error;
    const { error: e2 } = await admin
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: geraet.equipment_model_id, exercise_id: data!.id, sort_order: 99 });
    if (e2) throw e2;
    return data!.id as string;
  }

  function ersteStelle(plan: TrainingPlan) {
    const einheit = plan.einheiten[0]!;
    return { einheitKey: einheit.key, position: einheit.positionen[0]! };
  }

  it("Tausch erzeugt Version +1, aktiv, alter Plan ersetzt, nur die gewaehlte Position aendert sich", async () => {
    const { m, plan } = await mitAktivemPlan("swap-ok");
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein);
    const geraet = await machineVon(s.voll);

    const neu = await tauschePlanPosition(m.client, m.userId, plan.id, {
      einheitKey,
      positionKey: position.key,
      exerciseId,
      machineId: geraet.id,
    });

    expect(neu).toMatchObject({ version: plan.version + 1, status: "aktiv", studioId: s.voll });
    expect(neu.id).not.toBe(plan.id);
    expect(neu.acceptedAt).not.toBeNull();
    expect(neu.eingabe).toEqual(plan.eingabe);
    expect(neu.gruende).toEqual(plan.gruende);
    expect(neu.struktur).toBe(plan.struktur);
    expect(neu.regelVersion).toBe(plan.regelVersion);
    expect((await zeile(plan.id)).status).toBe("ersetzt");

    const erwartet = structuredClone(plan.einheiten);
    Object.assign(erwartet[0]!.positionen[0]!, { exerciseId, machineId: geraet.id, hauptmuskeln: ["quadrizeps"] });
    expect(neu.einheiten).toEqual(erwartet);
    const { data } = await admin
      .from("training_plans")
      .select("status")
      .eq("user_id", m.userId)
      .eq("status", "aktiv");
    expect(data).toHaveLength(1);
  });

  it("anderer Baustein wird abgelehnt", async () => {
    const { m, plan } = await mitAktivemPlan("swap-baustein");
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein === "ziehen" ? "druecken" : "ziehen");
    const geraet = await machineVon(s.voll);
    const e = await fehlerVon(
      tauschePlanPosition(m.client, m.userId, plan.id, { einheitKey, positionKey: position.key, exerciseId, machineId: geraet.id }),
    );
    expect(e.code).toBe("validation_failed");
    expect((await zeile(plan.id)).status).toBe("aktiv");
  });

  it("Uebung mit gemiedenem Bereich wird abgelehnt", async () => {
    const { m, plan } = await mitAktivemPlan("swap-meiden", { knie: "meiden", schulter: "vorsichtig" });
    const { einheitKey, position } = ersteStelle(plan);
    const exerciseId = await ersatzUebung(position.baustein, ["knie"]);
    const geraet = await machineVon(s.voll);
    const e = await fehlerVon(
      tauschePlanPosition(m.client, m.userId, plan.id, { einheitKey, positionKey: position.key, exerciseId, machineId: geraet.id }),
    );
    expect(e.code).toBe("validation_failed");
    // Kontrolle: schulter ist nur "vorsichtig" und sperrt nicht, nur "meiden" sperrt.
    const ok = await ersatzUebung(position.baustein, ["schulter"]);
    await expect(
      tauschePlanPosition(m.client, m.userId, plan.id, { einheitKey, positionKey: position.key, exerciseId: ok, machineId: geraet.id }),
    ).resolves.toMatchObject({ status: "aktiv" });
  });

  it("Geraet eines fremden Studios wird abgelehnt", async () => {
    const { m, plan } = await mitAktivemPlan("swap-fremd");
    const { einheitKey, position } = ersteStelle(plan);
    // Die Uebung der Position haengt am gemeinsamen Katalogtyp beider Studios: nur
    // das Geraet ist fremd. Mit einer Uebung, die dem fremden Geraet fehlt, scheiterte
    // der Test auch ohne Studio-Pruefung.
    const fremd = await machineVon(s.voll2);
    const e = await fehlerVon(
      tauschePlanPosition(m.client, m.userId, plan.id, {
        einheitKey,
        positionKey: position.key,
        exerciseId: position.exerciseId,
        machineId: fremd.id,
      }),
    );
    expect(e.code).toBe("validation_failed");
    expect((await zeile(plan.id)).status).toBe("aktiv");
  });

  it("Tausch auf nicht aktiven Plan: Konflikt", async () => {
    const m = await legeMitgliedAn("swap-vorschlag", { studios: [s.voll] });
    const vorschlag = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { einheitKey, position } = ersteStelle(vorschlag);
    const geraet = await machineVon(s.voll);
    const e = await fehlerVon(
      tauschePlanPosition(m.client, m.userId, vorschlag.id, {
        einheitKey,
        positionKey: position.key,
        exerciseId: position.exerciseId,
        machineId: geraet.id,
      }),
    );
    expect(e.code).toBe("conflict");
  });

  it("fremder Plan, ausgetretenes Mitglied und unbekannte Position", async () => {
    const { m, plan } = await mitAktivemPlan("swap-grenzen");
    const { einheitKey, position } = ersteStelle(plan);
    const geraet = await machineVon(s.voll);
    const eingabe = { einheitKey, positionKey: position.key, exerciseId: position.exerciseId, machineId: geraet.id };
    const anderer = await legeMitgliedAn("swap-anderer", { studios: [s.voll] });
    expect((await fehlerVon(tauschePlanPosition(anderer.client, anderer.userId, plan.id, eingabe))).code).toBe("conflict");
    expect(
      (await fehlerVon(tauschePlanPosition(m.client, m.userId, plan.id, { ...eingabe, positionKey: "gibt-es-nicht" }))).code,
    ).toBe("validation_failed");
    const { error } = await admin.from("studio_memberships").delete().eq("user_id", m.userId).eq("studio_id", s.voll);
    if (error) throw error;
    expect((await fehlerVon(tauschePlanPosition(m.client, m.userId, plan.id, eingabe))).code).toBe("conflict");
    expect((await zeile(plan.id)).status).toBe("aktiv");
  });

  it("ohne Anmeldung nicht aufrufbar", async () => {
    const { error } = await anonClient().rpc("swap_training_plan_position", {
      p_plan_id: crypto.randomUUID(),
      p_einheit_key: "A",
      p_position_key: "x",
      p_exercise_id: crypto.randomUUID(),
      p_machine_id: crypto.randomUUID(),
    });
    expect(error).not.toBeNull();
  });
});
