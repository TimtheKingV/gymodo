import { listFlows, requireUserId } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/** Alle Follow-along-Flows des eigenen Studios (RLS), Schritte nach Position, mit Gesamtdauer `dauerS`. */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) return errorResponse("unauthorized", "Anmeldung erforderlich.");
  try {
    await requireUserId(client);
    const flows = await listFlows(client);
    return Response.json({ flows }, { status: 200, headers: { "cache-control": "private, no-store" } });
  } catch (error) {
    return fromDomainError(error);
  }
}
