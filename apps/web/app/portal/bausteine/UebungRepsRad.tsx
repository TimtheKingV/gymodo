"use client";

import { Rad } from "./EinstellungRad";
import { wiederholungenWerte } from "./einstellungVorschlaege";

/**
 * Die Wiederholungsspanne einer Uebung als Rad statt Tastatur -- derselbe
 * Stil wie bei den Einstellungen (Trainer-Wunsch: "im gleichen Zug ...
 * Gleiches auch beim Reiter Übungen").
 */
export function UebungRepsRad({
  gross = false,
  abStart = "8",
  bisStart = "12",
}: {
  gross?: boolean;
  abStart?: string;
  bisStart?: string;
}) {
  return (
    <Rad
      gross={gross}
      spalten={[
        {
          name: "targetRepsMin",
          label: "Wiederholungen ab",
          werte: wiederholungenWerte(),
          start: abStart,
        },
        { name: "targetRepsMax", label: "bis", werte: wiederholungenWerte(), start: bisStart },
      ]}
    />
  );
}
