import { beforeAll, describe, expect, it } from "vitest";
import { GET as courses } from "@/app/api/v1/me/courses/route";
import {
  DELETE as buchungLoeschen,
  PUT as buchungSetzen,
} from "@/app/api/v1/course-sessions/[sessionId]/booking/route";
import { accessTokenFor, createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

let studioId: string;
let terminId: string;
let mitgliedToken: string;

function anfrage(pfad: string, token: string | null, rumpf?: unknown): Request {
  return new Request(`http://localhost:3000${pfad}`, {
    method: rumpf === undefined ? "GET" : "PUT",
    headers: {
      ...(token === null ? {} : { authorization: `Bearer ${token}` }),
      ...(rumpf === undefined ? {} : { "content-type": "application/json" }),
    },
    ...(rumpf === undefined ? {} : { body: JSON.stringify(rumpf) }),
  });
}

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio } = await admin
    .from("studios")
    .insert({ name: "API-Kurse", timezone: "Europe/Berlin" })
    .select("id")
    .single();
  studioId = studio!.id;

  const mitgliedEmail = uniqueEmail("api-kurs-mitglied");
  const mitgliedId = await createTestUser(mitgliedEmail);
  await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: mitgliedId, role: "member" });
  mitgliedToken = await accessTokenFor(mitgliedEmail);

  const { data: vorlage } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name: "API-Kraftzirkel",
      default_duration_min: 60,
      default_capacity: 1,
    })
    .select("id")
    .single();

  const { data: termin } = await admin
    .from("course_sessions")
    .insert({
      studio_id: studioId,
      course_template_id: vorlage!.id,
      starts_at: new Date(Date.now() + 3 * 86_400_000).toISOString(),
      duration_min: 60,
      capacity: 1,
      room: "Kursraum 2",
      instructor_name: "Marek T.",
    })
    .select("id")
    .single();
  terminId = termin!.id;
});

describe("GET /api/v1/me/courses", () => {
  it("ohne Anmeldung 401", async () => {
    const antwort = await courses(anfrage(`/api/v1/me/courses?studio=${studioId}`, null));
    expect(antwort.status).toBe(401);
  });

  it("liefert den Wochenplan mit freien Plaetzen", async () => {
    const von = new Date(Date.now() - 86_400_000).toISOString();
    const bis = new Date(Date.now() + 7 * 86_400_000).toISOString();
    const antwort = await courses(
      anfrage(`/api/v1/me/courses?studio=${studioId}&from=${von}&to=${bis}`, mitgliedToken),
    );
    expect(antwort.status).toBe(200);
    const daten = await antwort.json();
    expect(daten.timezone).toBe("Europe/Berlin");
    const termin = daten.sessions.find(
      (s: { sessionId: string }) => s.sessionId === terminId,
    );
    expect(termin.freeSeats).toBe(1);
    expect(termin.ownStatus).toBeNull();
  });

  it("ohne studio-Parameter 422", async () => {
    const antwort = await courses(anfrage("/api/v1/me/courses", mitgliedToken));
    expect(antwort.status).toBe(422);
  });

  it("ein studio-Parameter, der keine UUID ist, liefert 422 -- nicht die rohe Postgres-Meldung", async () => {
    const antwort = await courses(anfrage("/api/v1/me/courses?studio=abc", mitgliedToken));
    expect(antwort.status).toBe(422);
    const daten = await antwort.json();
    // Die rohe Meldung nennt "uuid" und den Wert "abc" -- genau das darf
    // nicht durchgereicht werden (Finding 2 des Gesamtreviews).
    expect(daten.error.message).not.toMatch(/invalid input syntax/i);
  });

  it("ein unbrauchbares from liefert 422", async () => {
    const antwort = await courses(
      anfrage(`/api/v1/me/courses?studio=${studioId}&from=kein-datum`, mitgliedToken),
    );
    expect(antwort.status).toBe(422);
  });

  it("ein unbrauchbares to liefert 422", async () => {
    const von = new Date().toISOString();
    const antwort = await courses(
      anfrage(`/api/v1/me/courses?studio=${studioId}&from=${von}&to=kein-datum`, mitgliedToken),
    );
    expect(antwort.status).toBe(422);
  });
});

describe("PUT und DELETE /api/v1/course-sessions/{id}/booking", () => {
  const kontext = { params: Promise.resolve({ sessionId: "" }) };

  it("anmelden, zweimal derselbe PUT, dann abmelden", async () => {
    const buchungId = crypto.randomUUID();
    const ctx = { params: Promise.resolve({ sessionId: terminId }) };

    const erste = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/${terminId}/booking`, mitgliedToken, { bookingId: buchungId }),
      ctx,
    );
    expect(erste.status).toBe(200);
    const ersteDaten = await erste.json();
    expect(ersteDaten.result).toBe("booked");
    expect(ersteDaten.created).toBe(true);

    const zweite = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/${terminId}/booking`, mitgliedToken, { bookingId: buchungId }),
      { params: Promise.resolve({ sessionId: terminId }) },
    );
    const zweiteDaten = await zweite.json();
    expect(zweiteDaten.created).toBe(false);
    expect(zweiteDaten.bookingId).toBe(ersteDaten.bookingId);

    const weg = await buchungLoeschen(
      new Request(`http://localhost:3000/api/v1/course-sessions/${terminId}/booking`, {
        method: "DELETE",
        headers: { authorization: `Bearer ${mitgliedToken}` },
      }),
      { params: Promise.resolve({ sessionId: terminId }) },
    );
    expect(weg.status).toBe(200);
  });

  it("ohne bookingId 422", async () => {
    const antwort = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/${terminId}/booking`, mitgliedToken, {}),
      { params: Promise.resolve({ sessionId: terminId }) },
    );
    expect(antwort.status).toBe(422);
  });

  it("eine bookingId, die keine UUID ist, liefert 422 -- nicht die rohe Postgres-Meldung", async () => {
    const antwort = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/${terminId}/booking`, mitgliedToken, {
        bookingId: "abc",
      }),
      { params: Promise.resolve({ sessionId: terminId }) },
    );
    expect(antwort.status).toBe(422);
    const daten = await antwort.json();
    expect(daten.error.message).not.toMatch(/invalid input syntax/i);
  });

  it("ein fremder Termin antwortet 404, nicht 403", async () => {
    const antwort = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/x/booking`, mitgliedToken, {
        bookingId: crypto.randomUUID(),
      }),
      { params: Promise.resolve({ sessionId: crypto.randomUUID() }) },
    );
    expect(antwort.status).toBe(404);
  });

  it("eine sessionId, die keine UUID ist, liefert 422 -- nicht die rohe Postgres-Meldung", async () => {
    const antwort = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/abc/booking`, mitgliedToken, {
        bookingId: crypto.randomUUID(),
      }),
      { params: Promise.resolve({ sessionId: "abc" }) },
    );
    expect(antwort.status).toBe(422);
    const daten = await antwort.json();
    expect(daten.error.message).not.toMatch(/invalid input syntax/i);
  });

  it("ohne Anmeldung 401", async () => {
    const antwort = await buchungSetzen(
      anfrage(`/api/v1/course-sessions/${terminId}/booking`, null, {
        bookingId: crypto.randomUUID(),
      }),
      kontext,
    );
    expect(antwort.status).toBe(401);
  });
});
