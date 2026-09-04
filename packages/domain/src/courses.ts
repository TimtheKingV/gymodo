import type { SupabaseClient } from "@supabase/supabase-js";
import { z } from "zod";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { serienTermine } from "./serie.js";
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
  await requireUserId(client);

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
  await requireUserId(client);

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

/**
 * `default_instructor_user_id` bleibt hier aussen vor. Die Spalte ist eine
 * Zuordnung, kein Text -- und kein Bildschirm dieser Phase kann sie
 * ausdruecken: die Vorlagenseite zeigt nur `defaultInstructorName`, keine
 * ID, in keinem Feld. Sie trotzdem aus der Eingabe zu schreiben hiesse,
 * dass jedes Speichern eine Zuordnung loescht, die jemand anders gesetzt
 * hat, ohne dass irgendwo ein Formular das verlangt hat. Das Setzen wird
 * Aufgabe des Bildschirms, der spaeter eine Trainerauswahl anbietet -- und
 * der entscheidet dann auch, was "nichts ausgewaehlt" bedeutet.
 */
export async function updateCourseTemplate(
  client: SupabaseClient,
  studioId: string,
  templateId: string,
  eingabe: Omit<CourseTemplateInput, "defaultInstructorUserId">,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, absage);

  const geprueft = vorlageSchema.omit({ defaultInstructorUserId: true }).safeParse(eingabe);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }

  const { data, error } = await client
    .from("course_templates")
    .update({
      name: geprueft.data.name,
      description: geprueft.data.description,
      default_duration_min: geprueft.data.defaultDurationMin,
      default_capacity: geprueft.data.defaultCapacity,
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

// ---------------------------------------------------------------------
// Termine
// ---------------------------------------------------------------------

const terminSchema = z.object({
  templateId: z.string().uuid("Ein Termin gehoert zu einer Vorlage."),
  startsAt: z.string().datetime({ offset: true }),
  durationMin: z
    .number()
    .int("Die Dauer zaehlt in ganzen Minuten.")
    .min(5, "Kuerzer als fuenf Minuten ist kein Kurs.")
    .max(480, "Laenger als acht Stunden ist kein Kurs."),
  capacity: z
    .number()
    .int("Plaetze zaehlen in ganzen Zahlen.")
    .min(1, "Ein Kurs ohne Platz ist keiner.")
    .max(500, "Mehr als 500 Plaetze ist kein Kursraum."),
  room: z.string().trim().nullable(),
  instructorUserId: z.string().uuid().nullable(),
  instructorName: z.string().trim().nullable(),
});

export type CourseSessionInput = z.infer<typeof terminSchema>;

/**
 * Auch das Ende der Serie ist eine Systemgrenze. Ohne diese Pruefung
 * ginge ein unbrauchbarer Wert bis in serienTermine durch und
 * Intl.DateTimeFormat wuerfe dort einen rohen RangeError -- ein
 * Absturz statt eines Satzes, den ein Mensch lesen kann.
 */
const wiederholungSchema = z
  .string()
  .datetime({ offset: true, message: "Das Ende der Wiederholung ist kein gültiger Zeitpunkt." })
  .nullable();

/**
 * Legt einen Termin an -- oder eine ausgeschriebene woechentliche Serie
 * bis einschliesslich `wiederholungBis`.
 *
 * Serientermine sind echte Zeilen, keine Regel (Spec Abschnitt 9). Der
 * Preis dafuer wird hier bezahlt: ein Insert mit n Zeilen. Der Gewinn ist,
 * dass danach jeder Termin einzeln aenderbar und absagbar ist, ohne dass
 * jemals eine Regel aufgeloest werden muss.
 *
 * Gerechnet wird in der Zeitzone des Studios (serie.ts), nicht auf dem
 * Zeitstrahl: 18:00 bleibt 18:00, auch ueber die Zeitumstellung.
 */
export async function createCourseSessions(
  client: SupabaseClient,
  studioId: string,
  eingabe: CourseSessionInput,
  wiederholungBis: string | null,
): Promise<string[]> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, absage);

  const geprueft = terminSchema.safeParse(eingabe);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }
  const wiederholungGeprueft = wiederholungSchema.safeParse(wiederholungBis);
  if (!wiederholungGeprueft.success) {
    throw new DomainError("validation_failed", wiederholungGeprueft.error.issues[0]!.message);
  }
  await pruefeTrainerZuordnung(client, studioId, geprueft.data.instructorUserId);

  // RLS prueft nur, dass DIESER Termin zu studioId gehoert -- die Foreign
  // Key auf course_templates prueft bloss, dass die Vorlage EXISTIERT, in
  // welchem Studio auch immer, und Fremdschluessel-Pruefungen laufen an
  // RLS vorbei. Ohne diesen Aufruf koennte Personal von Studio A einen
  // Termin anlegen, der auf eine bekannte Vorlagen-UUID von Studio B
  // zeigt -- und course_week gibt deren name/description an jedes
  // Mitglied von A weiter. getCourseTemplate praeft die studio_id schon
  // und wirft not_found, wenn sie nicht passt -- dieselbe Bauform wie
  // pruefeTrainerZuordnung: die Fachschicht erzwingt, was eine
  // check-Constraint nicht kann.
  await getCourseTemplate(client, studioId, geprueft.data.templateId);

  const { data: studio, error: studioFehler } = await client
    .from("studios")
    .select("timezone")
    .eq("id", studioId)
    .maybeSingle<{ timezone: string }>();
  if (studioFehler) throw new DomainError("internal", studioFehler.message);
  if (!studio) throw new DomainError("not_found", "Dieses Studio gibt es nicht.");

  const start = new Date(geprueft.data.startsAt);
  const zeitpunkte =
    wiederholungGeprueft.data === null
      ? [start]
      : serienTermine(start, new Date(wiederholungGeprueft.data), studio.timezone);

  const { data, error } = await client
    .from("course_sessions")
    .insert(
      zeitpunkte.map((zeitpunkt) => ({
        studio_id: studioId,
        course_template_id: geprueft.data.templateId,
        starts_at: zeitpunkt.toISOString(),
        duration_min: geprueft.data.durationMin,
        capacity: geprueft.data.capacity,
        room: geprueft.data.room,
        instructor_user_id: geprueft.data.instructorUserId,
        instructor_name: geprueft.data.instructorName,
      })),
    )
    .select("id")
    .returns<{ id: string }[]>();

  if (error) throw new DomainError("internal", error.message);
  return (data ?? []).map((z) => z.id);
}

