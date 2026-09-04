import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Die Lesepfade, Spec 2026-09-03-kurse-design.md Abschnitt 5.
 *
 * course_week ist die einzige Stelle, an der ein Mitglied die Belegung
 * eines Termins erfaehrt -- als ZAHL. Die Zeilen dahinter bleiben ihm
 * verschlossen.
 */

let studioId: string;
let trainerEmail: string;
let mitgliedEmail: string;
let zweitMitgliedEmail: string;
let fremdEmail: string;
let vorlageId: string;
let terminId: string;

const VON = "2026-10-19T00:00:00Z";
const BIS = "2026-11-02T00:00:00Z";

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioFehler } = await admin
    .from("studios")
    .insert({ name: "Lesen-Studio", timezone: "Europe/Berlin" })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;
  studioId = studio.id;

  const { data: fremdStudio } = await admin
    .from("studios")
    .insert({ name: "Fremdes Lesen-Studio" })
    .select("id")
    .single();

  trainerEmail = uniqueEmail("lesen-trainer");
  mitgliedEmail = uniqueEmail("lesen-mitglied");
  zweitMitgliedEmail = uniqueEmail("lesen-mitglied2");
  fremdEmail = uniqueEmail("lesen-fremd");

  const trainerId = await createTestUser(trainerEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const zweitId = await createTestUser(zweitMitgliedEmail);
  const fremdId = await createTestUser(fremdEmail);

  const { error } = await admin.from("studio_memberships").insert([
    { studio_id: studioId, user_id: trainerId, role: "trainer" },
    { studio_id: studioId, user_id: mitgliedId, role: "member" },
    { studio_id: studioId, user_id: zweitId, role: "member" },
    { studio_id: fremdStudio!.id, user_id: fremdId, role: "member" },
  ]);
  if (error) throw error;

  const { data: vorlage } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name: "Kraftzirkel",
      description: "Sechs Stationen im Wechsel.",
      default_duration_min: 60,
      default_capacity: 16,
    })
    .select("id")
    .single();
  vorlageId = vorlage!.id;

  // Zwei Termine, beide 18:00 Ortszeit Berlin -- einer VOR, einer NACH
  // der Zeitumstellung am 25. Oktober 2026. In UTC sind das 16:00 und
  // 17:00; in local_day muss jeder auf seinem eigenen Tag liegen.
  const { data: termine } = await admin
    .from("course_sessions")
    .insert([
      {
        studio_id: studioId,
        course_template_id: vorlageId,
        starts_at: "2026-10-22T16:00:00Z",
        duration_min: 60,
        capacity: 2,
        room: "Kursraum 2",
        instructor_name: "Marek T.",
      },
      {
        studio_id: studioId,
        course_template_id: vorlageId,
        starts_at: "2026-10-29T17:00:00Z",
        duration_min: 60,
        capacity: 16,
        room: "Kursraum 2",
        instructor_name: "Marek T.",
      },
    ])
    .select("id, starts_at")
    .order("starts_at");
  terminId = termine![0]!.id;
});

