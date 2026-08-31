import { beforeAll, describe, expect, it } from "vitest";
import { getSessions } from "@fitretro/domain";
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
let machineB: string;
let breitId: string;
let engId: string;

/** Feste Zeitpunkte, damit die Vier-Stunden-Regel pruefbar bleibt. */
const HOUR = 60 * 60 * 1000;

function newId(): string {
  return crypto.randomUUID();
}

function isoAgo(hours: number): string {
  return new Date(Date.now() - hours * HOUR).toISOString();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Sessions-Lesen Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("read-member-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(uniqueEmail("read-member-a2"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Kabelzug", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: model.id, label: "12" },
      { studio_id: studioA, equipment_model_id: model.id, label: "13" },
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
});

async function seedSession(options: {
  userId: string;
  startedAt: string;
  completedAt?: string;
  completedReason?: "manual" | "auto";
}): Promise<string> {
  const id = newId();
  const { error } = await serviceClient().from("workout_sessions").insert({
    id,
    studio_id: studioA,
    user_id: options.userId,
    started_at: options.startedAt,
    completed_at: options.completedAt ?? null,
    completed_reason: options.completedReason ?? null,
  });
  if (error) throw error;
  return id;
}

async function seedSet(options: {
  sessionId: string;
  userId: string;
  machineId: string;
  exerciseId: string;
  setIndex: number;
  performedAt: string;
  weightKg?: number;
}): Promise<void> {
  const { error } = await serviceClient().from("workout_sets").insert({
    id: newId(),
    studio_id: studioA,
    user_id: options.userId,
    session_id: options.sessionId,
    machine_id: options.machineId,
    exercise_id: options.exerciseId,
    set_index: options.setIndex,
    weight_kg: options.weightKg ?? 45,
    reps: 10,
    performed_at: options.performedAt,
  });
  if (error) throw error;
}

describe("getSessions", () => {
  it("liefert nur die eigenen Einheiten", async () => {
    const own = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(30),
      completedAt: isoAgo(29),
      completedReason: "manual",
    });
    const foreign = await seedSession({
      userId: memberA2Id,
      startedAt: isoAgo(30),
      completedAt: isoAgo(29),
      completedReason: "manual",
    });

    const client = await userClient(memberAEmail);
    const { sessions } = await getSessions(client);

    const ids = sessions.map((session) => session.id);
    expect(ids).toContain(own);
    expect(ids).not.toContain(foreign);
  });

  it("leitet Bloecke aus den Saetzen ab, gruppiert nach Geraet und Uebung", async () => {
    const sessionId = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(28),
      completedAt: isoAgo(27),
      completedReason: "manual",
    });
    // Zirkel: Geraet A, Geraet B, dann wieder Geraet A -- das ergibt drei
    // Bloecke, nicht vier, weil der zweite Durchgang denselben Block trifft.
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 1,
      performedAt: isoAgo(28),
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineB,
      exerciseId: engId,
      setIndex: 1,
      performedAt: isoAgo(27.8),
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 2,
      performedAt: isoAgo(27.5),
    });

    const client = await userClient(memberAEmail);
    const { sessions } = await getSessions(client);
    const session = sessions.find((entry) => entry.id === sessionId);

    expect(session?.blocks).toHaveLength(2);
    expect(session?.blocks[0]?.machineId).toBe(machineA);
    expect(session?.blocks[0]?.sets).toHaveLength(2);
    expect(session?.blocks[1]?.machineId).toBe(machineB);
  });

  it("zaehlt Geraete und Saetze fuer die Uebersicht", async () => {
    const sessionId = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(26),
      completedAt: isoAgo(25),
      completedReason: "manual",
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 1,
      performedAt: isoAgo(26),
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineB,
      exerciseId: engId,
      setIndex: 1,
      performedAt: isoAgo(25.9),
    });

    const client = await userClient(memberAEmail);
    const { sessions } = await getSessions(client);
    const session = sessions.find((entry) => entry.id === sessionId);

    expect(session?.machineCount).toBe(2);
    expect(session?.setCount).toBe(2);
  });

  it("beendet eine Einheit ohne Satz seit ueber vier Stunden traege als auto", async () => {
    // Einmal festhalten: isoAgo() liefert bei jedem Aufruf einen neuen
    // Zeitpunkt, und der Abschluss soll auf die Millisekunde genau auf dem
    // letzten Satz liegen.
    const lastSetAt = isoAgo(9);
    const sessionId = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(10),
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 1,
      performedAt: lastSetAt,
    });

    const client = await userClient(memberAEmail);
    const { sessions } = await getSessions(client);
    const session = sessions.find((entry) => entry.id === sessionId);

    expect(session?.completedReason).toBe("auto");
    // Der Abschluss liegt beim letzten Satz, nicht bei jetzt -- sonst haette
    // die Einheit rueckwirkend Stunden gedauert, in denen niemand trainiert hat.
    expect(session?.completedAt).toBe(lastSetAt);
  });

  it("haelt den traegen Abschluss auch in der Datenbank fest", async () => {
    const sessionId = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(12),
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 1,
      performedAt: isoAgo(11),
    });

    const client = await userClient(memberAEmail);
    await getSessions(client);

    const { data } = await serviceClient()
      .from("workout_sessions")
      .select("completed_reason")
      .eq("id", sessionId)
      .single();
    expect(data?.completed_reason).toBe("auto");
  });

  it("laesst eine Einheit mit frischem Satz offen", async () => {
    const sessionId = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(1),
    });
    await seedSet({
      sessionId,
      userId: memberAId,
      machineId: machineA,
      exerciseId: breitId,
      setIndex: 1,
      performedAt: isoAgo(0.2),
    });

    const client = await userClient(memberAEmail);
    const { sessions } = await getSessions(client);
    const session = sessions.find((entry) => entry.id === sessionId);

    expect(session?.completedAt).toBeNull();
    expect(session?.completedReason).toBeNull();
  });

  it("ruehrt eine ausdruecklich beendete Einheit nicht an", async () => {
    const completedAt = isoAgo(20);
    const sessionId = await seedSession({
      userId: memberAId,
      startedAt: isoAgo(21),
      completedAt,
      completedReason: "manual",
    });

    const client = await userClient(memberAEmail);
    const { sessions } = await getSessions(client);
    const session = sessions.find((entry) => entry.id === sessionId);

    expect(session?.completedReason).toBe("manual");
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(getSessions(anonClient())).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});
