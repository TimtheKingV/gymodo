import { beforeAll, describe, expect, it } from "vitest";
import { getProgress } from "@fitretro/domain";
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
let memberA2Id: string;
let machineA: string;
let breitId: string;
let ungenutztId: string;

function newId(): string {
  return crypto.randomUUID();
}

function at(day: string, hour = 18): string {
  return new Date(`${day}T${String(hour).padStart(2, "0")}:00:00Z`).toISOString();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Fortschritt Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("prog-member-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(uniqueEmail("prog-member-a2"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinpresse", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: model.id, label: "07" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineA = machine.id;

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
        studio_id: studioA,
        name: "Nie trainiert",
        target_reps_min: 8,
        target_reps_max: 12,
      },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;
  breitId = exercises[0]!.id;
  ungenutztId = exercises[1]!.id;

  const sessionId = newId();
  const { error: sessionError } = await admin.from("workout_sessions").insert({
    id: sessionId,
    studio_id: studioA,
    user_id: memberAId,
    started_at: at("2026-08-13"),
    completed_at: at("2026-08-13", 19),
    completed_reason: "manual",
  });
  if (sessionError) throw sessionError;

  const foreignSessionId = newId();
  const { error: foreignSessionError } = await admin
    .from("workout_sessions")
    .insert({
      id: foreignSessionId,
      studio_id: studioA,
      user_id: memberA2Id,
      started_at: at("2026-08-13"),
    });
  if (foreignSessionError) throw foreignSessionError;

  const base = {
    studio_id: studioA,
    session_id: sessionId,
    user_id: memberAId,
    machine_id: machineA,
    exercise_id: breitId,
    reps: 10,
    rir: null,
    problem_flag: false,
    problem_reason: null,
  };
  const { error: setError } = await admin.from("workout_sets").insert([
    // 13. August: zwei Saetze, der schwerste ist 75,0
    { ...base, id: newId(), set_index: 1, weight_kg: 70, performed_at: at("2026-08-13", 18) },
    { ...base, id: newId(), set_index: 2, weight_kg: 75, performed_at: at("2026-08-13", 19) },
    // 20. August
    { ...base, id: newId(), set_index: 3, weight_kg: 77.5, performed_at: at("2026-08-20") },
    // 27. August
    { ...base, id: newId(), set_index: 4, weight_kg: 80, performed_at: at("2026-08-27") },
    // Fremdes Mitglied, gleiche Uebung -- darf nicht auftauchen
    {
      ...base,
      id: newId(),
      user_id: memberA2Id,
      session_id: foreignSessionId,
      set_index: 1,
      weight_kg: 200,
      performed_at: at("2026-08-27"),
    },
  ]);
  if (setError) throw setError;
});

describe("getProgress", () => {
  it("fasst je Uebung und Trainingstag zusammen, statt Rohsaetze zu liefern", async () => {
    const client = await userClient(memberAEmail);

    const { exercises } = await getProgress(client);
    const entry = exercises.find((item) => item.exerciseId === breitId);

    // Vier Saetze an drei Tagen ergeben drei Punkte.
    expect(entry?.points).toHaveLength(3);
    expect(entry?.points.map((point) => point.performedOn)).toEqual([
      "2026-08-13",
      "2026-08-20",
      "2026-08-27",
    ]);
  });

  it("nimmt je Tag den schwersten bestaetigten Satz", async () => {
    const client = await userClient(memberAEmail);

    const { exercises } = await getProgress(client);
    const entry = exercises.find((item) => item.exerciseId === breitId);

    expect(entry?.points[0]?.topWeightKg).toBe(75);
  });

  it("liefert den aktuellen Wert und die Veraenderung seit dem ersten Punkt", async () => {
    const client = await userClient(memberAEmail);

    const { exercises } = await getProgress(client);
    const entry = exercises.find((item) => item.exerciseId === breitId);

    expect(entry?.currentWeightKg).toBe(80);
    expect(entry?.firstWeightKg).toBe(75);
    expect(entry?.changeKg).toBe(5);
    expect(entry?.exerciseName).toBe("Beidbeinig");
  });

  it("laesst eine nie trainierte Uebung weg", async () => {
    const client = await userClient(memberAEmail);

    const { exercises } = await getProgress(client);

    expect(exercises.map((item) => item.exerciseId)).not.toContain(
      ungenutztId,
    );
  });

  it("mischt die Daten anderer Mitglieder nicht hinein", async () => {
    const client = await userClient(memberAEmail);

    const { exercises } = await getProgress(client);
    const entry = exercises.find((item) => item.exerciseId === breitId);

    expect(entry?.currentWeightKg).toBe(80);
  });

  it("grenzt den Zeitraum auf Wunsch ein", async () => {
    const client = await userClient(memberAEmail);

    const { exercises } = await getProgress(client, {
      since: "2026-08-19",
    });
    const entry = exercises.find((item) => item.exerciseId === breitId);

    expect(entry?.points.map((point) => point.performedOn)).toEqual([
      "2026-08-20",
      "2026-08-27",
    ]);
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(getProgress(anonClient())).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});
