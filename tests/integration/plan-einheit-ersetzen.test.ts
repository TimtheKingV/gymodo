import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { serviceClient } from "./helpers/clients.js";
import {
  GYMTAVO,
  aktiverKatalogPlan,
  erzeugeKatalogPlan,
  legeMitgliedAn,
  legePlanStudiosAn,
  type KatalogPlan,
  type KatalogPosition,
  type PlanStudios,
} from "./helpers/plan-studio.js";

// P4: replace_training_plan_einheit (0075) ersetzt eine Einheit als Ganzes und legt eine
// neue aktive Version an. Alle Aufrufe mit dem Client des Mitglieds.
const admin = serviceClient();
let s: PlanStudios;
const gymtavoUebungen: string[] = [];
const kennung = crypto.randomUUID();

beforeAll(async () => {
  s = await legePlanStudiosAn(kennung);
});

afterAll(async () => {
  if (gymtavoUebungen.length > 0) {
    const { error } = await admin.from("exercises").delete().in("id", gymtavoUebungen);
    if (error) throw error;
  }
  const { error } = await admin.from("exercises").delete().eq("studio_id", GYMTAVO).like("name", `% ${kennung}`);
  if (error) throw error;
});

type Fehler = { code?: string; message?: string };

async function fehlerVon(p: PromiseLike<{ error: Fehler | null }>): Promise<Fehler> {
  const { error } = await p;
  if (!error) throw new Error("Kein Fehler geworfen");
  return error;
}

async function status(id: string): Promise<string> {
  const { data, error } = await admin.from("training_plans").select("status").eq("id", id).single();
  if (error) throw error;
  return data.status as string;
}

type NeuerPlan = {
  id: string;
  version: number;
  status: string;
  accepted_at: string | null;
  eingabe: unknown;
  gruende: string[];
  struktur: string;
  regel_version: string;
  einheiten: Array<{ key: string; name: string; geschaetzteMinuten?: number; positionen: KatalogPosition[] }>;
};

function ersetze(client: SupabaseClient, planId: string, einheitKey: string, positionen: unknown, minuten = 55) {
  return client
    .rpc("replace_training_plan_einheit", {
      p_plan_id: planId,
      p_einheit_key: einheitKey,
      p_positionen: positionen,
      p_minuten: minuten,
    })
    .single();
}

async function mitAktivemPlan(prefix: string, limits?: Record<string, "meiden" | "vorsichtig">) {
  const m = await legeMitgliedAn(prefix, { studios: [], ...(limits ? { limits } : {}) });
  const plan = await aktiverKatalogPlan(m, s);
  return { m, plan };
}

/** Die Positionen der ersten Einheit unveraendert (so liefert sie die Domain zurueck). */
function ersteEinheit(plan: KatalogPlan) {
  const e = plan.einheiten[0]!;
  const positionen = structuredClone(e.positionen) as KatalogPosition[];
  // Der Fixture-Plan hat bei Cardio keine Reserve; baueEinheit liefert sie immer.
  for (const p of positionen) {
    if (p.baustein === "cardio") Object.assign(p, { reserveVon: 1, reserveBis: 3 });
  }
  return { key: e.key, positionen };
}

async function neueUebung(
  o: { baustein?: string | null; typ?: string | null; bereiche?: string[]; muscles?: unknown[] } = {},
): Promise<string> {
  const { data, error } = await admin
    .from("exercises")
    .insert({
      studio_id: GYMTAVO,
      name: `Ersetzen ${crypto.randomUUID()}`,
      muscles: o.muscles ?? [
        { key: "quadrizeps", role: "primary" },
        { key: "gluteus", role: "secondary" },
      ],
      target_min: 8,
      target_max: 12,
      plan_baustein: o.baustein === undefined ? "druecken" : o.baustein,
      plan_typ: o.typ === undefined ? "isolation" : o.typ,
      plan_bereiche: o.bereiche ?? [],
    })
    .select("id")
    .single();
  if (error) throw error;
  gymtavoUebungen.push(data.id as string);
  const { error: e2 } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: s.katalogModell, exercise_id: data.id, sort_order: 99 });
  if (e2) throw e2;
  return data.id as string;
}

