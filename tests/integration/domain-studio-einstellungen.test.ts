import { beforeAll, describe, expect, it } from "vitest";
import { DomainError, getStudioSettings, updateStudioSettings } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

let studioId: string;
let trainerEmail: string;
let mitgliedEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Fachschicht-Einstellungen" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  trainerEmail = uniqueEmail("fach-einst-trainer");
  mitgliedEmail = uniqueEmail("fach-einst-mitglied");
  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
  if (error) throw error;
});

describe("getStudioSettings", () => {
  it("liefert Stammdaten, Frist und Code in einem Rutsch", async () => {
    const client = await userClient(trainerEmail);
    const einstellungen = await getStudioSettings(client, studioId);

    expect(einstellungen.name).toBe("Fachschicht-Einstellungen");
    expect(einstellungen.timezone).toBe("Europe/Berlin");
    expect(einstellungen.cancellationDeadlineHours).toBe(2);
    expect(einstellungen.joinCode).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);
    expect(einstellungen.joinCodeActive).toBe(true);
  });

  it("ein Mitglied bekommt eine Absage, keine Daten", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(getStudioSettings(client, studioId)).rejects.toThrow(DomainError);
  });

  it("die Absage nennt die Einstellungen, nicht den Geraetekatalog", async () => {
    const client = await userClient(mitgliedEmail);
    const erwarteteMeldung = "Nur Trainer und Inhaber sehen und aendern die Studio-Einstellungen.";

    await expect(getStudioSettings(client, studioId)).rejects.toThrow(erwarteteMeldung);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Sollte nicht ankommen",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(erwarteteMeldung);
  });
});

describe("updateStudioSettings", () => {
  it("speichert Name, Zeitzone und Frist", async () => {
    const client = await userClient(trainerEmail);
    await updateStudioSettings(client, studioId, {
      name: "Kraftwerk Süd",
      timezone: "Europe/Zurich",
      cancellationDeadlineHours: 12,
    });

    const danach = await getStudioSettings(client, studioId);
    expect(danach.name).toBe("Kraftwerk Süd");
    expect(danach.timezone).toBe("Europe/Zurich");
    expect(danach.cancellationDeadlineHours).toBe(12);
  });

  it("ein leerer Name sagt, was gilt -- nicht nur, dass es nicht ging", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "   ",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(/Name/);
  });

  it("eine Frist jenseits einer Woche wird vor der Datenbank abgefangen", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Kraftwerk Süd",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 169,
      }),
    ).rejects.toThrow(/168|Woche/);
  });

  it("eine unbekannte Zeitzone wird abgewiesen", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Kraftwerk Süd",
        timezone: "Mond/Krater",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(/Zeitzone/);
  });

  it("ein Mitglied speichert nicht", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(
      updateStudioSettings(client, studioId, {
        name: "Von einem Mitglied",
        timezone: "Europe/Berlin",
        cancellationDeadlineHours: 2,
      }),
    ).rejects.toThrow(DomainError);
  });
});
