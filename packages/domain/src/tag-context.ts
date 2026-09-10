import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { hashTagToken, isValidTagToken } from "./tags.js";
import { resolveMachineContext, type MachineContext } from "./machine-context.js";

/**
 * Ein Tag-Kontext ist ein Geraetekontext -- der Tag sagt nur, welches
 * Geraet gemeint ist. Der Alias bleibt exportiert, damit vorhandene
 * Importe nicht brechen.
 */
export type TagContext = MachineContext;

/**
 * Token -> Geraetekontext.
 *
 * Diese Funktion trug bis zur Geraeteauswahl ohne Scan den gesamten Rumpf.
 * Er liegt jetzt in machine-context.ts, weil ein Geraet auch aus einer
 * Liste gewaehlt werden kann und dann kein Token existiert.
 *
 * Der Token wird nur gehasht verwendet und nie protokolliert (Spec 10.4).
 *
 * userId wird hier aufgeloest, noch vor dem Tag-Lookup -- genau wie im
 * fruehen Rumpf. So bekommt ein nicht angemeldeter Aufruf "unauthorized"
 * statt "not_found", und resolveMachineContext muss requireUserId (ein
 * Netzwerksprung zum Auth-Service) nicht ein zweites Mal ausfuehren.
 */
export async function getTagContext(
  client: SupabaseClient,
  token: string,
): Promise<TagContext> {
  if (!isValidTagToken(token)) {
    throw new DomainError("validation_failed", "Ungueltiges Tokenformat.");
  }
  const userId = await requireUserId(client);

  // RLS blendet Tags fremder Studios aus. Unbekannt, ungueltig und gesperrt
  // liefern deshalb dieselbe Antwort -- sonst liessen sich gueltige Tokens
  // durch Ausprobieren unterscheiden.
  const { data: tag } = await client
    .from("machine_tags")
    .select("machine_id")
    .eq("token_hash", hashTagToken(token))
    .eq("status", "active")
    .maybeSingle<{ machine_id: string | null }>();
  if (!tag?.machine_id) {
    throw new DomainError("not_found", "Dieser Code ist nicht aktiv.");
  }

  return resolveMachineContext(client, userId, tag.machine_id);
}
