import { beforeAll, describe, expect, it } from "vitest";
import {
  joinStudioByCode,
  listStudioMembers,
  regenerateStudioJoinCode,
  removeMembership,
  setMembershipRole,
  setStudioJoinCodeActive,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let joinCode: string;
let trainerEmail: string;
let ownerEmail: string;
let ownerId: string;
let mitgliedEmail: string;
let mitgliedId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Domain-Leute-Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;
  joinCode = studio.join_code;

  trainerEmail = uniqueEmail("domain-leute-trainer");
  ownerEmail = uniqueEmail("domain-leute-owner");
  mitgliedEmail = uniqueEmail("domain-leute-mitglied");
  const trainerId = await createTestUser(trainerEmail);
  ownerId = await createTestUser(ownerEmail);
  mitgliedId = await createTestUser(mitgliedEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: ownerId, role: "owner" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
  if (error) throw error;
});

describe("joinStudioByCode", () => {
  it("meldet den Beitritt einer neuen Person", async () => {
    // Eigenes Studio statt des gemeinsamen Fixtures: ein erfolgreicher
    // Beitritt legt dauerhaft eine Mitgliedschaft an, und wuerde er das
    // gemeinsame Studio treffen, saehe listStudioMembers spaeter vier statt
    // drei Personen. Die anderen beiden Tests hier bleiben unveraendert am
    // gemeinsamen Code, weil sie nie erfolgreich beitreten.
    const admin = serviceClient();
    const { data: eigenesStudio, error } = await admin
      .from("studios")
      .insert({ name: "Domain-Leute-Beitritt-Studio" })
      .select("id, join_code")
      .single();
    if (error) throw error;

    const email = uniqueEmail("domain-code-neu");
    await createTestUser(email);
    const client = await userClient(email);
    const ergebnis = await joinStudioByCode(client, eigenesStudio.join_code);
    expect(ergebnis).toEqual({ studioId: eigenesStudio.id, joined: true });
  });

  it("meldet einen unbekannten Code als not_found", async () => {
    const email = uniqueEmail("domain-code-unbekannt");
    await createTestUser(email);
    const client = await userClient(email);
    await expect(joinStudioByCode(client, "ZZZZZZZZ")).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist einen leeren Code als validation_failed zurueck", async () => {
    const email = uniqueEmail("domain-code-leer");
    await createTestUser(email);
    const client = await userClient(email);
    await expect(joinStudioByCode(client, "   ")).rejects.toMatchObject({
      code: "validation_failed",
    });
  });
});

describe("regenerateStudioJoinCode / setStudioJoinCodeActive", () => {
  it("ein Trainer erneuert den Code", async () => {
    const client = await userClient(trainerEmail);
    const neuerCode = await regenerateStudioJoinCode(client, studioId);
    expect(neuerCode).not.toBe(joinCode);
    joinCode = neuerCode;
  });

  it("ein Mitglied darf den Code nicht erneuern", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(regenerateStudioJoinCode(client, studioId)).rejects.toMatchObject({
      code: "unauthorized",
    });
  });

  it("ein Trainer sperrt und entsperrt den Code", async () => {
    const client = await userClient(trainerEmail);
    await setStudioJoinCodeActive(client, studioId, false);

    const email = uniqueEmail("domain-code-nach-sperre");
    await createTestUser(email);
    const sperrClient = await userClient(email);
    await expect(joinStudioByCode(sperrClient, joinCode)).rejects.toMatchObject({
      code: "not_found",
    });

    await setStudioJoinCodeActive(client, studioId, true);
  });
});

describe("listStudioMembers", () => {
  it("ein Trainer sieht alle drei Personen", async () => {
    const client = await userClient(trainerEmail);
    const liste = await listStudioMembers(client, studioId);
    expect(liste).toHaveLength(3);
    expect(liste.map((person) => person.email).sort()).toEqual(
      [trainerEmail, ownerEmail, mitgliedEmail].sort(),
    );
  });

  it("ein Mitglied bekommt unauthorized", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(listStudioMembers(client, studioId)).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});

describe("setMembershipRole", () => {
  it("stuft ein Mitglied zum Trainer hoch und zurueck", async () => {
    const client = await userClient(trainerEmail);
    await setMembershipRole(client, studioId, mitgliedId, "trainer");

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", mitgliedId)
      .single();
    expect(data?.role).toBe("trainer");

    await setMembershipRole(client, studioId, mitgliedId, "member");
  });

  it("lehnt den Inhaber als Ziel ab", async () => {
    const client = await userClient(trainerEmail);
    await expect(setMembershipRole(client, studioId, ownerId, "member")).rejects.toMatchObject({
      code: "not_found",
    });
  });
});

describe("removeMembership", () => {
  it("entfernt eine Person aus dem Studio", async () => {
    const email = uniqueEmail("domain-entfernen");
    const userId = await createTestUser(email);
    const admin = serviceClient();
    await admin
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: userId, role: "member" });

    const client = await userClient(trainerEmail);
    await removeMembership(client, studioId, userId);

    const { data } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("studio_id", studioId)
      .eq("user_id", userId);
    expect(data).toEqual([]);
  });

  it("lehnt den Inhaber als Ziel ab", async () => {
    const client = await userClient(trainerEmail);
    await expect(removeMembership(client, studioId, ownerId)).rejects.toMatchObject({
      code: "not_found",
    });
  });
});
