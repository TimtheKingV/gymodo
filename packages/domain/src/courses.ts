import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { requireStudioStaff } from "./studio.js";

/**
 * Kurse, Spec 2026-09-03-kurse-design.md.
 *
 * Die Schreibvorgaenge auf Buchungen laufen ausschliesslich ueber die
 * beiden RPCs aus 0036 -- course_bookings hat bewusst keine
 * Insert-Policy. Was hier steht, ist Uebersetzung: aus Spalten Typen,
 * aus Ergebniswerten deutsche Saetze.
 */

const absage = "Nur Trainer und Inhaber pflegen den Kursplan.";

export type CourseTemplate = {
  id: string;
  studioId: string;
  name: string;
  description: string | null;
  defaultDurationMin: number;
  defaultCapacity: number;
  photoPath: string | null;
  defaultInstructorUserId: string | null;
  defaultInstructorName: string | null;
};

type VorlageZeile = {
  id: string;
  studio_id: string;
  name: string;
  description: string | null;
  default_duration_min: number;
  default_capacity: number;
  photo_path: string | null;
  default_instructor_user_id: string | null;
  default_instructor_name: string | null;
};

const VORLAGE_SPALTEN =
  "id, studio_id, name, description, default_duration_min, default_capacity, photo_path, default_instructor_user_id, default_instructor_name";

function zuVorlage(zeile: VorlageZeile): CourseTemplate {
  return {
    id: zeile.id,
    studioId: zeile.studio_id,
    name: zeile.name,
    description: zeile.description,
    defaultDurationMin: zeile.default_duration_min,
    defaultCapacity: zeile.default_capacity,
    photoPath: zeile.photo_path,
    defaultInstructorUserId: zeile.default_instructor_user_id,
    defaultInstructorName: zeile.default_instructor_name,
  };
}

/**
 * Die Grenzen sind dieselben wie die check-Constraints aus 0035 -- nicht,
 * weil eine der beiden Pruefungen ueberfluessig waere, sondern damit ein
 * Tippfehler als deutscher Satz zurueckkommt statt als 23514.
 */
const vorlageSchema = z.object({
  name: z.string().trim().min(1, "Der Kurs braucht einen Namen."),
  description: z.string().trim().nullable(),
  defaultDurationMin: z
    .number()
    .int("Die Dauer zaehlt in ganzen Minuten.")
    .min(5, "Kuerzer als fuenf Minuten ist kein Kurs.")
    .max(480, "Laenger als acht Stunden ist kein Kurs."),
  defaultCapacity: z
    .number()
    .int("Plaetze zaehlen in ganzen Zahlen.")
    .min(1, "Ein Kurs ohne Platz ist keiner.")
    .max(500, "Mehr als 500 Plaetze ist kein Kursraum."),
  defaultInstructorUserId: z.string().uuid().nullable(),
  defaultInstructorName: z.string().trim().nullable(),
});

export type CourseTemplateInput = z.infer<typeof vorlageSchema>;

/**
 * Zeigt die Zuordnung auf Personal DIESES Studios?
 *
 * Die Datenbank erzwingt das nicht: eine check-Constraint kann keine
 * Unterabfrage, und ein Trigger dafuer waere eine fuenfte Funktion in
 * einem Projekt, das vier ohne gesetzten search_path als offenen Punkt
 * fuehrt (0035, Kommentar an default_instructor_user_id). Hier ist die
 * Stelle, an der es geprueft wird.
 */
async function pruefeTrainerZuordnung(
  client: SupabaseClient,
  studioId: string,
  userId: string | null,
): Promise<void> {
  if (userId === null) return;

  const { data } = await client
    .from("studio_memberships")
    .select("role")
    .eq("studio_id", studioId)
    .eq("user_id", userId)
    .maybeSingle<{ role: string }>();

  if (!data || (data.role !== "trainer" && data.role !== "owner")) {
    throw new DomainError(
      "validation_failed",
      "Als Standard-Trainer kommt nur infrage, wer in diesem Studio Trainer oder Inhaber ist.",
    );
  }
}

export async function listCourseTemplates(
  client: SupabaseClient,
  studioId: string,
): Promise<CourseTemplate[]> {
  const { data, error } = await client
    .from("course_templates")
    .select(VORLAGE_SPALTEN)
    .eq("studio_id", studioId)
    .order("name", { ascending: true })
    .returns<VorlageZeile[]>();

  if (error) throw new DomainError("internal", error.message);
  return (data ?? []).map(zuVorlage);
}

export async function getCourseTemplate(
  client: SupabaseClient,
  studioId: string,
  templateId: string,
): Promise<CourseTemplate> {
  const { data, error } = await client
    .from("course_templates")
    .select(VORLAGE_SPALTEN)
    .eq("studio_id", studioId)
    .eq("id", templateId)
    .maybeSingle<VorlageZeile>();

  if (error) throw new DomainError("internal", error.message);
  // Eine fremde und eine nicht existierende Vorlage antworten gleich --
  // eine Fehlermeldung darf nie verraten, ob eine fremde Zeile existiert
  // (errors.ts).
  if (!data) throw new DomainError("not_found", "Diese Kursvorlage gibt es nicht.");
  return zuVorlage(data);
}

export async function createCourseTemplate(
  client: SupabaseClient,
  studioId: string,
  eingabe: CourseTemplateInput,
): Promise<string> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, absage);

  const geprueft = vorlageSchema.safeParse(eingabe);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  await pruefeTrainerZuordnung(client, studioId, geprueft.data.defaultInstructorUserId);

  const { data, error } = await client
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name: geprueft.data.name,
      description: geprueft.data.description,
      default_duration_min: geprueft.data.defaultDurationMin,
      default_capacity: geprueft.data.defaultCapacity,
      default_instructor_user_id: geprueft.data.defaultInstructorUserId,
      default_instructor_name: geprueft.data.defaultInstructorName,
    })
    .select("id")
    .single<{ id: string }>();

  if (error) throw new DomainError("internal", error.message);
  return data.id;
}

export async function updateCourseTemplate(
  client: SupabaseClient,
  studioId: string,
  templateId: string,
  eingabe: CourseTemplateInput,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, absage);

  const geprueft = vorlageSchema.safeParse(eingabe);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  await pruefeTrainerZuordnung(client, studioId, geprueft.data.defaultInstructorUserId);

  const { data, error } = await client
    .from("course_templates")
    .update({
      name: geprueft.data.name,
      description: geprueft.data.description,
      default_duration_min: geprueft.data.defaultDurationMin,
      default_capacity: geprueft.data.defaultCapacity,
      default_instructor_user_id: geprueft.data.defaultInstructorUserId,
      default_instructor_name: geprueft.data.defaultInstructorName,
    })
    .eq("studio_id", studioId)
    .eq("id", templateId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError("not_found", "Diese Kursvorlage gibt es nicht.");
  }
}
