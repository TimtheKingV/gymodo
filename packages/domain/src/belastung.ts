import { z } from "zod";

/**
 * EIN Ort fuer Einheiten, Umfangsarten und ihre Darstellung.
 *
 * Spec 2026-09-21-cardio-geraete-design, Abschnitt 5.3: Die Regel in
 * progression.ts rechnet nur mit Zahlen; was die Zahlen bedeuten, sagen
 * `load_unit` am Geraetemodell und `volume_kind` an der Uebung. Alles, was
 * eine Einheit KENNEN muss -- Formatierung, Vorgaben, Obergrenzen -- steht
 * hier und nirgends sonst. Eine neue Einheit kostet je Funktion eine
 * Zeile und einen Eintrag im Check-Constraint (Migration 0045).
 *
 * Belastung und Nebenbelastung teilen sich dieselbe Liste: die Neigung
 * (pct) ist am Laufband Nebenbelastung, koennte an einem anderen Geraet
 * aber die Hauptbelastung sein. Eine zweite Liste waere eine Kopie, die
 * auseinanderlaeuft.
 */

export const LOAD_UNITS = ["kg", "watt", "level", "kmh", "pct", "rpm"] as const;
export type LoadUnit = (typeof LOAD_UNITS)[number];
export const loadUnitSchema = z.enum(LOAD_UNITS);

export const VOLUME_KINDS = ["reps", "seconds", "meters"] as const;
export type VolumeKind = (typeof VOLUME_KINDS)[number];
export const volumeKindSchema = z.enum(VOLUME_KINDS);

/** Nur Anzeige (Spec Abschnitt 3.5). Keine Regel liest sie. */
export const CATEGORIES = ["kraft", "cardio"] as const;
export type Category = (typeof CATEGORIES)[number];
export const categorySchema = z.enum(CATEGORIES);

/**
 * Obergrenze je Umfangsart. Die Datenbank kennt nur die Schranke gegen
 * Unsinn (100000, Migration 0045); die fachliche Grenze prueft recordSet
 * gegen die Uebung. Vier Stunden sind kein Satz, und 1000 Wiederholungen
 * waren schon vorher die Grenze.
 */
export const MAX_VOLUME: Record<VolumeKind, number> = {
  reps: 1000,
  seconds: 4 * 60 * 60,
  meters: 100_000,
};

export function volumeZuGross(kind: VolumeKind): string {
  switch (kind) {
    case "reps":
      return "Mehr als 1000 Wiederholungen sind kein Satz.";
    case "seconds":
      return "Mehr als vier Stunden sind kein Satz.";
    case "meters":
      return "Mehr als 100 km sind kein Satz.";
  }
}

/**
 * Nachkommastellen je Einheit. Kilogramm immer eine ("80,0 statt 80 --
 * sonst liest sich ein Wechsel auf 82,5 wie ein Formatfehler", bisher in
 * layout.tsx), Watt, Level und Umdrehungen keine: ihre Rastung ist ganz.
 */
const NACHKOMMASTELLEN: Record<LoadUnit, number> = {
  kg: 1,
  watt: 0,
  level: 0,
  kmh: 1,
  pct: 1,
  rpm: 0,
};

function zahl(wert: number, stellen: number): string {
  return wert.toLocaleString("de-DE", {
    minimumFractionDigits: stellen,
    maximumFractionDigits: stellen,
  });
}

/** "80,0 kg", "120 W", "Level 8", "8,5 km/h", "6,0 %", "85 U/min" */
export function formatLoad(value: number, unit: LoadUnit): string {
  const z = zahl(value, NACHKOMMASTELLEN[unit]);
  switch (unit) {
    case "kg":
      return `${z} kg`;
    case "watt":
      return `${z} W`;
    case "level":
      return `Level ${z}`;
    case "kmh":
      return `${z} km/h`;
    case "pct":
      return `${z} %`;
    case "rpm":
      return `${z} U/min`;
  }
}

/**
 * "+2,5 kg", "-10 W", "+1 Level". Das Vorzeichen steht immer, auch bei
 * null -- der Abschluss-Screen zeigt eine Rechnung, keine Empfehlung, und
 * "+0,0 kg" sagt ehrlicher "halten" als eine nackte Zahl.
 */
