"use client";

import { useMemo, useState } from "react";
import { MAX_SERIENTERMINE, ortszeitTeile, serienTermine } from "@fitretro/domain/serie";

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
    const startZeit = new Date(start);
    if (Number.isNaN(startZeit.getTime())) return [];
    if (bis === "") return [startZeit];
    const bisZeit = new Date(`${bis}T12:00:00`);
    if (Number.isNaN(bisZeit.getTime())) return [startZeit];
    return serienTermine(startZeit, bisZeit, zeitzone);
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
