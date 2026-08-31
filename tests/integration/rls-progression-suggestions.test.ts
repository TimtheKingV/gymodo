import { beforeAll, describe, expect, it } from "vitest";
import { PROGRESSION_ALGO_VERSION } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let trainerAEmail: string;
let memberAId: string;
let memberA2Id: string;
let memberBId: string;
let machineA: string;
let machineB: string;
let exerciseA: string;
let exerciseB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Vorschlag Studio A" }, { name: "Vorschlag Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("vor-member-a");
  trainerAEmail = uniqueEmail("vor-trainer-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(uniqueEmail("vor-member-a2"));
  memberBId = await createTestUser(uniqueEmail("vor-member-b"));
  const trainerAId = await createTestUser(trainerAEmail);

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

function suggestionForMemberA(overrides: Record<string, unknown> = {}) {
  return {
    studio_id: studioA,
    user_id: memberAId,
    machine_id: machineA,
    exercise_id: exerciseA,
    algo_version: PROGRESSION_ALGO_VERSION,
    inputs: { targetRepsMin: 8, targetRepsMax: 12, currentWeightKg: 80 },
    result_weight_kg: 82.5,
    reason_code: "korridor_oben_erreicht",
    ...overrides,
  };
}

describe("RLS auf progression_suggestions", () => {
  it("positiv: ein Vorschlag zur eigenen Kombination wird gespeichert", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("progression_suggestions")
      .insert(suggestionForMemberA());

    expect(error).toBeNull();
  });

  it("negativ: ein Vorschlag auf fremde user_id wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ user_id: memberA2Id }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: ein Geraet aus einem fremden Studio wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ machine_id: machineB }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: eine Uebung aus einem fremden Studio wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ exercise_id: exerciseB }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: ein fremder Vorschlag ist unsichtbar", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("progression_suggestions")
      .insert({
        studio_id: studioB,
        user_id: memberBId,
        machine_id: machineB,
        exercise_id: exerciseB,
        algo_version: PROGRESSION_ALGO_VERSION,
        inputs: {},
        result_weight_kg: 50,
        reason_code: "im_korridor",
      })
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("progression_suggestions")
      .select("id")
      .eq("id", seeded!.id);

    expect(data).toEqual([]);
  });

  it("negativ: der Vorschlag eines anderen Mitglieds ist unsichtbar", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ user_id: memberA2Id }))
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("progression_suggestions")
      .select("id")
      .eq("id", seeded!.id);

    expect(data).toEqual([]);
  });

  it("positiv: ein Trainer sieht die Vorschlaege seiner Studiomitglieder", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("progression_suggestions")
      .insert(suggestionForMemberA())
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data } = await client
      .from("progression_suggestions")
      .select("id")
      .eq("id", seeded!.id);

    expect(data).toHaveLength(1);
  });

  it("positiv: ohne Verlauf wird ein Vorschlag ohne Gewicht festgehalten", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client.from("progression_suggestions").insert(
      suggestionForMemberA({
        result_weight_kg: null,
        reason_code: "kein_verlauf",
      }),
    );

    expect(error).toBeNull();
  });

  it("Nachvollziehbarkeit: eine leere Algorithmusversion wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ algo_version: "  " }));

    expect(error).not.toBeNull();
  });

  it("Nachvollziehbarkeit: die Eingaben muessen ein JSON-Objekt sein", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ inputs: "80 kg" }));

    expect(error).not.toBeNull();
  });

  it("Historie: ein Vorschlag laesst sich nicht nachtraeglich aendern", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("progression_suggestions")
      .insert(suggestionForMemberA({ result_weight_kg: 82.5 }))
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    await client
      .from("progression_suggestions")
      .update({ result_weight_kg: 200 })
      .eq("id", seeded!.id);

    const { data } = await admin
      .from("progression_suggestions")
      .select("result_weight_kg")
      .eq("id", seeded!.id)
      .single();
    expect(Number(data?.result_weight_kg)).toBe(82.5);
  });

  it("Historie: ein Vorschlag laesst sich nicht loeschen", async () => {
    const admin = serviceClient();
    const { data: seeded, error: seedError } = await admin
      .from("progression_suggestions")
      .insert(suggestionForMemberA())
      .select("id")
      .single();
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    await client.from("progression_suggestions").delete().eq("id", seeded!.id);

    const { data } = await admin
      .from("progression_suggestions")
      .select("id")
      .eq("id", seeded!.id);
    expect(data).toHaveLength(1);
  });
});
