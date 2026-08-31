import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, getTagContext, hashTagToken } from "@fitretro/domain";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberAId: string;
let machineA: string;
let breitId: string;
let engId: string;
let tokenA: string;
let tokenRevoked: string;
let tokenForeign: string;

function newId(): string {
  return crypto.randomUUID();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Kontext Studio A" }, { name: "Kontext Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("kontext-member-a");
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
      photo_path: "studio-a/kabelzug.jpg",
    })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { error: settingError } = await admin
    .from("equipment_setting_definitions")
    .insert([
      {
        equipment_model_id: model.id,
        key: "sitz",
        label: "Sitzposition",
        kind: "number",
        min_value: 1,
        max_value: 8,
        step_value: 1,
        sort_order: 1,
      },
    ]);
  if (settingError) throw settingError;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Latzug breit",
        target_reps_min: 8,
        target_reps_max: 12,
      },
      {
        studio_id: studioA,
        name: "Latzug eng",
        target_reps_min: 8,
        target_reps_max: 12,
      },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;
  breitId = exercises[0]!.id;
  engId = exercises[1]!.id;

  const { error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: model.id, exercise_id: breitId, sort_order: 1 },
      { equipment_model_id: model.id, exercise_id: engId, sort_order: 2 },
    ]);
  if (linkError) throw linkError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: model.id, label: "12" },
    ])
    .select("id");
  if (machineError) throw machineError;
  machineA = machines[0]!.id;

  const { data: foreignModel, error: foreignModelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioB, name: "Fremdgeraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (foreignModelError) throw foreignModelError;
  const { data: foreignMachine, error: foreignMachineError } = await admin
    .from("machines")
    .insert({
      studio_id: studioB,
      equipment_model_id: foreignModel.id,
      label: "99",
    })
    .select("id")
    .single();
  if (foreignMachineError) throw foreignMachineError;

  tokenA = createTagToken();
  tokenRevoked = createTagToken();
  tokenForeign = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioA,
      machine_id: machineA,
      token_hash: hashTagToken(tokenA),
      status: "active",
    },
    {
      studio_id: studioA,
      token_hash: hashTagToken(tokenRevoked),
      status: "revoked",
    },
    {
      studio_id: studioB,
      machine_id: foreignMachine.id,
      token_hash: hashTagToken(tokenForeign),
      status: "active",
    },
  ]);
  if (tagError) throw tagError;
});

describe("getTagContext", () => {
  it("loest den Tag auf und liefert Geraet, Modell und Einstellparameter", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.machine.id).toBe(machineA);
    expect(context.machine.label).toBe("12");
    expect(context.equipmentModel.name).toBe("Kabelzug");
    expect(context.equipmentModel.weightStepKg).toBe(2.5);
    expect(context.settingDefinitions).toHaveLength(1);
    expect(context.settingDefinitions[0]!.key).toBe("sitz");
  });

  it("liefert die Uebungen in der vom Studio gepflegten Reihenfolge", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.exercises.map((exercise) => exercise.id)).toEqual([
      breitId,
      engId,
    ]);
  });

  it("waehlt beim Erstkontakt die erste Uebung vor und schlaegt nichts vor", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.selectedExerciseId).toBe(breitId);
    expect(context.suggestion.resultWeightKg).toBeNull();
    expect(context.suggestion.reasonCode).toBe("kein_verlauf");
  });

  it("waehlt die zuletzt genutzte Uebung vor", async () => {
    const admin = serviceClient();
    const sessionId = newId();
    const { error: sessionError } = await admin
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (sessionError) throw sessionError;
    const { error: setError } = await admin.from("workout_sets").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionId,
      machine_id: machineA,
      exercise_id: engId,
      set_index: 1,
      weight_kg: 45,
      reps: 12,
      performed_at: new Date("2026-08-27T18:00:00Z").toISOString(),
    });
    if (setError) throw setError;

    const client = await userClient(memberAEmail);
    const context = await getTagContext(client, tokenA);

    expect(context.selectedExerciseId).toBe(engId);
  });

  it("berechnet den Vorschlag aus der eigenen Historie und haelt ihn fest", async () => {
    const admin = serviceClient();
    const sessionId = newId();
    const { error: sessionError } = await admin
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (sessionError) throw sessionError;
    // Korridor 8-12 mit Reserve ausgeschoepft -- die Regel steigert.
    const { error: setError } = await admin.from("workout_sets").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionId,
      machine_id: machineA,
      exercise_id: engId,
      set_index: 2,
      weight_kg: 45,
      reps: 12,
      rir: 2,
      performed_at: new Date("2026-08-28T18:00:00Z").toISOString(),
    });
    if (setError) throw setError;

    const client = await userClient(memberAEmail);
    const context = await getTagContext(client, tokenA);

    expect(context.suggestion.reasonCode).toBe("korridor_oben_erreicht");
    expect(context.suggestion.resultWeightKg).toBe(47.5);

    const { data } = await admin
      .from("progression_suggestions")
      .select("reason_code, result_weight_kg")
      .eq("user_id", memberAId)
      .eq("machine_id", machineA)
      .eq("exercise_id", engId)
      .order("created_at", { ascending: false })
      .limit(1);
    expect(data?.[0]?.reason_code).toBe("korridor_oben_erreicht");
  });

  it("liefert die eigenen Einstellwerte mit", async () => {
    const admin = serviceClient();
    const { error } = await admin
      .from("member_machine_calibrations")
      .insert({
        studio_id: studioA,
        user_id: memberAId,
        machine_id: machineA,
        exercise_id: engId,
        setting_values: { sitz: 6 },
        schema_version: 1,
      });
    if (error) throw error;

    const client = await userClient(memberAEmail);
    const context = await getTagContext(client, tokenA);

    expect(context.calibration?.settingValues).toEqual({ sitz: 6 });
  });

  it("weist einen gesperrten Tag zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(getTagContext(client, tokenRevoked)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("weist einen unbekannten Tag zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      getTagContext(client, createTagToken()),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("cross-tenant: der Tag eines fremden Studios ist nicht aufloesbar", async () => {
    const client = await userClient(memberAEmail);

    await expect(getTagContext(client, tokenForeign)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("weist ein unbrauchbares Tokenformat als Eingabefehler zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(getTagContext(client, "viel-zu-kurz")).rejects.toMatchObject({
      code: "validation_failed",
    });
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(getTagContext(anonClient(), tokenA)).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});
