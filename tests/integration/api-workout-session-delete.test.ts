import { beforeAll, describe, expect, it } from "vitest";
import { PUT } from "@/app/api/v1/workout-sessions/[sessionId]/sets/[setId]/route";
import { DELETE } from "@/app/api/v1/workout-sessions/[sessionId]/route";
import { accessTokenFor, createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

let studioA: string;
let memberAEmail: string;
let memberA2Email: string;
let machineA: string;
let exerciseA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "API Loeschen Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  memberAEmail = uniqueEmail("api-loeschen-a");
  memberA2Email = uniqueEmail("api-loeschen-a2");
  const memberAId = await createTestUser(memberAEmail);
  const memberA2Id = await createTestUser(memberA2Email);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinpresse", load_step: 2.5 })
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

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({ studio_id: studioA, name: "Beidbeinig", target_min: 8, target_max: 12 })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseA = exercise.id;
});

function deleteRequest(sessionId: string, bearer?: string): Request {
  return new Request(`http://localhost/api/v1/workout-sessions/${sessionId}`, {
    method: "DELETE",
    headers: bearer ? { authorization: `Bearer ${bearer}` } : {},
  });
}

function deleteContext(sessionId: string): { params: Promise<{ sessionId: string }> } {
  return { params: Promise.resolve({ sessionId }) };
}

async function einheitMitSatz(bearer: string): Promise<{ sessionId: string; setId: string }> {
  const sessionId = crypto.randomUUID();
  const setId = crypto.randomUUID();
  const response = await PUT(
    new Request(`http://localhost/api/v1/workout-sessions/${sessionId}/sets/${setId}`, {
      method: "PUT",
      headers: { "content-type": "application/json", authorization: `Bearer ${bearer}` },
      body: JSON.stringify({ machineId: machineA, exerciseId: exerciseA, setIndex: 1, load: 80, volume: 10 }),
    }),
    { params: Promise.resolve({ sessionId, setId }) },
  );
  expect(response.status).toBe(200);
  return { sessionId, setId };
}

describe("DELETE /workout-sessions/{id}", () => {
  it("loescht die eigene Einheit samt Saetzen und antwortet 204", async () => {
    const bearer = await accessTokenFor(memberAEmail);
    const { sessionId, setId } = await einheitMitSatz(bearer);

    const response = await DELETE(deleteRequest(sessionId, bearer), deleteContext(sessionId));

    expect(response.status).toBe(204);
    const admin = serviceClient();
    expect((await admin.from("workout_sessions").select("id").eq("id", sessionId)).data).toHaveLength(0);
    expect((await admin.from("workout_sets").select("id").eq("id", setId)).data).toHaveLength(0);
  });

  it("antwortet auch beim zweiten Aufruf mit 204", async () => {
    const bearer = await accessTokenFor(memberAEmail);
    const { sessionId } = await einheitMitSatz(bearer);
    await DELETE(deleteRequest(sessionId, bearer), deleteContext(sessionId));

    const response = await DELETE(deleteRequest(sessionId, bearer), deleteContext(sessionId));

    expect(response.status).toBe(204);
  });

  it("laesst die Einheit eines anderen Mitglieds stehen -- und verraet sie nicht", async () => {
    const bearerA = await accessTokenFor(memberAEmail);
    const { sessionId } = await einheitMitSatz(bearerA);
    const bearerA2 = await accessTokenFor(memberA2Email);

    const response = await DELETE(deleteRequest(sessionId, bearerA2), deleteContext(sessionId));

    expect(response.status).toBe(204);
    const admin = serviceClient();
    expect((await admin.from("workout_sessions").select("id").eq("id", sessionId)).data).toHaveLength(1);
  });

  it("weist einen Aufruf ohne Anmeldung mit 401 ab", async () => {
    const response = await DELETE(deleteRequest(crypto.randomUUID()), deleteContext(crypto.randomUUID()));
    expect(response.status).toBe(401);
  });

  it("weist eine unbrauchbare Kennung mit 422 ab", async () => {
    const bearer = await accessTokenFor(memberAEmail);
    const response = await DELETE(deleteRequest("x", bearer), deleteContext("x"));
    expect(response.status).toBe(422);
  });
});
