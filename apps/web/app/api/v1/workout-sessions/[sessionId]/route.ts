import { deleteSession } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string }> };

/**
 * Loescht eine eigene Einheit (Sammelstelle Punkt 19, Schnitt 4). Eine
 * Einheit, die es nicht (mehr) gibt, ist danach genau das -- kein 404,
 * deshalb antwortet auch ein zweiter Aufruf mit 204, und eine fremde
 * Kennung ebenso (RLS trifft null Zeilen, siehe deleteSession).
 */
export async function DELETE(request: Request, context: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  const { sessionId } = await context.params;
  try {
    await deleteSession(client, { sessionId });
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
