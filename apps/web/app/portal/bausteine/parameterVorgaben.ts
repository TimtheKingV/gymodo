/**
 * Vorgaben fuer Einstellparameter -- Trainer-Feedback: "so muss man weniger
 * tippen ... (auch bei einheit nix tippen sondern vorgeben)". Wiederholungen
 * und Winkel sind feste Bereiche; Gewicht liest seinen Bereich aus dem
 * Modell selbst (Schritt und Minimum stammen vom Modell, 150 kg ist die
 * feste Obergrenze -- /design-Runde "Vorgaben-Rad").
 *
 * "Eigener Parameter" bleibt der freie Weg: dort zeigt das Formular statt
 * einer Vorgabe das Rad (ParameterRad.tsx) fuer Minimum/Maximum/Schritt/
 * Einheit -- Auswahl statt Tastatur, aber ohne feste Bedeutung.
 */

export type ParameterVorgabeId = "wiederholungen" | "gewicht" | "winkel" | "eigen";

export type ParameterBereich = {
  minValue: number;
  maxValue: number;
  stepValue: number;
  unit: string;
};

export type GewichtsModell = {
  weightStepKg: number;
  minWeightKg: number;
  maxWeightKg: number | null;
};

export type ParameterVorgabe = {
  id: ParameterVorgabeId;
  name: string;
  meta: string;
  /** null bei "Eigener Parameter" -- dort gilt das Rad, kein fester Bereich. */
  bereich: ParameterBereich | null;
};

/** Kein Modell traegt ueber 150 kg hinaus eine eigene Obergrenze --
    Trainer-Vorgabe: "dann bis 150". */
const GEWICHT_OBERGRENZE_KG = 150;

export function wiederholungenBereich(): ParameterBereich {
  return { minValue: 1, maxValue: 30, stepValue: 1, unit: "" };
}

export function winkelBereich(): ParameterBereich {
  return { minValue: 0, maxValue: 90, stepValue: 5, unit: "°" };
}

export function gewichtBereich(modell: GewichtsModell): ParameterBereich {
  return {
    minValue: modell.minWeightKg,
    maxValue: modell.maxWeightKg ?? GEWICHT_OBERGRENZE_KG,
    stepValue: modell.weightStepKg,
    unit: "kg",
  };
}

function formatZahl(wert: number): string {
  return wert.toLocaleString("de-DE", {
    minimumFractionDigits: Number.isInteger(wert) ? 0 : 1,
    maximumFractionDigits: 1,
  });
}

function bereichMeta(bereich: ParameterBereich): string {
  const einheit = bereich.unit ? ` ${bereich.unit}` : "";
  return `Zahl · ${formatZahl(bereich.minValue)} – ${formatZahl(bereich.maxValue)}${einheit} · Schritt ${formatZahl(bereich.stepValue)}${einheit}`;
}

export function parameterVorgaben(modell: GewichtsModell): ParameterVorgabe[] {
  return [
    {
      id: "wiederholungen",
      name: "Wiederholungen",
      meta: `${bereichMeta(wiederholungenBereich())} · Standard 10`,
      bereich: wiederholungenBereich(),
    },
    {
      id: "gewicht",
      name: "Gewicht",
      meta: bereichMeta(gewichtBereich(modell)),
      bereich: gewichtBereich(modell),
    },
    {
      id: "winkel",
      name: "Winkel",
      meta: bereichMeta(winkelBereich()),
      bereich: winkelBereich(),
    },
    {
      id: "eigen",
      name: "Eigener Parameter",
      meta: "Art, Bereich und Einheit frei eintragen",
      bereich: null,
    },
  ];
}

/** Ein Rad-Wert traegt zwei Woerter: was das Rad zeigt, und was das
    Formular abschickt. Bei "keine" sind die beiden verschieden -- die
    Einheit soll dann leer ankommen, nicht das Wort "keine" tragen. */
export type RadWert = { anzeige: string; wert: string };

function zahlenWerte(von: number, bis: number): RadWert[] {
  return Array.from({ length: bis - von + 1 }, (_, i) => {
    const zahl = String(von + i);
    return { anzeige: zahl, wert: zahl };
  });
}

/** 0 bis 200 -- grosszuegig genug fuer Rasten, Zentimeter und Gewichtsstufen.
    Wer mehr braucht, traegt Schluessel und Beschriftung weiterhin frei ein;
    nur die Zahlenwerte selbst kommen aus dem Rad. */
export function eigeneMinMaxWerte(): RadWert[] {
  return zahlenWerte(0, 200);
}

export function eigeneSchrittWerte(): RadWert[] {
  return ["0,5", "1", "2", "2,5", "5", "10"].map((wert) => ({ anzeige: wert, wert }));
}

export function eigeneEinheitWerte(): RadWert[] {
  return [
    { anzeige: "keine", wert: "" },
    { anzeige: "Stufe", wert: "Stufe" },
    { anzeige: "kg", wert: "kg" },
    { anzeige: "°", wert: "°" },
    { anzeige: "cm", wert: "cm" },
    { anzeige: "Wdh.", wert: "Wdh." },
  ];
}
