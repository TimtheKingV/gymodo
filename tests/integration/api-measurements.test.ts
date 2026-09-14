import { beforeAll, describe, expect, it } from "vitest";
import { GET as bootstrapGET } from "@/app/api/v1/me/bootstrap/route";
import { PUT as goalPUT } from "@/app/api/v1/me/goals/route";
import { DELETE as measurementDELETE } from "@/app/api/v1/me/measurements/[measuredOn]/route";
import { GET as measurementsGET, PUT as measurementsPUT } from "@/app/api/v1/me/measurements/route";
import { accessTokenFor, createTestUser, uniqueEmail } from "./helpers/clients.js";

function goalPutRequest(rumpf: unknown, auth: string): Request {
  return new Request("http://localhost/api/v1/me/goals", {
    method: "PUT",
    headers: { authorization: `Bearer ${auth}` },
    body: JSON.stringify(rumpf),
  });
}

function putRequest(rumpf: unknown, auth?: string): Request {
  return new Request("http://localhost/api/v1/me/measurements", {
    method: "PUT",
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
    body: JSON.stringify(rumpf),
  });
}

function getRequest(query = "", auth?: string): Request {
  return new Request(`http://localhost/api/v1/me/measurements${query}`, {
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

function deleteRequest(measuredOn: string, auth?: string): Request {
  return new Request(`http://localhost/api/v1/me/measurements/${measuredOn}`, {
    method: "DELETE",
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

function deleteContext(measuredOn: string): { params: Promise<{ measuredOn: string }> } {
  return { params: Promise.resolve({ measuredOn }) };
}

async function neuerBearer(prefix: string): Promise<string> {
  const email = uniqueEmail(prefix);
  await createTestUser(email);
  return accessTokenFor(email);
}

describe("PUT /me/measurements", () => {
  let bearer: string;

  beforeAll(async () => {
    bearer = await neuerBearer("messwert-put");
  });

  it("legt einen Eintrag an und antwortet 200 mit dem Messwert", async () => {
    const response = await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 82.5 }, bearer));

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual({
      measuredOn: "2026-09-01", weightKg: 82.5, goalReached: false,
    });
  });

  it("ersetzt am selben Tag statt eine zweite Zeile anzulegen", async () => {
    await measurementsPUT(putRequest({ measuredOn: "2026-09-02", weightKg: 82.0 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-02", weightKg: 81.5 }, bearer));

    const response = await measurementsGET(getRequest("?since=2026-09-02", bearer));
    const payload = (await response.json()) as { points: Array<{ measuredOn: string; weightKg: number }> };

    expect(payload.points).toEqual([{ measuredOn: "2026-09-02", weightKg: 81.5 }]);
  });

  it("weist ein Datum in zwei Tagen mit 422 ab", async () => {
    const uebermorgen = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000).toISOString().slice(0, 10);
    const response = await measurementsPUT(putRequest({ measuredOn: uebermorgen, weightKg: 80 }, bearer));

    expect(response.status).toBe(422);
  });

  it("weist einen Aufruf ohne Anmeldung mit 401 ab", async () => {
    const response = await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 80 }));
    expect(response.status).toBe(401);
  });
});

describe("GET /me/measurements", () => {
  let bearer: string;

  beforeAll(async () => {
    bearer = await neuerBearer("messwert-get");
    await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 84 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-03", weightKg: 83 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-10", weightKg: 82 }, bearer));
  });

  it("liefert die Punkte aufsteigend mit stimmiger Zusammenfassung", async () => {
    const response = await measurementsGET(getRequest("", bearer));
    const payload = (await response.json()) as {
      points: Array<{ measuredOn: string; weightKg: number }>;
      summary: { first: { weightKg: number } | null; latest: { weightKg: number } | null; changeKg: number | null };
    };

    expect(payload.points.map((p) => p.measuredOn)).toEqual(["2026-09-01", "2026-09-03", "2026-09-10"]);
    expect(payload.summary.first?.weightKg).toBe(84);
    expect(payload.summary.latest?.weightKg).toBe(82);
    expect(payload.summary.changeKg).toBe(-2);
  });

  it("?since= schneidet die Punkte davor ab", async () => {
    const response = await measurementsGET(getRequest("?since=2026-09-03", bearer));
    const payload = (await response.json()) as { points: Array<{ measuredOn: string }> };

    expect(payload.points.map((p) => p.measuredOn)).toEqual(["2026-09-03", "2026-09-10"]);
  });
});

