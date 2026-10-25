/**
 * Startwert, Uebertragung und Wiedereinstieg fuer Zielgewichte.
 *
 * Haupt-Spec 2026-10-21 Abschnitt 6 (Startgewicht, Uebertragung, F18) und
 * Etappe-4-Spec G5, G12. Rein und deterministisch: keine Uhr, der Abstand in
 * Tagen wird uebergeben. Alle Ergebnisse liegen in loadMin..loadMax auf einer
 * einstellbaren Stufe; gerundet wird immer ab ("lieber zu leicht").
 */
import type { Erfahrung } from "./trainingsplan-typen.js";
import type { PlanGewichtGrund } from "./plangewicht.js";
import { snapToNearestStep, type WorkoutSetInput } from "./progression.js";

export type Geraetegrenzen = { loadStep: number; loadMin: number; loadMax: number };

/**
 * Faktortabelle der Startschaetzung v1 (unvalidierte, bewusst vorsichtige Puffer).
 * Der Geraetestartwert (load_start) gilt als Wert fuer eine regelmaessig
 * trainierende, durchschnittliche Person; die Faktoren senken ihn nur, sie
 * erhoehen ihn nie, weil eine zu leichte Last im Training sofort korrigiert
 * wird, eine zu schwere aber Verletzungen und Abbruch riskiert.
 * - Erfahrung: neu 0,70 (Technik und Sehnen brauchen Zeit), unregelmaessig 0,85,
 *   regelmaessig 1,00.
 * - Geschlecht: weiblich 0,90 (geringere absolute Kraft im Mittel, Spanne
 *   gross; relative Aufbaufaehigkeit aehnlich, daher nur der Startwert).
 * - Altersgruppe (untere Grenze): bis 29 1,00; 30-49 0,95; 50-64 0,90; ab 65 0,80.
 * - Koerpergewicht: unter 60 kg 0,90; unter 75 kg 0,95; sonst 1,00 (kein Bonus).
 * Fehlende oder nicht lesbare Angaben zaehlen als 1,00.
 */
export const STARTSCHAETZUNG_VERSION = "1.0.0";

export const STARTSCHAETZUNG_FAKTOREN = {
  erfahrung: { neu: 0.7, unregelmaessig: 0.85, regelmaessig: 1 } as Record<Erfahrung, number>,
  weiblich: 0.9,
  alter: [
    { ab: 65, faktor: 0.8 },
    { ab: 50, faktor: 0.9 },
    { ab: 30, faktor: 0.95 },
  ],
  koerpergewicht: [
    { unter: 60, faktor: 0.9 },
    { unter: 75, faktor: 0.95 },
  ],
} as const;

/**
 * Wiedereinstieg nach Pausen (F18), Abstand in Tagen zum letzten Block.
 * Unvalidierte Puffer, keine behaupteten Kraftverluste.
 */
export const WIEDEREINSTIEG_VERSION = "1.0.0";

export const WIEDEREINSTIEG_STUFEN = [
  { bisTage: 7, faktor: 1, saetzeMinus: 0 },
  { bisTage: 14, faktor: 1, saetzeMinus: 0 },
  { bisTage: 28, faktor: 0.925, saetzeMinus: 1 },
  { bisTage: 42, faktor: 0.875, saetzeMinus: 1 },
] as const;

/** Uebertragung: 3 % Last je Wiederholung Abweichung, gedeckelt auf +-20 %. */
export const UEBERTRAGUNG_PROZENT_JE_WDH = 0.03;
export const UEBERTRAGUNG_DECKEL = 0.2;

/** Begrenzt auf loadMin..loadMax und rundet ab auf eine einstellbare Stufe. */
function abgerundet(wunsch: number, g: Geraetegrenzen): number {
  const begrenzt = Math.min(Math.max(wunsch, g.loadMin), g.loadMax);
  const stufen = Math.floor((begrenzt - g.loadMin) / g.loadStep + 1e-9);
  return Math.min(g.loadMin + stufen * g.loadStep, g.loadMax);
}

/** G12: Last des letzten Arbeitssatzes des letzten Blocks, auf die Stufe gerastet. */
export function startgewichtAusHistorie(block: WorkoutSetInput[], geraet: Geraetegrenzen): number | null {
  const letzter = block[block.length - 1];
  if (letzter === undefined) return null;
  const gerastet = snapToNearestStep(letzter.load, geraet);
  return Math.min(Math.max(gerastet, geraet.loadMin), geraet.loadMax);
}

function alterFaktor(gruppe: string | null): number {
  const m = gruppe === null ? null : /\d+/.exec(gruppe);
  if (m === null) return 1;
  const alter = Number(m[0]);
  return STARTSCHAETZUNG_FAKTOREN.alter.find((s) => alter >= s.ab)?.faktor ?? 1;
}

export function schaetzeStartgewicht(e: {
  loadStart: number | null;
  erfahrung: Erfahrung;
  geschlecht: string | null;
  altersgruppe: string | null;
  koerpergewichtKg: number | null;
  geraet: Geraetegrenzen;
}): number {
  const f = STARTSCHAETZUNG_FAKTOREN;
  const weiblich = e.geschlecht !== null && ["w", "f", "weiblich", "female"].includes(e.geschlecht.toLowerCase());
  const kg = e.koerpergewichtKg;
  const kgFaktor = kg === null ? 1 : (f.koerpergewicht.find((s) => kg < s.unter)?.faktor ?? 1);
  const faktor = f.erfahrung[e.erfahrung] * (weiblich ? f.weiblich : 1) * alterFaktor(e.altersgruppe) * kgFaktor;
  return abgerundet((e.loadStart ?? e.geraet.loadMin) * faktor, e.geraet);
}

/** Last-Faktor (z. B. 1,09) aus gemachten Wiederholungen plus Reserve gegen Zielmitte plus Zielreserve. */
export function uebertragungsFaktor(e: {
  gemacht: number;
  reserve: number;
  wdhMitte: number;
  zielreserve: number;
}): number {
  const abweichung = e.gemacht + e.reserve - (e.wdhMitte + e.zielreserve);
  const korrektur = Math.min(
    Math.max(abweichung * UEBERTRAGUNG_PROZENT_JE_WDH, -UEBERTRAGUNG_DECKEL),
    UEBERTRAGUNG_DECKEL,
  );
  return 1 + korrektur;
}

/**
 * F18. Bis 14 Tage bleibt das Ziel unveraendert (grund null); die Steigerung
 * ab 8 Tagen unterdrueckt der Aufrufer. Ueber 42 Tage gibt es keine Last:
 * es gilt die Startschaetzung.
 */
export function wiedereinstieg(
  abstandTage: number,
  ziel: number,
  geraet: Geraetegrenzen,
): { load: number | null; saetzeMinus: 0 | 1; grund: PlanGewichtGrund | null } {
  const stufe = WIEDEREINSTIEG_STUFEN.find((s) => abstandTage <= s.bisTage);
  if (stufe === undefined) return { load: null, saetzeMinus: 0, grund: "startschaetzung" };
  if (stufe.faktor === 1) return { load: ziel, saetzeMinus: 0, grund: null };
  return { load: abgerundet(ziel * stufe.faktor, geraet), saetzeMinus: stufe.saetzeMinus, grund: "wiedereinstieg" };
}
