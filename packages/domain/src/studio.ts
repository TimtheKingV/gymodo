import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
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
  meldung = "Nur Trainer und Inhaber pflegen den Geraetekatalog.",
): Promise<void> {
  const { data } = await client
    .from("studio_memberships")
    .select("role")
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .maybeSingle<{ role: string }>();

  if (!data || (data.role !== "trainer" && data.role !== "owner")) {
    throw new DomainError("unauthorized", meldung);
  }
}

export type StudioSettings = {
  id: string;
  name: string;
  timezone: string;
  cancellationDeadlineHours: number;
  joinCode: string;
  joinCodeActive: boolean;
};

/**
 * Die Zeitzone wird gegen die Liste des Laufzeitsystems geprueft, nicht
 * gegen eine eigene Aufzaehlung: `studios.timezone` ist ein freier Text
 * (0001), und eine Zeitzone, die Intl nicht kennt, laesst spaeter jede
 * Kursanzeige auflaufen. Die Pruefung gehoert deshalb vor das Speichern,
 * nicht vor das Anzeigen.
 */
function istBekannteZeitzone(wert: string): boolean {
  try {
    new Intl.DateTimeFormat("de-DE", { timeZone: wert });
    return true;
  } catch {
    return false;
  }
}

const einstellungenSchema = z.object({
  name: z.string().trim().min(1, "Das Studio braucht einen Namen."),
  timezone: z
    .string()
    .trim()
    .refine(istBekannteZeitzone, "Diese Zeitzone kennt das System nicht."),
  cancellationDeadlineHours: z
    .number()
    .int("Die Stornofrist zaehlt in ganzen Stunden.")
    .min(0, "Eine negative Frist gibt es nicht. 0 heisst: bis zum Beginn.")
    .max(168, "Mehr als 168 Stunden -- eine Woche -- ist keine Frist mehr."),
});

export type StudioSettingsInput = z.infer<typeof einstellungenSchema>;

/**
 * Eigene Meldung statt der Geraetekatalog-Standardmeldung von
 * requireStudioStaff: wer die Einstellungen nicht sehen oder aendern darf,
 * soll das auch fuer Einstellungen erfahren, nicht fuer den Katalog
 * (Spec Abschnitt 5 -- eine Absage sagt, was gilt).
 */
const einstellungenAbsage = "Nur Trainer und Inhaber sehen und aendern die Studio-Einstellungen.";

export async function getStudioSettings(
  client: SupabaseClient,
  studioId: string,
): Promise<StudioSettings> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, einstellungenAbsage);

  const { data, error } = await client
    .from("studios")
    .select("id, name, timezone, cancellation_deadline_hours, join_code, join_code_active")
    .eq("id", studioId)
    .maybeSingle<{
      id: string;
      name: string;
      timezone: string;
      cancellation_deadline_hours: number;
      join_code: string;
      join_code_active: boolean;
    }>();

  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("not_found", "Dieses Studio gibt es nicht.");

  return {
    id: data.id,
    name: data.name,
    timezone: data.timezone,
    cancellationDeadlineHours: data.cancellation_deadline_hours,
    joinCode: data.join_code,
    joinCodeActive: data.join_code_active,
  };
}

/**
 * Der Beitrittscode fehlt hier mit Absicht: er wird ueber
 * regenerate_studio_join_code und set_studio_join_code_active geaendert,
 * und seit 0032 hat `authenticated` gar kein Spaltenrecht darauf.
 */
export async function updateStudioSettings(
  client: SupabaseClient,
  studioId: string,
  input: StudioSettingsInput,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, einstellungenAbsage);

  const parsed = einstellungenSchema.safeParse(input);
  if (!parsed.success) {
    throw new DomainError("validation_failed", parsed.error.issues[0]!.message);
  }

  const { data, error } = await client
    .from("studios")
    .update({
      name: parsed.data.name,
      timezone: parsed.data.timezone,
      cancellation_deadline_hours: parsed.data.cancellationDeadlineHours,
    })
    .eq("id", studioId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError("unauthorized", "Nur Trainer und Inhaber aendern die Einstellungen.");
  }
}
