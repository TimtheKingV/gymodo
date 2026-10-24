import { z } from "zod";
import { erzeugePlanVorschlag, listPlaene, requireUserId } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

// An der Systemgrenze pruefen: eine kaputte UUID kaeme sonst als rohe
// Postgres-Meldung ("invalid input syntax for type uuid") zurueck.
const studioIdSchema = z.string().uuid("studioId ist keine gueltige UUID.");

/** Neuer Planvorschlag fuer ein Studio des Mitglieds; ein alter Vorschlag wird verworfen. */
export async function POST(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }
  const studioId = studioIdSchema.safeParse((payload as { studioId?: unknown } | null)?.studioId);
  if (!studioId.success) return errorResponse("validation_failed", "studioId fehlt oder ist ungueltig.");
  try {
    const plan = await erzeugePlanVorschlag(client, await requireUserId(client), studioId.data);
    return Response.json(plan, { status: 201 });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Alle Planversionen des Mitglieds in diesem Studio, neueste zuerst. Liest nur (F14). */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const studioId = studioIdSchema.safeParse(new URL(request.url).searchParams.get("studioId") ?? undefined);
  if (!studioId.success) return errorResponse("validation_failed", "studioId fehlt oder ist ungueltig.");
  try {
    const plaene = await listPlaene(client, await requireUserId(client), studioId.data);
    return Response.json(plaene, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}
