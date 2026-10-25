/**
 * Zielgewicht je Planposition aus der zuletzt abgeschlossenen Einheit.
 *
 * Spec 2026-10-25 (G4, G18). Rein und deterministisch: keine Uhr, kein Zufall.
 * Schwellen unveraendert aus progression.ts v2.0.0; nur Arbeitssaetze zaehlen,
 * die Nebenlast wird nie gesteigert, ein Problemflag schlaegt jede Steigerung.
 */
import {
  snapToNearestStep,
  uniformLoad,
  type WorkoutSetInput,
} from "./progression.js";

export const PLANGEWICHT_ALGO_VERSION = "1.0.0";

export type PlanGewichtGrund =
  | "korridor_oben_erreicht"
  | "korridor_unten_verfehlt"
  | "im_korridor"
  | "problem_gemeldet"
  | "geraetegrenze_erreicht"
  | "kein_verlauf"
  | "daten_uneindeutig"
  | "letztes_gewicht"
  | "startschaetzung"
  | "uebertragung"
  | "wiedereinstieg";

export type PlanGewichtEingabe = {
  position: { wdhVon: number; wdhBis: number; reserveVon: number };
  geraet: { loadStep: number; loadMin: number; loadMax: number };
  /** Arbeitssaetze der abgeschlossenen Einheit, chronologisch; nur diese Position/Uebung/dieses Geraet. */
  block: WorkoutSetInput[];
  /** Arbeitssaetze der Einheit davor am selben Geraet und derselben Uebung, falls vorhanden. */
  vorher: WorkoutSetInput[] | null;
  aktuellesZiel: { load: number; secondaryLoad: number | null } | null;
};

export type PlanGewichtErgebnis = {
  load: number | null;
  secondaryLoad: number | null;
  grund: PlanGewichtGrund;
};

const oben = (sets: WorkoutSetInput[], wdhBis: number): boolean =>
  sets.length > 0 && sets.every((s) => s.volume >= wdhBis);

const untenVerfehlt = (sets: WorkoutSetInput[], wdhVon: number): boolean =>
  sets[0] !== undefined && sets[0].volume < wdhVon;

export function berechnePlanGewicht(e: PlanGewichtEingabe): PlanGewichtErgebnis {
  const { geraet, position, block, vorher } = e;
  const ziel = e.aktuellesZiel;
  const unveraendert = (grund: PlanGewichtGrund): PlanGewichtErgebnis => ({
    load: ziel?.load ?? null,
    secondaryLoad: ziel?.secondaryLoad ?? null,
    grund,
  });

  if (block.length === 0) return unveraendert("kein_verlauf");
  const ist = uniformLoad({ sets: block });
  if (ist === null) return unveraendert("daten_uneindeutig");

  const aktuell = snapToNearestStep(ist.load, geraet);
  const ergebnis = (load: number, grund: PlanGewichtGrund): PlanGewichtErgebnis => ({
    load,
    secondaryLoad: ist.secondaryLoad,
    grund,
  });

  // Ergebnis in den Geraetegrenzen, abgerundet auf eine einstellbare Stufe.
  const einstellbar = (wunsch: number): number => {
    const begrenzt = Math.min(Math.max(wunsch, geraet.loadMin), geraet.loadMax);
    const stufen = Math.floor((begrenzt - geraet.loadMin) / geraet.loadStep + 1e-9);
    return geraet.loadMin + stufen * geraet.loadStep;
  };
  const aktuellGesetzt = einstellbar(aktuell);
  const setzbar = (wunsch: number, grund: PlanGewichtGrund): PlanGewichtErgebnis => {
    const load = einstellbar(wunsch);
    return ergebnis(load, load === aktuellGesetzt && wunsch !== aktuell ? "geraetegrenze_erreicht" : grund);
  };

  if (block.some((s) => s.problemFlag)) return setzbar(aktuell, "problem_gemeldet");

  const letzter = block[block.length - 1];
  const mitReserve = letzter !== undefined && letzter.rir !== null && letzter.rir >= position.reserveVon;
  const vorherGleich =
    vorher !== null &&
    (() => {
      const u = uniformLoad({ sets: vorher });
      return u !== null && u.load === ist.load && u.secondaryLoad === ist.secondaryLoad;
    })();
  const zweimalOben =
    letzter !== undefined &&
    letzter.rir === null &&
    vorher !== null &&
    oben(vorher, position.wdhBis) &&
    vorherGleich;

  if (oben(block, position.wdhBis) && (mitReserve || zweimalOben)) {
    return setzbar(aktuell + geraet.loadStep, "korridor_oben_erreicht");
  }

  if (
    untenVerfehlt(block, position.wdhVon) &&
    vorher !== null &&
    untenVerfehlt(vorher, position.wdhVon) &&
    vorherGleich
  ) {
    return setzbar(aktuell - geraet.loadStep, "korridor_unten_verfehlt");
  }

  return setzbar(aktuell, "im_korridor");
}
