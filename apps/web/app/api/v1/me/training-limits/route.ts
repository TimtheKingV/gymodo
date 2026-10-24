import {
  deleteTrainingLimits,
  getTrainingLimits,
  requireUserId,
  saveTrainingLimits,
} from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/** Beschwerden sind Gesundheitsdaten (DSGVO Art. 9): nie cachen, 404 ohne Einwilligung. */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    const limits = await getTrainingLimits(client, await requireUserId(client));
    if (!limits) return errorResponse("not_found", "Keine Beschwerden hinterlegt.");
    return Response.json(limits, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Speichert mit Einwilligung; der Zeitstempel kommt vom Server, nicht vom Client. */
export async function PUT(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }
  try {
    const limits = await saveTrainingLimits(client, await requireUserId(client), payload, new Date());
    return Response.json(limits, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** Einwilligung widerrufen; idempotent, immer 204. */
export async function DELETE(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    await deleteTrainingLimits(client, await requireUserId(client));
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
