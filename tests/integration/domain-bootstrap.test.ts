import { beforeAll, describe, expect, it } from "vitest";
import {
  acceptPlan,
  createTagToken,
  erzeugePlanVorschlag,
  getBootstrap,
  hashTagToken,
  type Bootstrap,
  type TrainingPlan,
} from "@fitretro/domain";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";
import {
  legeEinheitAn,
  legeMitgliedAn,
  legePlanStudiosAn,
  type Mitglied,
  type PlanStudios,
} from "./helpers/plan-studio.js";

let studioA: string;
let memberAEmail: string;
let memberAId: string;
let machineA: string;
let foreignMachine: string;
let breitId: string;
let engId: string;
let tokenA: string;

function newId(): string {
  return crypto.randomUUID();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Bootstrap Studio A" }, { name: "Bootstrap Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  const studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("boot-member-a");
  memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(uniqueEmail("boot-member-b"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioB, user_id: memberBId, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      {
        studio_id: studioA,
        name: "Kabelzug",
        load_step: 2.5,
        load_min: 5,
        load_max: 100,
      },
      // load_min hier ausdruecklich: bei einem Bulk-Insert vereinheitlicht
      // PostgREST die Spaltenmenge und schickt fuer fehlende Schluessel NULL
      // statt DEFAULT -- der Not-Null-Constraint schluege sonst zu.
      {
        studio_id: studioB,
        name: "Fremdgeraet",
        load_step: 5,
        load_min: 0,
        load_max: null,
      },
    ])
    .select("id");
  if (modelError) throw modelError;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Latzug breit",
        target_min: 8,
        target_max: 12,
      },
      {
        studio_id: studioA,
        name: "Latzug eng",
        target_min: 8,
        target_max: 12,
      },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;
  breitId = exercises[0]!.id;
  engId = exercises[1]!.id;

  const { error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: models[0]!.id, exercise_id: breitId, sort_order: 1 },
      { equipment_model_id: models[0]!.id, exercise_id: engId, sort_order: 2 },
    ]);
  if (linkError) throw linkError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "12" },
      { studio_id: studioB, equipment_model_id: models[1]!.id, label: "99" },
    ])
    .select("id");
  if (machineError) throw machineError;
  machineA = machines[0]!.id;
  foreignMachine = machines[1]!.id;

  tokenA = createTagToken();
  await tagsAnlegen(admin, [
    { studioId: studioA, machineId: machineA, token: tokenA, status: "active" },
    { studioId: studioB, machineId: foreignMachine, status: "active" },
  ]);

  // Zwei Kalibrierungen derselben Kombination -- die neuere muss gewinnen.
  const { error: calibrationError } = await admin
    .from("member_machine_calibrations")
    .insert([
      {
        studio_id: studioA,
        user_id: memberAId,
        machine_id: machineA,
        exercise_id: breitId,
        setting_values: { sitz: 3 },
        schema_version: 1,
        created_at: new Date("2026-08-01T10:00:00Z").toISOString(),
      },
      {
        studio_id: studioA,
        user_id: memberAId,
        machine_id: machineA,
        exercise_id: breitId,
        setting_values: { sitz: 6 },
        schema_version: 1,
        created_at: new Date("2026-08-20T10:00:00Z").toISOString(),
      },
    ]);
  if (calibrationError) throw calibrationError;

  const sessionId = newId();
  const { error: sessionError } = await admin
    .from("workout_sessions")
    .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
  if (sessionError) throw sessionError;

  const { error: setError } = await admin.from("workout_sets").insert([
    {
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionId,
      machine_id: machineA,
      exercise_id: breitId,
      set_index: 1,
      load: 42.5,
      volume: 12,
      performed_at: new Date("2026-08-20T18:00:00Z").toISOString(),
    },
    {
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionId,
      machine_id: machineA,
      exercise_id: breitId,
      set_index: 2,
      load: 45,
      volume: 11,
      performed_at: new Date("2026-08-27T18:00:00Z").toISOString(),
    },
  ]);
  if (setError) throw setError;
});

