import { DomainError } from "./errors.js";

/** ISO-Wochentag: 1 = Montag ... 7 = Sonntag. */
export type Wochentag = 1 | 2 | 3 | 4 | 5 | 6 | 7;

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
