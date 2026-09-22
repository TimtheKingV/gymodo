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

/** 0 bis 200 -- grosszuegig genug fuer Rasten, Zentimeter und
    Gewichtsstufen. */
export function minMaxWerte(): RadWert[] {
  return zahlenWerte(0, 200);
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

/** Wie minMaxWerte(), nur mit "kein Anschlag" am Anfang -- die Obergrenze
    eines Modells bleibt optional (vormaliger Hinweis: "leer lassen, wenn
    kein Anschlag bekannt ist"). "kein Anschlag" traegt "" als Wert, geht
    also als nicht gesetzt durch, genau wie die leere Auswahl vorher. */
export function maxGewichtWerte(): RadWert[] {
  return [{ anzeige: "kein Anschlag", wert: "" }, ...minMaxWerte()];
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
export function belastungsWerte(unit: LoadUnit): BelastungsWerte {
  const vorgabe = defaultLoadRange(unit);
  const start = {
    min: dezimal(vorgabe.min),
    max: vorgabe.max === null ? "" : dezimal(vorgabe.max),
    schritt: dezimal(vorgabe.step),
  };
  const kein: RadWert = { anzeige: "kein Anschlag", wert: "" };
  switch (unit) {
    case "kg":
      return { min: minMaxWerte(), max: maxGewichtWerte(), schritt: gewichtsSchrittWerte(), start };
    case "watt": {
      const liste = bereich(0, 500, 5);
      return { min: liste, max: [kein, ...liste], schritt: werte(["5", "10", "25"]), start };
    }
    case "level": {
      const liste = bereich(0, 30, 1);
      return { min: liste, max: [kein, ...liste], schritt: werte(["1"]), start };
    }
    case "kmh": {
      const liste = bereich(0, 30, 0.5);
      return { min: liste, max: [kein, ...liste], schritt: werte(["0,1", "0,5", "1"]), start };
    }
    case "pct": {
      const liste = bereich(0, 30, 0.5);
      return { min: liste, max: [kein, ...liste], schritt: werte(["0,5", "1"]), start };
    }
    case "rpm": {
      const liste = bereich(0, 200, 5);
      return { min: liste, max: [kein, ...liste], schritt: werte(["5", "10"]), start };
    }
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
