import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, getBootstrap, hashTagToken } from "@fitretro/domain";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

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
        weight_step_kg: 2.5,
        min_weight_kg: 5,
        max_weight_kg: 100,
      },
      // min_weight_kg hier ausdruecklich: bei einem Bulk-Insert vereinheitlicht
      // PostgREST die Spaltenmenge und schickt fuer fehlende Schluessel NULL
      // statt DEFAULT -- der Not-Null-Constraint schluege sonst zu.
      {
        studio_id: studioB,
        name: "Fremdgeraet",
        weight_step_kg: 5,
        min_weight_kg: 0,
        max_weight_kg: null,
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
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioA,
      machine_id: machineA,
      token_hash: hashTagToken(tokenA),
      status: "active",
    },
    {
      studio_id: studioB,
      machine_id: foreignMachine,
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    },
  ]);
  if (tagError) throw tagError;

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
      weight_kg: 42.5,
      reps: 12,
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
      weight_kg: 45,
      reps: 11,
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
    expect(machine?.equipmentModel.weightStepKg).toBe(2.5);
    expect(machine?.equipmentModel.maxWeightKg).toBe(100);
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
    expect(last?.weightKg).toBe(45);
    expect(last?.reps).toBe(11);
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
