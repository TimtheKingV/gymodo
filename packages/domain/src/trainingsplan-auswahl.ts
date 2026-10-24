// Kandidatenauswahl des Plangenerators (Spec 2026-10-21, Abschnitt 2 und Review-Fokus 2/3).
// Eigene Datei, damit der Generator nur den Ablauf je Einheit enthaelt.
import { PlanNichtMoeglichError } from "./errors.js";
import type { FokusBereich } from "./trainingsplan-typen.js";
import type { Baustein, Bereich, PlanTyp } from "./trainingsplan-typen.js";
import { FOKUS_MUSKELN } from "./trainingsplan-regeln.js";

/** Reihenfolge der Liste ist die Auswahlreihenfolge; der Aufrufer sortiert fuer Determinismus. */
export type Kandidat = {
  exerciseId: string;
  machineId: string;
  baustein: Baustein;
  typ: PlanTyp;
  bereiche: Bereich[];
  hauptmuskeln: string[];
};

export type Beschwerden = Partial<Record<Bereich, "meiden" | "vorsichtig">>;

function trifft(k: Kandidat, beschwerden: Beschwerden, stufe: "meiden" | "vorsichtig"): boolean {
  return k.bereiche.some((b) => beschwerden[b] === stufe);
}

/**
 * Wendet die Beschwerden auf den ganzen Katalog an: "meiden" schliesst aus (nie eine
 * gemiedene Uebung planen), "vorsichtig" sortiert nur stabil nach hinten, schliesst nie aus.
 */
export function filtereKandidaten(kandidaten: Kandidat[], beschwerden: Beschwerden): Kandidat[] {
  const erlaubt = kandidaten.filter((k) => !trifft(k, beschwerden, "meiden"));
  return [
    ...erlaubt.filter((k) => !trifft(k, beschwerden, "vorsichtig")),
    ...erlaubt.filter((k) => trifft(k, beschwerden, "vorsichtig")),
  ];
}

export function nachBaustein(kandidaten: Kandidat[], baustein: Baustein): Kandidat[] {
  return kandidaten.filter((k) => k.baustein === baustein);
}

/**
 * Wirft, wenn ein Pflichtbaustein leer bleibt. Der Grund unterscheidet, ob das Studio kein
 * Geraet hat oder die Beschwerden alles sperren, weil die Abhilfe jeweils eine andere ist.
 */
export function pruefePflicht(baustein: Baustein, alle: Kandidat[], gefiltert: Kandidat[]): void {
  if (nachBaustein(gefiltert, baustein).length > 0) return;
  const grund = nachBaustein(alle, baustein).length === 0 ? "kein_geraet" : "beschwerden";
  throw new PlanNichtMoeglichError(baustein, grund);
}

/** "vorsichtig" betrifft eine Uebung, wenn einer ihrer Bereiche so markiert ist. */
export function istVorsichtig(k: Kandidat, beschwerden: Beschwerden): boolean {
  return trifft(k, beschwerden, "vorsichtig");
}

function rotiere(gruppen: Kandidat[], variation: number, belegt: ReadonlySet<string>): Kandidat | null {
  for (let s = 0; s < gruppen.length; s++) {
    const k = gruppen[(variation + s) % gruppen.length]!;
    if (!belegt.has(k.exerciseId)) return k;
  }
  return null;
}

/**
 * Variation ueber die Einheiten: der n-te Einsatz eines Bausteins nimmt Uebung n mod Anzahl.
 * Gezaehlt werden verschiedene exerciseIds (in Reihenfolge des ersten Auftretens), nicht
 * Uebung x Geraet -- sonst bekaeme B dieselbe Uebung nur an einem anderen Geraet.
 * Von der gewaehlten Uebung wird das erste Geraet genommen. Steht die Uebung schon in der
 * Einheit (etwa als Fokus), wird die naechste freie genommen, damit nichts doppelt steht.
 * Rotiert wird zuerst nur ueber unbedenkliche Uebungen; vorsichtige kommen erst dran, wenn
 * keine unbedenkliche frei ist -- sonst bekaeme B bei zwei Kandidaten stets die vorsichtige.
 */
export function waehleKandidat(
  liste: Kandidat[],
  variation: number,
  belegt: ReadonlySet<string>,
  vorsichtig: (k: Kandidat) => boolean = () => false,
): Kandidat | null {
  const uebungen = new Map<string, Kandidat>();
  for (const k of liste) if (!uebungen.has(k.exerciseId)) uebungen.set(k.exerciseId, k);
  const gruppen = [...uebungen.values()];
  return (
    rotiere(gruppen.filter((k) => !vorsichtig(k)), variation, belegt) ??
    rotiere(gruppen.filter(vorsichtig), variation, belegt)
  );
}

/** Erster freier Kandidat der erlaubten Bausteine, der einen Hauptmuskel des Fokusbereichs traegt. */
export function waehleFokus(
  kandidaten: Kandidat[],
  bereich: FokusBereich,
  bausteine: readonly Baustein[],
  belegt: ReadonlySet<string>,
): Kandidat | null {
  const muskeln = FOKUS_MUSKELN[bereich];
  return (
    kandidaten.find(
      (k) =>
        bausteine.includes(k.baustein) &&
        !belegt.has(k.exerciseId) &&
        k.hauptmuskeln.some((m) => muskeln.includes(m)),
    ) ?? null
  );
}