/**
 * `instructor_user_id` bleibt hier aussen vor. Die Spalte ist die
 * Zuordnung, kein Text -- und kein Bildschirm dieser Phase kann sie
 * ausdruecken: `course_week`, der einzige Lesepfad des Termin-Bildschirms,
 * liefert nicht einmal `instructor_user_id` zurueck, nur den Anzeigenamen.
 * Sie trotzdem aus der Eingabe zu schreiben hiesse, dass jedes Speichern
 * eine Zuordnung loescht, die jemand anders gesetzt hat. Das Setzen wird
 * Aufgabe des Bildschirms, der spaeter eine Trainerauswahl anbietet -- und
 * der entscheidet dann auch, was "nichts ausgewaehlt" bedeutet.
 */
export async function updateCourseSession(
  client: SupabaseClient,
  studioId: string,
  sessionId: string,
  eingabe: Omit<CourseSessionInput, "templateId" | "instructorUserId">,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, absage);

  const geprueft = terminSchema
    .omit({ templateId: true, instructorUserId: true })
    .safeParse(eingabe);
  if (!geprueft.success) {
    throw new DomainError("validation_failed", geprueft.error.issues[0]!.message);
  }

  const { data, error } = await client
    .from("course_sessions")
    .update({
      starts_at: geprueft.data.startsAt,
      duration_min: geprueft.data.durationMin,
      capacity: geprueft.data.capacity,
      room: geprueft.data.room,
      instructor_name: geprueft.data.instructorName,
    })
    .eq("studio_id", studioId)
    .eq("id", sessionId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError("not_found", "Diesen Termin gibt es nicht.");
  }

  // capacity ist gerade eben moeglicherweise gestiegen -- ausserhalb der
  // beiden gesperrten Buchungsfunktionen, die sonst die einzigen sind,
  // die je nachruecken lassen. Ohne diesen Aufruf bliebe eine wartende
  // Liste bei einer erhoehten Kapazitaet fuer immer stehen (0038,
  // Finding 3). Unbedingter Aufruf: er ist ein No-op, wenn es nichts
  // nachzuruecken gibt.
  const { error: promoteFehler } = await client.rpc("promote_course_waitlist", {
    p_session_id: sessionId,
  });
  if (promoteFehler) throw new DomainError("internal", promoteFehler.message);
}

