"use client";

import { useState } from "react";
import { Feld } from "../../../../../Form";
import styles from "../../../../../portal.module.css";
import { feldZuInstant, feldwerte } from "../zeit";

/**
 * Datum und Uhrzeit eines bestehenden Termins (Termin.dc.html).
 *
 * Das ersetzt das Textfeld, in das bis hierher ein ISO-8601-Zeitpunkt von
 * Hand getippt wurde -- samt dem Hinweis "Ein Datumsfeld bekommt dieser
 * Bildschirm in Phase 5". Das ist diese Phase.
 *
 * Warum ein Client-Rand: terminSpeichernAction erwartet einen Zeitpunkt
 * MIT Zone (kurse-actions.ts, unveraendert), die Felder liefern aber die
 * nackte Wandzeit. Umgerechnet wird in der Zone des STUDIOS, nicht in der
 * des Browsers -- sonst verschoebe ein Trainer, der von unterwegs
 * arbeitet, den Kurs.
 *
 * Das Artboard zeichnet nur "Uhrzeit". Das Datum steht trotzdem hier: das
 * Feld, das dieser Rand ersetzt, konnte einen Termin auf einen anderen Tag
 * legen, und ein Umbau, der die Optik trifft und dabei stillschweigend
 * eine Faehigkeit entfernt, ist kein Umbau. Beide Felder stehen in einer
 * Zeile und lesen sich als eines.
 */
export function TerminZeit({
  startsAt,
  zeitzone,
}: {
  startsAt: string;
  zeitzone: string;
}) {
  const anfang = feldwerte(startsAt, zeitzone);
  const [datum, setDatum] = useState(anfang.datum);
  const [uhrzeit, setUhrzeit] = useState(anfang.uhrzeit);

  const zeitpunkt = feldZuInstant(datum, uhrzeit, zeitzone);

  return (
    <>
      <div className={styles.grid}>
        <Feld
          name="datumLokal"
          label="Datum"
          type="date"
          value={datum}
          onChange={(e) => setDatum(e.target.value)}
          required
        />
        <Feld
          name="uhrzeitLokal"
          label="Uhrzeit"
          type="time"
          value={uhrzeit}
          onChange={(e) => setUhrzeit(e.target.value)}
          required
        />
      </div>
      <input
        type="hidden"
        name="startsAt"
        value={zeitpunkt === null ? "" : zeitpunkt.toISOString()}
      />
    </>
  );
}
