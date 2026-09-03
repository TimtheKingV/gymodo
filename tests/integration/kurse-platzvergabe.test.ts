import { beforeAll, describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

/**
 * Die Platzvergabe, Spec 2026-09-03-kurse-design.md Abschnitt 2.
 *
 * Der erste Block ist der wichtigste Test dieses Bauabschnitts und der
 * einzige, der bei falscher Bauweise trotzdem gruen werden kann -- er
 * braucht deshalb echte parallele Verbindungen, nicht nacheinander
 * abgesetzte Aufrufe.
 */

let studioId: string;
let trainerEmail: string;
let vorlageId: string;

function inStunden(stunden: number): string {
  return new Date(Date.now() + stunden * 60 * 60 * 1000).toISOString();
}

/** Ein Termin mit frei waehlbarer Kapazitaet und Startzeit. */
async function terminAnlegen(opts: {
  capacity: number;
  startsAt: string;
  status?: "planned" | "cancelled";
}): Promise<string> {
  const admin = serviceClient();
  const { data, error } = await admin
    .from("course_sessions")
    .insert({
      studio_id: studioId,
      course_template_id: vorlageId,
      starts_at: opts.startsAt,
      duration_min: 60,
      capacity: opts.capacity,
      ...(opts.status === "cancelled"
        ? { status: "cancelled", cancelled_at: new Date().toISOString() }
        : {}),
    })
    .select("id")
    .single();
  if (error) throw error;
  return data.id;
}

/** N frische Mitglieder desselben Studios, alle schon angemeldet. */
async function mitglieder(anzahl: number, praefix: string): Promise<SupabaseClient[]> {
  const admin = serviceClient();
  const adressen: string[] = [];
  for (let i = 0; i < anzahl; i += 1) {
    const adresse = uniqueEmail(`${praefix}-${i}`);
    const id = await createTestUser(adresse);
    const { error } = await admin
      .from("studio_memberships")
      .insert({ studio_id: studioId, user_id: id, role: "member" });
    if (error) throw error;
    adressen.push(adresse);
  }
  // Erst alle anmelden, dann zurueckgeben: die Anmeldung soll NICHT Teil
  // der gemessenen Gleichzeitigkeit sein, sonst staffeln sich die Aufrufe
  // von selbst und der Test prueft nichts.
  return Promise.all(adressen.map((a) => userClient(a)));
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioFehler } = await admin
    .from("studios")
    .insert({ name: "Platzvergabe-Studio", timezone: "Europe/Berlin" })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;
  studioId = studio.id;

  trainerEmail = uniqueEmail("pv-trainer");
  const trainerId = await createTestUser(trainerEmail);
  const { error } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: trainerId, role: "trainer" });
  if (error) throw error;

  const { data: vorlage, error: vorlageFehler } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name: "Kraftzirkel",
      default_duration_min: 60,
      default_capacity: 16,
    })
    .select("id")
    .single();
  if (vorlageFehler) throw vorlageFehler;
  vorlageId = vorlage.id;
});

