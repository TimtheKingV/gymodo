import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Kurse, Spec 2026-09-03-kurse-design.md Abschnitt 3.
 *
 * Diese Datei haelt die Policy-Matrix. Der wichtigste Teil steht ganz
 * unten und prueft eine ABWESENHEIT: course_bookings hat keine Insert-,
 * Update- und Delete-Policy, und genau das macht die Zeilensperre aus
 * 0036 zu einer Garantie statt zu einer Zierde (Spec Abschnitt 2).
 */

let studioId: string;
let fremdStudioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let zweitMitgliedEmail: string;
let fremdTrainerEmail: string;
let mitgliedId: string;
let zweitMitgliedId: string;
let vorlageId: string;
let terminId: string;

/** Immer weit in der Zukunft -- sonst greift die Vergangenheitsregel. */
function inTagen(tage: number): string {
  return new Date(Date.now() + tage * 24 * 60 * 60 * 1000).toISOString();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Kurse-Studio" }, { name: "Fremdes Kurse-Studio" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioId = studios[0]!.id;
  fremdStudioId = studios[1]!.id;

  trainerEmail = uniqueEmail("kurs-trainer");
  mitgliedEmail = uniqueEmail("kurs-mitglied");
  zweitMitgliedEmail = uniqueEmail("kurs-mitglied2");
  fremdTrainerEmail = uniqueEmail("kurs-fremd");

  const trainerId = await createTestUser(trainerEmail);
  mitgliedId = await createTestUser(mitgliedEmail);
  zweitMitgliedId = await createTestUser(zweitMitgliedEmail);
  const fremdTrainerId = await createTestUser(fremdTrainerEmail);

  const { error: mitgliedFehler } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: studioId, user_id: zweitMitgliedId, role: "member" },
    { studio_id: fremdStudioId, user_id: fremdTrainerId, role: "trainer" },
  ]);
  if (mitgliedFehler) throw mitgliedFehler;

  const { data: vorlage, error: vorlageFehler } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name: "Kraftzirkel",
      description: "Zirkeltraining aus Kraft- und Ausdaueruebungen im Wechsel.",
      default_duration_min: 60,
      default_capacity: 16,
    })
    .select("id")
    .single();
  if (vorlageFehler) throw vorlageFehler;
  vorlageId = vorlage.id;

  const { data: termin, error: terminFehler } = await admin
    .from("course_sessions")
    .insert({
      studio_id: studioId,
      course_template_id: vorlageId,
      starts_at: inTagen(7),
      duration_min: 60,
      capacity: 16,
      room: "Kursraum 2",
      instructor_name: "Marek T.",
    })
    .select("id")
    .single();
  if (terminFehler) throw terminFehler;
  terminId = termin.id;

  // Eine Buchung, die es nur ueber Service-Role gibt -- ueber die
  // Policies waere sie nicht anlegbar, und genau das prueft der letzte
  // Block dieser Datei.
  const { error: buchungFehler } = await admin.from("course_bookings").insert({
    id: crypto.randomUUID(),
    studio_id: studioId,
    course_session_id: terminId,
    user_id: mitgliedId,
    status: "booked",
  });
  if (buchungFehler) throw buchungFehler;
});

describe("course_templates", () => {
  it("ein Mitglied liest die Vorlagen seines Studios -- die Member-App braucht Name und Beschreibung", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client.from("course_templates").select("id, name").eq("id", vorlageId);
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
  });

  it("ein fremder Trainer sieht sie nicht", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data } = await client.from("course_templates").select("id").eq("id", vorlageId);
    expect(data).toEqual([]);
  });

  it("ein Mitglied legt keine Vorlage an", async () => {
    const client = await userClient(mitgliedEmail);
    const { error } = await client.from("course_templates").insert({
      studio_id: studioId,
      name: "Heimlich",
      default_duration_min: 30,
      default_capacity: 5,
    });
    expect(error).not.toBeNull();
  });

  it("ein Trainer legt eine Vorlage an", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.from("course_templates").insert({
      studio_id: studioId,
      name: "Rueckenfit",
      default_duration_min: 45,
      default_capacity: 12,
    });
    expect(error).toBeNull();
  });

  it("ein Trainer legt keine Vorlage in ein fremdes Studio -- Cross-Tenant", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.from("course_templates").insert({
      studio_id: fremdStudioId,
      name: "Uebergriff",
      default_duration_min: 45,
      default_capacity: 12,
    });
    expect(error).not.toBeNull();
  });

  it("ein Trainer aendert die Vorlage seines Studios, ein Mitglied nicht", async () => {
    const trainer = await userClient(trainerEmail);
    const { data: geaendert, error } = await trainer
      .from("course_templates")
      .update({ default_capacity: 18 })
      .eq("id", vorlageId)
      .select("default_capacity");
    expect(error).toBeNull();
    expect(geaendert).toEqual([{ default_capacity: 18 }]);

    const mitglied = await userClient(mitgliedEmail);
    const { data: nichts } = await mitglied
      .from("course_templates")
      .update({ default_capacity: 99 })
      .eq("id", vorlageId)
      .select("id");
    expect(nichts).toEqual([]);
  });

  it("ein fremder Trainer aendert die Vorlage nicht -- Cross-Tenant", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data } = await client
      .from("course_templates")
      .update({ default_capacity: 99 })
      .eq("id", vorlageId)
      .select("id");
    expect(data).toEqual([]);
  });

  it("kein Loeschpfad -- auch nicht fuer den Trainer", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.from("course_templates").delete().eq("id", vorlageId).select("id");
    expect(data).toEqual([]);
  });
});

