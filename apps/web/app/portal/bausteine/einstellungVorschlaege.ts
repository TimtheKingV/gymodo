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
