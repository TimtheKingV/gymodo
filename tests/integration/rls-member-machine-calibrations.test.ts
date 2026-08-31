import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberA2Email: string;
let trainerAEmail: string;
let memberAId: string;
let memberA2Id: string;
let memberBId: string;
let trainerAId: string;
let machineA: string;
let machineB: string;
let exerciseA: string;
let exerciseB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Kalibrierung Studio A" }, { name: "Kalibrierung Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("kal-member-a");
  memberA2Email = uniqueEmail("kal-member-a2");
  trainerAEmail = uniqueEmail("kal-trainer-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(memberA2Email);
  memberBId = await createTestUser(uniqueEmail("kal-member-b"));
  trainerAId = await createTestUser(trainerAEmail);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
      { studio_id: studioB, user_id: memberBId, role: "member" },
      { studio_id: studioA, user_id: trainerAId, role: "trainer" },
    ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Beinpresse", weight_step_kg: 2.5 },
      { studio_id: studioB, name: "Fremdpresse", weight_step_kg: 2.5 },
    ])
    .select("id");
  if (modelError) throw modelError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "07" },
      { studio_id: studioB, equipment_model_id: models[1]!.id, label: "99" },
    ])
    .select("id");
  if (machineError) throw machineError;
  machineA = machines[0]!.id;
  machineB = machines[1]!.id;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Beidbeinig",
        target_reps_min: 8,
        target_reps_max: 12,
      },
      {
        studio_id: studioB,
        name: "Fremduebung",
        target_reps_min: 8,
        target_reps_max: 12,
      },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;
  exerciseA = exercises[0]!.id;
  exerciseB = exercises[1]!.id;
});

function calibrationOfMemberA(overrides: Record<string, unknown> = {}) {
  return {
    studio_id: studioA,
    user_id: memberAId,
    machine_id: machineA,
    exercise_id: exerciseA,
    setting_values: { sitz: 4, lehne: 2, startwinkel: 30 },
    schema_version: 1,
    ...overrides,
  };
}

describe("RLS auf member_machine_calibrations", () => {
  it("positiv: ein Mitglied erfasst seine eigenen Einstellwerte", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA());

    expect(error).toBeNull();
  });

  it("negativ: Einstellwerte auf fremde user_id werden abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ user_id: memberA2Id }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: ein Geraet aus einem fremden Studio wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ machine_id: machineB }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: eine Uebung aus einem fremden Studio wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ exercise_id: exerciseB }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: fremde Einstellwerte sind unsichtbar", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("member_machine_calibrations")
      .insert({
        studio_id: studioB,
        user_id: memberBId,
        machine_id: machineB,
        exercise_id: exerciseB,
        setting_values: { sitz: 1 },
        schema_version: 1,
      })
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("member_machine_calibrations")
      .select("id")
      .eq("id", seeded!.id);

    expect(data).toEqual([]);
  });

  it("negativ: die Einstellwerte eines anderen Mitglieds sind unsichtbar", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ user_id: memberA2Id }))
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("member_machine_calibrations")
      .select("id")
      .eq("id", seeded!.id);

    expect(data).toEqual([]);
  });

  it("positiv: ein Trainer sieht die Einstellwerte seiner Studiomitglieder", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA())
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data } = await client
      .from("member_machine_calibrations")
      .select("id")
      .eq("id", seeded!.id);

    expect(data).toHaveLength(1);
  });

  it("positiv: eine Aenderung legt eine neue Zeile an, statt die alte zu ersetzen", async () => {
    const client = await userClient(memberAEmail);
    const { error: firstError } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ setting_values: { sitz: 3 } }));
    if (firstError) throw firstError;

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ setting_values: { sitz: 5 } }));

    expect(error).toBeNull();
  });

  it("Historie: die eigenen Einstellwerte lassen sich nicht ueberschreiben", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ setting_values: { sitz: 4 } }))
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    await client
      .from("member_machine_calibrations")
      .update({ setting_values: { sitz: 9 } })
      .eq("id", seeded!.id);

    const { data } = await admin
      .from("member_machine_calibrations")
      .select("setting_values")
      .eq("id", seeded!.id)
      .single();
    expect(data?.setting_values).toEqual({ sitz: 4 });
  });

  it("Historie: die eigenen Einstellwerte lassen sich nicht loeschen", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA())
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    await client
      .from("member_machine_calibrations")
      .delete()
      .eq("id", seeded!.id);

    const { data } = await admin
      .from("member_machine_calibrations")
      .select("id")
      .eq("id", seeded!.id);
    expect(data).toHaveLength(1);
  });

  it("Einstellwerte muessen ein JSON-Objekt sein", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(calibrationOfMemberA({ setting_values: [1, 2, 3] }));

    expect(error).not.toBeNull();
  });

  it("positiv: eine trainerbegleitete Erfassung haelt fest, wer dabei war", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("member_machine_calibrations")
      .insert(
        calibrationOfMemberA({
          source: "trainer_assisted",
          recorded_by: trainerAId,
        }),
      );

    expect(error).toBeNull();
  });
});
