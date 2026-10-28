import { z } from "zod";
import { erzeugePlanVorschlag, listPlaene, requireUserId } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

// An der Systemgrenze pruefen: eine kaputte UUID kaeme sonst als rohe
// Postgres-Meldung ("invalid input syntax for type uuid") zurueck.
const studioIdSchema = z.string().uuid("studioId ist keine gueltige UUID.");

/** Neuer Planvorschlag aus dem Katalog fuer den Ort `studioId`; ein alter Vorschlag wird verworfen. */
export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }
  // Die studioId nennt den Ort; fehlt sie, gilt das Freie Training.
  const studioId = studioIdSchema.optional().safeParse((payload as { studioId?: unknown } | null)?.studioId);
  if (!studioId.success) return errorResponse("validation_failed", "studioId ist ungueltig.");
  try {
    const plan = await erzeugePlanVorschlag(client, await requireUserId(client), studioId.data);
    return Response.json(plan, { status: 201 });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Alle Planversionen des Mitglieds, neueste zuerst. Liest nur (F14). */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    const plaene = await listPlaene(client, await requireUserId(client));
    return Response.json(plaene, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}
