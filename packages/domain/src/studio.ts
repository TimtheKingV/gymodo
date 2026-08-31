import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";

/**
 * Rolle des Aufrufers im Studio. memberships_select_own laesst jeden seine
 * eigene Mitgliedschaft lesen -- die Antwort kommt also ohne Service-Role aus.
 *
 * Das ersetzt die Policies nicht; sie bleiben die Instanz, die entscheidet.
 * Es sorgt nur dafuer, dass eine Ablehnung als verstaendlicher Fehler
 * ankommt statt als roher Datenbankfehler -- und dass ein 25-MiB-Upload gar
 * nicht erst beginnt.
 *
 * Ein fremdes und ein nicht existierendes Studio antworten gleich: die
 * fehlende Mitgliedschaft ist in beiden Faellen der Grund, und damit verraet
 * die Antwort nicht, welche Studios es gibt.
 */
export async function requireStudioStaff(
  client: SupabaseClient,
  studioId: string,
  userId: string,
): Promise<void> {
  const { data } = await client
    .from("studio_memberships")
    .select("role")
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .maybeSingle<{ role: string }>();

  if (!data || (data.role !== "trainer" && data.role !== "owner")) {
    throw new DomainError(
      "unauthorized",
      "Nur Trainer und Inhaber pflegen den Geraetekatalog.",
    );
  }
}
