import { getTagContext } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

type Context = { params: Promise<{ token: string }> };

/**
 * Alles, was der Geraete-Screen nach einem Tap braucht -- in einer Anfrage
 * (Spec 6.3). Mehrere Roundtrips wuerden das Performancebudget reissen,
 * bevor das Mitglied den ersten Satz sieht.
 *
 * Der Token steht im Pfad, wird aber nur gehasht verwendet und taucht weder
 * in der Antwort noch in Protokollen auf (Spec 10.4, 10.6).
 */
export async function GET(
  request: Request,
  context: Context,
): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  const { token } = await context.params;

  try {
    const tagContext = await getTagContext(client, token);
    return Response.json(tagContext, {
      status: 200,
      // Persoenliche Werte und Historie: nie in einem geteilten Cache.
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
