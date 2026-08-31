import { getBootstrap } from "@fitretro/domain";
import { errorResponse, fromDomainError } from "@/lib/api/respond";
import { bearerClientFrom } from "@/lib/supabase/bearer";

export const dynamic = "force-dynamic";

/**
 * Der Prefetch beim App-Start (Spec 6.6).
 *
 * Danach funktioniert jeder Tap sofort und ohne Empfang -- Geraetebereiche
 * liegen haeufig im Keller, und das Studio-WLAN ist oft ein Captive Portal.
 */
export async function GET(request: Request): Promise<Response> {
  const client = bearerClientFrom(request);
  if (!client) {
    return errorResponse("unauthorized", "Anmeldung erforderlich.");
  }

  try {
    const bootstrap = await getBootstrap(client);
    return Response.json(bootstrap, {
      status: 200,
      // Enthaelt eigene Kalibrierungen und letzte Werte.
      headers: { "cache-control": "private, no-store" },
    });
  } catch (error) {
    return fromDomainError(error);
  }
}
