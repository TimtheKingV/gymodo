import { setDisplayName } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Den eigenen Anzeigenamen setzen.
 *
 * Ausserhalb der sechs Endpoints aus M1-Spec SS6.3 -- wie schon die
 * Studio-Endpoints aus Sub-Projekt 1, der Tag-Kontext aus Sub-Projekt 2
 * und die Kurse aus Sub-Projekt 3. Die Architekturaussage dahinter
 * (screenorientiert, keine Fachlogik im Client) bleibt unberuehrt.
 *
 * PUT, nicht POST: derselbe Aufruf zweimal gesendet ergibt denselben
 * Namen -- dasselbe Muster wie beim Satz-Schreibweg.
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
    const profil = await setDisplayName(client, payload);
    return Response.json(profil, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
