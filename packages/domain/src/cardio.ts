import { z } from "zod";
import type { LoadUnit, VolumeKind } from "./belastung.js";

/**
 * Die Werte eines Cardio-Satzes (Testnotiz 14.10., 18:45 #7; "Anzahl Stufen"
 * am Treppensteiger: Testnotiz 18.10., #5; Spec
 * 2026-10-15-cardio-werte-design). Die Reihenfolge ist die der Knoepfe und
 * der Satzzeile -- in der App steht dieselbe Liste (CardioWert.swift).
 */
export const CARDIO_WERTE = ["zeit", "strecke", "stufe", "stufenanzahl", "kmh", "steigung", "watt", "frequenz", "kcal"] as const;
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
    stufenanzahl: ganz(1, 10_000),
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
  stufenanzahl: "stufenanzahl",
  kmh: "kmh",
  steigung: "steigung_pct",
  watt: "watt",
  frequenz: "frequenz",
  kcal: "kcal",
};

export const CARDIO_SELECT = CARDIO_WERTE.map((w) => CARDIO_SPALTEN[w]).join(", ");

export type CardioZeile = Record<"dauer_s" | "strecke_m" | "stufe" | "stufenanzahl" | "kmh" | "steigung_pct" | "watt" | "kcal" | "frequenz", number | string | null>;

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

/** Der Bereich jeder Spalte (cardioWerteSchema, Migration 0054). */
const GRENZEN: Record<CardioWert, readonly [number, number]> = {
  zeit: [1, 86_400],
  strecke: [1, 200_000],
  stufe: [0, 100],
  stufenanzahl: [1, 10_000],
  kmh: [0, 50],
  steigung: [-10, 40],
  watt: [0, 3_000],
  frequenz: [0, 300],
  kcal: [0, 10_000],
};
const ZEHNTEL: readonly CardioWert[] = ["kmh", "steigung"];

/**
 * Die Cardio-Werte eines Satzes einer App von vor E2: load/volume an einem
 * Cardio-Geraet (Final-Review A; Spec 3.1). Dieselbe Regel wie Migration
 * 0055: Sekunden -> zeit, Meter -> strecke, die Belastung je Einheit in
 * ihren Wert, die Nebenbelastung nur, wenn die Belastung den Wert nicht
 * schon belegt. Was das Geraet nicht anbietet, faellt weg; jeder Wert wird
 * gerundet und in den Bereich seiner Spalte gekappt.
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
    if (!wert || zahl === null || zahl === undefined || !liste.includes(wert) || werte[wert] !== undefined) return;
    // Halbe Werte weg von der Null, wie round() in Postgres (Migration 0055):
    // Math.round runde -2,25 sonst auf -2,2 statt -2,3.
    const weg = (x: number) => Math.sign(x) * Math.round(Math.abs(x));
    const gerundet = ZEHNTEL.includes(wert) ? weg(zahl * 10) / 10 : weg(zahl);
    const [min, max] = GRENZEN[wert];
    werte[wert] = Math.min(Math.max(gerundet, min), max);
  };
  setze(e.volumeKind === "seconds" ? "zeit" : e.volumeKind === "meters" ? "strecke" : undefined, e.volume);
  setze(WERT_JE_EINHEIT[e.loadUnit], e.load);
  setze(e.secondaryUnit ? WERT_JE_EINHEIT[e.secondaryUnit] : undefined, e.secondaryLoad);
  return werte as CardioWerte;
}

/** Was ein Leseweg vom Geraet eines Satzes wissen muss, um ihn zu deuten. */
export type CardioGeraet = {
  /** Die geerbte Liste; leer bei Kraft. */
  liste: CardioWert[];
  loadUnit: LoadUnit;
  secondaryUnit: LoadUnit | null;
};

/**
 * Die Cardio-Werte eines gelesenen Satzes (Final-Review A). Ein Satz mit
 * Cardio-Spalten liefert sie; ein Satz einer alten App (load/volume) an
 * einem Cardio-Geraet liefert die daraus abgeleiteten Werte, damit die neue
 * App "20:00 · Stufe 5" zeigt. load/volume bleiben daneben stehen -- die
 * alte App liest sie als Pflichtfelder. `volumeKind` null: die Uebung ist
 * nicht mehr lesbar, dann zaehlt nur die Belastung.
 */
export function cardioDesSatzes(
  row: CardioZeile & {
    load: number | string | null;
    secondary_load: number | string | null;
    volume: number | null;
  },
  geraet: CardioGeraet | undefined,
  volumeKind: VolumeKind | null,
): CardioWerte | null {
  const eigene = cardioAusZeile(row);
  if (eigene || !geraet || geraet.liste.length === 0 || row.load === null) return eigene;
  const werte = altEingabeUmwandeln(
    {
      load: Number(row.load),
      secondaryLoad: row.secondary_load === null ? null : Number(row.secondary_load),
      volume: volumeKind ? row.volume : null,
      loadUnit: geraet.loadUnit,
      secondaryUnit: geraet.secondaryUnit,
      volumeKind: volumeKind ?? "reps",
    },
    geraet.liste,
  );
  return Object.keys(werte).length === 0 ? null : werte;
}
