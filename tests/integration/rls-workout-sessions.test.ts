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
let memberBEmail: string;
let trainerAEmail: string;
let memberAId: string;
let memberA2Id: string;
let memberBId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Sessions Studio A" }, { name: "Sessions Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("sessions-member-a");
  memberA2Email = uniqueEmail("sessions-member-a2");
  memberBEmail = uniqueEmail("sessions-member-b");
  trainerAEmail = uniqueEmail("sessions-trainer-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(memberA2Email);
  memberBId = await createTestUser(memberBEmail);
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
});

/** Sessions tragen eine clientseitig erzeugte UUID (Spec Abschnitt 6.3). */
function newId(): string {
  return crypto.randomUUID();
}

describe("RLS auf workout_sessions", () => {
  it("positiv: ein Mitglied legt seine eigene Session an", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client.from("workout_sessions").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
    });

    expect(error).toBeNull();
  });

  it("negativ: ein Mitglied kann keine Session fuer ein anderes anlegen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client.from("workout_sessions").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberA2Id,
    });

    expect(error).not.toBeNull();
  });

  it("cross-tenant: ein Mitglied kann keine Session in einem fremden Studio anlegen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client.from("workout_sessions").insert({
      id: newId(),
      studio_id: studioB,
      user_id: memberAId,
    });

    expect(error).not.toBeNull();
  });

  it("cross-tenant: eine Session aus einem fremden Studio ist unsichtbar", async () => {
    const admin = serviceClient();
    const foreignId = newId();
    const { error: seedError } = await admin.from("workout_sessions").insert({
      id: foreignId,
      studio_id: studioB,
      user_id: memberBId,
    });
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("workout_sessions")
      .select("id")
      .eq("id", foreignId);

    expect(data).toEqual([]);
  });

  it("negativ: ein Mitglied sieht die Session eines anderen Mitglieds nicht", async () => {
    const admin = serviceClient();
    const otherId = newId();
    const { error: seedError } = await admin.from("workout_sessions").insert({
      id: otherId,
      studio_id: studioA,
      user_id: memberA2Id,
    });
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    const { data } = await client
      .from("workout_sessions")
      .select("id")
      .eq("id", otherId);

    expect(data).toEqual([]);
  });

  it("positiv: ein Trainer sieht die Sessions seiner Studiomitglieder", async () => {
    const admin = serviceClient();
    const sessionId = newId();
    const { error: seedError } = await admin.from("workout_sessions").insert({
      id: sessionId,
      studio_id: studioA,
      user_id: memberAId,
    });
    if (seedError) throw seedError;

    const client = await userClient(trainerAEmail);
    const { data } = await client
      .from("workout_sessions")
      .select("id")
      .eq("id", sessionId);

    expect(data).toHaveLength(1);
  });

  it("positiv: ein Mitglied beendet seine eigene Session", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = newId();
    const { error: insertError } = await client
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (insertError) throw insertError;

    const { error } = await client
      .from("workout_sessions")
      .update({
        completed_at: new Date().toISOString(),
        completed_reason: "manual",
      })
      .eq("id", sessionId);

    expect(error).toBeNull();
  });

  it("negativ: eine fremde Session laesst sich nicht beenden", async () => {
    const admin = serviceClient();
    const otherId = newId();
    const { error: seedError } = await admin.from("workout_sessions").insert({
      id: otherId,
      studio_id: studioA,
      user_id: memberA2Id,
    });
    if (seedError) throw seedError;

    const client = await userClient(memberAEmail);
    await client
      .from("workout_sessions")
      .update({
        completed_at: new Date().toISOString(),
        completed_reason: "manual",
      })
      .eq("id", otherId);

    const { data } = await admin
      .from("workout_sessions")
      .select("completed_at")
      .eq("id", otherId)
      .single();
    expect(data?.completed_at).toBeNull();
  });

  it("Historie: auch die eigene Session laesst sich nicht loeschen", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = newId();
    const { error: insertError } = await client
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (insertError) throw insertError;

    await client.from("workout_sessions").delete().eq("id", sessionId);

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sessions")
      .select("id")
      .eq("id", sessionId);
    expect(data).toHaveLength(1);
  });

  it("die id kommt vom Client -- ohne id schlaegt der Insert fehl", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client
      .from("workout_sessions")
      .insert({ studio_id: studioA, user_id: memberAId });

    expect(error).not.toBeNull();
  });

  it("ein Abschlusszeitpunkt ohne Grund wird abgewiesen", async () => {
    const client = await userClient(memberAEmail);

    const { error } = await client.from("workout_sessions").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      completed_at: new Date().toISOString(),
    });

    expect(error).not.toBeNull();
  });
});
