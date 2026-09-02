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
let machineA: string;
let machineB: string;
let exerciseA: string;
let exerciseB: string;
let sessionA: string;
let sessionA2: string;
let sessionB: string;

function newId(): string {
  return crypto.randomUUID();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Sets Studio A" }, { name: "Sets Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("sets-member-a");
  memberA2Email = uniqueEmail("sets-member-a2");
  trainerAEmail = uniqueEmail("sets-trainer-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(memberA2Email);
  memberBId = await createTestUser(uniqueEmail("sets-member-b"));
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

  sessionA = newId();
  sessionA2 = newId();
  sessionB = newId();
  const { error: sessionError } = await admin.from("workout_sessions").insert([
    { id: sessionA, studio_id: studioA, user_id: memberAId },
    { id: sessionA2, studio_id: studioA, user_id: memberA2Id },
    { id: sessionB, studio_id: studioB, user_id: memberBId },
  ]);
  if (sessionError) throw sessionError;
});

/** Ein vollstaendiger Satz von Mitglied A in seiner eigenen Session. */
function setOfMemberA(overrides: Record<string, unknown> = {}) {
  return {
    id: newId(),
    studio_id: studioA,
    user_id: memberAId,
    session_id: sessionA,
    machine_id: machineA,
    exercise_id: exerciseA,
    set_index: 1,
    weight_kg: 80,
    reps: 10,
    ...overrides,
  };
}

describe("RLS auf workout_sets", () => {
  it("positiv: ein Mitglied loggt einen Satz in seiner eigenen Session", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ set_index: 1 }));

    expect(error).toBeNull();
  });

  it("negativ: ein Satz auf fremde user_id wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ user_id: memberA2Id, set_index: 2 }));

    expect(error).not.toBeNull();
  });

  it("negativ: ein Satz in die Session eines anderen Mitglieds wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ session_id: sessionA2, set_index: 3 }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: ein Geraet aus einem fremden Studio wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ machine_id: machineB, set_index: 4 }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: eine Uebung aus einem fremden Studio wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ exercise_id: exerciseB, set_index: 5 }));

    expect(error).not.toBeNull();
  });

  it("cross-tenant: Saetze aus einem fremden Studio sind unsichtbar", async () => {
    const admin = serviceClient();
    const foreignId = newId();
    const { error: seedError } = await admin.from("workout_sets").insert({
      id: foreignId,
      studio_id: studioB,
      user_id: memberBId,
      session_id: sessionB,
      machine_id: machineB,
      exercise_id: exerciseB,
      set_index: 1,
      weight_kg: 50,
      reps: 10,
    });
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("workout_sets")
      .select("id")
      .eq("id", foreignId);

    expect(data).toEqual([]);
  });

  it("negativ: ein Mitglied sieht die Saetze eines anderen Mitglieds nicht", async () => {
    const admin = serviceClient();
    const otherId = newId();
    const { error: seedError } = await admin.from("workout_sets").insert({
      id: otherId,
      studio_id: studioA,
      user_id: memberA2Id,
      session_id: sessionA2,
      machine_id: machineA,
      exercise_id: exerciseA,
      set_index: 1,
      weight_kg: 60,
      reps: 10,
    });
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("workout_sets")
      .select("id")
      .eq("id", otherId);

    expect(data).toEqual([]);
  });

  it("Datenschutzgrenze: ein Trainer sieht die Saetze seiner Studiomitglieder nicht", async () => {
    const admin = serviceClient();
    const setId = newId();
    const { error: seedError } = await admin.from("workout_sets").insert({
      id: setId,
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionA,
      machine_id: machineA,
      exercise_id: exerciseA,
      set_index: 90,
      weight_kg: 80,
      reps: 10,
    });
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data, error } = await client
      .from("workout_sets")
      .select("id")
      .eq("id", setId);

    // Gewicht und Wiederholungen sind das Kernstueck dessen, was Spec
    // Abschnitt 4 hinter die Grenze stellt.
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("Idempotenz: derselbe Satz zweimal geschickt ergibt genau eine Zeile", async () => {
    const client = await userClient(memberAEmail);
    const payload = setOfMemberA({ set_index: 20, reps: 10 });

    const first = await client.from("workout_sets").upsert(payload);
    expect(first.error).toBeNull();
    const second = await client.from("workout_sets").upsert(payload);
    expect(second.error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sets")
      .select("id")
      .eq("id", payload.id);
    expect(data).toHaveLength(1);
  });

  it("Blockstruktur: dieselbe Satznummer im selben Block wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);
    const { error: firstError } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ set_index: 30 }));
    if (firstError) throw firstError;

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ set_index: 30 }));

    expect(error).not.toBeNull();
  });

  it("Blockstruktur: dieselbe Satznummer an einer anderen Uebung ist erlaubt", async () => {
    const admin = serviceClient();
    const { data: extra, error: exerciseError } = await admin
      .from("exercises")
      .insert({
        studio_id: studioA,
        name: "Einbeinig",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (exerciseError) throw exerciseError;

    const client = await userClient(memberAEmail);
    const { error: firstError } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ set_index: 40 }));
    if (firstError) throw firstError;

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ set_index: 40, exercise_id: extra!.id }));

    expect(error).toBeNull();
  });

  it("Historie: auch der eigene Satz laesst sich nicht loeschen", async () => {
    const client = await userClient(memberAEmail);
    const payload = setOfMemberA({ set_index: 50 });
    const { error: insertError } = await client
      .from("workout_sets")
      .insert(payload);
    if (insertError) throw insertError;

    await client.from("workout_sets").delete().eq("id", payload.id);

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sets")
      .select("id")
      .eq("id", payload.id);
    expect(data).toHaveLength(1);
  });

  it("eine Problemursache ohne gesetztes Problemkennzeichen wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sets")
      .insert(setOfMemberA({ set_index: 60, problem_reason: "schmerz" }));

    expect(error).not.toBeNull();
  });

  it("die id kommt vom Client -- ohne id schlaegt der Insert fehl", async () => {
    const client = await userClient(memberAEmail);
    const { id: _ignored, ...withoutId } = setOfMemberA({ set_index: 70 });

    const { error } = await client.from("workout_sets").insert(withoutId);

    expect(error).not.toBeNull();
  });
});
