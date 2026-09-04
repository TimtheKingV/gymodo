import { z } from "zod";
import { bookCourseSession, cancelCourseBooking } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Kontext = { params: Promise<{ sessionId: string }> };

/**
 * sessionId geht ungeprueft an die RPCs durch, sobald sie den Router
 * verlaesst -- ein "x" wie im vorigen Test kaeme dort als
 * "invalid input syntax for type uuid" zurueck. Bislang wurde das
 * spuerbar durch bookCourseSession/cancelCourseBooking als
 * DomainError("internal", …) durchgereicht und von respond.ts
 * woertlich weitergegeben (Finding 2 des Gesamtreviews). Hier, an der
 * Systemgrenze, statt in respond.ts -- das bleibt unangetastet.
 */
const sessionIdSchema = z.string().uuid("Die Terminkennung ist keine gültige UUID.");

/**
 * Anmelden. PUT mit clientseitig erzeugter UUID -- derselbe Aufruf
 * zweimal ergibt denselben Platz (Spec 6.3). created sagt, ob dieser
 * Aufruf ihn erzeugt hat.
 */
export async function PUT(request: Request, kontext: Kontext): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { sessionId } = await kontext.params;
  const geprueft = sessionIdSchema.safeParse(sessionId);
  if (!geprueft.success) {
    return errorResponse("validation_failed", geprueft.error.issues[0]!.message);
  }

  let rumpf: { bookingId?: unknown };
  try {
    rumpf = (await request.json()) as { bookingId?: unknown };
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gültiges JSON.");
  }

  if (typeof rumpf.bookingId !== "string" || rumpf.bookingId.length === 0) {
    return errorResponse(
      "validation_failed",
      "bookingId fehlt. Die Kennung erzeugt der Client, damit derselbe Aufruf zweimal denselben Platz ergibt.",
    );
  }
  // Dieselbe Luecke wie bei sessionId oben: bookingId geht ungeprueft an
  // book_course_session (p_booking_id uuid) durch. Ein "abc" kaeme dort
  // als "invalid input syntax for type uuid" zurueck -- derselbe Fehler,
  // den diese ganze Fixrunde schliessen sollte, an einem Feld vorbei.
  const bookingIdGeprueft = sessionIdSchema.safeParse(rumpf.bookingId);
  if (!bookingIdGeprueft.success) {
    return errorResponse("validation_failed", "bookingId ist keine gültige UUID.");
  }

  try {
    const ergebnis = await bookCourseSession(client, sessionId, rumpf.bookingId);
    return Response.json(ergebnis, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}

/**
 * Abmelden. Ohne Rumpf: die Funktion findet die eigene offene Buchung
 * selbst -- der Client kennt seine Buchungskennung nicht zwingend noch.
 */
export async function DELETE(request: Request, kontext: Kontext): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { sessionId } = await kontext.params;
  const geprueft = sessionIdSchema.safeParse(sessionId);
  if (!geprueft.success) {
    return errorResponse("validation_failed", geprueft.error.issues[0]!.message);
  }

  try {
    const ergebnis = await cancelCourseBooking(client, sessionId);
    return Response.json(ergebnis, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
