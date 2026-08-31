import { beforeAll, describe, expect, it } from "vitest";
import { PUT } from "@/app/api/v1/workout-sessions/[sessionId]/sets/[setId]/route";
import { POST } from "@/app/api/v1/workout-sessions/[sessionId]/complete/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";

let studioA: string;
let memberAEmail: string;
let memberAId: string;
let memberA2Id: string;
let machineA: string;
let machineB: string;
let exerciseA: string;
let token: string;

function newId(): string {
  return crypto.randomUUID();
}

function setRequest(body: unknown, bearer?: string): Request {
  return new Request("http://localhost/api/v1/workout-sessions/x/sets/y", {
    method: "PUT",
    headers: {
      "content-type": "application/json",
      ...(bearer ? { authorization: `Bearer ${bearer}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

function params(sessionId: string, setId: string) {
  return { params: Promise.resolve({ sessionId, setId }) };
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "API Studio A" }, { name: "API Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  const studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("api-member-a");
  memberAId = await createTestUser(memberAEmail);
  memberA2Id = await createTestUser(uniqueEmail("api-member-a2"));
  const memberBId = await createTestUser(uniqueEmail("api-member-b"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioA, user_id: memberA2Id, role: "member" },
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

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Beidbeinig",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseA = exercise.id;

  token = await accessTokenFor(memberAEmail);
});

function body(overrides: Record<string, unknown> = {}) {
  return {
    machineId: machineA,
    exerciseId: exerciseA,
    setIndex: 1,
    weightKg: 80,
    reps: 10,
    ...overrides,
  };
}

describe("PUT /api/v1/workout-sessions/{sessionId}/sets/{setId}", () => {
  it("speichert den Satz und liefert ihn kanonisch zurueck", async () => {
    const sessionId = newId();
    const setId = newId();

    const response = await PUT(
      setRequest(body(), token),
      params(sessionId, setId),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { id: string; weightKg: number };
    expect(payload.id).toBe(setId);
    expect(payload.weightKg).toBe(80);
  });

  it("nimmt die Kennungen aus dem Pfad, nicht aus der Nutzlast", async () => {
    const sessionId = newId();
    const setId = newId();

    const response = await PUT(
      setRequest(body({ setId: newId(), sessionId: newId() }), token),
      params(sessionId, setId),
    );

    const payload = (await response.json()) as {
      id: string;
      sessionId: string;
    };
    expect(payload.id).toBe(setId);
    expect(payload.sessionId).toBe(sessionId);
  });

  it("Idempotenz: derselbe Aufruf zweimal ergibt eine Zeile", async () => {
    const sessionId = newId();
    const setId = newId();

    await PUT(setRequest(body(), token), params(sessionId, setId));
    const second = await PUT(
      setRequest(body(), token),
      params(sessionId, setId),
    );

    expect(second.status).toBe(200);
    const { data } = await serviceClient()
      .from("workout_sets")
      .select("id")
      .eq("id", setId);
    expect(data).toHaveLength(1);
  });

  it("antwortet ohne Authorization-Kopfzeile mit 401", async () => {
    const response = await PUT(
      setRequest(body()),
      params(newId(), newId()),
    );

    expect(response.status).toBe(401);
    const payload = (await response.json()) as { error: { code: string } };
    expect(payload.error.code).toBe("unauthorized");
  });

  it("antwortet auf ein unbrauchbares Token mit 401", async () => {
    const response = await PUT(
      setRequest(body(), "kein.gueltiges.token"),
      params(newId(), newId()),
    );

    expect(response.status).toBe(401);
  });

  it("antwortet auf eine ungueltige Nutzlast mit 422 und Fehlercode", async () => {
    const response = await PUT(
      setRequest(body({ reps: 0 }), token),
      params(newId(), newId()),
    );

    expect(response.status).toBe(422);
    const payload = (await response.json()) as { error: { code: string } };
    expect(payload.error.code).toBe("validation_failed");
  });

  it("antwortet auf kaputtes JSON mit 422", async () => {
    const request = new Request("http://localhost/x", {
      method: "PUT",
      headers: {
        "content-type": "application/json",
        authorization: `Bearer ${token}`,
      },
      body: "{kein json",
    });

    const response = await PUT(request, params(newId(), newId()));

    expect(response.status).toBe(422);
  });

  it("antwortet auf ein Geraet aus einem fremden Studio mit 404", async () => {
    const response = await PUT(
      setRequest(body({ machineId: machineB }), token),
      params(newId(), newId()),
    );

    expect(response.status).toBe(404);
  });
});

describe("POST /api/v1/workout-sessions/{sessionId}/complete", () => {
  async function seedSession(userId: string): Promise<string> {
    const id = newId();
    const { error } = await serviceClient()
      .from("workout_sessions")
      .insert({ id, studio_id: studioA, user_id: userId });
    if (error) throw error;
    return id;
  }

  function completeRequest(bearer?: string): Request {
    return new Request("http://localhost/complete", {
      method: "POST",
      headers: bearer ? { authorization: `Bearer ${bearer}` } : {},
    });
  }

  it("beendet die eigene Session", async () => {
    const sessionId = await seedSession(memberAId);

    const response = await POST(completeRequest(token), {
      params: Promise.resolve({ sessionId }),
    });

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { completedReason: string };
    expect(payload.completedReason).toBe("manual");
  });

  it("antwortet ohne Token mit 401", async () => {
    const sessionId = await seedSession(memberAId);

    const response = await POST(completeRequest(), {
      params: Promise.resolve({ sessionId }),
    });

    expect(response.status).toBe(401);
  });

  it("antwortet auf die Session eines anderen Mitglieds mit 404", async () => {
    const foreignId = await seedSession(memberA2Id);

    const response = await POST(completeRequest(token), {
      params: Promise.resolve({ sessionId: foreignId }),
    });

    expect(response.status).toBe(404);
  });
});
