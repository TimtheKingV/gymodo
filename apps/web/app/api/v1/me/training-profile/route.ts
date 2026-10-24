import { getTrainingProfile, requireUserId, saveTrainingProfile } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/** Das Trainingsprofil des Mitglieds (Trainingsplan-Spec Abschnitt 1). 404 ohne Profil. */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    const profil = await getTrainingProfile(client, await requireUserId(client));
    if (!profil) return errorResponse("not_found", "Noch kein Trainingsprofil.");
    return Response.json(profil, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}

/** PUT, nicht POST: der Upsert macht denselben Aufruf zweimal zu demselben Profil. */
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
    const profil = await saveTrainingProfile(client, await requireUserId(client), payload);
    return Response.json(profil, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