describe("Der Wettlauf um den letzten Platz", () => {
  it("zehn gleichzeitige Anmeldungen auf einen Platz: genau eine gewinnt", async () => {
    const terminId = await terminAnlegen({ capacity: 1, startsAt: inStunden(72) });
    const clients = await mitglieder(10, "wettlauf");

    // Promise.all setzt alle zehn RPCs ab, ohne auf die vorige Antwort zu
    // warten -- sie treffen die Datenbank ueberlappend.
    const antworten = await Promise.all(
      clients.map((c) =>
        c.rpc("book_course_session", {
          p_session_id: terminId,
          p_booking_id: crypto.randomUUID(),
        }),
      ),
    );

    for (const antwort of antworten) expect(antwort.error).toBeNull();
    const ergebnisse = antworten.map((a) => a.data as { result: string });

    expect(ergebnisse.filter((e) => e.result === "booked")).toHaveLength(1);
    expect(ergebnisse.filter((e) => e.result === "waitlisted")).toHaveLength(9);

    // Gegenprobe am Bestand, nicht nur an den Antworten.
    const admin = serviceClient();
    const { data: zeilen } = await admin
      .from("course_bookings")
      .select("status")
      .eq("course_session_id", terminId);
    expect(zeilen!.filter((z) => z.status === "booked")).toHaveLength(1);
    expect(zeilen).toHaveLength(10);
  });

  it("die Warteliste ist lueckenlos und ohne Doppelbelegung", async () => {
    const terminId = await terminAnlegen({ capacity: 2, startsAt: inStunden(72) });
    const clients = await mitglieder(8, "lueckenlos");

    const antworten = await Promise.all(
      clients.map((c) =>
        c.rpc("book_course_session", {
          p_session_id: terminId,
          p_booking_id: crypto.randomUUID(),
        }),
      ),
    );

    const wartend = antworten
      .map((a) => a.data as { result: string; waitlist_position: number | null })
      .filter((e) => e.result === "waitlisted")
      .map((e) => e.waitlist_position!)
      .sort((a, b) => a - b);

    expect(wartend).toEqual([1, 2, 3, 4, 5, 6]);
  });

  it("zwanzig gleichzeitige Anmeldungen auf fuenf Plaetze: genau fuenf", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });
    const clients = await mitglieder(20, "zwanzig");

    const antworten = await Promise.all(
      clients.map((c) =>
        c.rpc("book_course_session", {
          p_session_id: terminId,
          p_booking_id: crypto.randomUUID(),
        }),
      ),
    );

    const ergebnisse = antworten.map((a) => a.data as { result: string });
    expect(ergebnisse.filter((e) => e.result === "booked")).toHaveLength(5);
    expect(ergebnisse.filter((e) => e.result === "waitlisted")).toHaveLength(15);
  });
});

describe("Idempotenz", () => {
  it("derselbe PUT zweimal ergibt eine Buchung -- created sagt, welcher der erste war", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });
    const [client] = await mitglieder(1, "idem");
    const buchungId = crypto.randomUUID();

    const erste = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: buchungId,
    });
    const zweite = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: buchungId,
    });

    expect(erste.data.result).toBe("booked");
    expect(erste.data.created).toBe(true);
    expect(zweite.data.result).toBe("booked");
    expect(zweite.data.created).toBe(false);
    expect(zweite.data.booking_id).toBe(erste.data.booking_id);

    const admin = serviceClient();
    const { data } = await admin
      .from("course_bookings")
      .select("id")
      .eq("course_session_id", terminId);
    expect(data).toHaveLength(1);
  });

  it("eine ANDERE Buchungskennung desselben Nutzers liefert dieselbe Buchung", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });
    const [client] = await mitglieder(1, "idem2");

    const erste = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const zweite = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    expect(zweite.data.booking_id).toBe(erste.data.booking_id);
    expect(zweite.data.created).toBe(false);
  });
});

describe("Wann gar nicht erst gebucht wird", () => {
  it("ein abgesagter Termin nimmt niemanden auf", async () => {
    const terminId = await terminAnlegen({
      capacity: 5,
      startsAt: inStunden(72),
      status: "cancelled",
    });
    const [client] = await mitglieder(1, "abgesagt");

    const { data } = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    expect(data.result).toBe("session_cancelled");
    expect(data.created).toBe(false);
  });

  it("ein begonnener Termin nimmt niemanden mehr auf -- die Grenze ist der Beginn, nicht das Ende", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(-0.5) });
    const [client] = await mitglieder(1, "vorbei");

    const { data } = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    expect(data.result).toBe("past");
  });

  it("wer nicht Mitglied ist, bekommt null -- kein Orakel darueber, welche Termine es gibt", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });

    const admin = serviceClient();
    const { data: fremdStudio } = await admin
      .from("studios")
      .insert({ name: "Fremdes Platzvergabe-Studio" })
      .select("id")
      .single();
    const fremdEmail = uniqueEmail("pv-fremd");
    const fremdId = await createTestUser(fremdEmail);
    await admin
      .from("studio_memberships")
      .insert({ studio_id: fremdStudio!.id, user_id: fremdId, role: "member" });

    const client = await userClient(fremdEmail);
    const { data } = await client.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    expect(data).toBeNull();

    // Und ein Termin, den es gar nicht gibt, antwortet identisch.
    const { data: erfunden } = await client.rpc("book_course_session", {
      p_session_id: crypto.randomUUID(),
      p_booking_id: crypto.randomUUID(),
    });
    expect(erfunden).toBeNull();
  });
});

