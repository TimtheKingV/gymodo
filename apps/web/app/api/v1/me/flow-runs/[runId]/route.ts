import { recordFlowRun, requireUserId } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ runId: string }> };

/**
 * Meldet den Abschluss eines Flow-Durchlaufs: Body `{flowId, startedAt, endedAt, lastStep, outcome}`.
 * Idempotent ueber die `runId` (von der App erzeugt): erneutes Senden aendert nichts, Antwort 204.
 * Unbekannter oder fremder Flow: 404.
 */
export async function PUT(request: Request, { params }: Context): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  const { runId } = await params;
  let payload: unknown;
  try {
    payload = await request.json();
  } catch {
    return errorResponse("validation_failed", "Der Rumpf ist kein gueltiges JSON.");
  }
  const body = typeof payload === "object" && payload !== null ? (payload as Record<string, unknown>) : {};
  if (typeof body.flowId !== "string") return errorResponse("validation_failed", "Der Parameter flowId fehlt.");
  if (typeof body.startedAt !== "string") return errorResponse("validation_failed", "Der Parameter startedAt fehlt.");
  if (typeof body.endedAt !== "string") return errorResponse("validation_failed", "Der Parameter endedAt fehlt.");
  if (typeof body.lastStep !== "number") return errorResponse("validation_failed", "Der letzte Schritt muss eine Zahl sein.");
  if (body.outcome !== "finished" && body.outcome !== "aborted") {
    return errorResponse("validation_failed", "Das Ergebnis muss finished oder aborted sein.");
  }
  try {
    await recordFlowRun(client, await requireUserId(client), {
      id: runId,
      flowId: body.flowId,
      startedAt: body.startedAt,
      endedAt: body.endedAt,
      lastStep: body.lastStep,
      outcome: body.outcome,
    });
    return new Response(null, { status: 204 });
  } catch (error) {
    return fromDomainError(error);
  }
}
