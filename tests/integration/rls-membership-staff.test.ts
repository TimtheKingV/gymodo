import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let fremdStudioId: string;
let trainerEmail: string;
let trainerId: string;
let ownerEmail: string;
let ownerId: string;
let mitgliedEmail: string;
let mitgliedId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Leute-Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  const { data: fremd, error: fremdError } = await admin
    .from("studios")
    .insert({ name: "Fremdes Leute-Studio" })
    .select("id")
    .single();
  if (fremdError) throw fremdError;
  fremdStudioId = fremd.id;

  trainerEmail = uniqueEmail("leute-trainer");
  trainerId = await createTestUser(trainerEmail);
  ownerEmail = uniqueEmail("leute-owner");
  ownerId = await createTestUser(ownerEmail);
  mitgliedEmail = uniqueEmail("leute-mitglied");
  mitgliedId = await createTestUser(mitgliedEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: ownerId, role: "owner" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
  if (error) throw error;
});

describe("list_studio_members", () => {
  it("ein Trainer sieht alle drei Mitgliedschaften mit E-Mail-Adresse", async () => {
    const client = await userClient(trainerEmail);
    const { data, error } = await client.rpc("list_studio_members", { p_studio_id: studioId });
    expect(error).toBeNull();
    expect(data).toHaveLength(3);
    const emails = (data as Array<{ email: string }>).map((zeile) => zeile.email).sort();
    expect(emails).toEqual([mitgliedEmail, ownerEmail, trainerEmail].sort());
  });

  it("ein Mitglied sieht die Liste nicht", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client.rpc("list_studio_members", { p_studio_id: studioId });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("Staff eines anderen Studios sieht nichts", async () => {
    const admin = serviceClient();
    const fremdTrainerEmail = uniqueEmail("leute-fremd-trainer");
    const fremdTrainerId = await createTestUser(fremdTrainerEmail);
    await admin
      .from("studio_memberships")
      .insert({ studio_id: fremdStudioId, user_id: fremdTrainerId, role: "trainer" });

    const client = await userClient(fremdTrainerEmail);
    const { data } = await client.rpc("list_studio_members", { p_studio_id: studioId });
    expect(data).toEqual([]);
  });
});

describe("memberships_update_staff", () => {
  it("ein Trainer stuft ein Mitglied zum Trainer hoch", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studio_memberships")
      .update({ role: "trainer" })
      .eq("studio_id", studioId)
      .eq("user_id", mitgliedId);
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", mitgliedId)
      .single();
    expect(data?.role).toBe("trainer");

    await admin
      .from("studio_memberships")
      .update({ role: "member" })
      .eq("studio_id", studioId)
      .eq("user_id", mitgliedId);
  });

  it("ein Trainer kann die Inhaberrolle nicht antasten", async () => {
    const client = await userClient(trainerEmail);
    await client
      .from("studio_memberships")
      .update({ role: "member" })
      .eq("studio_id", studioId)
      .eq("user_id", ownerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", ownerId)
      .single();
    expect(data?.role).toBe("owner");
  });

  it("ein Mitglied kann niemanden hochstufen", async () => {
    const client = await userClient(mitgliedEmail);
    await client
      .from("studio_memberships")
      .update({ role: "trainer" })
      .eq("studio_id", studioId)
      .eq("user_id", mitgliedId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", mitgliedId)
      .single();
    expect(data?.role).toBe("member");
  });
});

describe("memberships_delete_staff", () => {
  it("ein Trainer entfernt ein Mitglied", async () => {
    const email = uniqueEmail("leute-entfernen");
    const userId = await createTestUser(email);
    const admin = serviceClient();
    await admin
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });

    const client = await userClient(trainerEmail);
    const { error } = await client
      .from("studio_memberships")
      .delete()
      .eq("studio_id", studioId)
      .eq("user_id", userId);
    expect(error).toBeNull();

    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("studio_id", studioId)
      .eq("user_id", userId);
    expect(data).toEqual([]);
  });

  it("ein Trainer kann den Inhaber nicht entfernen", async () => {
    const client = await userClient(trainerEmail);
    await client
      .from("studio_memberships")
      .delete()
      .eq("studio_id", studioId)
      .eq("user_id", ownerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("studio_id", studioId)
      .eq("user_id", ownerId);
    expect(data).toHaveLength(1);
  });

  it("ein Mitglied kann niemanden entfernen", async () => {
    const client = await userClient(mitgliedEmail);
    await client
      .from("studio_memberships")
      .delete()
      .eq("studio_id", studioId)
      .eq("user_id", trainerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("studio_id", studioId)
      .eq("user_id", trainerId);
    expect(data).toHaveLength(1);
  });
});