describe("getBootstrap", () => {
  it("liefert das eigene Studio", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.studios.map((studio) => studio.id)).toEqual([studioA]);
  });

  it("liefert die Geraete des Studios samt Modelldaten", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    const machine = bootstrap.machines.find((m) => m.id === machineA);
    expect(machine?.label).toBe("12");
    expect(machine?.equipmentModel.loadStep).toBe(2.5);
    expect(machine?.equipmentModel.loadMax).toBe(100);
  });

  it("liefert je Geraet die Tag-Hashes fuer die Aufloesung ohne Empfang", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    const machine = bootstrap.machines.find((m) => m.id === machineA);
    expect(machine?.tokenHashes).toContain(hashTagToken(tokenA));
  });

  it("liefert die Uebungen je Geraet in der gepflegten Reihenfolge", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    const machine = bootstrap.machines.find((m) => m.id === machineA);
    expect(machine?.exercises.map((exercise) => exercise.id)).toEqual([
      breitId,
      engId,
    ]);
  });

  it("liefert je Kombination nur die neueste eigene Kalibrierung", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    const forBreit = bootstrap.calibrations.filter(
      (calibration) =>
        calibration.machineId === machineA &&
        calibration.exerciseId === breitId,
    );
    expect(forBreit).toHaveLength(1);
    expect(forBreit[0]!.settingValues).toEqual({ sitz: 6 });
  });

  it("liefert je Kombination den zuletzt bestaetigten Satz", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    const last = bootstrap.lastSets.find(
      (set) => set.machineId === machineA && set.exerciseId === breitId,
    );
    expect(last?.load).toBe(45);
    expect(last?.volume).toBe(11);
  });

  it("cross-tenant: ein Geraet aus einem fremden Studio fehlt", async () => {
    const client = await userClient(memberAEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.machines.map((m) => m.id)).not.toContain(foreignMachine);
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(getBootstrap(anonClient())).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});

