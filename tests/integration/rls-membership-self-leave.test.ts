import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient, createTestUser, userClient, uniqueEmail } from "./helpers/clients.js";

let studioId: string;
let mitgliedEmail: string;
let mitgliedId: string;
let trainerEmail: string;
let trainerId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Austritts-Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  mitgliedEmail = uniqueEmail("austritt-mitglied");
  mitgliedId = await createTestUser(mitgliedEmail);
  trainerEmail = uniqueEmail("austritt-trainer");
  trainerId = await createTestUser(trainerEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
  ]);
  if (error) throw error;
});

describe("Selbstaustritt", () => {
  it("ein Trainer kann sich selbst nicht entfernen", async () => {
    const client = await userClient(trainerEmail);
    await client.from("studio_memberships").delete().eq("user_id", trainerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", trainerId);
    expect(data).toHaveLength(1);
  });

  it("ein Mitglied kann eine fremde Mitgliedschaft nicht entfernen", async () => {
    const client = await userClient(mitgliedEmail);
    await client.from("studio_memberships").delete().eq("user_id", trainerId);

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", trainerId);
    expect(data).toHaveLength(1);
  });

  it("ein Mitglied kann die eigene Mitgliedschaft entfernen", async () => {
    const client = await userClient(mitgliedEmail);
    const { error } = await client
      .from("studio_memberships")
      .delete()
      .eq("user_id", mitgliedId);
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", mitgliedId);
    expect(data).toEqual([]);
  });
});
