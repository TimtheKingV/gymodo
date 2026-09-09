import { z } from "zod";
import { getSessions } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Der Trainingsverlauf fuer den Home-Tab, einschliesslich Session-Detail.
 *
 * Dieser Lesezugriff schliesst nebenbei vergessene Einheiten ab (Spec 5.2):
 * der traege Autoabschluss braucht keinen Cronjob, weil er hier entsteht.
 */

/**
 * studio geht ungeprueft an PostgREST durch, sobald es den Router
 * verlaesst -- ein "?studio=abc" kaeme dort als "invalid input syntax for
 * type uuid" zurueck. Deshalb hier, an der Systemgrenze, wie in
 * me/courses.
 *
 * Optional, anders als dort: der Verlauf gehoert dem Mitglied, nicht dem
 * Studio. Ohne den Parameter faellt nur die Wochenzahl weg -- wer sein
 * letztes Studio verlassen hat, behaelt Verlauf und Gesamtzahl.
 */
const parameterSchema = z.object({
  studio: z.string().uuid("Der Parameter studio ist keine gueltige UUID.").optional(),
});

export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const geprueft = parameterSchema.safeParse({
    studio: new URL(request.url).searchParams.get("studio") ?? undefined,
  });
  if (!geprueft.success) {
    return errorResponse("validation_failed", geprueft.error.issues[0]!.message);
  }

  try {
    // Wie in me/progress: exactOptionalPropertyTypes verbietet ein
    // explizites "studioId: undefined", also nur bei vorhandenem Wert
    // ueberhaupt ins Optionsobjekt aufnehmen.
    const sessions = await getSessions(
      client,
      geprueft.data.studio ? { studioId: geprueft.data.studio } : {},
    );
    return Response.json(sessions, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
