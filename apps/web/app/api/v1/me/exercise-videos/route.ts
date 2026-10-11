import { getExerciseVideos } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Signierte Uebungsvideos fuer "Geraet waehlen" (Testnotiz 11.10., #1).
 *
 * no-store: die URLs laufen nach 15 Minuten ab, und ein Zwischenspeicher
 * wuerde abgelaufene ausliefern.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  try {
    const videos = await getExerciseVideos(client);
    return Response.json(videos, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
