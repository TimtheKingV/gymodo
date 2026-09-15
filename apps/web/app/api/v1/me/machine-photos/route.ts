import { getMachinePhotos } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Signierte Geraetefotos fuer "Geraet waehlen" (Sammelstelle Punkt 16).
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
    const fotos = await getMachinePhotos(client);
    return Response.json(fotos, {
      status: 200,
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