describe("DELETE /me/measurements/:measuredOn", () => {
  let bearer: string;

  beforeAll(async () => {
    bearer = await neuerBearer("messwert-delete");
  });

  it("entfernt den Tag; ein zweites DELETE antwortet ebenfalls 204", async () => {
    await measurementsPUT(putRequest({ measuredOn: "2026-09-05", weightKg: 80 }, bearer));

    const erste = await measurementDELETE(deleteRequest("2026-09-05", bearer), deleteContext("2026-09-05"));
    expect(erste.status).toBe(204);

    const zweite = await measurementDELETE(deleteRequest("2026-09-05", bearer), deleteContext("2026-09-05"));
    expect(zweite.status).toBe(204);

    const response = await measurementsGET(getRequest("?since=2026-09-05", bearer));
    const payload = (await response.json()) as { points: unknown[] };
    expect(payload.points).toEqual([]);
  });
});

describe("GET /me/bootstrap -- latestWeight", () => {
  it("ist null ohne Eintrag", async () => {
    const bearer = await neuerBearer("messwert-bootstrap-leer");

    const response = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );

    const payload = (await response.json()) as { member: { latestWeight: unknown } };
    expect(payload.member.latestWeight).toBeNull();
  });

  it("traegt den juengsten Punkt nach einem Eintrag", async () => {
    const bearer = await neuerBearer("messwert-bootstrap-wert");
    await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 90 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-05", weightKg: 88.5 }, bearer));

    const response = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );

    const payload = (await response.json()) as {
      member: { latestWeight: { measuredOn: string; weightKg: number } | null };
    };
    expect(payload.member.latestWeight).toEqual({ measuredOn: "2026-09-05", weightKg: 88.5 });
  });
});

describe("PUT /me/measurements -- Ziel erreicht", () => {
  it("meldet goalReached, sobald der Eintrag das Zielgewicht abnehmend erreicht", async () => {
    const bearer = await neuerBearer("messwert-ziel-erreicht");
    await goalPUT(goalPutRequest({ kind: "target_weight", targetValue: 78 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 82.5 }, bearer));

    const response = await measurementsPUT(putRequest({ measuredOn: "2026-09-10", weightKg: 78.0 }, bearer));
    const payload = (await response.json()) as { goalReached: boolean };
    expect(payload.goalReached).toBe(true);

    // Erreicht heisst abgeschlossen: der Bootstrap zeigt kein aktives
    // Zielgewicht mehr -- es steht als "reached" in der Geschichte.
    const bootstrap = await bootstrapGET(
      new Request("http://localhost/api/v1/me/bootstrap", {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );
    const bootstrapPayload = (await bootstrap.json()) as {
      member: { goals: { targetWeight: unknown } };
    };
    expect(bootstrapPayload.member.goals.targetWeight).toBeNull();
  });

  it("meldet goalReached: false, solange das Zielgewicht noch nicht erreicht ist", async () => {
    const bearer = await neuerBearer("messwert-ziel-nicht-erreicht");
    await goalPUT(goalPutRequest({ kind: "target_weight", targetValue: 78 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 82.5 }, bearer));

    const response = await measurementsPUT(putRequest({ measuredOn: "2026-09-05", weightKg: 78.5 }, bearer));
    const payload = (await response.json()) as { goalReached: boolean };
    expect(payload.goalReached).toBe(false);
  });

  it("gegengeprueft in Zunahme-Richtung: das Ziel liegt ueber dem Start", async () => {
    const bearer = await neuerBearer("messwert-ziel-zunahme");
    await goalPUT(goalPutRequest({ kind: "target_weight", targetValue: 78 }, bearer));
    await measurementsPUT(putRequest({ measuredOn: "2026-09-01", weightKg: 74.0 }, bearer));

    const nichtErreicht = await measurementsPUT(
      putRequest({ measuredOn: "2026-09-05", weightKg: 77.5 }, bearer),
    );
    expect(((await nichtErreicht.json()) as { goalReached: boolean }).goalReached).toBe(false);

    const erreicht = await measurementsPUT(putRequest({ measuredOn: "2026-09-10", weightKg: 78.0 }, bearer));
    expect(((await erreicht.json()) as { goalReached: boolean }).goalReached).toBe(true);
  });
});
