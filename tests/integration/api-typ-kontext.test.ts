import { beforeAll, describe, expect, it } from "vitest";
import { GET } from "@/app/api/v1/equipment-models/[modelId]/context/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";

const GYMTAVO = "00000000-0000-4000-8000-000000000001";

let bearer: string;
let typ: string;
let fremdesModell: string;

function anfrage(query = "", auth?: string): Request {
  return new Request(`http://localhost/api/v1/equipment-models/x/context${query}`, {
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

function params(modelId: string) {
  return { params: Promise.resolve({ modelId }) };
}

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Typkontext-API Fremd" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { data: modelle, error: modellError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: GYMTAVO, name: `Dip-Station ${crypto.randomUUID()}`, load_step: 2.5, load_min: 0 },
      { studio_id: studio.id, name: "Fremdmodell", load_step: 2.5, load_min: 0 },
    ])
    .select("id");
  if (modellError) throw modellError;
  typ = modelle[0]!.id;
  fremdesModell = modelle[1]!.id;

  const email = uniqueEmail("typkontext-api");
  await createTestUser(email);
  bearer = await accessTokenFor(email);
});

describe("GET /api/v1/equipment-models/{id}/context", () => {
  it("liefert den Kontext eines Gymtavo-Typs, privat und ungecacht", async () => {
    const response = await GET(anfrage("", bearer), params(typ));

    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("private, no-store");
    const body = (await response.json()) as { machine: unknown; equipmentModel: { id: string } };
    expect(body.machine).toBeNull();
    expect(body.equipmentModel.id).toBe(typ);
  });

  it("antwortet auf den Typ eines fremden Studios mit 404", async () => {
    const response = await GET(anfrage("", bearer), params(fremdesModell));

    expect(response.status).toBe(404);
  });

  it("weist einen ungueltigen Studio-Parameter als Eingabefehler zurueck", async () => {
    const response = await GET(anfrage("?studio=kein-uuid", bearer), params(typ));

    expect(response.status).toBe(422);
  });

  it("verlangt eine Anmeldung", async () => {
    const response = await GET(anfrage(), params(typ));

    expect(response.status).toBe(401);
  });
});
