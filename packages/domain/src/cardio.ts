import { z } from "zod";
import type { LoadUnit, VolumeKind } from "./belastung.js";

/**
 * Die Werte eines Cardio-Satzes (Testnotiz 14.10., 18:45 #7; Spec
 * 2026-10-15-cardio-werte-design). Die Reihenfolge ist die der Knoepfe und
 * der Satzzeile -- in der App steht dieselbe Liste (CardioWert.swift).
 */
export const CARDIO_WERTE = ["zeit", "strecke", "stufe", "kmh", "steigung", "watt", "frequenz", "kcal"] as const;
export type CardioWert = (typeof CARDIO_WERTE)[number];
export const cardioWertSchema = z.enum(CARDIO_WERTE);

const ganz = (min: number, max: number) => z.number().int().min(min).max(max).optional();
const zehntel = (min: number, max: number) =>
  z.number().min(min).max(max).refine((x) => Math.abs(x * 10 - Math.round(x * 10)) < 1e-9, "Höchstens eine Nachkommastelle.").optional();

export const cardioWerteSchema = z
  .object({
    zeit: ganz(1, 86_400),
    strecke: ganz(1, 200_000),
    stufe: ganz(0, 100),
    kmh: zehntel(0, 50),
    steigung: zehntel(-10, 40),
    watt: ganz(0, 3_000),
    frequenz: ganz(0, 300),
    kcal: ganz(0, 10_000),
  })
  .strict();
export type CardioWerte = z.infer<typeof cardioWerteSchema>;

export const cardioListeSchema = z
  .array(cardioWertSchema)
  .refine((liste) => new Set(liste).size === liste.length, "Ein Wert steht doppelt in der Liste.");

/** Spalte in workout_sets je Wert. */
export const CARDIO_SPALTEN: Record<CardioWert, string> = {
  zeit: "dauer_s",
  strecke: "strecke_m",
  stufe: "stufe",
  kmh: "kmh",
  steigung: "steigung_pct",
  watt: "watt",
  frequenz: "frequenz",
  kcal: "kcal",
};

export const CARDIO_SELECT = CARDIO_WERTE.map((w) => CARDIO_SPALTEN[w]).join(", ");

export type CardioZeile = Record<"dauer_s" | "strecke_m" | "stufe" | "kmh" | "steigung_pct" | "watt" | "kcal" | "frequenz", number | string | null>;

/** null, wenn kein Wert gesetzt ist -- dann ist es ein Kraftsatz. numeric kommt als Zeichenkette. */
export function cardioAusZeile(row: CardioZeile): CardioWerte | null {
  const werte: CardioWerte = {};
  for (const wert of CARDIO_WERTE) {
    const roh = row[CARDIO_SPALTEN[wert] as keyof CardioZeile];
    if (roh !== null && roh !== undefined) werte[wert] = Number(roh);
  }
  return Object.keys(werte).length === 0 ? null : werte;
}

export function cardioZuSpalten(werte: CardioWerte): Record<string, number | null> {
  return Object.fromEntries(CARDIO_WERTE.map((w) => [CARDIO_SPALTEN[w], werte[w] ?? null]));
}

/** Eigene Liste vor der des Katalog-Typs, geordnet nach CARDIO_WERTE (Spec 2.1). */
export function cardioListeDesModells(m: { eigene: readonly string[]; katalog: readonly string[] | null }): CardioWert[] {
  const quelle = m.eigene.length > 0 ? m.eigene : m.katalog ?? [];
  return CARDIO_WERTE.filter((w) => quelle.includes(w));
}

export function cardioPruefen(werte: CardioWerte, liste: readonly CardioWert[]): string | null {
  const gesetzt = CARDIO_WERTE.filter((w) => werte[w] !== undefined);
  if (gesetzt.length === 0) return "Mindestens ein Wert fehlt.";
  if (gesetzt.some((w) => !liste.includes(w))) return "Dieser Wert gehört nicht zu diesem Gerät.";
  return null;
}

const WERT_JE_EINHEIT: Partial<Record<LoadUnit, CardioWert>> = {
  level: "stufe",
  kmh: "kmh",
  watt: "watt",
  pct: "steigung",
  rpm: "frequenz",
};

/**
 * Ein Satz einer App von vor E2 an einem Cardio-Geraet: load/volume statt
 * cardio (Spec 3.1). Was das Geraet nicht anbietet, faellt weg, statt den
 * Satz abzulehnen -- er liegt vielleicht seit Tagen in einer Warteschlange.
 */
export function altEingabeUmwandeln(
  e: {
    load: number | null | undefined;
    secondaryLoad: number | null | undefined;
    volume: number | null | undefined;
    loadUnit: LoadUnit;
    secondaryUnit: LoadUnit | null;
    volumeKind: VolumeKind;
  },
  liste: readonly CardioWert[],
): CardioWerte {
  const werte: Partial<Record<CardioWert, number>> = {};
  const setze = (wert: CardioWert | undefined, zahl: number | null | undefined) => {
    if (wert && zahl !== null && zahl !== undefined && liste.includes(wert)) werte[wert] = zahl;
  };
  setze(e.volumeKind === "seconds" ? "zeit" : e.volumeKind === "meters" ? "strecke" : undefined, e.volume);
  setze(WERT_JE_EINHEIT[e.loadUnit], e.load);
  setze(e.secondaryUnit ? WERT_JE_EINHEIT[e.secondaryUnit] : undefined, e.secondaryLoad);
  // Ganzzahlige Spalten runden: eine alte Stufe 5.0 bleibt 5.
  for (const w of ["zeit", "strecke", "stufe", "watt", "frequenz", "kcal"] as const) {
    if (werte[w] !== undefined) werte[w] = Math.round(werte[w]!);
  }
  return werte as CardioWerte;
}
