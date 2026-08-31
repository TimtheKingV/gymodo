import { recordSet } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ sessionId: string; setId: string }> };

/**
 * Speichert einen bestaetigten Satz.
 *
 * PUT statt POST, weil der Client die Kennungen erzeugt: derselbe Aufruf
 * zweimal ergibt denselben Satz (Spec 6.3). Die Kennungen aus dem Pfad
 * gewinnen gegen alles, was im Rumpf steht -- die URL benennt die Ressource.
 *
 * Die Problemmeldung braucht keinen eigenen Endpoint, sie ist ein Feld
 * dieses Rumpfes (Spec 6.3).
 */
export async function PUT(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse(
      "validation_failed",
      "Der Rumpf ist kein gueltiges JSON.",
    );
  }

  const { sessionId, setId } = await context.params;

  try {
    const saved = await recordSet(client, {
      ...(typeof payload === "object" && payload !== null ? payload : {}),
      sessionId,
      setId,
    });
    return Response.json(saved, { status: 200 });
  } catch (error) {
    return fromDomainError(error);
  }
}
