import { beforeAll, describe, expect, it } from "vitest";
import { GET as bootstrapGET } from "@/app/api/v1/me/bootstrap/route";
import { GET as sessionsGET } from "@/app/api/v1/me/sessions/route";
import { GET as progressGET } from "@/app/api/v1/me/progress/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";

let bearer: string;
let exerciseId: string;

function newId(): string {
  return crypto.randomUUID();
}

function request(url: string, auth?: string): Request {
  return new Request(url, {
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Me-API Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const email = uniqueEmail("meapi-member");
  const userId = await createTestUser(email);
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: userId, role: "member" });
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Beinpresse", weight_step_kg: 2.5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studio.id, equipment_model_id: model.id, label: "07" })
    .select("id")
    .single();
  if (machineError) throw machineError;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studio.id,
      name: "Beidbeinig",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseId = exercise.id;

  const { error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert({
      equipment_model_id: model.id,
      exercise_id: exerciseId,
      sort_order: 1,
    });
  if (linkError) throw linkError;

  const sessionId = newId();
  const { error: sessionError } = await admin.from("workout_sessions").insert({
    id: sessionId,
    studio_id: studio.id,
    user_id: userId,
    started_at: new Date("2026-08-27T18:00:00Z").toISOString(),
    completed_at: new Date("2026-08-27T18:47:00Z").toISOString(),
    completed_reason: "manual",
  });
  if (sessionError) throw sessionError;

  const { error: setError } = await admin.from("workout_sets").insert({
    id: newId(),
    studio_id: studio.id,
    user_id: userId,
    session_id: sessionId,
    machine_id: machine.id,
    exercise_id: exerciseId,
    set_index: 1,
    weight_kg: 80,
    reps: 10,
    performed_at: new Date("2026-08-27T18:10:00Z").toISOString(),
  });
  if (setError) throw setError;

  bearer = await accessTokenFor(email);
});

describe("GET /api/v1/me/bootstrap", () => {
  it("liefert Studios, Geraete und die eigenen letzten Werte", async () => {
    const response = await bootstrapGET(
      request("http://localhost/api/v1/me/bootstrap", bearer),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      studios: unknown[];
      machines: Array<{ label: string }>;
      lastSets: Array<{ weightKg: number }>;
    };
    expect(payload.studios).toHaveLength(1);
    expect(payload.machines[0]?.label).toBe("07");
    expect(payload.lastSets[0]?.weightKg).toBe(80);
  });

  it("antwortet ohne Token mit 401", async () => {
    const response = await bootstrapGET(
      request("http://localhost/api/v1/me/bootstrap"),
    );

    expect(response.status).toBe(401);
  });

  it("verbietet das Ablegen in einem geteilten Cache", async () => {
    const response = await bootstrapGET(
      request("http://localhost/api/v1/me/bootstrap", bearer),
    );

    expect(response.headers.get("cache-control")).toContain("private");
  });
});

describe("GET /api/v1/me/sessions", () => {
  it("liefert den eigenen Verlauf mit Bloecken", async () => {
    const response = await sessionsGET(
      request("http://localhost/api/v1/me/sessions", bearer),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      sessions: Array<{ setCount: number; blocks: unknown[] }>;
    };
    expect(payload.sessions[0]?.setCount).toBe(1);
    expect(payload.sessions[0]?.blocks).toHaveLength(1);
  });

  it("antwortet ohne Token mit 401", async () => {
    const response = await sessionsGET(
      request("http://localhost/api/v1/me/sessions"),
    );

    expect(response.status).toBe(401);
  });
});

describe("GET /api/v1/me/progress", () => {
  it("liefert Aggregate je Uebung", async () => {
    const response = await progressGET(
      request("http://localhost/api/v1/me/progress", bearer),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      exercises: Array<{ exerciseId: string; currentWeightKg: number }>;
    };
    const entry = payload.exercises.find(
      (item) => item.exerciseId === exerciseId,
    );
    expect(entry?.currentWeightKg).toBe(80);
  });

  it("nimmt den Zeitraum aus der Abfragezeichenfolge", async () => {
    const response = await progressGET(
      request(
        "http://localhost/api/v1/me/progress?since=2026-09-01",
        bearer,
      ),
    );

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { exercises: unknown[] };
    expect(payload.exercises).toEqual([]);
  });

  it("antwortet auf ein unbrauchbares Datum mit 422", async () => {
    const response = await progressGET(
      request("http://localhost/api/v1/me/progress?since=gestern", bearer),
    );

    expect(response.status).toBe(422);
  });

  it("antwortet ohne Token mit 401", async () => {
    const response = await progressGET(
      request("http://localhost/api/v1/me/progress"),
    );

    expect(response.status).toBe(401);
  });
});
