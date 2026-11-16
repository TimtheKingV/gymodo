import type { TrainingProfile } from "./trainingsprofil.js";

/** Das Wochenziel als Zaehler (wie oft, nicht wann); der Server rechnet es, die App zeigt es. */
export type Wochenziel = { kraft: number; cardio: number; cardioMinuten: number };

const KRAFT_FALLBACK = 2;
const CARDIO_MINUTEN_FALLBACK = 30;

const klemme = (n: number) => Math.min(7, Math.max(1, Math.round(n)));
const zahl = (n: number | null | undefined): n is number => typeof n === "number" && Number.isFinite(n);

/**
 * Kraft: Profil-Zaehler, sonst Tage des aktiven Plans, sonst Ziel weekly_days, sonst 2 (1..7).
 * So zeigt ein Bestandskonto ohne neue Profilfelder nie 0 Kraft-Karten.
 */
export function berechneWochenziel(
  profil: TrainingProfile | null,
  weeklyDays: number | null,
  planTage: number | null,
): Wochenziel {
  const kraft = [profil?.kraftProWoche, planTage, weeklyDays].find(zahl) ?? KRAFT_FALLBACK;
  return {
    kraft: klemme(kraft),
    cardio: profil?.cardioProWoche ?? 0,
    cardioMinuten: profil?.cardioMinuten ?? CARDIO_MINUTEN_FALLBACK,
  };
}
