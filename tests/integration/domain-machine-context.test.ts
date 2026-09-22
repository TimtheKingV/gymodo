import { beforeAll, describe, expect, it } from "vitest";
import {
  createTagToken,
  getMachineContext,
  getTagContext,
} from "@fitretro/domain";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberAId: string;
let machineA: string;
let machineForeign: string;
let laufband: string;
let breitId: string;
let dauerlaufId: string;
let tokenA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "MC Studio A" }, { name: "MC Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("mc-member-a");
  memberAId = await createTestUser(memberAEmail);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: memberAId, role: "member" });
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Kabelzug",
      manufacturer: "Technogym",
      load_step: 2.5,
      load_min: 5,
      load_max: 100,
    })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { error: settingError } = await admin
    .from("equipment_setting_definitions")
    .insert({
      equipment_model_id: model.id,
      key: "sitz",
      label: "Sitzposition",
      kind: "number",
      min_value: 1,
      max_value: 8,
      step_value: 1,
      sort_order: 1,
    });
  if (settingError) throw settingError;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Latzug breit",
      target_min: 8,
      target_max: 12,
    })
    .select("id");
  if (exerciseError) throw exerciseError;
  breitId = exercises[0]!.id;

  const { error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: model.id, exercise_id: breitId, sort_order: 1 });
  if (linkError) throw linkError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: model.id, label: "12" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineA = machines.id;

  const { data: foreignModel, error: foreignModelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioB, name: "Fremdgeraet", load_step: 5 })
    .select("id")
    .single();
  if (foreignModelError) throw foreignModelError;

  const { data: foreign, error: foreignMachineError } = await admin
    .from("machines")
    .insert({
      studio_id: studioB,
      equipment_model_id: foreignModel.id,
      label: "99",
    })
    .select("id")
    .single();
  if (foreignMachineError) throw foreignMachineError;
  machineForeign = foreign.id;

  // Laufband: Tempo als Belastung, Neigung als Nebenbelastung, Minuten als
  // Umfang (Cardio-Spec Abschnitt 9, Probe aufs Exempel).
  const { data: laufbandModell, error: laufbandModellError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Laufband",
      category: "cardio",
      load_unit: "kmh",
      load_step: 0.5,
      load_min: 0,
      load_max: 20,
      secondary_unit: "pct",
      secondary_step: 0.5,
      secondary_min: 0,
      secondary_max: 15,
    })
    .select("id")
    .single();
  if (laufbandModellError) throw laufbandModellError;

  const { data: dauerlauf, error: dauerlaufError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Dauerlauf",
      volume_kind: "seconds",
      target_min: 900,
      target_max: 1200,
    })
    .select("id")
    .single();
  if (dauerlaufError) throw dauerlaufError;
  dauerlaufId = dauerlauf.id;

  const { error: laufbandLinkError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: laufbandModell.id, exercise_id: dauerlaufId, sort_order: 1 });
  if (laufbandLinkError) throw laufbandLinkError;

  const { data: laufbandGeraet, error: laufbandGeraetError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: laufbandModell.id, label: "L1" })
    .select("id")
    .single();
  if (laufbandGeraetError) throw laufbandGeraetError;
  laufband = laufbandGeraet.id;

  tokenA = createTagToken();
  await tagsAnlegen(admin, [
    { studioId: studioA, machineId: machineA, token: tokenA, status: "active" },
  ]);
});

describe("getMachineContext", () => {
  it("liefert Geraet, Modell, Einstellparameter und Uebungen", async () => {
    const client = await userClient(memberAEmail);

    const context = await getMachineContext(client, machineA);

    expect(context.machine.id).toBe(machineA);
    expect(context.machine.label).toBe("12");
    expect(context.equipmentModel.name).toBe("Kabelzug");
    expect(context.equipmentModel.loadStep).toBe(2.5);
    // Ein Kraftgeraet nach 0045: Kilogramm, keine Nebenbelastung.
    expect(context.equipmentModel.loadUnit).toBe("kg");
    expect(context.equipmentModel.secondaryUnit).toBeNull();
    expect(context.equipmentModel.secondaryStep).toBeNull();
    expect(context.settingDefinitions.map((s) => s.key)).toEqual(["sitz"]);
    expect(context.exercises.map((e) => e.name)).toEqual(["Latzug breit"]);
    expect(context.exercises[0]?.volumeKind).toBe("reps");
    expect(context.selectedExerciseId).toBe(breitId);
  });

  it("liefert am Laufband Einheit, Nebenbelastung und Umfangsart der Uebung", async () => {
    const client = await userClient(memberAEmail);

    const context = await getMachineContext(client, laufband);

    expect(context.equipmentModel).toMatchObject({
      loadUnit: "kmh",
      loadStep: 0.5,
      loadMin: 0,
      loadMax: 20,
      secondaryUnit: "pct",
      secondaryStep: 0.5,
      secondaryMin: 0,
      secondaryMax: 15,
    });
    expect(context.exercises[0]).toMatchObject({
      id: dauerlaufId,
      volumeKind: "seconds",
      targetMin: 900,
      targetMax: 1200,
    });
    // Erstkontakt: kein Vorschlag, aber die Eingaben tragen die Rastung.
    expect(context.suggestion.reasonCode).toBe("kein_verlauf");
    expect(context.suggestion.inputs.loadStep).toBe(0.5);
  });

  // Der eigentliche Punkt der Aufteilung: beide Wege muessen dasselbe
  // liefern, sonst waere der Listenweg zweiter Klasse.
  it("liefert dasselbe wie getTagContext fuer dasselbe Geraet", async () => {
    const client = await userClient(memberAEmail);

    const ueberTag = await getTagContext(client, tokenA);
    const ueberId = await getMachineContext(client, machineA);

    expect(ueberId.machine).toEqual(ueberTag.machine);
    expect(ueberId.equipmentModel).toEqual(ueberTag.equipmentModel);
    expect(ueberId.settingDefinitions).toEqual(ueberTag.settingDefinitions);
    expect(ueberId.exercises).toEqual(ueberTag.exercises);
    expect(ueberId.selectedExerciseId).toBe(ueberTag.selectedExerciseId);
  });

  // Ein Token ist ein oeffentlicher Locator, den jeder scannen kann, der
  // davorsteht. Eine machineId ist erratbar -- deshalb ist DIESER Test der
  // Sicherheitsbeweis des ganzen Sub-Projekts.
  it("cross-tenant: ein Geraet aus einem fremden Studio ist nicht lesbar", async () => {
    const client = await userClient(memberAEmail);

    await expect(getMachineContext(client, machineForeign)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("antwortet auf eine unbekannte machineId neutral mit not_found", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      getMachineContext(client, crypto.randomUUID()),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(getMachineContext(anonClient(), machineA)).rejects.toMatchObject({
      code: "unauthorized",
    });
  });

  it("haelt den Vorschlag in progression_suggestions fest", async () => {
    const client = await userClient(memberAEmail);
    const admin = serviceClient();

    await getMachineContext(client, machineA);

    const { data } = await admin
      .from("progression_suggestions")
      .select("machine_id, user_id")
      .eq("machine_id", machineA)
      .eq("user_id", memberAId);

    expect(data!.length).toBeGreaterThan(0);
  });
});
