import { beforeAll, describe, expect, it } from "vitest";
import { completeSession, getSessions, reopenSession } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Testnotiz 14.10., 18:45 #3/#4: ein von Hand beendetes Training laesst
// sich 30 Minuten lang wieder oeffnen.
let studioA: string;
let memberAEmail: string;
let memberAId: string;
let memberA2Id: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Fortsetzen Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("fortsetzen-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(uniqueEmail("fortsetzen-a2"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
    ]);
  if (membershipError) throw membershipError;
});

async function seedBeendet(
  userId: string,
  minutenHer: number,
  grund: "manual" | "auto" = "manual",
): Promise<string> {
  const id = crypto.randomUUID();
  const ende = new Date(Date.now() - minutenHer * 60_000).toISOString();
  const { error } = await serviceClient().from("workout_sessions").insert({
    id,
    studio_id: studioA,
    user_id: userId,
    started_at: new Date(Date.now() - (minutenHer + 60) * 60_000).toISOString(),
    completed_at: ende,
    completed_reason: grund,
    paused_seconds: 120,
  });
  if (error) throw error;
  return id;
}

describe("reopenSession", () => {
  it("oeffnet eine vor 10 Minuten beendete Einheit, ein zweiter Aufruf ebenso", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 10);

    await reopenSession(client, { sessionId });
    await reopenSession(client, { sessionId });

    const { data } = await serviceClient()
      .from("workout_sessions")
      .select("completed_at, completed_reason, paused_seconds")
      .eq("id", sessionId)
      .single();
    expect(data).toEqual({ completed_at: null, completed_reason: null, paused_seconds: 120 });
  });

  it("lehnt nach 31 Minuten ab", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 31);
    await expect(reopenSession(client, { sessionId })).rejects.toMatchObject({
      code: "conflict",
      message: "Zu spät zum Fortsetzen.",
    });
  });

  it("lehnt eine selbsttaetig beendete Einheit ab", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 5, "auto");
    await expect(reopenSession(client, { sessionId })).rejects.toMatchObject({ code: "conflict" });
  });

  it("findet die Einheit eines anderen Mitglieds nicht", async () => {
    const client = await userClient(memberAEmail);
    const fremd = await seedBeendet(memberA2Id, 5);
    await expect(reopenSession(client, { sessionId: fremd })).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("zweiter Abschluss setzt neues Ende und neue Pausensumme", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = await seedBeendet(memberAId, 10);

    await reopenSession(client, { sessionId });
    const zweiter = await completeSession(client, { sessionId, pausedSeconds: 1320 });

    expect(Date.now() - Date.parse(zweiter.completedAt)).toBeLessThan(60_000);
    const { sessions } = await getSessions(client);
    expect(sessions.find((s) => s.id === sessionId)?.pausedSeconds).toBe(1320);
  });
});
