import { completeSession } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string }> };

/**
 * Beendet eine Trainingseinheit ausdruecklich (Spec 5.2).
 *
 * Ohne Rumpf: die Kennung steht im Pfad, der Grund ist bei diesem Weg immer
 * `manual`. Der traege Autoabschluss nach vier Stunden ist kein Aufruf,
 * sondern eine Leseregel -- er entsteht beim naechsten Lesezugriff.
 */
export async function POST(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { sessionId } = await context.params;

  try {
    const completed = await completeSession(client, { sessionId });
    return Response.json(completed, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
