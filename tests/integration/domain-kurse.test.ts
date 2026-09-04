import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  bookCourseSession,
  cancelCourseBooking,
  cancelCourseSession,
  createCourseSessions,
  createCourseTemplate,
  getCourseTemplate,
  listCourseParticipants,
  listCourseTemplates,
  listCourseWeek,
  updateCourseSession,
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
let mitgliedId: string;

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
  mitgliedId = await createTestUser(mitgliedEmail);

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

  it("ein Mitglied DIESES Studios ohne Personal-Rolle wird als Standard-Trainer abgewiesen", async () => {
    // Anders als der vorige Test: die Zeile fuer (studioId, userId)
    // EXISTIERT hier -- role ist bloss "member", nicht "trainer" oder
    // "owner". pruefeTrainerZuordnung ist die einzige Stelle des Systems,
    // die diese Regel prueft (0035 kann es nicht); ein ungeprüfter Zweig
    // waere eine unbewachte Regel.
    const client = await userClient(trainerEmail);
    await expect(
      createCourseTemplate(client, studioId, {
        name: "Mitglied als Trainer",
        description: null,
        defaultDurationMin: 60,
        defaultCapacity: 16,
        defaultInstructorUserId: mitgliedId,
        defaultInstructorName: "Wer auch immer",
      }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("Personal eines ANDEREN Studios wird als Standard-Trainer abgewiesen", async () => {
    // Die Zeile fuer (studioId, userId) FEHLT hier -- die Person ist
    // Trainer, aber anderswo. Der dritte und letzte Zweig von
    // pruefeTrainerZuordnung.
    const admin = serviceClient();
    const { data: anderesStudio } = await admin
      .from("studios")
      .insert({ name: "Anderes Fachschicht-Studio" })
      .select("id")
      .single();
    const anderswoTrainerId = await createTestUser(uniqueEmail("fk-anderswo-trainer"));
    await admin
      .from("studio_memberships")
      .insert({ studio_id: anderesStudio!.id, user_id: anderswoTrainerId, role: "trainer" });

    const client = await userClient(trainerEmail);
    await expect(
      createCourseTemplate(client, studioId, {
        name: "Trainer von woanders",
        description: null,
        defaultDurationMin: 60,
        defaultCapacity: 16,
        defaultInstructorUserId: anderswoTrainerId,
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

  it("aendern laesst eine gesetzte Standard-Trainer-Zuordnung unangetastet", async () => {
    // Kein Formular dieser Phase kann default_instructor_user_id setzen
    // (kurse-actions.ts liest kein trainerId-Feld beim Speichern) --
    // deshalb setzt hier die Serviceschicht die Zuordnung, so wie es
    // spaeter eine Trainerauswahl taete.
    const admin = serviceClient();
    const client = await userClient(trainerEmail);
    const id = await createCourseTemplate(client, studioId, {
      name: "Mit Zuordnung",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 10,
      defaultInstructorUserId: null,
      defaultInstructorName: "Anna B.",
    });
    const { error: setzFehler } = await admin
      .from("course_templates")
      .update({ default_instructor_user_id: trainerId })
      .eq("id", id);
    if (setzFehler) throw setzFehler;

    await updateCourseTemplate(client, studioId, id, {
      name: "Mit Zuordnung",
      description: "Andere Felder aendern sich, die Zuordnung nicht.",
      defaultDurationMin: 75,
      defaultCapacity: 12,
      defaultInstructorName: "Anna B.",
    });

    const { data: zeile, error: leseFehler } = await admin
      .from("course_templates")
      .select("default_instructor_user_id")
      .eq("id", id)
      .single();
    if (leseFehler) throw leseFehler;
    expect(zeile.default_instructor_user_id).toBe(trainerId);
  });
});

describe("Termine und die Serie", () => {
  it("legt die Serie aus dem Artboard an -- 14 Termine, alle mit den Werten der Vorlage", async () => {
    const client = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(client, studioId, {
      name: "Serienkurs",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 16,
      defaultInstructorUserId: null,
      defaultInstructorName: "Marek T.",
    });

    const ids = await createCourseSessions(
      client,
      studioId,
      {
        templateId: vorlageId,
        startsAt: "2026-09-03T16:00:00Z",
        durationMin: 60,
        capacity: 16,
        room: "Kursraum 2",
        instructorUserId: null,
        instructorName: "Marek T.",
      },
      "2026-12-03T16:00:00Z",
    );
    expect(ids).toHaveLength(14);

    const woche = await listCourseWeek(
      client,
      studioId,
      "2026-09-01T00:00:00Z",
      "2026-09-08T00:00:00Z",
    );
    const angelegt = woche.sessions.find((s) => s.sessionId === ids[0]);
    expect(angelegt!.capacity).toBe(16);
    expect(angelegt!.room).toBe("Kursraum 2");
    expect(angelegt!.instructorName).toBe("Marek T.");
    expect(angelegt!.status).toBe("planned");
  });

  it("eine spaetere Aenderung an der Vorlage laesst bestehende Termine unberuehrt", async () => {
    const client = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(client, studioId, {
      name: "Unberuehrt",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 16,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    const [terminId] = await createCourseSessions(
      client,
      studioId,
      {
        templateId: vorlageId,
        startsAt: "2026-09-17T16:00:00Z",
        durationMin: 60,
        capacity: 16,
        room: null,
        instructorUserId: null,
        instructorName: null,
      },
      null,
    );

    await updateCourseTemplate(client, studioId, vorlageId, {
      name: "Unberuehrt",
      description: null,
      defaultDurationMin: 30,
      defaultCapacity: 4,
      defaultInstructorName: null,
    });

    const woche = await listCourseWeek(
      client,
      studioId,
      "2026-09-15T00:00:00Z",
      "2026-09-22T00:00:00Z",
    );
    const termin = woche.sessions.find((s) => s.sessionId === terminId);
    expect(termin!.capacity).toBe(16);
    expect(termin!.durationMin).toBe(60);
  });

  it("ein Mitglied legt keinen Termin an", async () => {
    const client = await userClient(mitgliedEmail);
    const trainer = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(trainer, studioId, {
      name: "Gesperrt",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 8,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    await expect(
      createCourseSessions(
        client,
        studioId,
        {
          templateId: vorlageId,
          startsAt: "2026-09-24T16:00:00Z",
          durationMin: 60,
          capacity: 8,
          room: null,
          instructorUserId: null,
          instructorName: null,
        },
        null,
      ),
    ).rejects.toMatchObject({ code: "unauthorized" });
  });

  it("ein Termin darf nicht auf eine Vorlage eines FREMDEN Studios zeigen", async () => {
    // RLS prueft nur studio_id des Termins; die Foreign Key auf
    // course_templates prueft bloss, dass die Zeile EXISTIERT, nicht in
    // welchem Studio. Ohne diese Pruefung koennte Personal von Studio A
    // einen Termin anlegen, der auf eine Vorlage von Studio B zeigt --
    // und course_week gibt deren name/description an jedes Mitglied von
    // A weiter.
    const admin = serviceClient();
    const { data: fremdStudio } = await admin
      .from("studios")
      .insert({ name: "Fremdes Vorlagenstudio" })
      .select("id")
      .single();
    const { data: fremdVorlage } = await admin
      .from("course_templates")
      .insert({
        studio_id: fremdStudio!.id,
        name: "Geheime Vorlage von B",
        default_duration_min: 60,
        default_capacity: 8,
      })
      .select("id")
      .single();

    const trainer = await userClient(trainerEmail);
    await expect(
      createCourseSessions(
        trainer,
        studioId,
        {
          templateId: fremdVorlage!.id,
          startsAt: "2026-09-24T16:00:00Z",
          durationMin: 60,
          capacity: 8,
          room: null,
          instructorUserId: null,
          instructorName: null,
        },
        null,
      ),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("aendern laesst eine gesetzte Trainer-Zuordnung des Termins unangetastet", async () => {
    // Kein Formular dieser Phase kann instructor_user_id setzen
    // (kurse-actions.ts liest kein trainerId-Feld beim Speichern) --
    // deshalb setzt hier die Serviceschicht die Zuordnung, so wie es
    // spaeter eine Trainerauswahl taete.
    const admin = serviceClient();
    const client = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(client, studioId, {
      name: "Mit Trainer",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 8,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    const [terminId] = await createCourseSessions(
      client,
      studioId,
      {
        templateId: vorlageId,
        startsAt: "2026-10-08T16:00:00Z",
        durationMin: 60,
        capacity: 8,
        room: null,
        instructorUserId: null,
        instructorName: null,
      },
      null,
    );
    const { error: setzFehler } = await admin
      .from("course_sessions")
      .update({ instructor_user_id: trainerId })
      .eq("id", terminId!);
    if (setzFehler) throw setzFehler;

    await updateCourseSession(client, studioId, terminId!, {
      startsAt: "2026-10-08T17:00:00Z",
      durationMin: 90,
      capacity: 10,
      room: "Kursraum 3",
      instructorName: "Marek T.",
    });

    const { data: zeile, error: leseFehler } = await admin
      .from("course_sessions")
      .select("instructor_user_id")
      .eq("id", terminId!)
      .single();
    if (leseFehler) throw leseFehler;
    expect(zeile.instructor_user_id).toBe(trainerId);
  });

  it("absagen setzt Status und Zeitpunkt gemeinsam", async () => {
    const client = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(client, studioId, {
      name: "Faellt aus",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 8,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    const [terminId] = await createCourseSessions(
      client,
      studioId,
      {
        templateId: vorlageId,
        startsAt: "2026-10-01T16:00:00Z",
        durationMin: 60,
        capacity: 8,
        room: null,
        instructorUserId: null,
        instructorName: null,
      },
      null,
    );

    await cancelCourseSession(client, studioId, terminId!);

    const woche = await listCourseWeek(
      client,
      studioId,
      "2026-09-29T00:00:00Z",
      "2026-10-06T00:00:00Z",
    );
    expect(woche.sessions.find((s) => s.sessionId === terminId)!.status).toBe("cancelled");
  });

  it("ein unbrauchbares Wiederholungsende wird abgewiesen, statt tief in der Rechnung abzustuerzen", async () => {
    const client = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(client, studioId, {
      name: "Kaputtes Ende",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 8,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });

    await expect(
      createCourseSessions(
        client,
        studioId,
        {
          templateId: vorlageId,
          startsAt: "2026-11-05T17:00:00.000Z",
          durationMin: 60,
          capacity: 8,
          room: null,
          instructorUserId: null,
          instructorName: null,
        },
        "kein Datum",
      ),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });
});

describe("Buchen und Stornieren durch die Fachschicht", () => {
  it("anmelden, nachsehen, abmelden", async () => {
    const trainer = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(trainer, studioId, {
      name: "Buchbar",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 1,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    const inDreiTagen = new Date(Date.now() + 3 * 86_400_000).toISOString();
    const [terminId] = await createCourseSessions(
      trainer,
      studioId,
      {
        templateId: vorlageId,
        startsAt: inDreiTagen,
        durationMin: 60,
        capacity: 1,
        room: null,
        instructorUserId: null,
        instructorName: null,
      },
      null,
    );

    const mitglied = await userClient(mitgliedEmail);
    const gebucht = await bookCourseSession(mitglied, terminId!, crypto.randomUUID());
    expect(gebucht.result).toBe("booked");
    expect(gebucht.created).toBe(true);
    expect(gebucht.freeSeats).toBe(0);

    const teilnehmer = await listCourseParticipants(trainer, terminId!);
    expect(teilnehmer).toHaveLength(1);
    expect(teilnehmer[0]!.email).toBe(mitgliedEmail);

    const storniert = await cancelCourseBooking(mitglied, terminId!);
    expect(storniert.promotedUserId).toBeNull();
  });

  it("nach der Frist kommt ein deutscher Satz, kein Datenbankfehler", async () => {
    const trainer = await userClient(trainerEmail);
    const vorlageId = await createCourseTemplate(trainer, studioId, {
      name: "Knapp",
      description: null,
      defaultDurationMin: 60,
      defaultCapacity: 5,
      defaultInstructorUserId: null,
      defaultInstructorName: null,
    });
    const inEinerStunde = new Date(Date.now() + 3_600_000).toISOString();
    const [terminId] = await createCourseSessions(
      trainer,
      studioId,
      {
        templateId: vorlageId,
        startsAt: inEinerStunde,
        durationMin: 60,
        capacity: 5,
        room: null,
        instructorUserId: null,
        instructorName: null,
      },
      null,
    );

    const mitglied = await userClient(mitgliedEmail);
    await bookCourseSession(mitglied, terminId!, crypto.randomUUID());

    await expect(cancelCourseBooking(mitglied, terminId!)).rejects.toMatchObject({
      code: "conflict",
    });
    await expect(cancelCourseBooking(mitglied, terminId!)).rejects.toThrow(/2 Stunden/);
  });

  it("ein Termin aus einem fremden Studio liefert not_found, nicht forbidden", async () => {
    const admin = serviceClient();
    const { data: fremdStudio } = await admin
      .from("studios")
      .insert({ name: "Fremdes Buchstudio" })
      .select("id")
      .single();
    const { data: fremdVorlage } = await admin
      .from("course_templates")
      .insert({
        studio_id: fremdStudio!.id,
        name: "Fremd",
        default_duration_min: 60,
        default_capacity: 5,
      })
      .select("id")
      .single();
    const { data: fremdTermin } = await admin
      .from("course_sessions")
      .insert({
        studio_id: fremdStudio!.id,
        course_template_id: fremdVorlage!.id,
        starts_at: new Date(Date.now() + 86_400_000).toISOString(),
        duration_min: 60,
        capacity: 5,
      })
      .select("id")
      .single();

    const mitglied = await userClient(mitgliedEmail);
    await expect(
      bookCourseSession(mitglied, fremdTermin!.id, crypto.randomUUID()),
    ).rejects.toMatchObject({ code: "not_found" });
  });
});