/**
 * Absage statt Loeschen: die Zeile bleibt stehen, damit angemeldete
 * Mitglieder sehen, was passiert ist. Die Buchungen bleiben ebenfalls
 * stehen -- sie nachtraeglich zu stornieren waere ein stilles Update auf
 * fremder Historie.
 */
export async function cancelCourseSession(
  client: SupabaseClient,
  studioId: string,
  sessionId: string,
): Promise<void> {
  const userId = await requireUserId(client);
  await requireStudioStaff(client, studioId, userId, absage);

  const { data, error } = await client
    .from("course_sessions")
    .update({ status: "cancelled", cancelled_at: new Date().toISOString() })
    .eq("studio_id", studioId)
    .eq("id", sessionId)
    .select("id");

  if (error) throw new DomainError("internal", error.message);
  if (!data || data.length === 0) {
    throw new DomainError("not_found", "Diesen Termin gibt es nicht.");
  }
}

// ---------------------------------------------------------------------
// Der Wochenplan
// ---------------------------------------------------------------------

export type CourseWeekSession = {
  sessionId: string;
  templateId: string;
  name: string;
  description: string | null;
  startsAt: string;
  localDay: string;
  durationMin: number;
  capacity: number;
  room: string | null;
  instructorName: string | null;
  status: "planned" | "cancelled";
  bookedCount: number;
  waitlistCount: number;
  freeSeats: number;
  ownStatus: "booked" | "waitlisted" | null;
  ownBookingId: string | null;
  ownWaitlistPosition: number | null;
};

export type CourseWeek = {
  from: string;
  to: string;
  timezone: string;
  sessions: CourseWeekSession[];
};

type WochenAntwort = {
  from: string;
  to: string;
  timezone: string;
  sessions: {
    session_id: string;
    template_id: string;
    name: string;
    description: string | null;
    starts_at: string;
    local_day: string;
    duration_min: number;
    capacity: number;
    room: string | null;
    instructor_name: string | null;
    status: "planned" | "cancelled";
    booked_count: number;
    waitlist_count: number;
    free_seats: number;
    own_status: "booked" | "waitlisted" | null;
    own_booking_id: string | null;
    own_waitlist_position: number | null;
  }[];
};

export async function listCourseWeek(
  client: SupabaseClient,
  studioId: string,
  from: string,
  to: string,
): Promise<CourseWeek> {
  await requireUserId(client);

  const { data, error } = await client.rpc("course_week", {
    p_studio_id: studioId,
    p_from: from,
    p_to: to,
  });

  if (error) throw new DomainError("internal", error.message);
  // null heisst "nicht erlaubt oder gibt es nicht" (Spec Abschnitt 5).
  // Beides wird zu not_found, damit die Antwort nicht verraet, welche
  // Studios es gibt.
  if (!data) throw new DomainError("not_found", "Diesen Kursplan gibt es nicht.");

  const antwort = data as WochenAntwort;
  return {
    from: antwort.from,
    to: antwort.to,
    timezone: antwort.timezone,
    sessions: antwort.sessions.map((s) => ({
      sessionId: s.session_id,
      templateId: s.template_id,
      name: s.name,
      description: s.description,
      startsAt: s.starts_at,
      localDay: s.local_day,
      durationMin: s.duration_min,
      capacity: s.capacity,
      room: s.room,
      instructorName: s.instructor_name,
      status: s.status,
      bookedCount: s.booked_count,
      waitlistCount: s.waitlist_count,
      freeSeats: s.free_seats,
      ownStatus: s.own_status,
      ownBookingId: s.own_booking_id,
      ownWaitlistPosition: s.own_waitlist_position,
    })),
  };
}

// ---------------------------------------------------------------------
// Teilnehmer
// ---------------------------------------------------------------------

export type CourseParticipant = {
  userId: string;
  email: string;
  status: "booked" | "waitlisted";
  bookedAt: string;
  promotedAt: string | null;
  waitlistPosition: number | null;
};

export async function listCourseParticipants(
  client: SupabaseClient,
  sessionId: string,
): Promise<CourseParticipant[]> {
  await requireUserId(client);

  const { data, error } = await client.rpc("list_course_participants", {
    p_session_id: sessionId,
  });

  if (error) throw new DomainError("internal", error.message);

  type Zeile = {
    user_id: string;
    email: string;
    status: "booked" | "waitlisted";
    booked_at: string;
    promoted_at: string | null;
    waitlist_position: number | null;
  };

  return ((data ?? []) as Zeile[]).map((z) => ({
    userId: z.user_id,
    email: z.email,
    status: z.status,
    bookedAt: z.booked_at,
    promotedAt: z.promoted_at,
    waitlistPosition: z.waitlist_position,
  }));
}

