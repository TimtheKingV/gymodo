import type { SupabaseClient } from "@supabase/supabase-js";
import { DomainError } from "./errors.js";

const TAG = /^\d{4}-\d{2}-\d{2}$/;

/** Prueft YYYY-MM-DD und dass der Kalendertag existiert (kein 30. Februar). */
export function pruefeTag(roh: string): string {
  const datum = TAG.test(roh) ? new Date(`${roh}T00:00:00Z`) : null;
  const gueltig = datum !== null && !Number.isNaN(datum.getTime()) && datum.toISOString().slice(0, 10) === roh;
  if (!gueltig) throw new DomainError("validation_failed", "Der Tag muss ein Datum im Format JJJJ-MM-TT sein.");
  return roh;
}

/**
 * Hakt Cardio fuer einen Kalendertag ab. Idempotent: ein zweiter Aufruf aendert nichts.
 * `day` und `heute` sind Kalendertage des Mitglieds (YYYY-MM-DD); in der Zukunft
 * laesst sich nichts abhaken.
 */
export async function setCardioCheck(client: SupabaseClient, userId: string, day: string, heute: string): Promise<void> {
  pruefeTag(day);
  pruefeTag(heute);
  if (day > heute) throw new DomainError("validation_failed", "Cardio laesst sich nicht fuer die Zukunft abhaken.");
  const { error } = await client
    .from("cardio_checks")
    .upsert({ user_id: userId, day }, { onConflict: "user_id,day", ignoreDuplicates: true });
  if (error) throw new DomainError("internal", "Cardio konnte nicht abgehakt werden.");
}

/** Nimmt das Abhaken zurueck; ein fehlender Tag ist kein Fehler. */
export async function deleteCardioCheck(client: SupabaseClient, userId: string, day: string): Promise<void> {
  pruefeTag(day);
  const { error } = await client.from("cardio_checks").delete().eq("user_id", userId).eq("day", day);
  if (error) throw new DomainError("internal", "Cardio konnte nicht zurueckgenommen werden.");
}

/** Die abgehakten Tage von `von` bis `bis` (beide eingeschlossen), aufsteigend. */
export async function listCardioChecks(client: SupabaseClient, userId: string, von: string, bis: string): Promise<string[]> {
  pruefeTag(von);
  pruefeTag(bis);
  if (von > bis) throw new DomainError("validation_failed", "Der Zeitraum beginnt nach seinem Ende.");
  const { data, error } = await client
    .from("cardio_checks")
    .select("day")
    .eq("user_id", userId)
    .gte("day", von)
    .lte("day", bis)
    .order("day", { ascending: true });
  if (error) throw new DomainError("internal", "Die Cardio-Tage konnten nicht geladen werden.");
  return (data ?? []).map((zeile) => zeile.day as string);
}
