import { bookCourseSession, cancelCourseBooking } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Kontext = { params: Promise<{ sessionId: string }> };

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
