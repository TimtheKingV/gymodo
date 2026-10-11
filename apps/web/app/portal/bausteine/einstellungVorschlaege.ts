import {
  defaultLoadRange,
  defaultTargetRange,
  type Category,
  type LoadUnit,
  type VolumeKind,
} from "@fitretro/domain/belastung";
import type { AuswahlOption } from "./Auswahl";

/**
 * Vorschlaege rund um Einstellungen und Stammdaten -- Namen zum schnellen
 * Ausfuellen (ein Klick aufs Namensfeld zeigt ein Rad statt Tastatur) und
 * Werte fuer die Rad-Spalten selbst. Die frueheren festen Vorgaben mit
 * eigenem Bereich (Wiederholungen/Gewicht/Winkel als Radioauswahl) sind
 * entfallen -- Trainer-Feedback: "man muss das einfach immer einstellen",
 * der Bereich kommt jetzt ausnahmslos aus dem Rad.
 */

export type RadWert = { anzeige: string; wert: string };

function werte(liste: string[]): RadWert[] {
  return liste.map((wert) => ({ anzeige: wert, wert }));
}

function zahlenWerte(von: number, bis: number): RadWert[] {
  return werte(Array.from({ length: bis - von + 1 }, (_, i) => String(von + i)));
}

/** Haeufige Einstellungen an Kraftgeraeten -- Startpunkt zum schnellen
    Ausfuellen des Namensfelds, keine Einschraenkung: frei ueberschreibbar. */
export function nameVorschlaege(): RadWert[] {
  return werte([
    "Wiederholungen",
    "Gewicht",
    "Winkel",
    "Sitzhöhe",
    "Rückenlehne",
    "Griffweite",
    "Neigung",
    "Standbreite",
  ]);
}

/** Das Namensrad des Schreibtischs (Testnotiz 23.09., zweite Sitzung,
    #2): erst die Vorschlaege, am Ende "Sonstiges …" -- nur dann erscheint
    ein Textfeld fuer einen eigenen Namen. */
export const SONSTIGES = "__sonstiges";

export function nameRadWerte(): RadWert[] {
  return [...nameVorschlaege(), { anzeige: "Sonstiges …", wert: SONSTIGES }];
}

export type Vorgabe = { min: string; max: string; schritt: string; einheit: string };

/** Was ein Name ueber seinen Bereich verraet -- Winkel sind Grad in
    5er-Schritten, eine Sitzhoehe sind Stufen. Nur eine Vorauswahl: jede
    Spalte bleibt danach frei drehbar. */
const VORGABEN: Record<string, Vorgabe> = {
  Wiederholungen: { min: "1", max: "30", schritt: "1", einheit: "Wdh." },
  Gewicht: { min: "0", max: "100", schritt: "2,5", einheit: "kg" },
  Winkel: { min: "0", max: "90", schritt: "5", einheit: "°" },
  Sitzhöhe: { min: "1", max: "10", schritt: "1", einheit: "Stufe" },
  Rückenlehne: { min: "1", max: "8", schritt: "1", einheit: "Stufe" },
  Griffweite: { min: "1", max: "5", schritt: "1", einheit: "Stufe" },
  Neigung: { min: "0", max: "45", schritt: "5", einheit: "°" },
  Standbreite: { min: "20", max: "60", schritt: "5", einheit: "cm" },
};

const NEUTRAL: Vorgabe = { min: "0", max: "10", schritt: "1", einheit: "" };

export function vorgabeFuer(name: string): Vorgabe {
  return VORGABEN[name] ?? NEUTRAL;
}

function zahlAus(text: string): number {
  return Number(text.replace(",", "."));
}

/** Deutsch geschrieben, ohne Rundungsreste (0,1 + 0,2 …). */
function zahlText(zahl: number): string {
  return String(Math.round(zahl * 100) / 100).replace(".", ",");
}

/** 0 bis 200 im Takt des Schritts -- grosszuegig genug fuer Rasten,
    Zentimeter und Gewichtsstufen. Mit Schritt 5 stehen nur 0, 5, 10 …
    im Rad (Testnotiz 23.09., zweite Sitzung, #3): ein Minimum von 7 bei
    Schritt 5 waere am Geraet ohnehin nicht einstellbar. */