describe("course_week", () => {
  it("liefert die Termine der Woche mit der Belegung als Zahl", async () => {
    const client = await userClient(mitgliedEmail);
    const { data, error } = await client.rpc("course_week", {
      p_studio_id: studioId,
      p_from: VON,
      p_to: BIS,
    });
    expect(error).toBeNull();
    expect(data.sessions).toHaveLength(2);
    expect(data.timezone).toBe("Europe/Berlin");

    const erster = data.sessions[0];
    expect(erster.name).toBe("Kraftzirkel");
    expect(erster.room).toBe("Kursraum 2");
    expect(erster.instructor_name).toBe("Marek T.");
    expect(erster.capacity).toBe(2);
    expect(erster.booked_count).toBe(0);
    expect(erster.free_seats).toBe(2);
    expect(erster.own_status).toBeNull();
  });

  it("beide 18:00-Termine liegen an ihrem eigenen Ortstag -- die Zeitumstellung verschiebt keinen", async () => {
    const client = await userClient(mitgliedEmail);
    const { data } = await client.rpc("course_week", {
      p_studio_id: studioId,
      p_from: VON,
      p_to: BIS,
    });
    // 22.10. ist Sommerzeit (16:00 UTC = 18:00 MESZ),
    // 29.10. ist Winterzeit (17:00 UTC = 18:00 MEZ).
    expect(data.sessions.map((s: { local_day: string }) => s.local_day)).toEqual([
      "2026-10-22",
      "2026-10-29",
    ]);
  });

  it("zaehlt Gebuchte und Wartende getrennt und zeigt die EIGENE Buchung", async () => {
    const erster = await userClient(mitgliedEmail);
    const zweiter = await userClient(zweitMitgliedEmail);

    await erster.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    await zweiter.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const dritterEmail = uniqueEmail("lesen-dritter");
    const dritterId = await createTestUser(dritterEmail);
    await serviceClient()
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: dritterId, role: "member" });
    const dritter = await userClient(dritterEmail);
    await dritter.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const { data } = await dritter.rpc("course_week", {
      p_studio_id: studioId,
      p_from: VON,
      p_to: BIS,
    });
    const termin = data.sessions.find(
      (s: { session_id: string }) => s.session_id === terminId,
    );
    expect(termin.booked_count).toBe(2);
    expect(termin.waitlist_count).toBe(1);
    expect(termin.free_seats).toBe(0);
    expect(termin.own_status).toBe("waitlisted");
    expect(termin.own_waitlist_position).toBe(1);

    // Derselbe Termin aus der Sicht des ersten -- mit SEINER Buchung.
    const { data: ausSicht1 } = await erster.rpc("course_week", {
      p_studio_id: studioId,
      p_from: VON,
      p_to: BIS,
    });
    const terminA = ausSicht1.sessions.find(
      (s: { session_id: string }) => s.session_id === terminId,
    );
    expect(terminA.own_status).toBe("booked");
    expect(terminA.own_waitlist_position).toBeNull();
  });

  it("wer nicht Mitglied ist, bekommt null -- kein Orakel", async () => {
    const client = await userClient(fremdEmail);
    const { data } = await client.rpc("course_week", {
      p_studio_id: studioId,
      p_from: VON,
      p_to: BIS,
    });
    expect(data).toBeNull();
  });

  it("eine leere Woche ist eine leere Liste, kein null", async () => {
    const client = await userClient(mitgliedEmail);
    const { data } = await client.rpc("course_week", {
      p_studio_id: studioId,
      p_from: "2027-01-01T00:00:00Z",
      p_to: "2027-01-08T00:00:00Z",
    });
    expect(data.sessions).toEqual([]);
  });
});

describe("list_course_participants", () => {
  it("Personal sieht die Liste mit Adresse, Status und Wartelistenposition", async () => {
    const trainer = await userClient(trainerEmail);
    const { data, error } = await trainer.rpc("list_course_participants", {
      p_session_id: terminId,
    });
    expect(error).toBeNull();
    expect(data).toHaveLength(3);

    const gebucht = data.filter((z: { status: string }) => z.status === "booked");
    const wartend = data.filter((z: { status: string }) => z.status === "waitlisted");
    expect(gebucht).toHaveLength(2);
    expect(wartend).toHaveLength(1);
    expect(wartend[0].waitlist_position).toBe(1);
    expect(gebucht[0].waitlist_position).toBeNull();
    expect(gebucht[0].email).toContain("@example.test");
  });

  it("ein Mitglied sieht sie NICHT -- auch nicht die eigene Zeile darin", async () => {
    const client = await userClient(mitgliedEmail);
    const { data } = await client.rpc("list_course_participants", {
      p_session_id: terminId,
    });
    expect(data).toEqual([]);
  });

  it("ein fremder Nutzer sieht nichts -- Cross-Tenant", async () => {
    const client = await userClient(fremdEmail);
    const { data } = await client.rpc("list_course_participants", {
      p_session_id: terminId,
    });
    expect(data).toEqual([]);
  });

  it("stornierte Buchungen stehen nicht auf der Liste, bleiben aber in der Tabelle", async () => {
    const admin = serviceClient();
    const { data: vorher } = await admin
      .from("course_bookings")
      .select("id")
      .eq("course_session_id", terminId);

    const erster = await userClient(mitgliedEmail);
    await erster.rpc("cancel_course_booking", { p_session_id: terminId });

    const trainer = await userClient(trainerEmail);
    const { data } = await trainer.rpc("list_course_participants", {
      p_session_id: terminId,
    });
    expect(data).toHaveLength(vorher!.length - 1);

    const { data: nachher } = await admin
      .from("course_bookings")
      .select("id")
      .eq("course_session_id", terminId);
    expect(nachher).toHaveLength(vorher!.length);
  });
});
