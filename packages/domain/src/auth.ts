import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";

/**
 * Die gepruefte Identitaet des Aufrufers -- nie aus der Nutzlast.
 *
 * `getUser()` laesst das Token vom Auth-Dienst pruefen, statt der lokalen
 * Kopie zu glauben. Das kostet einen Sprung und ist genau deshalb richtig:
 * bei einem Bearer-Token aus einer fremden App ist die lokale Kopie kein
 * Beleg.
 */
export async function requireUserId(client: SupabaseClient): Promise<string> {
  const { data } = await client.auth.getUser();
  const userId = data.user?.id;
  if (!userId) {
    throw new DomainError("unauthorized", "Kein angemeldeter Nutzer.");
  }
  return userId;
}
