import { DomainError } from "./errors.js";

/** ISO-Wochentag: 1 = Montag ... 7 = Sonntag. */
export type Wochentag = 1 | 2 | 3 | 4 | 5 | 6 | 7;

const ALLE_TAGE: Wochentag[] = [1, 2, 3, 4, 5, 6, 7];

/**
 * Wie viele Krafttage bleiben, wenn Kurse und Cardio schon Tage belegen?
 *
 * Doppelte Tage zaehlen einmal (ein Tag mit zwei Kursen ist ein Tag). Ein Plan
 * ohne Krafttag waere kein Trainingsplan, deshalb mindestens einer; `angehoben`
 * sagt der App, dass der Wunsch dafuer ueberstimmt wurde und sie es zeigen muss.
 */
export function kraftAnzahl(
  tage: number,
  kursTage: Wochentag[],
  cardioTage: Wochentag[],
): { anzahl: number; angehoben: boolean } {
  const belegt = new Set<number>([...kursTage, ...cardioTage]).size;
  const rest = tage - belegt;
  return rest < 1 ? { anzahl: 1, angehoben: true } : { anzahl: rest, angehoben: false };
}

/** Alle aufsteigenden Auswahlen von k Elementen, in lexikographischer Reihenfolge. */
function kombinationen(tage: Wochentag[], k: number): Wochentag[][] {
  if (k === 0) return [[]];
  const ergebnis: Wochentag[][] = [];
  for (let i = 0; i <= tage.length - k; i++) {
    for (const rest of kombinationen(tage.slice(i + 1), k - 1)) {
      ergebnis.push([tage[i]!, ...rest]);
    }
  }
  return ergebnis;
}

/**
 * Kleinster zyklischer Abstand zwischen benachbarten Tagen (Sonntag -> Montag
 * ist 1). Luecken zwischen zwei bereits belegten Tagen zaehlen nicht: sie stehen
 * fest und wuerden jede Auswahl gleich deckeln (Kurs am Mo und Cardio am So
 * lassen sich nicht verbessern).
 */
function kleinsteLuecke(belegt: Set<number>, gewaehlt: Wochentag[]): number {
  const alle = [...new Set<number>([...belegt, ...gewaehlt])].sort((a, b) => a - b);
  if (alle.length === 1) return 7;
  let klein = Infinity;
  for (let i = 0; i < alle.length; i++) {
    const a = alle[i]!;
    const b = alle[(i + 1) % alle.length]!;
    if (belegt.has(a) && belegt.has(b)) continue;
    klein = Math.min(klein, (b - a + 7) % 7);
  }
  return klein;
}

/**
 * Verteilt `anzahl` Krafttage moeglichst gleichmaessig auf die freien Tage.
 *
 * Bewusst erschoepfende Suche statt Greedy: Greedy waehlt bei Kurs Mo und Cardio
 * So fuer zwei Krafttage [2,4] statt [3,5] und laesst die Tage dicht an der
 * Belegung kleben. Es gibt hoechstens 2^7 Auswahlen, die Suche kostet nichts.
 * Gewinnt die Auswahl mit der groessten kleinsten Luecke; bei Gleichstand die
 * lexikographisch kleinste, damit das Ergebnis deterministisch bleibt.
 */
export function verteileKraft(belegt: Wochentag[], anzahl: number): Wochentag[] {
  const belegtSet = new Set<number>(belegt);
  const frei = ALLE_TAGE.filter((t) => !belegtSet.has(t));
  if (anzahl <= 0) return [];
  if (anzahl >= frei.length) return frei;

  let beste: Wochentag[] = [];
  let besteLuecke = -1;
  // Reihenfolge ist lexikographisch; nur strikt Besseres ersetzt, also gewinnt bei Gleichstand die fruehere.
  for (const kombi of kombinationen(frei, anzahl)) {
    const luecke = kleinsteLuecke(belegtSet, kombi);
    if (luecke > besteLuecke) {
      besteLuecke = luecke;
      beste = kombi;
    }
  }
  return beste;
}

/**
 * Prueft eine Woche vor dem Speichern: nur Tage 1-7, keiner doppelt innerhalb
 * einer Art, und ein Tag gehoert hoechstens zu einer Art (Kurs, Cardio, Kraft).
 */
export function pruefeWoche(w: {
  kursTage: Wochentag[];
  cardioTage: Wochentag[];
  kraftTage: Wochentag[];
}): void {
  const arten: [string, Wochentag[]][] = [
    ["Kurs", w.kursTage],
    ["Cardio", w.cardioTage],
    ["Kraft", w.kraftTage],
  ];
  const vergeben = new Map<number, string>();
  for (const [name, tage] of arten) {
    const eigene = new Set<number>();
    for (const tag of tage) {
      if (!Number.isInteger(tag) || tag < 1 || tag > 7) {
        throw new DomainError("validation_failed", `Ungültiger Wochentag bei ${name}.`);
      }
      if (eigene.has(tag)) {
        throw new DomainError("validation_failed", `Ein Tag steht bei ${name} doppelt.`);
      }
      eigene.add(tag);
      const andere = vergeben.get(tag);
      if (andere) {
        throw new DomainError("validation_failed", `Ein Tag kann nicht ${andere} und ${name} zugleich sein.`);
      }
    }
    for (const tag of eigene) vergeben.set(tag, name);
  }
  // Belegen Kurse und Cardio alle sieben Tage, bleibt kein Tag fuer Kraft: ein Plan ohne
  // Krafttag waere keiner. Ablehnen statt still einen Tag zu opfern.
  if (new Set<number>([...w.kursTage, ...w.cardioTage]).size === 7) {
    throw new DomainError("validation_failed", "Kurse und Cardio belegen alle Tage, für Krafttraining bleibt keiner.", {
      grund: "keine_freien_tage",
    });
  }
}
