import { createClient } from "@supabase/supabase-js";
import { hashTagToken, isValidTagToken } from "@fitretro/domain";
import { requiredEnv } from "@/lib/env";

export const dynamic = "force-dynamic";

/**
 * Web-Fallback fuer Geraete-Tags.
 *
 * Diese Seite ist oeffentlich und zeigt niemals persoenliche Daten.
 * Ein unbekannter, ungueltiger und ein gesperrter Token liefern bewusst
 * dieselbe Antwort, damit sich gueltige Tokens nicht durch Ausprobieren
 * unterscheiden lassen.
 */
export default async function TagFallbackPage({
  params,
}: {
  params: Promise<{ token: string }>;
}) {
  const { token } = await params;

  const unknown = (
    <main>
      <h1 data-testid="tag-unknown">Dieser Code ist nicht aktiv.</h1>
      <p>Bitte wende dich an dein Studio.</p>
    </main>
  );

  if (!isValidTagToken(token)) return unknown;

  // Oeffentlicher Endpunkt ohne Nutzersession: der anonyme Key berechtigt
  // zu nichts ausser dem Aufruf von resolve_tag_fallback (SECURITY DEFINER,
  // liefert ausschliesslich eine machine_tag_id fuer aktive Tags zurueck).
  const client = createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    { auth: { persistSession: false } },
  );

  const { data } = await client.rpc("resolve_tag_fallback", {
    p_token_hash: hashTagToken(token),
  });

  if (!data || data.length === 0) return unknown;

  return (
    <main>
      <h1>Gerät erkannt</h1>
      <p data-testid="install-hint">
        Installiere die App, um deine Einstellungen und deinen Verlauf zu
        speichern.
      </p>
    </main>
  );
}