describe("Stornieren und Nachruecken", () => {
  it("storniert der letzte Gebuchte, rueckt die erste Wartende nach und bekommt promoted_at", async () => {
    const terminId = await terminAnlegen({ capacity: 1, startsAt: inStunden(72) });
    const [ersteR, zweiteR, dritteR] = await mitglieder(3, "nachruecken");

    const erste = await ersteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const zweite = await zweiteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const dritte = await dritteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    expect(erste.data.result).toBe("booked");
    expect(zweite.data.result).toBe("waitlisted");
    expect(zweite.data.waitlist_position).toBe(1);
    expect(dritte.data.waitlist_position).toBe(2);

    const { data: storno } = await ersteR!.rpc("cancel_course_booking", {
      p_session_id: terminId,
    });
    expect(storno.result).toBe("cancelled");
    expect(storno.promoted_booking_id).toBe(zweite.data.booking_id);

    const admin = serviceClient();
    const { data: nachgerueckt } = await admin
      .from("course_bookings")
      .select("status, promoted_at")
      .eq("id", zweite.data.booking_id)
      .single();
    expect(nachgerueckt!.status).toBe("booked");
    expect(nachgerueckt!.promoted_at).not.toBeNull();

    // Und die dritte rueckt auf Position 1 -- ohne dass jemand eine
    // Spalte umgeschrieben haette.
    const { data: nachher } = await dritteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    expect(nachher.waitlist_position).toBe(1);
  });

  it("storniert jemand von der Warteliste, rueckt niemand nach", async () => {
    const terminId = await terminAnlegen({ capacity: 1, startsAt: inStunden(72) });
    const [ersteR, zweiteR, dritteR] = await mitglieder(3, "wartestorno");

    await ersteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    await zweiteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const dritte = await dritteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const { data: storno } = await zweiteR!.rpc("cancel_course_booking", {
      p_session_id: terminId,
    });
    expect(storno.result).toBe("cancelled");
    expect(storno.promoted_booking_id).toBeNull();

    const admin = serviceClient();
    const { data: unveraendert } = await admin
      .from("course_bookings")
      .select("status")
      .eq("id", dritte.data.booking_id)
      .single();
    expect(unveraendert!.status).toBe("waitlisted");
  });

  it("in einen abgesagten Termin rueckt niemand nach", async () => {
    const terminId = await terminAnlegen({ capacity: 1, startsAt: inStunden(72) });
    const [ersteR, zweiteR] = await mitglieder(2, "abgesagt-nachr");

    await ersteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const zweite = await zweiteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const admin = serviceClient();
    await admin
      .from("course_sessions")
      .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", terminId);

    const { data: storno } = await ersteR!.rpc("cancel_course_booking", {
      p_session_id: terminId,
    });
    expect(storno.promoted_booking_id).toBeNull();

    const { data: bleibt } = await admin
      .from("course_bookings")
      .select("status")
      .eq("id", zweite.data.booking_id)
      .single();
    expect(bleibt!.status).toBe("waitlisted");
  });

  it("wer nicht gebucht hat, bekommt not_booked", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });
    const [client] = await mitglieder(1, "ungebucht");

    const { data } = await client!.rpc("cancel_course_booking", { p_session_id: terminId });
    expect(data.result).toBe("not_booked");
  });
});

