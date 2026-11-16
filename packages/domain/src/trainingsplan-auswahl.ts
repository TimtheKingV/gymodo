// Kandidatenauswahl des Plangenerators (Spec 2026-10-21, Abschnitt 2 und Review-Fokus 2/3).
// Eigene Datei, damit der Generator nur den Ablauf je Einheit enthaelt.
import { PlanNichtMoeglichError } from "./errors.js";
import { NUR_MEHRGELENK_PFLICHT, type FokusBereich } from "./trainingsplan-typen.js";
import type { Baustein, Bereich, PlanTyp } from "./trainingsplan-typen.js";
import { FOKUS_MUSKELN } from "./trainingsplan-regeln.js";

/** Reihenfolge der Liste ist die Auswahlreihenfolge; der Aufrufer sortiert fuer Determinismus. */
export type Kandidat = {
  exerciseId: string;
  modelId: string;
  baustein: Baustein;
  typ: PlanTyp;
  bereiche: Bereich[];
  hauptmuskeln: string[];
  /** Die Uebung steht auf der Merkliste "gefaellt nicht": sie kommt nur zum Zug, wenn nichts anderes bleibt. */
  gefaelltNicht?: boolean;
  /** false: nur frei waehlbar und tauschbar, der Generator schlaegt die Uebung nie vor. */
  vorschlag?: boolean;
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

/** Kandidaten, die der Generator vorschlagen darf (Katalogfeld plan.vorschlag). */
export function vorschlagbar(kandidaten: Kandidat[]): Kandidat[] {
  return kandidaten.filter((k) => k.vorschlag !== false);
}

/**
 * Kandidaten fuer einen Platz des Bausteins (Pflicht, Ergaenzung, Auffuellung): druecken,
 * ziehen und beine_knie nur Mehrgelenk. Deren Isolationsuebungen (Flys, Pullover) kommen nur
 * ueber den Fokus oder die freie Wahl in den Plan.
 */
export function platzKandidaten(kandidaten: Kandidat[], baustein: Baustein): Kandidat[] {
  const liste = nachBaustein(kandidaten, baustein);
  return NUR_MEHRGELENK_PFLICHT.includes(baustein) ? liste.filter((k) => k.typ === "mehrgelenk") : liste;
}

export function nachBaustein(kandidaten: Kandidat[], baustein: Baustein): Kandidat[] {
  return kandidaten.filter((k) => k.baustein === baustein);
}

/**
 * Wirft, wenn ein Pflichtbaustein leer bleibt. Der Grund unterscheidet, ob das Studio kein
 * Geraet hat oder die Beschwerden alles sperren, weil die Abhilfe jeweils eine andere ist.
 */
export function pruefePflicht(baustein: Baustein, alle: Kandidat[], gefiltert: Kandidat[]): void {
  if (platzKandidaten(gefiltert, baustein).length > 0) return;
  const grund = platzKandidaten(alle, baustein).length === 0 ? "kein_geraet" : "beschwerden";
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
  const gemocht = gruppen.filter((k) => !k.gefaelltNicht);
  return (
    rotiere(gemocht.filter((k) => !vorsichtig(k)), variation, belegt) ??
    rotiere(gemocht.filter(vorsichtig), variation, belegt) ??
    rotiere(gruppen.filter((k) => k.gefaelltNicht), variation, belegt)
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
  const passt = (k: Kandidat) =>
    bausteine.includes(k.baustein) && !belegt.has(k.exerciseId) && k.hauptmuskeln.some((m) => muskeln.includes(m));
  // "gefaellt nicht" kommt erst dran, wenn keine andere Uebung den Fokus traegt.
  return kandidaten.find((k) => passt(k) && !k.gefaelltNicht) ?? kandidaten.find(passt) ?? null;
}
