import { reopenSession } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string }> };

/**
 * Oeffnet eine von Hand beendete Einheit wieder, hoechstens 30 Minuten nach
 * dem Beenden (Testnotiz 14.10., 18:45 #3/#4). Ohne Rumpf. 409 mit Text,
 * wenn es zu spaet ist oder die Einheit selbsttaetig beendet wurde.
 */
export async function POST(request: Request, context: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");

  const { sessionId } = await context.params;
  try {
    return Response.json(await reopenSession(client, { sessionId }), { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
