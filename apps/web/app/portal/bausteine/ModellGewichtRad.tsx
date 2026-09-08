"use client";

import { Rad } from "./EinstellungRad";
import { gewichtsSchrittWerte, maxGewichtWerte, minMaxWerte } from "./einstellungVorschlaege";

/**
 * Minimum/Maximum/Schritt eines Geraetemodells als Rad statt Tastatur --
 * derselbe Stil wie bei den Einstellungen (Trainer-Wunsch: "im gleichen
 * Zug ... das im selben Stil umsetzen"). Ersetzt die drei Textfelder in
 * ModellNeuFormular.tsx (Halle) sowie die Textfelder unter "Modell
 * anlegen" und "Stammdaten" (Schreibtisch).
 *
 * "kein Anschlag" (maxGewichtWerte()) haelt die bisherige Freiheit
 * lebendig, die Obergrenze offenzulassen -- ein Rad kennt sonst kein
 * "leer".
 */
export function ModellGewichtRad({
  gross = false,
  minStart = "0",
  maxStart = "",
  schrittStart = "2,5",
}: {
  gross?: boolean;
  minStart?: string;
  maxStart?: string;
  schrittStart?: string;
}) {
  return (
    <Rad
      gross={gross}
      spalten={[
        { name: "minWeightKg", label: "Minimum", werte: minMaxWerte(), start: minStart },
        { name: "maxWeightKg", label: "Maximum", werte: maxGewichtWerte(), start: maxStart },
        {
          name: "weightStepKg",
          label: "Schritt",
          werte: gewichtsSchrittWerte(),
          start: schrittStart,
        },
      ]}
    />
  );
}
