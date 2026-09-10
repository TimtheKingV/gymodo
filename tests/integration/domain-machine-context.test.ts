import { beforeAll, describe, expect, it } from "vitest";
import {
  createTagToken,
  getMachineContext,
  getTagContext,
} from "@fitretro/domain";
import {
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
let breitId: string;
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
      weight_step_kg: 2.5,
      min_weight_kg: 5,
      max_weight_kg: 100,
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
      target_reps_min: 8,
      target_reps_max: 12,
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
    .insert({ studio_id: studioB, name: "Fremdgeraet", weight_step_kg: 5 })
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
    expect(context.equipmentModel.weightStepKg).toBe(2.5);
    expect(context.settingDefinitions.map((s) => s.key)).toEqual(["sitz"]);
    expect(context.exercises.map((e) => e.name)).toEqual(["Latzug breit"]);
    expect(context.selectedExerciseId).toBe(breitId);
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
