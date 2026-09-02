import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken } from "@fitretro/domain";
import { GET } from "@/app/api/v1/tags/[token]/context/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

let activeToken: string;
let revokedToken: string;
let bearer: string;

function request(auth?: string): Request {
  return new Request("http://localhost/api/v1/tags/x/context", {
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

function params(token: string) {
  return { params: Promise.resolve({ token }) };
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Tag-API Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const email = uniqueEmail("tagapi-member");
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
    .insert({
      studio_id: studio.id,
      equipment_model_id: model.id,
      label: "07",
    })
    .select("id")
    .single();
  if (machineError) throw machineError;

  activeToken = createTagToken();
  revokedToken = createTagToken();
  await tagsAnlegen(admin, [
    { studioId: studio.id, machineId: machine.id, token: activeToken, status: "active" },
    { studioId: studio.id, token: revokedToken, status: "revoked" },
  ]);

  bearer = await accessTokenFor(email);
});

describe("GET /api/v1/tags/{token}/context", () => {
  it("liefert den Geraetekontext", async () => {
    const response = await GET(request(bearer), params(activeToken));

    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      machine: { label: string };
      suggestion: { reasonCode: string };
    };
    expect(payload.machine.label).toBe("07");
    expect(payload.suggestion.reasonCode).toBe("kein_verlauf");
  });

  it("antwortet ohne Token mit 401", async () => {
    const response = await GET(request(), params(activeToken));

    expect(response.status).toBe(401);
  });

  it("antwortet auf einen gesperrten Tag mit 404", async () => {
    const response = await GET(request(bearer), params(revokedToken));

    expect(response.status).toBe(404);
  });

  it("antwortet auf ein unbrauchbares Tokenformat mit 422", async () => {
    const response = await GET(request(bearer), params("zu-kurz"));

    expect(response.status).toBe(422);
  });

  it("verraet den Tag-Token nicht in der Antwort", async () => {
    const response = await GET(request(bearer), params(activeToken));

    expect(await response.text()).not.toContain(activeToken);
  });
});
