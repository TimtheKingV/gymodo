import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  acceptPlan,
  deleteTrainingLimits,
  erzeugePlanVorschlag,
  listPlaene,
  saveTrainingLimits,
  type TrainingPlan,
} from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";
import { legeEinheitAn, legeMitgliedAn, legePlanStudiosAn, type PlanStudios } from "./helpers/plan-studio.js";

// Task 7 Etappe 2: Plaene speichern, versionieren und bestaetigen.
// Alle Aufrufe laufen mit dem Client des Mitglieds, damit RLS (auch beim
// Laden der Kandidaten) wirklich greift.
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

async function zeilen(userId: string, studioId: string) {
  const { data, error } = await admin
    .from("training_plans")
    .select("id, version, status")
    .eq("user_id", userId)
    .eq("studio_id", studioId)
    .order("version");
  if (error) throw error;
  return data as Array<{ id: string; version: number; status: string }>;
}

const positionen = (p: TrainingPlan) => p.einheiten.flatMap((e) => e.positionen);

describe("erzeugePlanVorschlag", () => {
  it("erzeugt Vorschlag mit version 1", async () => {
    const m = await legeMitgliedAn("plan-v1", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    expect(plan).toMatchObject({ studioId: s.voll, version: 1, status: "vorschlag", acceptedAt: null, struktur: "gk_ab" });
    expect(plan.regelVersion).toBe("1.2.0");
    expect(plan.eingabe).toEqual({
      ziel: "muskelaufbau",
      tage: 3,
      minuten: 60,
      fokus: [],
      erfahrung: "regelmaessig",
      anfaengerBeendet: false,
      beschwerdenBeruecksichtigt: false,
    });
    expect(plan.eingabe).not.toHaveProperty("kandidaten");
    expect(plan.einheiten[0]!.positionen.length).toBeGreaterThan(0);
    expect(positionen(plan).every((p) => p.exerciseId && p.machineId)).toBe(true);
    expect(plan.gruende.length).toBeGreaterThan(0);
  });

  it("zweiter Vorschlag verwirft den ersten und hat version 2", async () => {
    const m = await legeMitgliedAn("plan-v2", { studios: [s.voll] });
    const erster = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const zweiter = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    expect(zweiter.version).toBe(2);
    expect(await zeilen(m.userId, s.voll)).toEqual([
      { id: erster.id, version: 1, status: "verworfen" },
      { id: zweiter.id, version: 2, status: "vorschlag" },
    ]);
  });

  it("Beschwerden meiden knie: keine Position mit Knie-Uebung", async () => {
    const m = await legeMitgliedAn("plan-knie", { studios: [s.voll], limits: { knie: "meiden" } });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    expect(plan.eingabe).toMatchObject({ beschwerdenBeruecksichtigt: true });
    expect(positionen(plan).length).toBeGreaterThan(0);
    expect(positionen(plan).some((p) => s.knieUebungen.includes(p.exerciseId))).toBe(false);
  });

  it("Beschwerden landen nicht in der Planzeile; Widerruf entfernt Hinweise, Uebungen bleiben", async () => {
    const m = await legeMitgliedAn("plan-dsgvo", { studios: [s.voll] });
    await saveTrainingLimits(
      m.client, m.userId, { einwilligung: true, areas: { knie: "meiden", schulter: "vorsichtig" } }, new Date(),
    );
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    expect(plan.gruende).toEqual(expect.arrayContaining(["beschwerden_meiden", "beschwerden_vorsichtig"]));
    await acceptPlan(m.client, m.userId, plan.id);
    const zweiter = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    await deleteTrainingLimits(m.client, m.userId);

    // Art. 9 DSGVO: nach dem Widerruf darf keine Planzeile mehr verraten, dass es Beschwerden gab.
    const { data: alle, error: fehlerAlle } = await admin
      .from("training_plans").select("id, eingabe, gruende").eq("user_id", m.userId);
    if (fehlerAlle) throw fehlerAlle;
    expect(alle).toHaveLength(2);
    for (const z of alle!) {
      expect(z.eingabe).toMatchObject({ beschwerdenBeruecksichtigt: false });
      expect((z.gruende as string[]).some((g) => g.startsWith("beschwerden_"))).toBe(false);
    }
    const [neu] = await listPlaene(m.client, m.userId, s.voll);
    expect(neu!.id).toBe(zweiter.id);
    expect(neu!.gruende).toEqual(zweiter.gruende.filter((g) => !g.startsWith("beschwerden_")));

    const { data, error } = await admin.from("training_plans").select("eingabe, einheiten").eq("id", plan.id).single();
    if (error) throw error;
    const roh = JSON.stringify(data.eingabe);
    expect(data.eingabe).not.toHaveProperty("beschwerden");
    for (const bereich of ["knie", "huefte", "unterer_ruecken", "schulter", "ellenbogen_handgelenk", "meiden", "vorsichtig"]) {
      expect(roh).not.toContain(bereich);
    }
    const gespeichert = (data.einheiten as TrainingPlan["einheiten"]).flatMap((e) => e.positionen);
    expect(gespeichert.some((p) => s.knieUebungen.includes(p.exerciseId))).toBe(false);
    // Die Uebungen selbst bleiben unveraendert (F14: Plaene sind stabil).
    expect(data.einheiten).toEqual(plan.einheiten);
    const gelesen = await listPlaene(m.client, m.userId, s.voll);
    expect(gelesen.map((p) => p.einheiten)).toEqual([zweiter.einheiten, plan.einheiten]);
  });

  it("Beschwerden geloescht: gleicher Plan wie ohne Beschwerden", async () => {
    const ohne = await legeMitgliedAn("plan-ohne-b", { studios: [s.voll] });
    const mit = await legeMitgliedAn("plan-mit-b", { studios: [s.voll], limits: { knie: "meiden" } });
    await deleteTrainingLimits(mit.client, mit.userId);
    const a = await erzeugePlanVorschlag(ohne.client, ohne.userId, s.voll);
    const b = await erzeugePlanVorschlag(mit.client, mit.userId, s.voll);
    expect(b.eingabe).toEqual(a.eingabe);
    expect(b.einheiten).toEqual(a.einheiten);
    expect(b.gruende).toEqual(a.gruende);
  });

  it("ohne Trainingsprofil: profil_unvollstaendig", async () => {
    const m = await legeMitgliedAn("plan-kein-tp", { studios: [s.voll], profil: null });
    const e = await fehlerVon(erzeugePlanVorschlag(m.client, m.userId, s.voll));
    expect(e.code).toBe("profil_unvollstaendig");
    expect(e.message).toContain("profil_unvollstaendig");
    expect(e.detail).toEqual({ fehlt: ["trainingsprofil"] });
    expect(await zeilen(m.userId, s.voll)).toEqual([]);
  });

  it("ohne weekly_days: profil_unvollstaendig", async () => {
    const m = await legeMitgliedAn("plan-keine-tage", { studios: [s.voll], weeklyDays: null });
    const e = await fehlerVon(erzeugePlanVorschlag(m.client, m.userId, s.voll));
    expect(e.code).toBe("profil_unvollstaendig");
    expect(e.detail).toEqual({ fehlt: ["tage"] });
  });

  it("ohne training_goal: profil_unvollstaendig", async () => {
    const m = await legeMitgliedAn("plan-kein-ziel", { studios: [s.voll], trainingGoal: null });
    const e = await fehlerVon(erzeugePlanVorschlag(m.client, m.userId, s.voll));
    expect(e.code).toBe("profil_unvollstaendig");
    expect(e.detail).toEqual({ fehlt: ["ziel"] });
  });

  it("weekly_days 7 plant wie 6", async () => {
    const sieben = await legeMitgliedAn("plan-7", { studios: [s.voll], weeklyDays: 7 });
    const sechs = await legeMitgliedAn("plan-6", { studios: [s.voll], weeklyDays: 6 });
    const a = await erzeugePlanVorschlag(sieben.client, sieben.userId, s.voll);
    const b = await erzeugePlanVorschlag(sechs.client, sechs.userId, s.voll);
    expect(a.struktur).toBe("gk_abc");
    expect(a.einheiten).toEqual(b.einheiten);
  });

  it("Studio ohne Druckmaschine: plan_nicht_moeglich baustein druecken", async () => {
    const m = await legeMitgliedAn("plan-ohne-druck", { studios: [s.ohneDruck] });
    const e = await fehlerVon(erzeugePlanVorschlag(m.client, m.userId, s.ohneDruck));
    expect(e.code).toBe("plan_nicht_moeglich");
    expect(e.detail).toEqual({ baustein: "druecken", grund: "kein_geraet" });
    expect(e.message).not.toContain("druecken");
    expect(await zeilen(m.userId, s.ohneDruck)).toEqual([]);
  });

  it("erzeugePlanVorschlag nach 8 Einheiten plant 3 Saetze", async () => {
    const m = await legeMitgliedAn("plan-anfaenger-ende", {
      studios: [s.voll, s.voll2], profil: { minutes: 60, experience: "neu", focus: [] },
    });
    const kraft = (p: TrainingPlan) => positionen(p).filter((x) => x.rolle !== "cardio");
    const plan = await acceptPlan(m.client, m.userId, (await erzeugePlanVorschlag(m.client, m.userId, s.voll)).id);
    expect(plan.eingabe.anfaengerBeendet).toBe(false);
    expect(new Set(kraft(plan).map((x) => x.saetze))).toEqual(new Set([2]));

    const stunden = (h: number) => new Date(Date.now() - h * 3_600_000);
    for (let i = 0; i < 8; i++) {
      await legeEinheitAn(m.userId, s.voll, { planId: plan.id, einheitKey: plan.einheiten[0]!.key, startedAt: stunden(100 - i * 10) });
    }
    const danach = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    expect(danach.eingabe.anfaengerBeendet).toBe(true);
    expect(danach.gruende).not.toContain("anfaenger_reserve");
    expect(new Set(kraft(danach).map((x) => x.saetze))).toEqual(new Set([3]));

    // Der Zaehler gilt je Paar: im zweiten Studio bleibt es beim Anfaengerplan.
    const anderes = await erzeugePlanVorschlag(m.client, m.userId, s.voll2);
    expect(anderes.eingabe.anfaengerBeendet).toBe(false);
  });

  it("Studio, in dem das Mitglied nicht ist: not_found", async () => {
    const m = await legeMitgliedAn("plan-fremdes-studio", { studios: [s.voll] });
    const e = await fehlerVon(erzeugePlanVorschlag(m.client, m.userId, s.voll2));
    expect(e.code).toBe("not_found");
  });
});

describe("acceptPlan", () => {
  it("accept macht aktiv, ersetzt den bisherigen aktiven Plan", async () => {
    const m = await legeMitgliedAn("plan-accept", { studios: [s.voll] });
    const v1 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const aktiv1 = await acceptPlan(m.client, m.userId, v1.id);
    expect(aktiv1).toMatchObject({ id: v1.id, status: "aktiv", version: 1 });
    expect(aktiv1.acceptedAt).not.toBeNull();

    const v2 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    // Ein neuer Vorschlag laesst den aktiven Plan unberuehrt.
    expect((await zeilen(m.userId, s.voll)).map((z) => z.status)).toEqual(["aktiv", "vorschlag"]);
    const aktiv2 = await acceptPlan(m.client, m.userId, v2.id);
    expect(aktiv2.status).toBe("aktiv");
    expect((await zeilen(m.userId, s.voll)).map((z) => z.status)).toEqual(["ersetzt", "aktiv"]);
  });

  it("accept auf verworfenen Vorschlag wirft Konflikt", async () => {
    const m = await legeMitgliedAn("plan-verworfen", { studios: [s.voll] });
    const v1 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const e = await fehlerVon(acceptPlan(m.client, m.userId, v1.id));
    expect(e.code).toBe("conflict");
  });

  it("zwei parallele accept hinterlassen genau einen aktiven Plan", async () => {
    const m = await legeMitgliedAn("plan-parallel", { studios: [s.voll] });
    const v1 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    await acceptPlan(m.client, m.userId, v1.id);
    const v2 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const ergebnisse = await Promise.allSettled([
      acceptPlan(m.client, m.userId, v2.id),
      acceptPlan(m.client, m.userId, v2.id),
    ]);
    expect(ergebnisse.filter((r) => r.status === "fulfilled")).toHaveLength(1);
    const abgelehnt = ergebnisse.find((r) => r.status === "rejected") as PromiseRejectedResult;
    expect((abgelehnt.reason as DomainError).code).toBe("conflict");
    const stand = await zeilen(m.userId, s.voll);
    expect(stand.filter((z) => z.status === "aktiv")).toEqual([{ id: v2.id, version: 2, status: "aktiv" }]);
  });

  it("unbekannte Plan-ID wirft Konflikt", async () => {
    const m = await legeMitgliedAn("plan-unbekannt", { studios: [s.voll] });
    const e = await fehlerVon(acceptPlan(m.client, m.userId, crypto.randomUUID()));
    expect(e.code).toBe("conflict");
  });
});

describe("RLS training_plans", () => {
  it("Update auf ein fremdes Studio wird abgelehnt", async () => {
    const m = await legeMitgliedAn("plan-umzug", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { data, error } = await m.client
      .from("training_plans")
      .update({ studio_id: s.ohneDruck })
      .eq("id", plan.id)
      .select("id");
    // WITH CHECK schlaegt als Fehler (42501) zu; 0 Zeilen waere ebenso eine Ablehnung.
    expect(error !== null || (data ?? []).length === 0).toBe(true);
    const { data: zeile } = await admin.from("training_plans").select("studio_id").eq("id", plan.id).single();
    expect(zeile!.studio_id).toBe(s.voll);
  });

  // Seit 0062 schreibt das Mitglied nur ueber create_/accept_training_plan.
  it("Update innerhalb des eigenen Studios wird ebenfalls abgelehnt", async () => {
    const m = await legeMitgliedAn("plan-update-ok", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const { data, error } = await m.client
      .from("training_plans")
      .update({ status: "verworfen" })
      .eq("id", plan.id)
      .select("id");
    expect(error !== null || (data ?? []).length === 0).toBe(true);
    const { data: zeile } = await admin.from("training_plans").select("status").eq("id", plan.id).single();
    expect(zeile!.status).toBe("vorschlag");
  });
});

describe("listPlaene", () => {
  it("Plaene verschiedener Studios des Mitglieds sind unabhaengig", async () => {
    const m = await legeMitgliedAn("plan-zwei-studios", { studios: [s.voll, s.voll2] });
    const a = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const b = await erzeugePlanVorschlag(m.client, m.userId, s.voll2);
    expect(b.version).toBe(1);
    await acceptPlan(m.client, m.userId, a.id);
    await acceptPlan(m.client, m.userId, b.id);
    const listeA = await listPlaene(m.client, m.userId, s.voll);
    const listeB = await listPlaene(m.client, m.userId, s.voll2);
    expect(listeA.map((p) => [p.id, p.status])).toEqual([[a.id, "aktiv"]]);
    expect(listeB.map((p) => [p.id, p.status])).toEqual([[b.id, "aktiv"]]);
  });

  it("neueste Version zuerst, ohne Neuberechnung", async () => {
    const m = await legeMitgliedAn("plan-liste", { studios: [s.voll] });
    const v1 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const v2 = await erzeugePlanVorschlag(m.client, m.userId, s.voll);
    const liste = await listPlaene(m.client, m.userId, s.voll);
    expect(liste.map((p) => p.version)).toEqual([2, 1]);
    expect(liste[0]).toEqual(v2);
    expect(liste[1]).toMatchObject({ id: v1.id, status: "verworfen", einheiten: v1.einheiten });
    expect(await listPlaene(m.client, m.userId, s.ohneDruck)).toEqual([]);
  });

  it("fremder Nutzer sieht keinen Plan", async () => {
    const a = await legeMitgliedAn("plan-eigner", { studios: [s.voll] });
    const b = await legeMitgliedAn("plan-fremder", { studios: [s.voll] });
    const plan = await erzeugePlanVorschlag(a.client, a.userId, s.voll);
    expect(await listPlaene(b.client, b.userId, s.voll)).toEqual([]);
    // Auch mit fremder userId liefert RLS nichts.
    expect(await listPlaene(b.client, a.userId, s.voll)).toEqual([]);
    const { data } = await b.client.from("training_plans").select("id").eq("id", plan.id);
    expect(data).toEqual([]);
    const e = await fehlerVon(acceptPlan(b.client, b.userId, plan.id));
    expect(e.code).toBe("conflict");
    expect((await zeilen(a.userId, s.voll))[0]!.status).toBe("vorschlag");
  });
});
