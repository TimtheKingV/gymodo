import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { DomainError } from "./errors.js";
import {
  BEREICHE,
  ERFAHRUNG,
  FOKUS_BEREICHE,
  MINUTEN,
  type Bereich,
  type Erfahrung,
  type FokusBereich,
  type Minuten,
} from "./trainingsplan-typen.js";

export type TrainingProfile = { minutes: Minuten; experience: Erfahrung; focus: FokusBereich[] };
export type LimitStufe = "meiden" | "vorsichtig";
export type TrainingLimits = { consentAt: string; areas: Partial<Record<Bereich, LimitStufe>> };

const profilSchema = z.object({
  minutes: z
    .number()
    .refine((m): m is Minuten => (MINUTEN as readonly number[]).includes(m), "Unbekannte Trainingsdauer."),
  experience: z.enum(ERFAHRUNG, { message: "Unbekannte Erfahrung." }),
  focus: z
    .array(z.enum(FOKUS_BEREICHE, { message: "Unbekannter Fokusbereich." }))
    .max(2, "Hoechstens zwei Fokusbereiche.")
    .refine((f) => new Set(f).size === f.length, "Ein Fokusbereich nur einmal."),
});

// .strict(): ein unbekannter Bereich ist ein Fehler, kein stilles Verwerfen;
// Gesundheitsdaten sollen nur exakt die erlaubten Schluessel enthalten.
const limitsSchema = z.object({
  einwilligung: z.literal(true, { message: "Ohne ausdrueckliche Einwilligung keine Beschwerden." }),
  areas: z
    .object(
      Object.fromEntries(
        BEREICHE.map((b) => [b, z.enum(["meiden", "vorsichtig"], { message: "Unbekannte Stufe." }).optional()]),
      ),
    )
    .strict("Unbekannter Bereich."),
});

function pruefe<T>(schema: z.ZodType<T>, roh: unknown): T {
  const r = schema.safeParse(roh);
  if (!r.success) throw new DomainError("validation_failed", r.error.issues[0]!.message);
  return r.data;
}

export function pruefeTrainingsprofil(roh: unknown): TrainingProfile {
  return pruefe(profilSchema, roh) as TrainingProfile;
}

/** Liefert nur die bereinigten areas; die Einwilligung ist damit bestaetigt. */
export function pruefeTrainingsLimits(roh: unknown): { areas: TrainingLimits["areas"] } {
  const g = pruefe(limitsSchema, roh);
  return { areas: g.areas as TrainingLimits["areas"] };
}

export async function getTrainingProfile(client: SupabaseClient, userId: string): Promise<TrainingProfile | null> {
  const { data, error } = await client
    .from("training_profiles")
    .select("minutes, experience, focus")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new DomainError("internal", "Das Trainingsprofil konnte nicht gelesen werden.");
  if (!data) return null;
  return { minutes: data.minutes, experience: data.experience, focus: data.focus };
}

export async function saveTrainingProfile(
  client: SupabaseClient,
  userId: string,
  input: unknown,
): Promise<TrainingProfile> {
  const profil = pruefeTrainingsprofil(input);
  const { error } = await client.from("training_profiles").upsert(
    { user_id: userId, ...profil, updated_at: new Date().toISOString() },
    { onConflict: "user_id" },
  );
  if (error) throw new DomainError("internal", "Das Trainingsprofil konnte nicht gespeichert werden.");
  return profil;
}

export async function getTrainingLimits(client: SupabaseClient, userId: string): Promise<TrainingLimits | null> {
  const { data, error } = await client
    .from("training_limits")
    .select("consent_at, areas")
    .eq("user_id", userId)
    .maybeSingle();
  if (error) throw new DomainError("internal", "Die Beschwerden konnten nicht gelesen werden.");
  if (!data) return null;
  return { consentAt: data.consent_at, areas: data.areas };
}

/**
 * consent_at kommt immer von `now`, nie aus der Eingabe. Jedes PUT erneuert die Einwilligung
 * bewusst: wer Beschwerden aendert, bestaetigt sie mit genau diesem Stand neu.
 */
export async function saveTrainingLimits(
  client: SupabaseClient,
  userId: string,
  input: unknown,
  now: Date,
): Promise<TrainingLimits> {
  const { areas } = pruefeTrainingsLimits(input);
  const stempel = now.toISOString();
  const { error } = await client.from("training_limits").upsert(
    { user_id: userId, consent_at: stempel, areas, updated_at: stempel },
    { onConflict: "user_id" },
  );
  if (error) throw new DomainError("internal", "Die Beschwerden konnten nicht gespeichert werden.");
  return { consentAt: stempel, areas };
}

/**
 * Einwilligung widerrufen = Zeile loeschen; keine Zeile ist kein Fehler.
 * Danach werden die eigenen Plaene bereinigt: Flag beschwerdenBeruecksichtigt und die
 * beschwerden_*-Gruende verraten sonst weiter, dass es Beschwerden gab (DSGVO Art. 9).
 * Die Uebungen (einheiten) bleiben, weil Plaene stabil sind (F14). Wiederholbar: ein
 * erneuter Aufruf nach einem Teilfehler raeumt den Rest auf.
 */
export async function deleteTrainingLimits(client: SupabaseClient, userId: string): Promise<void> {
  const { error } = await client.from("training_limits").delete().eq("user_id", userId);
  if (error) throw new DomainError("internal", "Die Beschwerden konnten nicht geloescht werden.");
  await bereinigePlaeneNachWiderruf(client, userId);
}

type PlanRest = { id: string; studio_id: string; eingabe: Record<string, unknown>; gruende: string[] };

async function bereinigePlaeneNachWiderruf(client: SupabaseClient, userId: string): Promise<void> {
  const fehler = () => new DomainError("internal", "Die Beschwerden konnten nicht aus den Plaenen entfernt werden.");
  // Die Update-Policy verlangt die Mitgliedschaft im Studio der Zeile; Zeilen aus verlassenen
  // Studios lassen sich mit dem Mitglieds-Client nicht aendern und wuerden das Update scheitern lassen.
  const [plaene, mitgliedschaften] = await Promise.all([
    client.from("training_plans").select("id, studio_id, eingabe, gruende").eq("user_id", userId),
    client.from("studio_memberships").select("studio_id").eq("user_id", userId),
  ]);
  if (plaene.error || mitgliedschaften.error) throw fehler();
  const studios = new Set((mitgliedschaften.data ?? []).map((z) => z.studio_id as string));
  const betroffen = ((plaene.data ?? []) as PlanRest[]).filter(
    (p) =>
      studios.has(p.studio_id) &&
      (p.eingabe.beschwerdenBeruecksichtigt === true || p.gruende.some((g) => g.startsWith("beschwerden_"))),
  );
  for (const p of betroffen) {
    const { error: e } = await client
      .from("training_plans")
      .update({
        eingabe: { ...p.eingabe, beschwerdenBeruecksichtigt: false },
        gruende: p.gruende.filter((g) => !g.startsWith("beschwerden_")),
      })
      .eq("id", p.id)
      .eq("user_id", userId);
    if (e) throw fehler();
  }
}
