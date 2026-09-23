"use client";

import { useState } from "react";
import { Rad } from "./EinstellungRad";
import { gewichtsSchrittWerte, maxGewichtWerte, minMaxWerte } from "./einstellungVorschlaege";

/**
 * Minimum/Maximum/Schritt eines Geraetemodells als Rad statt Tastatur --
 * derselbe Stil wie bei den Einstellungen (Trainer-Wunsch: "im gleichen
 * Zug ... das im selben Stil umsetzen"). Ersetzt die drei Textfelder in
 * ModellNeuFormular.tsx (Halle) sowie die Textfelder unter "Modell
 * anlegen" und "Stammdaten" (Schreibtisch).
 *
 * "∞" (maxGewichtWerte(), kein Anschlag) haelt die bisherige Freiheit
 * lebendig, die Obergrenze offenzulassen -- ein Rad kennt sonst kein
 * "leer".
 *
 * Minimum und Maximum zaehlen im Takt des Schritts (Testnotiz 23.09.,
 * zweite Sitzung, #3): bei 5 kg stehen dort 0, 5, 10 … -- ein Minimum von
 * 7 kg gibt es an so einem Stapel nicht. Wechselt der Schritt, bleiben
 * beide Spalten auf dem naechstliegenden Wert (EinstellungRad.tsx).
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
  const [schritt, setSchritt] = useState(schrittStart);
  return (
    <Rad
      gross={gross}
      spalten={[
        { name: "minWeightKg", label: "Minimum", werte: minMaxWerte(schritt), start: minStart },
        { name: "maxWeightKg", label: "Maximum", werte: maxGewichtWerte(schritt), start: maxStart },
        {
          name: "weightStepKg",
          label: "Schritt",
          werte: gewichtsSchrittWerte(),
          start: schrittStart,
          onWahl: setSchritt,
        },
      ]}
    />
  );
}