// ---------------------------------------------------------------------
// Buchen und Stornieren
// ---------------------------------------------------------------------

export type BookOutcome = {
  result: "booked" | "waitlisted";
  created: boolean;
  bookingId: string;
  waitlistPosition: number | null;
  freeSeats: number;
};

/**
 * Die duenne Huelle um book_course_session (0036).
 *
 * Hier wird die Regel aus Spec Abschnitt 5 in DomainError uebersetzt:
 * null bedeutet "nicht erlaubt oder gibt es nicht" und wird not_found --
 * beides antwortet gleich, damit die Meldung nicht verraet, welche
 * Termine es gibt. Ein Ergebnis mit einem anderen Grund als dem Zustand
 * ist ein erwarteter Ausgang und wird conflict mit einem Satz, den ein
 * Mensch lesen kann.
 */
export async function bookCourseSession(
  client: SupabaseClient,
  sessionId: string,
  bookingId: string,
): Promise<BookOutcome> {
  await requireUserId(client);

  const { data, error } = await client.rpc("book_course_session", {
    p_session_id: sessionId,
    p_booking_id: bookingId,
  });

  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("not_found", "Diesen Kurstermin gibt es nicht.");

  const antwort = data as {
    result: string;
    created: boolean;
    booking_id: string;
    waitlist_position: number | null;
    free_seats: number;
  };

  if (antwort.result === "session_cancelled") {
    throw new DomainError("conflict", "Dieser Termin fällt aus.");
  }
  if (antwort.result === "past") {
    throw new DomainError("conflict", "Dieser Kurs hat schon begonnen.");
  }
  if (antwort.result === "booking_id_reused") {
    // p_booking_id gehoert schon zu einer anderen Zeile -- oft der
    // eigenen, laengst stornierten (0038, Finding 4). Idempotenz gilt
    // nur fuer die EIGENE offene Buchung; alles andere braucht eine
    // frische Kennung, sonst liefe der Insert in der Datenbank in eine
    // Primary-Key-Verletzung.
    throw new DomainError(
      "conflict",
      "Diese Buchungskennung wurde schon verwendet. Bitte mit einer neuen Kennung erneut versuchen.",
    );
  }

  return {
    result: antwort.result as "booked" | "waitlisted",
    created: antwort.created,
    bookingId: antwort.booking_id,
    waitlistPosition: antwort.waitlist_position,
    freeSeats: antwort.free_seats,
  };
}

/**
 * promotedUserId ist nur fuer Personal gesetzt -- course_bookings_select
 * (0035) verbietet einem Mitglied, die Buchungszeile einer anderen Person
 * zu sehen, und cancel_course_booking (0038) haelt sich seit Finding 1 des
 * Gesamtreviews daran: ein Mitglied erfaehrt nur promoted, nie die
 * Identitaet. Nichts in diesem Repository liest promotedUserId heute --
 * das Feld bleibt aus demselben Grund stehen, aus dem promoted_at in 0035
 * angelegt wurde: eine kuenftige Anzeige braucht es nicht neu zu holen.
 */
export type CancelOutcome = { promotedUserId: string | null; promoted: boolean };

export async function cancelCourseBooking(
  client: SupabaseClient,
  sessionId: string,
  userId?: string,
): Promise<CancelOutcome> {
  await requireUserId(client);

  const { data, error } = await client.rpc("cancel_course_booking", {
    p_session_id: sessionId,
    p_user_id: userId ?? null,
  });

  if (error) throw new DomainError("internal", error.message);
  if (!data) throw new DomainError("not_found", "Diesen Kurstermin gibt es nicht.");

  const antwort = data as {
    result: string;
    deadline_hours?: number;
    promoted: boolean;
    promoted_user_id?: string | null;
  };

  if (antwort.result === "not_booked") {
    throw new DomainError("conflict", "Für diesen Termin bist du nicht angemeldet.");
  }
  if (antwort.result === "deadline") {
    const stunden = antwort.deadline_hours ?? 0;
    throw new DomainError(
      "conflict",
      stunden === 0
        ? "Der Kurs hat begonnen — Abmelden ist nicht mehr möglich."
        : `Abmelden ist bis ${stunden} Stunden vor Beginn möglich. Diese Frist ist vorbei.`,
    );
  }

  return {
    promotedUserId: antwort.promoted_user_id ?? null,
    promoted: antwort.promoted,
  };
}