// Etappe 3, Task 6: Trainingsprofil und aktive Plaene samt Zaehler im Bootstrap.
describe("getBootstrap -- Trainingsplan", () => {
  let ps: PlanStudios;
  const admin = serviceClient();
  const stunden = (h: number) => new Date(Date.now() - h * 3_600_000);

  beforeAll(async () => {
    ps = await legePlanStudiosAn(crypto.randomUUID());
  });

  async function aktiverPlan(m: Mitglied, studioId: string): Promise<TrainingPlan> {
    return acceptPlan(m.client, m.userId, (await erzeugePlanVorschlag(m.client, m.userId, studioId)).id);
  }

  function planIn(b: Bootstrap, studioId: string) {
    const treffer = b.member.plans.filter((p) => p.studioId === studioId);
    expect(treffer).toHaveLength(1);
    return treffer[0]!;
  }

  const satzAn = (plan: TrainingPlan) => ({
    machineId: plan.einheiten[0]!.positionen[0]!.machineId,
    exerciseId: plan.einheiten[0]!.positionen[0]!.exerciseId,
  });

  it("Bootstrap enthaelt member.plans nur fuer Studios mit Mitgliedschaft", async () => {
    const m = await legeMitgliedAn("boot-plan-mitgl", { studios: [ps.voll, ps.voll2] });
    const a = await aktiverPlan(m, ps.voll);
    await aktiverPlan(m, ps.voll2);
    // Ein Vorschlag ist kein Plan, nach dem trainiert wird.
    await erzeugePlanVorschlag(m.client, m.userId, ps.voll);
    // Austritt: der Plan bleibt lesbar (select_own), gehoert aber nicht mehr in den Bootstrap.
    const { error } = await admin.from("studio_memberships").delete().eq("user_id", m.userId).eq("studio_id", ps.voll2);
    if (error) throw error;

    const b = await getBootstrap(m.client);
    expect(b.member.plans.map((p) => p.studioId)).toEqual([ps.voll]);
    const p = planIn(b, ps.voll);
    expect(p).toMatchObject({
      planId: a.id,
      version: a.version,
      regelVersion: a.regelVersion,
      struktur: a.struktur,
      einheiten: a.einheiten,
      gruende: a.gruende,
      naechsteEinheitKey: a.einheiten[0]!.key,
      zuletztEinheitKey: null,
      einheitenErledigt: 0,
      anfaengerUebergang: false,
    });
    expect(b.member.trainingProfile).toEqual({ minutes: 60, experience: "regelmaessig", focus: [] });
  });

  it("naechsteEinheitKey folgt der zuletzt gezaehlten Einheit", async () => {
    const m = await legeMitgliedAn("boot-plan-folge", { studios: [ps.voll] });
    const plan = await aktiverPlan(m, ps.voll);
    const [a, b] = plan.einheiten.map((e) => e.key) as [string, string];
    await legeEinheitAn(m.userId, ps.voll, { planId: plan.id, einheitKey: b, startedAt: stunden(30) });
    await legeEinheitAn(m.userId, ps.voll, { planId: plan.id, einheitKey: a, startedAt: stunden(20) });
    // Nie beendet, letzter Satz vor 5 h: gilt als abgeschlossen (Auto-Abschluss nach 4 h).
    await legeEinheitAn(m.userId, ps.voll, {
      planId: plan.id, einheitKey: b, startedAt: stunden(6), completedAt: null,
      saetzeAm: [stunden(5.5), stunden(5)], satzAn: satzAn(plan),
    });
    // Laeuft noch (letzter Satz vor 10 min): zaehlt nicht, auch wenn sie juenger ist.
    await legeEinheitAn(m.userId, ps.voll, {
      planId: plan.id, einheitKey: a, startedAt: stunden(0.5), completedAt: null,
      saetzeAm: [stunden(1 / 6)], satzAn: satzAn(plan),
    });
    // Nur offene Positionen: nichts trainiert, zaehlt nicht.
    await legeEinheitAn(m.userId, ps.voll, { planId: plan.id, einheitKey: a, startedAt: stunden(3), status: ["offen"] });

    const p = planIn(await getBootstrap(m.client), ps.voll);
    expect(p).toMatchObject({ zuletztEinheitKey: b, naechsteEinheitKey: a, einheitenErledigt: 3 });
  });

  it("einheitenErledigt zaehlt ueber Planversionen desselben Paars", async () => {
    const m = await legeMitgliedAn("boot-plan-versionen", { studios: [ps.voll, ps.voll2] });
    const v1 = await aktiverPlan(m, ps.voll);
    await legeEinheitAn(m.userId, ps.voll, { planId: v1.id, einheitKey: v1.einheiten[0]!.key, startedAt: stunden(50) });
    await legeEinheitAn(m.userId, ps.voll, { planId: v1.id, einheitKey: v1.einheiten[1]!.key, startedAt: stunden(40) });
    const v2 = await aktiverPlan(m, ps.voll);
    // Optional zaehlt wie erledigt.
    await legeEinheitAn(m.userId, ps.voll, {
      planId: v2.id, einheitKey: v2.einheiten[0]!.key, startedAt: stunden(30), status: ["offen", "optional"],
    });
    // Anderes Studio, eigener Zaehler.
    const fremd = await aktiverPlan(m, ps.voll2);
    await legeEinheitAn(m.userId, ps.voll2, { planId: fremd.id, einheitKey: fremd.einheiten[0]!.key, startedAt: stunden(10) });

    const b = await getBootstrap(m.client);
    expect(planIn(b, ps.voll)).toMatchObject({
      planId: v2.id, version: 2, einheitenErledigt: 3, zuletztEinheitKey: v2.einheiten[0]!.key,
      naechsteEinheitKey: v2.einheiten[1]!.key,
    });
    expect(planIn(b, ps.voll2)).toMatchObject({ einheitenErledigt: 1 });
  });

  it("alternativen schliessen meiden-Uebungen aus und enthalten kein Beschwerdenfeld", async () => {
    const m = await legeMitgliedAn("boot-plan-meiden", {
      studios: [ps.voll], limits: { knie: "meiden", schulter: "vorsichtig" },
    });
    await aktiverPlan(m, ps.voll);
    const b = await getBootstrap(m.client);
    const p = planIn(b, ps.voll);
    const alle = Object.values(p.alternativen).flat();
    expect(alle.length).toBeGreaterThan(0);
    expect(alle.some((k) => ps.knieUebungen.includes(k.exerciseId))).toBe(false);
    expect(p.alternativen.beine_knie).toHaveLength(1);
    expect(p.alternativen.druecken).toHaveLength(1);
    for (const k of alle) expect(Object.keys(k).sort()).toEqual(["exerciseId", "machineId"]);

    // Die Beschwerden selbst stehen nirgends im Bootstrap (Gesundheitsdaten).
    expect(Object.keys(p).sort()).toEqual([
      "alternativen", "anfaengerUebergang", "einheiten", "einheitenErledigt", "gruende", "naechsteEinheitKey",
      "planId", "regelVersion", "struktur", "studioId", "version", "zuletztEinheitKey",
    ]);
    const { gruende: _gruende, ...ohneGruende } = p;
    const roh = JSON.stringify({ ...b, member: { ...b.member, plans: [ohneGruende] } });
    for (const wort of ["meiden", "vorsichtig", "consent", "areas", "limits", "beschwerden"]) {
      expect(roh).not.toContain(wort);
    }
  });

  it("alternativen sortieren vorsichtige Uebungen nach hinten", async () => {
    const m = await legeMitgliedAn("boot-plan-vorsicht", { studios: [ps.voll], limits: { knie: "vorsichtig" } });
    await aktiverPlan(m, ps.voll);
    const p = planIn(await getBootstrap(m.client), ps.voll);
    const knie = p.alternativen.beine_knie!.map((k) => k.exerciseId);
    expect(knie).toHaveLength(2);
    // knieUebungen[0] ist die Beinpresse (Bereich knie), die andere hat keinen Bereich.
    expect(knie[1]).toBe(ps.knieUebungen[0]);
  });

  it("anfaengerUebergang erst ab 8 Einheiten bei Erfahrung neu, nicht mehr nach Annahme eines Plans mit anfaengerBeendet", async () => {
    const m = await legeMitgliedAn("boot-plan-anfaenger", {
      studios: [ps.voll], profil: { minutes: 60, experience: "neu", focus: [] },
    });
    const plan = await aktiverPlan(m, ps.voll);
    for (let i = 0; i < 7; i++) {
      await legeEinheitAn(m.userId, ps.voll, {
        planId: plan.id, einheitKey: plan.einheiten[i % plan.einheiten.length]!.key, startedAt: stunden(100 - i * 10),
      });
    }
    expect(planIn(await getBootstrap(m.client), ps.voll)).toMatchObject({ einheitenErledigt: 7, anfaengerUebergang: false });

    await legeEinheitAn(m.userId, ps.voll, { planId: plan.id, einheitKey: plan.einheiten[0]!.key, startedAt: stunden(20) });
    expect(planIn(await getBootstrap(m.client), ps.voll)).toMatchObject({ einheitenErledigt: 8, anfaengerUebergang: true });

    const neu = await aktiverPlan(m, ps.voll);
    expect(neu.eingabe.anfaengerBeendet).toBe(true);
    expect(planIn(await getBootstrap(m.client), ps.voll)).toMatchObject({
      planId: neu.id, einheitenErledigt: 8, anfaengerUebergang: false,
    });
  });

  it("anfaengerUebergang bleibt aus bei anderer Erfahrung", async () => {
    const m = await legeMitgliedAn("boot-plan-erfahren", { studios: [ps.voll] });
    const plan = await aktiverPlan(m, ps.voll);
    for (let i = 0; i < 8; i++) {
      await legeEinheitAn(m.userId, ps.voll, { planId: plan.id, einheitKey: plan.einheiten[0]!.key, startedAt: stunden(100 - i * 10) });
    }
    expect(planIn(await getBootstrap(m.client), ps.voll)).toMatchObject({ einheitenErledigt: 8, anfaengerUebergang: false });
  });

  it("trainingProfile ist null ohne Profil", async () => {
    const m = await legeMitgliedAn("boot-plan-ohne-tp", { studios: [ps.voll], profil: null });
    const b = await getBootstrap(m.client);
    expect(b.member.trainingProfile).toBeNull();
    expect(b.member.plans).toEqual([]);
  });
});
