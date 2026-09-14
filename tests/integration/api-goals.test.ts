import { beforeAll, describe, expect, it } from "vitest";
import { GET as bootstrapGET } from "@/app/api/v1/me/bootstrap/route";
import { DELETE as goalDELETE } from "@/app/api/v1/me/goals/[kind]/route";
import { PUT as goalPUT } from "@/app/api/v1/me/goals/route";
import { GET as sessionsGET } from "@/app/api/v1/me/sessions/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";

function putRequest(rumpf: unknown, auth?: string): Request {
  return new Request("http://localhost/api/v1/me/goals", {
    method: "PUT",
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
    body: JSON.stringify(rumpf),
  });
}

function deleteRequest(kind: string, auth?: string): Request {
  return new Request(`http://localhost/api/v1/me/goals/${kind}`, {
    method: "DELETE",
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

function deleteContext(kind: string): { params: Promise<{ kind: string }> } {
  return { params: Promise.resolve({ kind }) };
}

function bootstrapRequest(auth: string): Request {
  return new Request("http://localhost/api/v1/me/bootstrap", {
    headers: { authorization: `Bearer ${auth}` },
  });
}

async function neuerBearer(prefix: string): Promise<{ email: string; userId: string; bearer: string }> {
  const email = uniqueEmail(prefix);
  const userId = await createTestUser(email);
  const bearer = await accessTokenFor(email);
  return { email, userId, bearer };
}

type BootstrapPayload = {
  member: { goals: { weeklyDays: { targetValue: number } | null; targetWeight: { targetValue: number } | null } };
};

describe("PUT /me/goals", () => {
  it("legt ein Ziel an und antwortet 200", async () => {
    const { bearer } = await neuerBearer("ziel-put-anlegen");

    const response = await goalPUT(putRequest({ kind: "weekly_days", targetValue: 3 }, bearer));

    expect(response.status).toBe(200);
    const payload = (await response.json()) as { kind: string; targetValue: number };
    expect(payload.kind).toBe("weekly_days");
    expect(payload.targetValue).toBe(3);
  });

  it("ersetzt das aktive Ziel -- der Bootstrap zeigt das neue", async () => {
    const { bearer } = await neuerBearer("ziel-put-ersetzen");

    await goalPUT(putRequest({ kind: "target_weight", targetValue: 80 }, bearer));
    await goalPUT(putRequest({ kind: "target_weight", targetValue: 76 }, bearer));

    const response = await bootstrapGET(bootstrapRequest(bearer));
    const payload = (await response.json()) as BootstrapPayload;

    expect(payload.member.goals.targetWeight?.targetValue).toBe(76);
  });

  it("weist eine unbekannte Zielsorte mit 422 ab", async () => {
    const { bearer } = await neuerBearer("ziel-put-unbekannt");

    const response = await goalPUT(putRequest({ kind: "monatsziel", targetValue: 3 }, bearer));

    expect(response.status).toBe(422);
  });

  it("weist einen Aufruf ohne Anmeldung mit 401 ab", async () => {
    const response = await goalPUT(putRequest({ kind: "weekly_days", targetValue: 3 }));
    expect(response.status).toBe(401);
  });
});

describe("DELETE /me/goals/:kind", () => {
  it("gibt das aktive Ziel auf -- der Bootstrap zeigt null", async () => {
    const { bearer } = await neuerBearer("ziel-delete-aufgeben");
    await goalPUT(putRequest({ kind: "weekly_days", targetValue: 4 }, bearer));

    const response = await goalDELETE(deleteRequest("weekly_days", bearer), deleteContext("weekly_days"));
    expect(response.status).toBe(204);

    const bootstrap = await bootstrapGET(bootstrapRequest(bearer));
    const payload = (await bootstrap.json()) as BootstrapPayload;
    expect(payload.member.goals.weeklyDays).toBeNull();
  });

  it("ohne aktives Ziel antwortet ebenfalls 204", async () => {
    const { bearer } = await neuerBearer("ziel-delete-ohne");

    const response = await goalDELETE(deleteRequest("target_weight", bearer), deleteContext("target_weight"));
    expect(response.status).toBe(204);
  });

  it("weist eine unbekannte Zielsorte mit 422 ab", async () => {
    const { bearer } = await neuerBearer("ziel-delete-unbekannt");

    const response = await goalDELETE(deleteRequest("monatsziel", bearer), deleteContext("monatsziel"));
    expect(response.status).toBe(422);
  });
});

describe("GET /me/sessions?studio= -- weeklyTarget", () => {
  let studioA: string;

  beforeAll(async () => {
    const admin = serviceClient();
    const { data: studio, error } = await admin
      .from("studios")
      .insert({ name: "Ziele Sessions Studio" })
      .select("id")
      .single();
    if (error) throw error;
    studioA = studio.id;
  });

  async function mitgliedMitStudio(prefix: string): Promise<{ bearer: string }> {
    const { userId, bearer } = await neuerBearer(prefix);
    const admin = serviceClient();
    const { error } = await admin
      .from("studio_memberships")
      .insert({ studio_id: studioA, user_id: userId, role: "member" });
    if (error) throw error;
    return { bearer };
  }

  it("traegt das Wochenziel in streak.weeklyTarget", async () => {
    const { bearer } = await mitgliedMitStudio("ziel-sessions-mit-ziel");
    await goalPUT(putRequest({ kind: "weekly_days", targetValue: 3 }, bearer));

    const response = await sessionsGET(
      new Request(`http://localhost/api/v1/me/sessions?studio=${studioA}`, {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );
    const payload = (await response.json()) as {
      summary: { streak: { weeks: number; weeklyTarget: number | null } | null };
    };

    expect(payload.summary.streak?.weeklyTarget).toBe(3);
    expect(payload.summary.streak?.weeks).toBe(0);
  });

  it("laesst streak.weeks unveraendert, ob ein Ziel gesetzt ist oder nicht", async () => {
    const { bearer } = await mitgliedMitStudio("ziel-sessions-ohne-ziel");

    const response = await sessionsGET(
      new Request(`http://localhost/api/v1/me/sessions?studio=${studioA}`, {
        headers: { authorization: `Bearer ${bearer}` },
      }),
    );
    const payload = (await response.json()) as {
      summary: { streak: { weeks: number; weeklyTarget: number | null } | null };
    };

    expect(payload.summary.streak?.weeklyTarget).toBeNull();
    expect(payload.summary.streak?.weeks).toBe(0);
  });
});
