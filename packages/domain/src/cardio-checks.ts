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
  // Seit 0072 ist (user_id, day) nicht mehr eindeutig (ein Tag kann mehrere Haken
  // haben), also kein upsert: erst nachsehen, dann einfuegen. Ein Rennen zwischen
  // zwei Aufrufen ergibt hoechstens eine zweite Zeile, die listCardioChecks buendelt.
  const vorhanden = await client.from("cardio_checks").select("id").eq("user_id", userId).eq("day", day).limit(1);
  if (vorhanden.error) throw new DomainError("internal", "Cardio konnte nicht abgehakt werden.");
  if ((vorhanden.data ?? []).length > 0) return;
  const { error } = await client.from("cardio_checks").insert({ user_id: userId, day });
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
  // Mehrere Haken am selben Tag (seit 0072) ergeben einen Tag.
  return [...new Set((data ?? []).map((zeile) => zeile.day as string))];
}

/** Ein Cardio-Haken; ein Tag kann seit 0072 mehrere haben, `minuten` ist optional. */
export type CardioCheck = { id: string; day: string; minuten: number | null };

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Legt einen weiteren Haken fuer `day` an (auch wenn der Tag schon einen hat). */
export async function addCardioCheck(
  client: SupabaseClient,
  userId: string,
  day: string,
  heute: string,
  minuten?: number,
): Promise<CardioCheck> {
  pruefeTag(day);
  pruefeTag(heute);
  if (day > heute) throw new DomainError("validation_failed", "Cardio laesst sich nicht fuer die Zukunft abhaken.");
  if (minuten !== undefined && (!Number.isInteger(minuten) || minuten < 1 || minuten > 600)) {
    throw new DomainError("validation_failed", "Die Minuten muessen eine ganze Zahl von 1 bis 600 sein.");
  }
  const { data, error } = await client
    .from("cardio_checks")
    .insert({ user_id: userId, day, ...(minuten !== undefined ? { minuten } : {}) })
    .select("id, day, minuten")
    .single();
  if (error || !data) throw new DomainError("internal", "Cardio konnte nicht abgehakt werden.");
  return { id: data.id as string, day: data.day as string, minuten: (data.minuten as number | null) ?? null };
}

/** Nimmt genau einen Haken zurueck; eine fremde oder fehlende id ist kein Fehler (RLS blendet fremde aus). */
export async function deleteCardioCheckById(client: SupabaseClient, userId: string, id: string): Promise<void> {
  if (!UUID.test(id)) throw new DomainError("validation_failed", "Die id muss eine UUID sein.");
  const { error } = await client.from("cardio_checks").delete().eq("user_id", userId).eq("id", id);
  if (error) throw new DomainError("internal", "Cardio konnte nicht zurueckgenommen werden.");
}

/** Alle Haken von `von` bis `bis` (beide eingeschlossen), aufsteigend nach Tag und Anlegezeit. */
export async function listCardioCheckEintraege(
  client: SupabaseClient,
  userId: string,
  von: string,
  bis: string,
): Promise<CardioCheck[]> {
  pruefeTag(von);
  pruefeTag(bis);
  if (von > bis) throw new DomainError("validation_failed", "Der Zeitraum beginnt nach seinem Ende.");
  const { data, error } = await client
    .from("cardio_checks")
    .select("id, day, minuten")
    .eq("user_id", userId)
    .gte("day", von)
    .lte("day", bis)
    .order("day", { ascending: true })
    .order("created_at", { ascending: true });
  if (error) throw new DomainError("internal", "Die Cardio-Haken konnten nicht geladen werden.");
  return (data ?? []).map((z) => ({ id: z.id as string, day: z.day as string, minuten: (z.minuten as number | null) ?? null }));
}