export function minMaxWerte(schritt = "1"): RadWert[] {
  const takt = zahlAus(schritt);
  if (!Number.isFinite(takt) || takt <= 0) return zahlenWerte(0, 200);
  const anzahl = Math.floor(200 / takt + 1e-9);
  return werte(Array.from({ length: anzahl + 1 }, (_, i) => zahlText(i * takt)));
}

export function schrittWerte(): RadWert[] {
  return werte(["0,5", "1", "2", "2,5", "5", "10"]);
}

export function einheitWerte(): RadWert[] {
  return [
    { anzeige: "keine", wert: "" },
    { anzeige: "Stufe", wert: "Stufe" },
    { anzeige: "kg", wert: "kg" },
    { anzeige: "°", wert: "°" },
    { anzeige: "cm", wert: "cm" },
    { anzeige: "Wdh.", wert: "Wdh." },
  ];
}

/** Schrittweiten, wie sie an Gewichtsstapeln und Kabelzuegen tatsaechlich
    vorkommen -- 1,25 kg ist die halbe Scheibe, nicht frei erfunden. Ersetzt
    die vormalige Chip-Auswahl in ModellNeuFormular.tsx (dieselben drei
    Werte, plus 10/20 fuer schwerere Geraete). */
export function gewichtsSchrittWerte(): RadWert[] {
  return werte(["1,25", "2,5", "5", "10", "20"]);
}

/** Wie minMaxWerte(), nur mit "∞" (kein Anschlag) am Ende -- die
    Obergrenze eines Modells bleibt optional (vormaliger Hinweis: "leer
    lassen, wenn kein Anschlag bekannt ist"). "∞" traegt "" als Wert, geht
    also als nicht gesetzt durch, genau wie die leere Auswahl vorher.
    Am Ende statt am Anfang und als Zeichen statt als Wort: Testnotiz vom
    22.09. -- "kein Anschlag" oben vor der 0 las sich wie ein Minimum. */
export function maxGewichtWerte(schritt?: string): RadWert[] {
  return [...minMaxWerte(schritt), { anzeige: "∞", wert: "" }];
}

/** 1 bis 50 -- deckt Kraft- ebenso wie Ausdauerbereiche ab, ohne die 200
    Zeilen von minMaxWerte() fuer eine Wiederholungszahl mitzuschleppen. */
export function wiederholungenWerte(): RadWert[] {
  return zahlenWerte(1, 50);
}

/**
 * Aus der Beschriftung wird der technische Schluessel -- der Trainer tippt
 * ihn nicht mehr selbst ein (Befund: zwei Felder fuer dieselbe Sache waren
 * unnoetig). Kollidiert eine Ableitung mit einem bestehenden Schluessel am
 * selben Modell, meldet das die Aktion wie zuvor ("Diesen Schluessel gibt
 * es an dem Modell schon.").
 */
