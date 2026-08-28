import { createClient } from "@supabase/supabase-js";
import { hashTagToken, isValidTagToken } from "@fitretro/domain";

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

  // Oeffentlicher Endpunkt ohne Nutzersession: bewusst mit erhoehten Rechten,
  // liefert aber ausschliesslich nicht personenbezogene Tagdaten zurueck.
  const client = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const { data: tag } = await client
    .from("machine_tags")
    .select("id, status")
    .eq("token_hash", hashTagToken(token))
    .eq("status", "active")
    .maybeSingle();

  if (!tag) return unknown;

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
