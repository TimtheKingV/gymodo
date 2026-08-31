import { beforeAll, describe, expect, it } from "vitest";
import { completeSession } from "@fitretro/domain";
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

function newId(): string {
  return crypto.randomUUID();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Abschluss Studio A" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("abschluss-member-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(uniqueEmail("abschluss-member-a2"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
    ]);
  if (membershipError) throw membershipError;
});

async function seedSession(userId: string): Promise<string> {
  const id = newId();
  const { error } = await serviceClient()
    .from("workout_sessions")
    .insert({ id, studio_id: studioA, user_id: userId });
  if (error) throw error;
  return id;
}

describe("completeSession", () => {
  it("beendet die eigene Session und haelt den Grund fest", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedSession(memberAId);

    const completed = await completeSession(client, { sessionId });

    expect(completed.completedAt).not.toBeNull();
    expect(completed.completedReason).toBe("manual");
  });

  it("Idempotenz: ein zweiter Abschluss verschiebt den Zeitpunkt nicht", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedSession(memberAId);

    const first = await completeSession(client, { sessionId });
    const second = await completeSession(client, { sessionId });

    expect(second.completedAt).toBe(first.completedAt);
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    const sessionId = await seedSession(memberAId);

    await expect(
      completeSession(anonClient(), { sessionId }),
    ).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("weist die Session eines anderen Mitglieds zurueck", async () => {
    const client = await userClient(memberAEmail);
    const foreignId = await seedSession(memberA2Id);

    await expect(
      completeSession(client, { sessionId: foreignId }),
    ).rejects.toMatchObject({ code: "not_found" });

    const { data } = await serviceClient()
      .from("workout_sessions")
      .select("completed_at")
      .eq("id", foreignId)
      .single();
    expect(data?.completed_at).toBeNull();
  });

  it("weist eine unbekannte Session zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      completeSession(client, { sessionId: newId() }),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist eine unbrauchbare Kennung als Eingabefehler zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      completeSession(client, { sessionId: "keine-uuid" }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });
});
