"use server";

import { revalidatePath } from "next/cache";
import {
  DomainError,
  createEquipmentModel,
  uploadEquipmentPhoto,
} from "@fitretro/domain";
import { createServerSupabaseClient } from "@/lib/supabase/server";

/**
 * Die Server Actions des Gangs.
 *
 * Getrennt von portal/actions.ts, weil sie IDs zurueckgeben statt nur ok:
 * der naechste Schritt braucht die frische ID im Pfad. Der Zustand des Gangs
 * steht in der URL, nicht in einem Client-State -- ein Neuladen mitten in
 * der Halle verliert damit nichts.
 */

/** Fuer eine Aktion, die etwas zurueckgibt -- eine ID fuer den naechsten Schritt. */
export type Ergebnis<T> = ({ ok: true } & T) | { ok: false; error: string };

/** Fuer eine Aktion, die nur gelingt oder nicht. */
export type ActionErgebnis = { ok: true } | { ok: false; error: string };

/** Ein Ergebnisformat fuer alle Formulare: entweder es klappt, oder ein Satz. */
function fehlerAus(
  fehler: unknown,
  ersatz: string,
): { ok: false; error: string } {
  if (fehler instanceof DomainError) return { ok: false, error: fehler.message };
  // Ein unerwarteter Fehler wird geloggt, aber nie im Wortlaut angezeigt:
  // seine Meldung kann Spaltennamen oder IDs fremder Zeilen enthalten.
  console.error("Einrichtungsschritt fehlgeschlagen:", fehler);
  return { ok: false, error: ersatz };
}

function text(formData: FormData, name: string): string {
  return String(formData.get(name) ?? "").trim();
}

function optionalerText(formData: FormData, name: string): string | null {
  const wert = text(formData, name);
  return wert.length > 0 ? wert : null;
}

/** Deutsche Eingabe: 2,5 ist dasselbe wie 2.5. */
function zahl(formData: FormData, name: string): number | undefined {
  const roh = text(formData, name).replace(",", ".");
  if (roh.length === 0) return undefined;
  const wert = Number(roh);
  return Number.isFinite(wert) ? wert : Number.NaN;
}

/**
 * Modell und Foto in einem Aufruf. Das Foto ist Pflicht (Entscheidung 10),
 * aber die Spalte bleibt nullable -- Altmodelle tragen keines.
 *
 * Reihenfolge erzwungen: uploadEquipmentPhoto braucht eine Modell-ID, also
 * entsteht erst die Zeile. Schlaegt der Upload danach fehl, bleibt ein
 * Modell ohne Foto stehen. Das ist kein verlorener Zustand, sondern genau
 * der Fall, den Schritt 2 als "Foto fehlt" nachfragt (Entscheidung 12).
 */
export async function modellAnlegen(
  studioId: string,
  _prev: unknown,
  formData: FormData,
): Promise<Ergebnis<{ modelId: string }>> {
  const client = await createServerSupabaseClient();

  const datei = formData.get("photo");
  if (!(datei instanceof File) || datei.size === 0) {
    return {
      ok: false,
      error:
        "Ohne Foto geht es nicht weiter — es ist der einzige Grund, warum jemand vor dem falschen Gerät merkt, dass er falsch steht.",
    };
  }

  let modelId: string;
  try {
    const modell = await createEquipmentModel(client, {
      studioId,
      name: text(formData, "name"),
      manufacturer: optionalerText(formData, "manufacturer"),
      weightStepKg: zahl(formData, "weightStepKg") ?? Number.NaN,
      minWeightKg: zahl(formData, "minWeightKg") ?? 0,
      maxWeightKg: zahl(formData, "maxWeightKg") ?? null,
    });
    modelId = modell.id;
  } catch (fehler) {
    return fehlerAus(fehler, "Das Modell liess sich nicht anlegen.");
  }

  try {
    // Das Foto laeuft bewusst durch den Server: nur hier lassen sich die
    // Aufnahmedaten entfernen, bevor die Datei im Bucket landet.
    await uploadEquipmentPhoto(client, {
      equipmentModelId: modelId,
      bytes: new Uint8Array(await datei.arrayBuffer()),
    });
  } catch (fehler) {
    const antwort = fehlerAus(fehler, "Das Foto liess sich nicht speichern.");
    // Das Modell steht trotzdem -- der Gang geht weiter, Schritt 2 fragt das
    // Foto nach. Ein Rollback waere hier der schlechtere Zustand.
    revalidatePath(`/portal/${studioId}/einrichten`);
    return antwort;
  }

  revalidatePath(`/portal/${studioId}/einrichten`);
  return { ok: true, modelId };
}
