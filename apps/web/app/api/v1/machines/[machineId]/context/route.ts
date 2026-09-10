import { getMachineContext } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ machineId: string }> };

/**
 * Derselbe Kontext wie tags/[token]/context, nur ohne Tag -- fuer ein
 * Geraet, das aus der Liste gewaehlt wurde, weil kein Aufkleber daran
 * klebt.
 *
 * Eigene Route statt eines zweiten Parameters an der Tag-Route: eine
 * Route namens "tag-context", deren halber Verkehr keinen Tag sieht,
 * waere ein Name, der luegt.
 *
 * Die Autorisierung liegt in getMachineContext bei RLS -- ein Geraet aus
 * einem fremden Studio ist nicht lesbar und antwortet not_found.
 */
export async function GET(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { machineId } = await context.params;

  try {
    const machineContext = await getMachineContext(client, machineId);
    return Response.json(machineContext, {
      status: 200,
      // Persoenliche Werte und Historie: nie in einem geteilten Cache.
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
