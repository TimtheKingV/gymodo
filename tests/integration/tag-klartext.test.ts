import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagAnlegen } from "../helpers/tags.js";

let studioId: string;
let trainerEmail: string;
let token: string;
let tagId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioFehler } = await admin
    .from("studios")
    .insert({ name: "Klartext Studio" })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;
  studioId = studio.id;

  trainerEmail = uniqueEmail("klartext-trainer");
  const trainer = await createTestUser(trainerEmail);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: trainer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  token = createTagToken();
  const angelegt = await tagAnlegen(admin, { studioId, token });
  tagId = angelegt.id;
});

describe("machine_tags.token", () => {
  it("leitet token_hash aus dem Klartext ab", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("machine_tags")
      .select("token, token_hash")
      .eq("id", tagId)
      .single<{ token: string; token_hash: string }>();
    expect(error).toBeNull();
    expect(data?.token).toBe(token);
    expect(data?.token_hash).toBe(hashTagToken(token));
  });

  it("laesst einen Trainer den Klartext nicht lesen", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("machine_tags")
      .select("token")
      .eq("id", tagId);
    expect(error).not.toBeNull();
  });

  it("laesst einen Trainer die uebrigen Spalten weiter lesen", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client
      .from("machine_tags")
      .select("id, status, kind, token_hash")
      .eq("id", tagId)
      .single<{ id: string; status: string; kind: string; token_hash: string }>();
    expect(error).toBeNull();
    expect(data?.token_hash).toBe(hashTagToken(token));
  });

  it("laesst einen Trainer den Klartext nicht ueberschreiben", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("machine_tags")
      .update({ token: createTagToken() })
      .eq("id", tagId);
    expect(error).not.toBeNull();
  });

  it("laesst einen Trainer keine Zeile mehr einfuegen", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("machine_tags")
      .insert({ studio_id: studioId, status: "unassigned", kind: "machine" });
    expect(error).not.toBeNull();
  });
});