describe("Die Stornofrist", () => {
  it("vor der Frist geht das Abmelden", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(5) });
    const [client] = await mitglieder(1, "frist-vor");

    await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const { data } = await client!.rpc("cancel_course_booking", { p_session_id: terminId });
    expect(data.result).toBe("cancelled");
  });

  it("nach der Frist nicht -- und die Antwort sagt, welche Frist gilt", async () => {
    // Studio-Vorgabe ist 2 Stunden (0032); ein Termin in einer Stunde
    // liegt darunter.
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(1) });
    const [client] = await mitglieder(1, "frist-nach");

    await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const { data } = await client!.rpc("cancel_course_booking", { p_session_id: terminId });
    expect(data.result).toBe("deadline");
    expect(data.deadline_hours).toBe(2);
  });

  it("von der Warteliste geht es auch nach der Frist -- sie kostet niemanden einen Platz", async () => {
    const terminId = await terminAnlegen({ capacity: 1, startsAt: inStunden(1) });
    const [ersteR, zweiteR] = await mitglieder(2, "frist-warte");

    await ersteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    await zweiteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const { data } = await zweiteR!.rpc("cancel_course_booking", { p_session_id: terminId });
    expect(data.result).toBe("cancelled");
  });

  it("Personal entfernt jemanden auch nach der Frist", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(1) });
    const [client] = await mitglieder(1, "frist-staff");

    await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const admin = serviceClient();
    const { data: buchung } = await admin
      .from("course_bookings")
      .select("user_id")
      .eq("course_session_id", terminId)
      .single();

    const trainer = await userClient(trainerEmail);
    const { data } = await trainer.rpc("cancel_course_booking", {
      p_session_id: terminId,
      p_user_id: buchung!.user_id,
    });
    expect(data.result).toBe("cancelled");
  });

  it("bei einem abgesagten Termin gilt die Frist nicht mehr", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(1) });
    const [client] = await mitglieder(1, "frist-abgesagt");

    await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    const admin = serviceClient();
    await admin
      .from("course_sessions")
      .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
      .eq("id", terminId);

    const { data } = await client!.rpc("cancel_course_booking", { p_session_id: terminId });
    expect(data.result).toBe("cancelled");
  });

  it("ein Mitglied entfernt kein anderes Mitglied", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });
    const [ersteR, zweiteR] = await mitglieder(2, "fremdstorno");

    await ersteR!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    const admin = serviceClient();
    const { data: buchung } = await admin
      .from("course_bookings")
      .select("user_id")
      .eq("course_session_id", terminId)
      .single();

    const { data } = await zweiteR!.rpc("cancel_course_booking", {
      p_session_id: terminId,
      p_user_id: buchung!.user_id,
    });
    expect(data).toBeNull();
  });

  it("nach dem Stornieren ist eine neue Anmeldung eine NEUE Zeile -- die Historie bleibt", async () => {
    const terminId = await terminAnlegen({ capacity: 5, startsAt: inStunden(72) });
    const [client] = await mitglieder(1, "wiederan");

    const erste = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });
    await client!.rpc("cancel_course_booking", { p_session_id: terminId });
    const zweite = await client!.rpc("book_course_session", {
      p_session_id: terminId,
      p_booking_id: crypto.randomUUID(),
    });

    expect(zweite.data.result).toBe("booked");
    expect(zweite.data.booking_id).not.toBe(erste.data.booking_id);

    const admin = serviceClient();
    const { data } = await admin
      .from("course_bookings")
      .select("status")
      .eq("course_session_id", terminId);
    expect(data).toHaveLength(2);
    expect(data!.filter((z) => z.status === "cancelled")).toHaveLength(1);
  });
});
