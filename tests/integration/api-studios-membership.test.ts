import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken } from "@fitretro/domain";
import { POST as joinByCode } from "@/app/api/v1/studios/join-by-code/route";
import { POST as joinByTag } from "@/app/api/v1/studios/join-by-tag/route";
import { DELETE as leaveMembership } from "@/app/api/v1/studios/[studioId]/membership/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

let studioId: string;
let joinCode: string;
let machineTagToken: string;
let memberBearer: string;

function jsonRequest(url: string, body: unknown, auth?: string): Request {
  return new Request(url, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      ...(auth ? { authorization: `Bearer ${auth}` } : {}),
    },
    body: JSON.stringify(body),
  });
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Beitritts-API Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;
  joinCode = studio.join_code;

  machineTagToken = createTagToken();
  await tagsAnlegen(admin, [{ studioId, token: machineTagToken, status: "active" }]);

  const email = uniqueEmail("beitrittapi-member");
  await createTestUser(email);
  memberBearer = await accessTokenFor(email);
});

describe("POST /api/v1/studios/join-by-code", () => {
  it("tritt einem Studio ueber den Code bei", async () => {
    const response = await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: joinCode }, memberBearer));
    expect(response.status).toBe(200);
    const payload = (await response.json()) as { studioId: string; joined: boolean };
    expect(payload.studioId).toBe(studioId);
    expect(payload.joined).toBe(true);
  });

  it("antwortet auf einen unbekannten Code mit 404, nicht 200 mit joined:false", async () => {
    const response = await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: "ZZZZZZZZ" }, memberBearer));
    expect(response.status).toBe(404);
  });

  it("antwortet ohne Token mit 401", async () => {
    const response = await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: joinCode }));
    expect(response.status).toBe(401);
  });
});

describe("POST /api/v1/studios/join-by-tag", () => {
  it("tritt einem Studio ueber einen Geraete-Tag bei", async () => {
    const email = uniqueEmail("beitrittapi-tag-member");
    await createTestUser(email);
    const bearer = await accessTokenFor(email);

    const response = await joinByTag(jsonRequest("http://localhost/api/v1/studios/join-by-tag", { tagToken: machineTagToken }, bearer));
    expect(response.status).toBe(200);
    const payload = (await response.json()) as { studioId: string; joined: boolean };
    expect(payload.studioId).toBe(studioId);
    expect(payload.joined).toBe(true);
  });

  it("antwortet auf ein unbrauchbares Tokenformat mit 422", async () => {
    const response = await joinByTag(jsonRequest("http://localhost/api/v1/studios/join-by-tag", { tagToken: "zu-kurz" }, memberBearer));
    expect(response.status).toBe(422);
  });
});

describe("DELETE /api/v1/studios/{studioId}/membership", () => {
  it("verlaesst ein Studio, dem man beigetreten ist", async () => {
    const email = uniqueEmail("beitrittapi-leave-member");
    await createTestUser(email);
    const bearer = await accessTokenFor(email);
    await joinByCode(jsonRequest("http://localhost/api/v1/studios/join-by-code", { code: joinCode }, bearer));

    const response = await leaveMembership(
      new Request(`http://localhost/api/v1/studios/${studioId}/membership`, {
        method: "DELETE",
        headers: { authorization: `Bearer ${bearer}` },
      }),
      { params: Promise.resolve({ studioId }) },
    );
    expect(response.status).toBe(204);
  });

  it("antwortet mit 404, wenn keine Mitgliedschaft besteht", async () => {
    const email = uniqueEmail("beitrittapi-notmember");
    await createTestUser(email);
    const bearer = await accessTokenFor(email);

    const response = await leaveMembership(
      new Request(`http://localhost/api/v1/studios/${studioId}/membership`, {
        method: "DELETE",
        headers: { authorization: `Bearer ${bearer}` },
      }),
      { params: Promise.resolve({ studioId }) },
    );
    expect(response.status).toBe(404);
  });
});
