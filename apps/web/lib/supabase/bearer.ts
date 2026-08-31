import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { requiredEnv } from "@/lib/env";

/**
 * Liest das Bearer-Token aus der Anfrage.
 *
 * Das Token darf niemals in Logs, Fehlerberichten oder Analytics auftauchen
 * (Spec Abschnitt 10.6) -- es wird deshalb hier nur weitergereicht und
 * nirgends ausgegeben.
 */
export function bearerToken(request: Request): string | null {
  const header = request.headers.get("authorization");
  if (!header) return null;
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match?.[1]?.trim() || null;
}

/**
 * Ein an den anfragenden Nutzer gebundener Client.
 *
 * Bewusst mit dem oeffentlichen Schluessel plus Authorization-Kopfzeile: nur
 * so greift RLS als dieser Nutzer. Der Service-Role-Schluessel hat in einem
 * normalen Request-Handler nichts zu suchen (Spec Abschnitt 9) -- er wuerde
 * die Studio-Konsistenzpruefungen aushebeln, die in den Policies leben und
 * nicht im Schema.
 */
export function createBearerSupabaseClient(token: string): SupabaseClient {
  return createClient(
    requiredEnv("SUPABASE_URL"),
    requiredEnv("SUPABASE_ANON_KEY"),
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: { headers: { Authorization: `Bearer ${token}` } },
    },
  );
}

/** Null, wenn die Anfrage kein Token mitbringt. */
export function bearerClientFrom(request: Request): SupabaseClient | null {
  const token = bearerToken(request);
  return token ? createBearerSupabaseClient(token) : null;
}
