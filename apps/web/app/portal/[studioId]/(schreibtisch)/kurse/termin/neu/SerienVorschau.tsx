"use client";

import { useMemo, useState } from "react";
import {
  MAX_SERIENTERMINE,
  ortszeitTeile,
  ortszeitZuInstant,
  serienTermine,
  type Ortszeit,
} from "@fitretro/domain/serie";

/**
 * Ein datetime-local-Feld liefert eine nackte Wandzeit ohne Zone
 * ("2026-11-05T18:00"). new Date() deutet die in der Zone des BROWSERS
 * -- serienTermine liest daraus aber die Wandzeit des STUDIOS. Sitzt der
 * Trainer in einer anderen Zone als sein Studio, entstuende ein anderer
 * Termin als der getippte. Deshalb wird das Feld hier zerlegt und
 * ausdruecklich als Ortszeit des Studios gedeutet.
 */
function alsOrtszeit(wert: string, stunde: number, minute: number): Ortszeit | null {
  const treffer = /^(\d{4})-(\d{2})-(\d{2})$/.exec(wert);
  if (!treffer) return null;
  return {
    jahr: Number(treffer[1]),
    monat: Number(treffer[2]),
    tag: Number(treffer[3]),
    stunde,
    minute,
  };
}

function feldZuInstant(wert: string, zeitzone: string): Date | null {
  const treffer = /^(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2})/.exec(wert);
  if (!treffer) return null;
  const teile = alsOrtszeit(treffer[1]!, Number(treffer[2]), Number(treffer[3]));
  return teile === null ? null : ortszeitZuInstant(teile, zeitzone);
}

/**
 * Zeigt, welche Termine entstehen -- BEVOR sie entstehen.
 *
 * Das ist die tragende Eigenschaft des Bildschirms (Spec Abschnitt 9):
 * Serientermine werden ausgeschrieben, nicht als Regel gespeichert, und
 * ausgeschriebene Termine kann man hinterher nur einzeln zurueckdrehen.
 * Wer 14 Zeilen anlegt, soll sie vorher gesehen haben.
 *
 * Gerechnet wird mit derselben Funktion wie auf dem Server -- nicht mit
 * einer zweiten Fassung, die knapp danebenliegt.
 */
export function SerienVorschau({ zeitzone }: { zeitzone: string }) {
  const [start, setStart] = useState("");
  const [bis, setBis] = useState("");

  const termine = useMemo(() => {
    if (start === "") return [];
    const startZeit = feldZuInstant(start, zeitzone);
    if (startZeit === null) return [];
    if (bis === "") return [startZeit];
    // Mittag in der Zone des Studios: serienTermine vergleicht auf den
    // Ortstag, und die Mittagslage haelt genug Abstand zu beiden
    // Tagesgrenzen.
    const bisTeile = alsOrtszeit(bis, 12, 0);
    if (bisTeile === null) return [startZeit];
    return serienTermine(startZeit, ortszeitZuInstant(bisTeile, zeitzone), zeitzone);
  }, [start, bis, zeitzone]);

  return (
    <>
      <label>
        Beginn
        <input
          type="datetime-local"
          name="startsAtLokal"
          required
          value={start}
          onChange={(e) => setStart(e.target.value)}
        />
      </label>

      {/* Der Server bekommt den Zeitpunkt mit Zonenangabe, nicht die
          nackte Wandzeit aus dem Feld -- sonst deutet er sie in seiner
          eigenen Zeitzone. */}
      <input
        type="hidden"
        name="startsAt"
        value={termine.length > 0 ? termine[0]!.toISOString() : ""}
      />

      <label>
        Wöchentlich wiederholen bis (leer lassen für einen einzelnen Termin)
        <input
          type="date"
          name="wiederholungBisLokal"
          value={bis}
          onChange={(e) => setBis(e.target.value)}
        />
      </label>
      <input
        type="hidden"
        name="wiederholungBis"
        value={bis === "" || termine.length === 0 ? "" : termine[termine.length - 1]!.toISOString()}
      />

      {termine.length > 0 && (
        <section>
          <p>
            <strong>
              {termine.length === 1
                ? "Dieser eine Termin wird angelegt."
                : `Diese ${termine.length} Termine werden angelegt.`}
            </strong>{" "}
            Jeder ist danach einzeln änderbar und absagbar.
          </p>
          <ul>
            {termine.slice(0, 5).map((termin) => {
              const t = ortszeitTeile(termin, zeitzone);
              return (
                <li key={termin.toISOString()}>
                  {String(t.tag).padStart(2, "0")}.{String(t.monat).padStart(2, "0")}.
                  {t.jahr} · {String(t.stunde).padStart(2, "0")}:
                  {String(t.minute).padStart(2, "0")}
                </li>
              );
            })}
            {termine.length > 5 && <li>… {termine.length - 5} weitere</li>}
          </ul>
          {termine.length === MAX_SERIENTERMINE && (
            <p>
              Mehr als {MAX_SERIENTERMINE} Termine legt das Portal auf einmal nicht an.
              Wähle ein früheres Enddatum.
            </p>
          )}
          <p>
            Änderst du die Vorlage später, bleiben diese Termine unverändert — sie
            behalten ihre eigenen Werte.
          </p>
        </section>
      )}
    </>
  );
}
