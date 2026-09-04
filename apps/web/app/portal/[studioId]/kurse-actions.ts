"use server";

import { revalidatePath } from "next/cache";
import { redirect } from "next/navigation";
import {
  DomainError,
  cancelCourseBooking,
  cancelCourseSession,
  createCourseSessions,
  createCourseTemplate,
  updateCourseSession,
  updateCourseTemplate,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Die Server Actions der Kursseiten.
 *
 * Getrennt von portal/actions.ts, weil die bestehende Datei bereits vier
 * Bereiche und zwanzig Importe traegt -- ein fuenfter Bereich gehoert in
 * eine eigene Datei, statt jene weiter wachsen zu lassen.
 */

import type { ActionResult } from "../actions";

function alsErgebnis(fehler: unknown): ActionResult {
  if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
  return { ok: false, error: "Das hat nicht geklappt. Versuch es noch einmal." };
}

function text(formular: FormData, feld: string): string {
  return String(formular.get(feld) ?? "").trim();
}

function optionalerText(formular: FormData, feld: string): string | null {
  const wert = text(formular, feld);
  return wert === "" ? null : wert;
}

function zahl(formular: FormData, feld: string): number {
  return Number(formular.get(feld));
}

export async function vorlageAnlegenAction(
  studioId: string,
  _vorher: unknown,
  formular: FormData,
): Promise<ActionResult> {
  let neueId: string;
  try {
    const client = await createServerSupabaseClient();
    neueId = await createCourseTemplate(client, studioId, {
      name: text(formular, "name"),
      description: optionalerText(formular, "beschreibung"),
      defaultDurationMin: zahl(formular, "dauer"),
      defaultCapacity: zahl(formular, "plaetze"),
      // Kein Formular dieser Phase rendert ein trainerId-Feld -- ein
      // Lesen hier waere derselbe Fehler, der auf den Update-Pfaden
      // schon in 32d83e9 geschlossen wurde: ein Feld lesen, das niemand
      // setzt, heisst die Spalte bei jedem Aufruf auf NULL schreiben.
      // Das Setzen ist Aufgabe der Trainerauswahl, die die Spec als
      // offenen Punkt fuehrt.
      defaultInstructorUserId: null,
      defaultInstructorName: optionalerText(formular, "trainerName"),
    });
  } catch (fehler) {
    return alsErgebnis(fehler);
  }
  revalidatePath(`/portal/${studioId}/kurse/vorlagen`);
  redirect(`/portal/${studioId}/kurse/vorlagen/${neueId}`);
}

export async function vorlageSpeichernAction(
  studioId: string,
  templateId: string,
  _vorher: unknown,
  formular: FormData,
): Promise<ActionResult> {
  try {
    const client = await createServerSupabaseClient();
    await updateCourseTemplate(client, studioId, templateId, {
      name: text(formular, "name"),
      description: optionalerText(formular, "beschreibung"),
      defaultDurationMin: zahl(formular, "dauer"),
      defaultCapacity: zahl(formular, "plaetze"),
      defaultInstructorName: optionalerText(formular, "trainerName"),
    });
  } catch (fehler) {
    return alsErgebnis(fehler);
  }
  revalidatePath(`/portal/${studioId}/kurse/vorlagen/${templateId}`);
  return { ok: true };
}

export async function terminAnlegenAction(
  studioId: string,
  _vorher: unknown,
  formular: FormData,
): Promise<ActionResult> {
  try {
    const client = await createServerSupabaseClient();
    await createCourseSessions(
      client,
      studioId,
      {
        templateId: text(formular, "vorlageId"),
        startsAt: text(formular, "startsAt"),
        durationMin: zahl(formular, "dauer"),
        capacity: zahl(formular, "plaetze"),
        room: optionalerText(formular, "raum"),
        // Kein Formular dieser Phase rendert ein trainerId-Feld -- siehe
        // Kommentar in vorlageAnlegenAction.
        instructorUserId: null,
        instructorName: optionalerText(formular, "trainerName"),
      },
      optionalerText(formular, "wiederholungBis"),
    );
  } catch (fehler) {
    return alsErgebnis(fehler);
  }
  revalidatePath(`/portal/${studioId}/kurse`);
  redirect(`/portal/${studioId}/kurse`);
}

export async function terminSpeichernAction(
  studioId: string,
  sessionId: string,
  _vorher: unknown,
  formular: FormData,
): Promise<ActionResult> {
  try {
    const client = await createServerSupabaseClient();
    await updateCourseSession(client, studioId, sessionId, {
      startsAt: text(formular, "startsAt"),
      durationMin: zahl(formular, "dauer"),
      capacity: zahl(formular, "plaetze"),
      room: optionalerText(formular, "raum"),
      instructorName: optionalerText(formular, "trainerName"),
    });
  } catch (fehler) {
    return alsErgebnis(fehler);
  }
  // Wie terminAbsagenAction: Kapazitaet, Beginn und Belegung stehen auch
  // auf der Wochenuebersicht, nicht nur auf dieser Seite.
  revalidatePath(`/portal/${studioId}/kurse/termin/${sessionId}`);
  revalidatePath(`/portal/${studioId}/kurse`);
  return { ok: true };
}

export async function terminAbsagenAction(
  studioId: string,
  sessionId: string,
): Promise<ActionResult> {
  try {
    const client = await createServerSupabaseClient();
    await cancelCourseSession(client, studioId, sessionId);
  } catch (fehler) {
    return alsErgebnis(fehler);
  }
  revalidatePath(`/portal/${studioId}/kurse/termin/${sessionId}`);
  revalidatePath(`/portal/${studioId}/kurse`);
  return { ok: true };
}

export async function teilnehmerEntfernenAction(
  studioId: string,
  sessionId: string,
  userId: string,
): Promise<ActionResult> {
  try {
    const client = await createServerSupabaseClient();
    await cancelCourseBooking(client, sessionId, userId);
  } catch (fehler) {
    return alsErgebnis(fehler);
  }
  // Der entfernte Teilnehmer aendert den gebuchten Zaehler, den auch die
  // Wochenuebersicht zeigt.
  revalidatePath(`/portal/${studioId}/kurse/termin/${sessionId}`);
  revalidatePath(`/portal/${studioId}/kurse`);
  return { ok: true };
}