describe("replace_training_plan_einheit", () => {
  it("schreibt eine neue aktive Version und setzt die alte auf ersetzt", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-ok");
    const { key, positionen } = ersteEinheit(plan);
    const gekuerzt = positionen.slice(0, 3).reverse();
    gekuerzt[0]!.saetze = 4;

    const { data, error } = await ersetze(m.client, plan.id, key, gekuerzt, 42);
    expect(error).toBeNull();
    const neu = data as NeuerPlan;

    expect(neu).toMatchObject({ version: plan.version + 1, status: "aktiv", struktur: plan.struktur });
    expect(neu.id).not.toBe(plan.id);
    expect(neu.accepted_at).not.toBeNull();
    expect(neu.eingabe).toEqual(plan.eingabe);
    expect(neu.gruende).toEqual(plan.gruende);
    expect(neu.regel_version).toBe(plan.regelVersion);
    expect(await status(plan.id)).toBe("ersetzt");

    const einheit = neu.einheiten.find((e) => e.key === key)!;
    expect(einheit.geschaetzteMinuten).toBe(42);
    expect(einheit.positionen.map((p) => p.key)).toEqual(gekuerzt.map((p) => p.key));
    expect(einheit.positionen[0]!.saetze).toBe(4);
    // Die zweite Einheit bleibt unberuehrt, ebenso Reihenfolge der Einheiten.
    expect(neu.einheiten.map((e) => e.key)).toEqual(plan.einheiten.map((e) => e.key));
    expect(neu.einheiten[1]).toEqual(plan.einheiten[1]);
    const { data: aktiv } = await admin
      .from("training_plans")
      .select("status")
      .eq("user_id", m.userId)
      .eq("status", "aktiv");
    expect(aktiv).toHaveLength(1);
  });

  it("fremder Plan: plan_nicht_annehmbar", async () => {
    const { plan } = await mitAktivemPlan("ersetzen-fremd");
    const anderer = await legeMitgliedAn("ersetzen-anderer", { studios: [] });
    const e = await fehlerVon(ersetze(anderer.client, plan.id, plan.einheiten[0]!.key, ersteEinheit(plan).positionen));
    expect(e).toMatchObject({ code: "P0001", message: "plan_nicht_annehmbar" });
    expect(await status(plan.id)).toBe("aktiv");
  });

  it("ersetzter Plan: plan_nicht_annehmbar", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-alt");
    const { key, positionen } = ersteEinheit(plan);
    const { error } = await ersetze(m.client, plan.id, key, positionen);
    expect(error).toBeNull();
    const e = await fehlerVon(ersetze(m.client, plan.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "plan_nicht_annehmbar" });
  });

  it("Uebung ohne plan_baustein: uebung_ohne_planmerkmale", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-merkmal");
    const { key, positionen } = ersteEinheit(plan);
    positionen[0]!.exerciseId = await neueUebung({ baustein: null, typ: null });
    const e = await fehlerVon(ersetze(m.client, plan.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "uebung_ohne_planmerkmale" });
    expect(await status(plan.id)).toBe("aktiv");
  });

  it("gemiedener Bereich: uebung_gemieden", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-meiden", { knie: "meiden", schulter: "vorsichtig" });
    const { key, positionen } = ersteEinheit(plan);
    const stelle = positionen.find((p) => p.baustein !== "cardio")!;
    stelle.exerciseId = await neueUebung({ baustein: stelle.baustein, typ: stelle.typ, bereiche: ["knie"] });
    const e = await fehlerVon(ersetze(m.client, plan.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "uebung_gemieden" });
    // Kontrolle: "vorsichtig" sperrt nicht.
    stelle.exerciseId = await neueUebung({ baustein: stelle.baustein, typ: stelle.typ, bereiche: ["schulter"] });
    const { error } = await ersetze(m.client, plan.id, key, positionen);
    expect(error).toBeNull();
  });

  it("Modell eines normalen Studios: modell_ungueltig", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-modell");
    const { key, positionen } = ersteEinheit(plan);
    positionen[0]!.modelId = s.studioModelle.voll;
    const e = await fehlerVon(ersetze(m.client, plan.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "modell_ungueltig" });
    expect(await status(plan.id)).toBe("aktiv");
  });

  it("doppelte exerciseId: plan_ungueltig", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-doppelt");
    const { key, positionen } = ersteEinheit(plan);
    positionen[1] = { ...positionen[0]!, key: "doppelt" };
    const e = await fehlerVon(ersetze(m.client, plan.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
  });

  it("saetze 11: plan_ungueltig", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-saetze");
    const { key, positionen } = ersteEinheit(plan);
    positionen[0]!.saetze = 11;
    const e = await fehlerVon(ersetze(m.client, plan.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    expect(await status(plan.id)).toBe("aktiv");
  });

  it("hauptmuskeln kommen aus exercises, nicht aus dem Rumpf", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-muskeln");
    const { key, positionen } = ersteEinheit(plan);
    const stelle = positionen.find((p) => p.baustein !== "cardio")!;
    stelle.exerciseId = await neueUebung({ baustein: stelle.baustein, typ: stelle.typ });
    stelle.hauptmuskeln = ["erfunden"];
    const { data, error } = await ersetze(m.client, plan.id, key, positionen);
    expect(error).toBeNull();
    const neu = data as NeuerPlan;
    const p = neu.einheiten.find((e) => e.key === key)!.positionen.find((x) => x.key === stelle.key)!;
    expect(p.hauptmuskeln).toEqual(["quadrizeps"]);
  });

  it("Cardio-Position behaelt reserveVon/reserveBis", async () => {
    const { m, plan } = await mitAktivemPlan("ersetzen-cardio");
    const { key, positionen } = ersteEinheit(plan);
    const cardio = positionen.find((p) => p.baustein === "cardio")!;
    const { data, error } = await ersetze(m.client, plan.id, key, positionen);
    expect(error).toBeNull();
    const neu = data as NeuerPlan;
    const c = neu.einheiten.find((e) => e.key === key)!.positionen.find((p) => p.key === cardio.key)!;
    expect(c).toMatchObject({ reserveVon: 1, reserveBis: 3, wdhVon: null, wdhBis: null, saetze: 1, pauseSek: 0 });
    // Ohne Reserve ist die Cardio-Position ungueltig.
    cardio.reserveVon = null;
    const e = await fehlerVon(ersetze(m.client, neu.id, key, positionen));
    expect(e).toMatchObject({ code: "P0001", message: "plan_ungueltig" });
    expect(await status(neu.id)).toBe("aktiv");
  });

  it("gemiedene Uebung, die schon in der Einheit steht, blockiert das Entfernen einer anderen Position nicht", async () => {
    const m = await legeMitgliedAn("ersetzen-spaeter", { studios: [] });
    const plan = await aktiverKatalogPlan(m, s);
    const { key, positionen } = ersteEinheit(plan);
    // Beschwerde erst nach dem Plan: die Beinpresse (Bereich knie) steht schon in der Einheit.
    const { error: le } = await admin
      .from("training_limits")
      .insert({ user_id: m.userId, consent_at: new Date().toISOString(), areas: { knie: "meiden" } });
    if (le) throw le;
    expect(positionen[0]!.exerciseId).toBe(s.uebungen["Beinpresse"]);
    const ohneLetzte = positionen.filter((p) => p.baustein !== "cardio").slice(0, -1);
    const { error } = await ersetze(m.client, plan.id, key, ohneLetzte);
    expect(error).toBeNull();
  });
});
