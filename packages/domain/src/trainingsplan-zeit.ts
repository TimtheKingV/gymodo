// Zeitrechnung des Trainingsplans (Spec 2026-10-21, Abschnitt 2). Reine Funktionen,
// damit der Generator das Zeitbudget ohne I/O und ohne Uhr nachrechnen kann.
import type { Minuten, PlanTyp } from "./trainingsplan-typen.js";

// Vorgaben v1 (Schaetzwerte); spaeter mit gemessenen Dauern (Pausensumme) nachjustieren.
export const ZEIT = {
  aufwaermenMin: 5,
  satzMin: 0.75,
  pauseMin: { mehrgelenk: 2.5, isolation: 1.5 },
  aufwaermsatzMin: 1.5,
  einstellenMin: 1.5,
  toleranz: 0.05,
} as const;

/** Cardio am Ende; bei kurzen Einheiten entfaellt es, damit die Kraft nicht leidet. */
export function cardioMinuten(minuten: Minuten): 0 | 10 | 20 {
  if (minuten <= 30) return 0;
  if (minuten <= 45) return 10;
  return 20;
}

/** Dauer einer Planuebung; nur Mehrgelenkuebungen brauchen einen Aufwaermsatz. */
export function uebungMinuten(typ: PlanTyp, saetze: number): number {
  return (
    ZEIT.einstellenMin +
    saetze * ZEIT.satzMin +
    (saetze - 1) * ZEIT.pauseMin[typ] +
    (typ === "mehrgelenk" ? ZEIT.aufwaermsatzMin : 0)
  );
}

/** Bei 30 Minuten wird das allgemeine Aufwaermen gespart (Aufwaermsatz reicht). */
export function aufwaermenMinuten(minuten: Minuten): number {
  return minuten <= 30 ? 0 : ZEIT.aufwaermenMin;
}

export function pauseSekunden(typ: PlanTyp): number {
  return ZEIT.pauseMin[typ] * 60;
}
