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