describe("course_sessions", () => {
  it("ein Mitglied liest die Termine seines Studios", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client.from("course_sessions").select("id, room").eq("id", terminId);
    expect(error).toBeNull();
    expect(data).toEqual([{ id: terminId, room: "Kursraum 2" }]);
  });

  it("ein fremder Trainer sieht sie nicht -- Cross-Tenant", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data } = await client.from("course_sessions").select("id").eq("id", terminId);
    expect(data).toEqual([]);
  });

  it("ein Mitglied legt keinen Termin an, ein Trainer schon", async () => {
    const mitglied = await userClient(mitgliedEmail);
    const { error: abgelehnt } = await mitglied.from("course_sessions").insert({
      studio_id: studioId,
      course_template_id: vorlageId,
      starts_at: inTagen(8),
      duration_min: 60,
      capacity: 16,
    });
    expect(abgelehnt).not.toBeNull();

    const trainer = await userClient(trainerEmail);
    const { error: erlaubt } = await trainer.from("course_sessions").insert({
      studio_id: studioId,
      course_template_id: vorlageId,
      starts_at: inTagen(9),
      duration_min: 60,
      capacity: 16,
    });
    expect(erlaubt).toBeNull();
  });

  it("ein Trainer legt keinen Termin in ein fremdes Studio -- Cross-Tenant", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.from("course_sessions").insert({
      studio_id: fremdStudioId,
      course_template_id: vorlageId,
      starts_at: inTagen(11),
      duration_min: 60,
      capacity: 16,
    });
    expect(error).not.toBeNull();
  });

  it("ein Trainer sagt ab; der Zeitpunkt gehoert zum Status", async () => {
    const trainer = await userClient(trainerEmail);
    const { data: termin } = await trainer
      .from("course_sessions")
      .insert({
        studio_id: studioId,
        course_template_id: vorlageId,
        starts_at: inTagen(10),
        duration_min: 60,
        capacity: 16,
      })
      .select("id")
      .single();

    // Status ohne Zeitpunkt prallt an der Constraint ab.
    const { error: halb } = await trainer
      .from("course_sessions")
      .update({ status: "cancelled" })
      .eq("id", termin!.id);
    expect(halb).not.toBeNull();

    const { error: ganz } = await trainer
      .from("course_sessions")
      .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", termin!.id);
    expect(ganz).toBeNull();
  });

  it("ein Mitglied aendert keinen Termin", async () => {
    const client = await userClient(mitgliedEmail);
    const { data } = await client
      .from("course_sessions")
      .update({ room: "Heimlich umgebucht" })
      .eq("id", terminId)
      .select("id");
    expect(data).toEqual([]);
  });

  it("ein fremder Trainer aendert keinen Termin -- Cross-Tenant", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data } = await client
      .from("course_sessions")
      .update({ room: "Fremdzugriff" })
      .eq("id", terminId)
      .select("id");
    expect(data).toEqual([]);
  });

  it("kein Loeschpfad -- Absage statt Loeschen", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.from("course_sessions").delete().eq("id", terminId).select("id");
    expect(data).toEqual([]);
  });
});

describe("course_bookings -- die Datenschutzgrenze", () => {
  it("ein Mitglied sieht die eigene Buchung", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client
      .from("course_bookings")
      .select("id, status")
      .eq("course_session_id", terminId);
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data![0]!.status).toBe("booked");
  });

  it("ein anderes Mitglied sieht sie NICHT -- die Teilnehmerliste gehoert dem Studio", async () => {
    const client = await userClient(zweitMitgliedEmail);
    const { data } = await client.from("course_bookings").select("id").eq("course_session_id", terminId);
    expect(data).toEqual([]);
  });

  it("ein Trainer sieht die Teilnehmerliste", async () => {
    const client = await userClient(trainerEmail);
    const { data } = await client.from("course_bookings").select("id").eq("course_session_id", terminId);
    expect(data).toHaveLength(1);
  });

  it("ein fremder Trainer sieht nichts -- Cross-Tenant", async () => {
    const client = await userClient(fremdTrainerEmail);
    const { data } = await client.from("course_bookings").select("id").eq("course_session_id", terminId);
    expect(data).toEqual([]);
  });
});

describe("course_bookings -- die gepruefte Abwesenheit", () => {
  /**
   * Diese vier Tests pruefen, dass es KEINE Policy gibt. Ohne sie waere
   * die Zeilensperre aus 0036 wertlos: ein Mitglied schriebe sich
   * 'booked' selbst und ginge an der Kapazitaet vorbei.
   */
  it("ein Mitglied legt keine Buchung an -- auch nicht fuer sich selbst", async () => {
    const client = await userClient(zweitMitgliedEmail);
    const { error } = await client.from("course_bookings").insert({
      id: crypto.randomUUID(),
      studio_id: studioId,
      course_session_id: terminId,
      user_id: zweitMitgliedId,
      status: "booked",
    });
    expect(error).not.toBeNull();
  });

  it("ein Trainer legt auch keine an -- der Weg fuehrt ausschliesslich ueber die Funktion", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.from("course_bookings").insert({
      id: crypto.randomUUID(),
      studio_id: studioId,
      course_session_id: terminId,
      user_id: zweitMitgliedId,
      status: "booked",
    });
    expect(error).not.toBeNull();
  });

  it("ein Mitglied schreibt die eigene Buchung nicht um", async () => {
    const client = await userClient(mitgliedEmail);
    const { data } = await client
      .from("course_bookings")
      .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("course_session_id", terminId)
      .select("id");
    expect(data).toEqual([]);
  });

  it("ein Mitglied loescht die eigene Buchung nicht -- Historie bleibt", async () => {
    const client = await userClient(mitgliedEmail);
    const { data } = await client
      .from("course_bookings")
      .delete()
      .eq("course_session_id", terminId)
      .select("id");
    expect(data).toEqual([]);
  });
});
