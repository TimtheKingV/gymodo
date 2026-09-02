import { beforeAll, describe, expect, it } from "vitest";
import { getStudioOverview } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let trainerEmail: string;
let mitgliedEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error } = await admin
    .from("studios")
    .insert({ name: "Fachschicht-Ueberblick" })
    .select("id")
    .single();
  if (error) throw error;
  studioId = studio.id;

  trainerEmail = uniqueEmail("fach-ueb-trainer");
  mitgliedEmail = uniqueEmail("fach-ueb-mitglied");
  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);

  await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
});

describe("getStudioOverview", () => {
  it("ein leeres Studio liefert Nullen und keine Aufschluesselung", async () => {
    const client = await userClient(trainerEmail);
    const uebersicht = await getStudioOverview(client, studioId);

    expect(uebersicht).not.toBeNull();
    expect(uebersicht!.activeMembers).toBe(0);
    expect(uebersicht!.sets).toBe(0);
    expect(uebersicht!.problemReports).toBe(0);
    expect(uebersicht!.breakdown).toBe(false);
    expect(uebersicht!.minMembers).toBe(5);
    expect(uebersicht!.topMachines).toEqual([]);
  });

  it("ein Mitglied bekommt null statt eines Fehlers", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(getStudioOverview(client, studioId)).resolves.toBeNull();
  });

  it("der Zeitraum reist mit", async () => {
    const client = await userClient(trainerEmail);
    const uebersicht = await getStudioOverview(client, studioId, 7);
    expect(uebersicht!.days).toBe(7);
  });
});