export function formatLoadDelta(delta: number, unit: LoadUnit): string {
  const vorzeichen = delta < 0 ? "-" : "+";
  const betrag = Math.abs(delta);
  // "Level 8" ist eine Stufe, "+1 Level" eine Aenderung um eine Stufe --
  // das Praefix der Anzeige taugt nicht fuer das Delta.
  if (unit === "level") return `${vorzeichen}${zahl(betrag, 0)} Level`;
  return `${vorzeichen}${formatLoad(betrag, unit)}`;
}

function minutenSekunden(seconds: number): string {
  const min = Math.floor(seconds / 60);
  const sek = seconds % 60;
  return `${min}:${String(sek).padStart(2, "0")}`;
}

/** "12 Wdh.", "20:00 min", "2.000 m" */
export function formatVolume(value: number, kind: VolumeKind): string {
  switch (kind) {
    case "reps":
      return `${zahl(value, 0)} Wdh.`;
    case "seconds":
      return `${minutenSekunden(value)} min`;
    case "meters":
      return `${zahl(value, 0)} m`;
  }
}

/**
 * "8–12 Wiederholungen", "15–20 min", "2.000–5.000 m". Der Korridor der
 * Uebung, wie das Portal und der Geraete-Screen ihn nennen. Minuten hier
 * ohne Sekunden: ein Korridor ist eine Vorgabe, keine Stoppuhr.
 */
export function formatVolumeRange(min: number, max: number, kind: VolumeKind): string {
  switch (kind) {
    case "reps":
      return `${zahl(min, 0)}–${zahl(max, 0)} Wiederholungen`;
    case "seconds":
      return `${zahl(Math.round(min / 60), 0)}–${zahl(Math.round(max / 60), 0)} min`;
    case "meters":
      return `${zahl(min, 0)}–${zahl(max, 0)} m`;
  }
}

/**
 * Startwerte fuer das Portal, wenn ein Trainer ein Modell anlegt. Die
 * Kilogramm-Werte sind die bisherigen Vorgaben (ModellGewichtRad: ab 0,
 * kein Anschlag, Schritt 2,5); der Rest sind uebliche Geraetebereiche,
 * die der Trainer am Rad korrigiert.
 */
export function defaultLoadRange(unit: LoadUnit): {
  min: number;
  max: number | null;
  step: number;
} {
  switch (unit) {
    case "kg":
      return { min: 0, max: null, step: 2.5 };
    case "watt":
      return { min: 25, max: 400, step: 5 };
    case "level":
      return { min: 1, max: 20, step: 1 };
    case "kmh":
      return { min: 0, max: 20, step: 0.5 };
    case "pct":
      return { min: 0, max: 15, step: 0.5 };
    case "rpm":
      return { min: 50, max: 120, step: 5 };
  }
}

/** Korridor-Vorgabe je Umfangsart: 8-12 wie bisher (M1 SS8.4), 15-20 min, 2-5 km. */
export function defaultTargetRange(kind: VolumeKind): { min: number; max: number } {
  switch (kind) {
    case "reps":
      return { min: 8, max: 12 };
    case "seconds":
      return { min: 15 * 60, max: 20 * 60 };
    case "meters":
      return { min: 2000, max: 5000 };
  }
}

/**
 * Rastet einen Wert auf die Stufen eines Geraets und klemmt ihn in dessen
 * Grenzen. Fuer die Nebenbelastung beim Schreiben eines Satzes: "82 U/min"
 * und "85 U/min" sollen dieselbe Bedingung sein, sonst zaehlte die Regel
 * zwei Tage mit gleicher Neigung als verschiedene Bedingungen.
 *
 * Epsilon vor dem Runden wie in Rastwerte.swift: (0,3 - 0) / 0,1 wird in
 * Gleitkomma zu 2.9999999999999996.
 */
export function snapToStep(
  value: number,
  min: number,
  max: number | null,
  step: number,
): number {
  if (!(step > 0)) return value;
  const geklemmt = Math.min(Math.max(value, min), max ?? Number.POSITIVE_INFINITY);
  const stufen = Math.round((geklemmt - min) / step + 1e-9);
  const gerastet = min + stufen * step;
  // Bei Schritt 0,1 wird 0 + 3 * 0,1 zu 0.30000000000000004; auf die
  // Nachkommastellen der Datenbank (numeric(6,2)) runden.
  const ergebnis = Number(gerastet.toFixed(2));
  return max !== null && ergebnis > max ? Number((min + (stufen - 1) * step).toFixed(2)) : ergebnis;
}