export function schluesselAus(beschriftung: string): string {
  return beschriftung
    .trim()
    .toLowerCase()
    .replace(/ä/g, "ae")
    .replace(/ö/g, "oe")
    .replace(/ü/g, "ue")
    .replace(/ß/g, "ss")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

// ---------------------------------------------------------------------
// Belastung und Umfang (Cardio-Spec Abschnitt 7): Wertelisten je Einheit
// und je Umfangsart. Die Startwerte kommen aus der Domain
// (defaultLoadRange / defaultTargetRange), damit Portal und spaeter iOS
// dieselben Vorgaben zeigen. Fuer kg sind Listen und Startwerte exakt die
// bisherigen -- ein Kraftgeraet sieht aus wie vorher.
// ---------------------------------------------------------------------


/** "2,5" statt "2.5", "5" statt "5,0" -- so, wie die Raeder ihre Werte tragen. */
export function dezimal(wert: number): string {
  return String(Number(wert.toFixed(2))).replace(".", ",");
}

function bereich(von: number, bis: number, schritt: number): RadWert[] {
  const anzahl = Math.floor((bis - von) / schritt + 1e-9) + 1;
  return werte(Array.from({ length: anzahl }, (_, i) => dezimal(von + i * schritt)));
}

export const KATEGORIE_OPTIONEN: AuswahlOption[] = [
  { wert: "kraft", anzeige: "Kraft" },
  { wert: "cardio", anzeige: "Cardio" },
];

/**
 * Welche Einheiten zu welcher Kategorie passen (Testnotiz 03.10., #1).
 * Kraft misst in kg, Cardio in allem anderen -- ein Laufband in kg oder
 * ein Latzug in km/h war bisher waehlbar und nie gemeint.
 */
const EINHEITEN_JE_KATEGORIE: Record<Category, LoadUnit[]> = {
  kraft: ["kg"],
  cardio: ["watt", "level", "kmh", "pct", "rpm"],
};

export function einheitenFuer(kategorie: Category): LoadUnit[] {
  return EINHEITEN_JE_KATEGORIE[kategorie];
}

/**
 * Das Minimum eines Modells ohne eigene Spalte (Testnotiz 03.10., #2):
 * der kleinste Wert ueber null im Takt, also der Schritt selbst -- 2,5 kg
 * bei 2,5 kg. Ein Bestandsminimum bleibt, solange es ueber null und im
 * Takt liegt; sonst wuerde jedes Speichern der Stammdaten es verschieben.
 */
/**
 * Den naechstliegenden Wert der Liste, wenn `start` keiner ihrer Werte ist.
 * Das Rad rastet einen krummen Startwert zwar selbst ein, meldet das aber
 * nicht -- wer daraus Minimum und Maximum rechnet, braucht den
 * eingerasteten Wert vorher (Gymtavo-Typen tragen 1 kg, das kg-Rad kennt
 * erst 1,25).
 */
export function einrasten(liste: RadWert[], start: string): string {
  if (liste.some((zeile) => zeile.wert === start)) return start;
  const ziel = zahlAus(start);
  if (!Number.isFinite(ziel)) return start;
  let bester = start;
  let abstand = Infinity;
  for (const zeile of liste) {
    const zahl = zahlAus(zeile.wert);
    if (Number.isFinite(zahl) && Math.abs(zahl - ziel) < abstand) {
      abstand = Math.abs(zahl - ziel);
      bester = zeile.wert;
    }
  }
  return bester;
}

export function belastungMinimum(schritt: string, bestand?: string): string {
  const takt = zahlAus(schritt);
  if (bestand === undefined || !Number.isFinite(takt) || takt <= 0) return schritt;
  const wert = zahlAus(bestand);
  const vielfaches = wert / takt;
  const imTakt = Math.abs(vielfaches - Math.round(vielfaches)) < 1e-6;
  return wert > 0 && imTakt ? dezimal(wert) : schritt;
}

/** Das Maximum kann nicht unter dem Minimum liegen -- "∞" bleibt stehen. */
export function maxAb(liste: RadWert[], minimum: string): RadWert[] {
  const untergrenze = zahlAus(minimum);
  return liste.filter((zeile) => zeile.wert === "" || zahlAus(zeile.wert) >= untergrenze - 1e-9);
}

export const EINHEIT_ANZEIGE: Record<LoadUnit, string> = {
  kg: "kg",
  watt: "Watt",
  level: "Level",
  kmh: "km/h",
  pct: "%",
  rpm: "U/min",
};

export const EINHEIT_OPTIONEN: AuswahlOption[] = (
  Object.keys(EINHEIT_ANZEIGE) as LoadUnit[]
).map((wert) => ({ wert, anzeige: EINHEIT_ANZEIGE[wert] }));

/** "keine" vorn: die Nebenbelastung ist die Ausnahme, nicht die Regel. */
export const NEBENBELASTUNG_OPTIONEN: AuswahlOption[] = [
  { wert: "", anzeige: "keine" },
  ...EINHEIT_OPTIONEN,
];

export const UMFANG_ANZEIGE: Record<VolumeKind, string> = {
  reps: "Wiederholungen",
  seconds: "Minuten",
  meters: "Meter",
};

export const UMFANG_OPTIONEN: AuswahlOption[] = (
  Object.keys(UMFANG_ANZEIGE) as VolumeKind[]
).map((wert) => ({ wert, anzeige: UMFANG_ANZEIGE[wert] }));

export type BelastungsWerte = {
  min: RadWert[];
  max: RadWert[];
  schritt: RadWert[];
  start: { min: string; max: string; schritt: string };
};

/**
 * Die drei Spalten des Belastungsrads je Einheit. Watt in Fuenfern,
 * Level und Umdrehungen ganz, km/h und Prozent in halben -- jeweils die
 * Rastung, die ein Geraet dieser Art tatsaechlich hat. Der Trainer
 * korrigiert am Rad, was nicht passt.
 */
/**
 * Die Raeder eines Modells je Einheit. Minimum und Maximum zaehlen im Takt
 * des gewaehlten Schritts (Testnotiz 23.09., zweite Sitzung, #3) -- bei
 * 0,5 km/h stehen dort 0, 0,5, 1 …, bei 5 W 0, 5, 10 …; "∞" (kein
 * Anschlag) steht am Ende des Maximums (Testnotiz 22.09.). Ohne Schritt
 * gilt der Vorgabeschritt der Einheit. Fuer kg sind es exakt
 * minMaxWerte/maxGewichtWerte.
 */
export function belastungsWerte(unit: LoadUnit, schritt?: string): BelastungsWerte {
  const vorgabe = defaultLoadRange(unit);
  const start = {
    min: dezimal(vorgabe.min),
    max: vorgabe.max === null ? "" : dezimal(vorgabe.max),
    schritt: dezimal(vorgabe.step),
  };
  const takt = schritt ?? start.schritt;
  const unbegrenzt: RadWert = { anzeige: "∞", wert: "" };
  const imTakt = (bis: number): RadWert[] => {
    const zahl = zahlAus(takt);
    return bereich(0, bis, Number.isFinite(zahl) && zahl > 0 ? zahl : 1);
  };
  const mit = (bis: number, schritte: string[]) => {
    const liste = imTakt(bis);
    return { min: liste, max: [...liste, unbegrenzt], schritt: werte(schritte), start };
  };
  switch (unit) {
    case "kg":
      return { min: minMaxWerte(takt), max: maxGewichtWerte(takt), schritt: gewichtsSchrittWerte(), start };
    case "watt":
      return mit(500, ["5", "10", "25"]);
    case "level":
      return mit(30, ["1"]);
    case "kmh":
      return mit(30, ["0,1", "0,5", "1"]);
    case "pct":
      return mit(30, ["0,5", "1"]);
    case "rpm":
      return mit(200, ["5", "10"]);
  }
}

export type UmfangsWerte = {
  liste: RadWert[];
  labelAb: string;
  labelBis: string;
  start: { min: string; max: string };
};

/**
 * Das Umfangsrad je Art. Minuten werden als Minuten gewaehlt und erst in
 * der Server-Action in Sekunden umgerechnet (formfelder.ts) -- ein Rad
 * voller Sekunden waere fuer niemanden lesbar.
 */
export function umfangWerte(kind: VolumeKind): UmfangsWerte {
  const vorgabe = defaultTargetRange(kind);
  switch (kind) {
    case "reps":
      return {
        liste: wiederholungenWerte(),
        labelAb: "Wiederholungen ab",
        labelBis: "bis",
        start: { min: String(vorgabe.min), max: String(vorgabe.max) },
      };
    case "seconds":
      return {
        liste: bereich(1, 90, 1),
        labelAb: "Minuten ab",
        labelBis: "bis",
        start: { min: String(vorgabe.min / 60), max: String(vorgabe.max / 60) },
      };
    case "meters":
      return {
        liste: bereich(500, 20000, 100),
        labelAb: "Meter ab",
        labelBis: "bis",
        start: { min: String(vorgabe.min), max: String(vorgabe.max) },
      };
  }
}

export function istKategorie(wert: string): wert is Category {
  return wert === "kraft" || wert === "cardio";
}

export function istEinheit(wert: string): wert is LoadUnit {
  return wert in EINHEIT_ANZEIGE;
}

export function istUmfangsart(wert: string): wert is VolumeKind {
  return wert in UMFANG_ANZEIGE;
}
