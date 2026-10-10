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
 *
 * Mit `suche` steht oben im Panel ein Suchfeld -- fuer lange Listen wie die
 * Gymtavo-Typen (Nachtrag 10.1), in denen Pfeiltasten allein zu langsam
 * sind. Der Fokus wandert beim Oeffnen dorthin; Pfeile und Enter wirken
 * dort wie am Knopf.
 *
 * Mit `pflicht` (und `name`) haelt die Auswahl das Absenden an, solange
 * nichts gewaehlt ist, und nennt den Satz darunter. Im Browser, nicht erst
 * in der Server-Action: React 19 leert ein Formular nach jeder Action, auch
 * nach einer abgelehnten -- der Trainer verloere sonst alle Eingaben.
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
  suche,
  pflicht,
}: {
  id?: string;
  name?: string;
  value: string;
  onChange: (wert: string) => void;
  optionen: AuswahlOption[];
  platzhalter?: string;
  gross?: boolean;
  ariaLabel?: string;
  /** Beschriftung des Suchfelds; ohne sie keine Suche. */
  suche?: string;
  /** Satz, wenn ohne Wahl abgesendet wird; ohne ihn ist die Wahl frei. */
  pflicht?: string;
}) {
  const [offen, setOffen] = useState(false);
  const [hervorgehoben, setHervorgehoben] = useState(0);
  const wurzel = useRef<HTMLDivElement>(null);
  const knopf = useRef<HTMLButtonElement>(null);
  const panel = useRef<HTMLDivElement>(null);
  const suchfeld = useRef<HTMLInputElement>(null);
  const verborgen = useRef<HTMLInputElement>(null);
  const ersterLauf = useRef(true);
  const [fehlt, setFehlt] = useState(false);
  const [text, setText] = useState("");
  const generierteId = useId();
  const knopfId = id ?? generierteId;

  const gewaehlt = optionen.find((option) => option.wert === value);
  const gesucht = text.trim().toLocaleLowerCase("de");
  const sichtbar = suche
    ? optionen.filter((option) => option.anzeige.toLocaleLowerCase("de").includes(gesucht))
    : optionen;

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

  useEffect(() => {
    if (offen && suche) suchfeld.current?.focus();
  }, [offen, suche]);

  // Wie beim Rad (EinstellungRad.tsx): ein verstecktes Feld meldet keine
  // Eingabe, wenn React seinen Wert setzt. AktionsFormular mit
  // nurBeiAenderung sieht eine Wahl sonst nicht, und "Änderungen speichern"
  // bliebe nach einer Typwahl gesperrt. Erst nach dem Rendern, damit der
  // neue Wert schon im Feld steht.
  useEffect(() => {
    if (ersterLauf.current) {
      ersterLauf.current = false;
      return;
    }
    verborgen.current?.dispatchEvent(new Event("input", { bubbles: true }));
  }, [value]);

  function oeffnen() {
    setText("");
    const index = optionen.findIndex((option) => option.wert === value);
    setHervorgehoben(index === -1 ? 0 : index);
    setOffen(true);
  }

  function waehlen(index: number) {
    const option = sichtbar[index];
    if (!option) return;
    onChange(option.wert);
    setFehlt(false);
    setOffen(false);
    knopf.current?.focus();
  }

  function aufTaste(ereignis: React.KeyboardEvent<HTMLElement>) {
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
      setHervorgehoben((index) => Math.min(sichtbar.length - 1, index + 1));
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
      {name && pflicht ? (
        // Kein type="hidden": versteckte Felder sind von der
        // Formularpruefung ausgenommen. Unsichtbar, nicht fokussierbar, und
        // onInvalid lenkt auf den Knopf statt auf die Blase des Browsers.
        <input
          ref={verborgen}
          className={styles.pflichtFeld}
          name={name}
          value={value}
          required
          tabIndex={-1}
          aria-hidden
          onChange={() => {}}
          onInvalid={(ereignis) => {
            ereignis.preventDefault();
            setFehlt(true);
            knopf.current?.focus();
          }}
        />
      ) : name ? (
        <input ref={verborgen} type="hidden" name={name} value={value} />
      ) : null}
      {fehlt && !value ? (
        <p className={styles.pflichtSatz} role="alert">
          {pflicht}
        </p>
      ) : null}
      {offen ? (
        <div className={styles.panel} ref={panel}>
          {suche ? (
            <input
              ref={suchfeld}
              type="search"
              className={styles.suche}
              aria-label={suche}
              placeholder={suche}
              value={text}
              onChange={(ereignis) => {
                setText(ereignis.target.value);
                setHervorgehoben(0);
              }}
              onKeyDown={aufTaste}
            />
          ) : null}
          {sichtbar.length === 0 ? <div className={styles.leer}>Kein Treffer.</div> : null}
          <div role="listbox" aria-label={ariaLabel}>
            {sichtbar.map((option, index) => (
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
        </div>
      ) : null}
    </div>
  );
}
