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
let staffAEmail: string;
let memberBEmail: string;
let modelA: string;
let exerciseB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Exercise Studio A" }, { name: "Exercise Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("ex-member-a");
  staffAEmail = uniqueEmail("ex-staff-a");
  memberBEmail = uniqueEmail("ex-member-b");

  const memberAId = await createTestUser(memberAEmail);
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
  ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Kabelzug", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;
  modelA = model.id;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioB,
      name: "Fremde Uebung",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseB = exercise.id;
});

describe("RLS auf exercises", () => {
  it("positiv: Staff kann eine Uebung anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioA,
      name: "Breiter Griff",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Uebung anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioA,
      name: "Verboten",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).not.toBeNull();
  });

  it("positiv: Mitglied sieht Uebungen seines Studios", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client
      .from("exercises")
      .select("id")
      .eq("studio_id", studioA);
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht Uebungen von Studio A nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("exercises")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });
});

describe("RLS auf equipment_model_exercises", () => {
  it("negativ: Studio-uebergreifende Verknuepfung wird abgelehnt, auch fuer Staff", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: exerciseB,
    });
    expect(error).not.toBeNull();
  });

  it("positiv: Staff kann Geraet und Uebung im selben Studio verknuepfen", async () => {
    const admin = serviceClient();
    const { data: ownExercise, error: exerciseError } = await admin
      .from("exercises")
      .insert({
        studio_id: studioA,
        name: "Eigene Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (exerciseError) throw exerciseError;

    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: ownExercise.id,
    });
    expect(error).toBeNull();
  });
});
