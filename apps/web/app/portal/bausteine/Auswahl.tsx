"use client";

import { useEffect, useId, useRef, useState } from "react";
import styles from "./Auswahl.module.css";

export type AuswahlOption = { wert: string; anzeige: string };

/**
 * Eigene Auswahl statt eines nativen <select> -- Trainer-Feedback: "sieht
 * aus wie von Windows 2000". Ersetzt alle fuenf nativen Dropdowns im
 * Schreibtisch (Art, Mitglied befoerdern, Kursvorlage, Zeitzone, Geraet fuer
 * einen Tag).
 *
 * Immer kontrolliert (`value`/`onChange`) -- die Aufrufstellen, die bisher
 * unkontrolliert mit `defaultValue` liefen (Kursvorlage, Zeitzone), tragen
 * seitdem einen eigenen `useState`, genau wie die schon kontrollierten
 * Stellen (Mitglied befoerdern, Geraet fuer einen Tag) es ohnehin taten.
 *
 * `name` ist optional: mit `name` traegt ein verstecktes Eingabefeld den
 * Wert ins umgebende <form> (gleiches Muster wie beim Rad,
 * EinstellungRad.tsx), ohne `name` bleibt die Auswahl reiner Client-Zustand
 * (z. B. LeuteActions.tsx, TagBinden.tsx -- kein <form>, ein Knopf danach).
 */
export function Auswahl({
  id,
  name,
  value,
  onChange,
  optionen,
  platzhalter,
  gross = false,
  ariaLabel,
}: {
  id?: string;
  name?: string;
  value: string;
  onChange: (wert: string) => void;
  optionen: AuswahlOption[];
  platzhalter?: string;
  gross?: boolean;
  ariaLabel?: string;
}) {
  const [offen, setOffen] = useState(false);
  const [hervorgehoben, setHervorgehoben] = useState(0);
  const wurzel = useRef<HTMLDivElement>(null);
  const knopf = useRef<HTMLButtonElement>(null);
  const panel = useRef<HTMLDivElement>(null);
  const generierteId = useId();
  const knopfId = id ?? generierteId;

  const gewaehlt = optionen.find((option) => option.wert === value);

  // Klick ausserhalb schliesst -- ein Klick auf eine Zeile bleibt innerhalb
  // von `wurzel` und schliesst hier nicht, das erledigt waehlen() selbst.
  useEffect(() => {
    if (!offen) return;
    function aufZeiger(ereignis: PointerEvent) {
      if (!wurzel.current?.contains(ereignis.target as Node)) setOffen(false);
    }
    document.addEventListener("pointerdown", aufZeiger);
    return () => document.removeEventListener("pointerdown", aufZeiger);
  }, [offen]);

  // Die hervorgehobene Zeile beim Oeffnen ins Bild scrollen -- bei langen
  // Listen (Zeitzonen, Mitglieder) sonst unsichtbar unterhalb des Panels.
  useEffect(() => {
    if (!offen) return;
    const zeile = panel.current?.querySelector('[data-hervorgehoben="true"]');
    zeile?.scrollIntoView({ block: "nearest" });
  }, [offen, hervorgehoben]);

  function oeffnen() {
    const index = optionen.findIndex((option) => option.wert === value);
    setHervorgehoben(index === -1 ? 0 : index);
    setOffen(true);
  }

  function waehlen(index: number) {
    const option = optionen[index];
    if (!option) return;
    onChange(option.wert);
    setOffen(false);
    knopf.current?.focus();
  }

  function aufTaste(ereignis: React.KeyboardEvent<HTMLButtonElement>) {
    if (!offen) {
      if (["ArrowDown", "ArrowUp", "Enter", " "].includes(ereignis.key)) {
        ereignis.preventDefault();
        oeffnen();
      }
      return;
    }
    if (ereignis.key === "Escape") {
      ereignis.preventDefault();
      setOffen(false);
    } else if (ereignis.key === "ArrowDown") {
      ereignis.preventDefault();
      setHervorgehoben((index) => Math.min(optionen.length - 1, index + 1));
    } else if (ereignis.key === "ArrowUp") {
      ereignis.preventDefault();
      setHervorgehoben((index) => Math.max(0, index - 1));
    } else if (ereignis.key === "Enter") {
      ereignis.preventDefault();
      waehlen(hervorgehoben);
    }
  }

  return (
    <div className={styles.wurzel} ref={wurzel}>
      <button
        id={knopfId}
        ref={knopf}
        type="button"
        className={gross ? styles.knopfGross : styles.knopf}
        aria-haspopup="listbox"
        aria-expanded={offen}
        aria-label={ariaLabel}
        onClick={() => (offen ? setOffen(false) : oeffnen())}
        onKeyDown={aufTaste}
      >
        <span className={gewaehlt ? undefined : styles.platzhalter}>
          {gewaehlt?.anzeige ?? platzhalter ?? ""}
        </span>
        <svg
          className={styles.chevron}
          width="16"
          height="16"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
        >
          <path d="M6 9l6 6 6-6" />
        </svg>
      </button>
      {name ? <input type="hidden" name={name} value={value} /> : null}
      {offen ? (
        <div className={styles.panel} ref={panel} role="listbox" aria-label={ariaLabel}>
          {optionen.map((option, index) => (
            <div
              key={option.wert}
              role="option"
              aria-selected={option.wert === value}
              data-hervorgehoben={index === hervorgehoben}
              className={
                option.wert === value
                  ? styles.zeileAktiv
                  : index === hervorgehoben
                    ? styles.zeileHervorgehoben
                    : styles.zeile
              }
              onMouseEnter={() => setHervorgehoben(index)}
              onClick={() => waehlen(index)}
            >
              {option.anzeige}
            </div>
          ))}
        </div>
      ) : null}
    </div>
  );
}
