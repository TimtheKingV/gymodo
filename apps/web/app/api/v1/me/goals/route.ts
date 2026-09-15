import { setGoal } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Ein Ziel setzen oder ersetzen (Spec 3.3). PUT, nicht POST: derselbe
 * Aufruf zweimal gesendet ersetzt zweimal dasselbe Ziel -- `set_member_goal`
 * schliesst das alte ab, bevor es das neue anlegt.
 */
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
    const ziel = await setGoal(client, payload);
    return Response.json(ziel, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
