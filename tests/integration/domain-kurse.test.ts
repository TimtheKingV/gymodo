import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  createCourseTemplate,
  getCourseTemplate,
  listCourseTemplates,
  updateCourseTemplate,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Die Fachschicht der Kurse gegen echtes Postgres und echte RLS.
 * Mocks ersetzen das nicht (M1-Spec 11).
 */

let studioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let trainerId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error } = await admin
    .from("studios")
    .insert({ name: "Fachschicht-Kurse", timezone: "Europe/Berlin" })
    .select("id")
    .single();
  if (error) throw error;
  studioId = studio.id;

  trainerEmail = uniqueEmail("fk-trainer");
  mitgliedEmail = uniqueEmail("fk-mitglied");
  trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);

  const { error: mFehler } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
  ]);
  if (mFehler) throw mFehler;
});

describe("Kursvorlagen", () => {
  it("ein Trainer legt eine Vorlage an und liest sie zurueck", async () => {
    const client = await userClient(trainerEmail);
    const id = await createCourseTemplate(client, studioId, {
      name: "Kraftzirkel",
      description: "Zirkeltraining aus Kraft- und Ausdaueruebungen im Wechsel.",
      defaultDurationMin: 60,
      defaultCapacity: 16,
      defaultInstructorUserId: trainerId,
      defaultInstructorName: "Marek T.",
    });

    const vorlage = await getCourseTemplate(client, studioId, id);
    expect(vorlage.name).toBe("Kraftzirkel");
    expect(vorlage.defaultCapacity).toBe(16);
    expect(vorlage.defaultInstructorName).toBe("Marek T.");
    expect(vorlage.photoPath).toBeNull();
  });

  it("ein Mitglied legt keine an", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(
      createCourseTemplate(client, studioId, {
        name: "Heimlich",
        description: null,
        defaultDurationMin: 30,
        defaultCapacity: 5,
        defaultInstructorUserId: null,
        defaultInstructorName: null,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("ein leerer Name wird abgewiesen, bevor die Datenbank ihn sieht", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      createCourseTemplate(client, studioId, {
        name: "   ",
        description: null,
        defaultDurationMin: 60,
        defaultCapacity: 16,
        defaultInstructorUserId: null,
        defaultInstructorName: null,
      }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("eine Kapazitaet von 0 wird abgewiesen -- ein Kurs ohne Platz ist keiner", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      createCourseTemplate(client, studioId, {
        name: "Leerkurs",
        description: null,
        defaultDurationMin: 60,
        defaultCapacity: 0,
        defaultInstructorUserId: null,
        defaultInstructorName: null,
      }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("ein Standard-Trainer, der nicht Personal dieses Studios ist, wird abgewiesen", async () => {
    // Die Datenbank erzwingt das nicht (0035, Kommentar an
    // default_instructor_user_id) -- die Fachschicht schon.
    const client = await userClient(trainerEmail);
    const fremdId = await createTestUser(uniqueEmail("fk-fremder"));
    await expect(
      createCourseTemplate(client, studioId, {
        name: "Fremdtrainer",
        description: null,
        defaultDurationMin: 60,
        defaultCapacity: 16,
        defaultInstructorUserId: fremdId,
        defaultInstructorName: "Wer auch immer",
      }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("die Liste kommt nach Namen sortiert", async () => {
    const client = await userClient(trainerEmail);
    await createCourseTemplate(client, studioId, {
      name: "Aqua",
      description: null,
      defaultDurationMin: 45,
      defaultCapacity: 10,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    const liste = await listCourseTemplates(client, studioId);
    const namen = liste.map((v) => v.name);
    expect(namen).toEqual([...namen].sort((a, b) => a.localeCompare(b, "de")));
  });

  it("aendern geht, und die Aenderung kommt zurueck", async () => {
    const client = await userClient(trainerEmail);
    const id = await createCourseTemplate(client, studioId, {
      name: "Yoga Flow",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 10,
      defaultInstructorUserId: null,
      defaultInstructorName: "Anna B.",
    });
    await updateCourseTemplate(client, studioId, id, {
      name: "Yoga Flow",
      description: "Ruhig, mit langen Haltephasen.",
      defaultDurationMin: 75,
      defaultCapacity: 12,
      defaultInstructorUserId: null,
      defaultInstructorName: "Anna B.",
    });
    const vorlage = await getCourseTemplate(client, studioId, id);
    expect(vorlage.defaultDurationMin).toBe(75);
    expect(vorlage.description).toBe("Ruhig, mit langen Haltephasen.");
  });

  it("eine Vorlage, die es nicht gibt, liefert not_found", async () => {
    const client = await userClient(trainerEmail);
    await expect(
      getCourseTemplate(client, studioId, crypto.randomUUID()),
    ).rejects.toMatchObject({ code: "not_found" });
  });
});
