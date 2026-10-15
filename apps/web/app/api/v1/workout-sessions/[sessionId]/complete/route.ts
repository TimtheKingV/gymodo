import { completeSession } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string }> };

/**
 * Beendet eine Trainingseinheit ausdruecklich (Spec 5.2).
 *
 * Der Rumpf ist optional: `{ pausedSeconds }` seit dem Fortsetzen
 * (Testnotiz 14.10., 18:45 #3/#4). Eine alte App schickt keinen -- dann
 * bleibt die Pausensumme, wie sie ist. Der Grund ist bei diesem Weg immer
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
  const text = await request.text();
  let rumpf: Record<string, unknown> = {};
  if (text.trim() !== "") {
    try {
      rumpf = JSON.parse(text) as Record<string, unknown>;
    } catch {
      return errorResponse("validation_failed", "Der Rumpf ist kein JSON.");
    }
  }

  try {
    const completed = await completeSession(client, { ...rumpf, sessionId });
    return Response.json(completed, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
