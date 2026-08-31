import { getProgress } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Der Gewichtsverlauf je Uebung, serverseitig zusammengefasst (Spec 6.3).
 *
 * Aggregate statt Rohsaetze: die Nutzlast bleibt auch nach einem Jahr
 * Training klein, und die Auswertungslogik bleibt auf dem Server.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const since = new URL(request.url).searchParams.get("since");

  try {
    const progress = await getProgress(client, since ? { since } : {});
    return Response.json(progress, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
