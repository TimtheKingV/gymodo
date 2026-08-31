import { beforeAll, describe, expect, it } from "vitest";
import { DomainError, recordSet } from "@fitretro/domain";
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
let machineB: string;
let exerciseA: string;
let exerciseB: string;

function newId(): string {
  return crypto.randomUUID();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "recordSet Studio A" }, { name: "recordSet Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("record-member-a");
  memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(uniqueEmail("record-member-b"));

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

function payload(overrides: Record<string, unknown> = {}) {
  return {
    sessionId: newId(),
    setId: newId(),
    machineId: machineA,
    exerciseId: exerciseA,
    setIndex: 1,
    weightKg: 80,
    reps: 10,
    ...overrides,
  };
}

describe("recordSet", () => {
  it("legt den Satz an und liefert ihn kanonisch zurueck", async () => {
    const client = await userClient(memberAEmail);
    const input = payload();

    const saved = await recordSet(client, input);

    expect(saved.id).toBe(input.setId);
    expect(saved.weightKg).toBe(80);
    expect(saved.reps).toBe(10);
    expect(saved.setIndex).toBe(1);
  });

  it("legt die Session implizit an -- es gibt keinen Startknopf", async () => {
    const client = await userClient(memberAEmail);
    const input = payload();

    await recordSet(client, input);

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sessions")
      .select("id, user_id, studio_id")
      .eq("id", input.sessionId)
      .single();
    expect(data?.user_id).toBe(memberAId);
    expect(data?.studio_id).toBe(studioA);
  });

  it("leitet das Studio aus dem Geraet ab, statt es vom Client zu glauben", async () => {
    const client = await userClient(memberAEmail);
    const input = payload({ studioId: studioB });

    const saved = await recordSet(client, input);

    expect(saved.studioId).toBe(studioA);
  });

  it("Idempotenz: derselbe Satz zweimal geschickt bleibt eine Zeile", async () => {
    const client = await userClient(memberAEmail);
    const input = payload();

    const first = await recordSet(client, input);
    const second = await recordSet(client, input);

    expect(second).toEqual(first);
    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sets")
      .select("id")
      .eq("id", input.setId);
    expect(data).toHaveLength(1);
  });

  it("nimmt die Problemmeldung als Feld des Satzes entgegen", async () => {
    const client = await userClient(memberAEmail);

    const saved = await recordSet(
      client,
      payload({ problemFlag: true, problemReason: "schmerz" }),
    );

    expect(saved.problemFlag).toBe(true);
    expect(saved.problemReason).toBe("schmerz");
  });

  it("weist eine Wiederholungszahl von null als Eingabefehler zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(recordSet(client, payload({ reps: 0 }))).rejects.toMatchObject({
      code: "validation_failed",
    });
  });

  it("weist eine Problemursache ohne Kennzeichen zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      recordSet(client, payload({ problemReason: "schmerz" })),
    ).rejects.toBeInstanceOf(DomainError);
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(recordSet(anonClient(), payload())).rejects.toMatchObject({
      code: "unauthorized",
    });
  });

  it("weist ein Geraet aus einem fremden Studio zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      recordSet(client, payload({ machineId: machineB })),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist eine Uebung aus einem fremden Studio zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      recordSet(client, payload({ exerciseId: exerciseB })),
    ).rejects.toBeInstanceOf(DomainError);
  });
});
