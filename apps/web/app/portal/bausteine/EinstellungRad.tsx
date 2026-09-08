"use client";

import { useEffect, useId, useRef, useState } from "react";
import type { RadWert } from "./einstellungVorschlaege";
import portalStyles from "../portal.module.css";
import styles from "./EinstellungRad.module.css";

const SICHTBARE_ZEILEN = 5; // ungerade -- sonst gibt es keine Mitte
const HALB = Math.floor(SICHTBARE_ZEILEN / 2);
const KOPFHOEHE = 32;

export type RadSpalte = {
  /** Ohne name traegt die Spalte kein eigenes Formularfeld -- fuer den
      Fall, dass nur onWahl zaehlt (NameFeld unten). */
  name?: string;
  label: string;
  werte: RadWert[];
  /** Muss zu einem RadWert.wert passen, sonst zaehlt die erste Zeile. */
  start?: string;
  /** Feuert bei jeder neuen Mitte -- fuer Spalten, die eine sichtbare
      Eingabe steuern statt (nur) ein eigenes Formularfeld zu tragen. */
  onWahl?: (wert: string) => void;
};

/**
 * Ein echtes Scroll-Rad je Spalte -- kein Chip, kein Eingabefeld mit
 * Tastatur. Trainer-Wunsch: "diese wollte ich dann als scroll haben und
 * nicht als Eingabefeld mit Keyboard", bestaetigt als Scroll-*Rad*, nicht
 * als scrollende Chip-Zeile ("ja daran hab ich gedacht").
 *
 * Jede Spalte mit `name` traegt ihren Wert ueber ein verstecktes
 * Eingabefeld; `onWahl` reicht die Auswahl zusaetzlich (oder stattdessen)
 * an eine steuernde Komponente weiter -- NameFeld nutzt das fuer ein
 * sichtbares Textfeld statt eines eigenen Formularfelds.
 */
export function Rad({
  spalten,
  gross = false,
}: {
  spalten: RadSpalte[];
  gross?: boolean;
}) {
  const zeilenhoehe = gross ? 44 : 40;
  return (
    <div
      className={styles.rad}
      style={{ height: KOPFHOEHE + zeilenhoehe * SICHTBARE_ZEILEN }}
    >
      {spalten.map((spalte, i) => (
        <RadSpalte key={spalte.name ?? i} {...spalte} zeilenhoehe={zeilenhoehe} />
      ))}
      <div
        className={styles.band}
        style={{ top: KOPFHOEHE + zeilenhoehe * HALB, height: zeilenhoehe }}
        aria-hidden
      />
    </div>
  );
}

/**
 * Der Startwert kann von einer Bestandszeile kommen (z. B. beim Bearbeiten
 * eines Modells) und krumm sein -- keine der Zeilen im Rad trifft ihn dann
 * exakt. Statt still auf die erste Zeile zu fallen (und den Wert beim
 * naechsten Speichern zu veraendern), waehlt das Rad die naechstliegende
 * Zahl. Passt gar nichts (Text, leer, kein Treffer), bleibt es bei Zeile 0.
 */
function naechsterIndex(werte: RadWert[], start: string | undefined): number {
  if (start === undefined) return 0;
  const exakt = werte.findIndex((wert) => wert.wert === start);
  if (exakt !== -1) return exakt;

  const startZahl = Number(start.replace(",", "."));
  if (!Number.isFinite(startZahl)) return 0;

  let bester = 0;
  let besterAbstand = Infinity;
  werte.forEach((wert, i) => {
    const zahl = Number(wert.wert.replace(",", "."));
    if (!Number.isFinite(zahl)) return;
    const abstand = Math.abs(zahl - startZahl);
    if (abstand < besterAbstand) {
      besterAbstand = abstand;
      bester = i;
    }
  });
  return bester;
}

function RadSpalte({
  name,
  label,
  werte,
  start,
  onWahl,
  zeilenhoehe,
}: RadSpalte & { zeilenhoehe: number }) {
  const startIndex = naechsterIndex(werte, start);
  const [index, setIndex] = useState(startIndex);
  const ref = useRef<HTMLDivElement>(null);
  const rahmen = useRef<number | null>(null);

  // Nur beim Einhaengen auf den Anfangswert stellen -- danach scrollt der
  // Trainer selbst, ein erneutes Setzen wuerde ihm den Finger wegziehen.
  useEffect(() => {
    const el = ref.current;
    if (el) el.scrollTop = startIndex * zeilenhoehe;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function aufScroll() {
    const el = ref.current;
    if (!el) return;
    if (rahmen.current !== null) cancelAnimationFrame(rahmen.current);
    rahmen.current = requestAnimationFrame(() => {
      const naechster = Math.min(
        werte.length - 1,
        Math.max(0, Math.round(el.scrollTop / zeilenhoehe)),
      );
      setIndex(naechster);
      onWahl?.(werte[naechster]?.wert ?? "");
    });
  }

  function aufTaste(ereignis: React.KeyboardEvent<HTMLDivElement>) {
    const el = ref.current;
    if (!el) return;
    if (ereignis.key === "ArrowDown") {
      ereignis.preventDefault();
      el.scrollBy({ top: zeilenhoehe, behavior: "smooth" });
    } else if (ereignis.key === "ArrowUp") {
      ereignis.preventDefault();
      el.scrollBy({ top: -zeilenhoehe, behavior: "smooth" });
    }
  }

  return (
    <div className={styles.spalte}>
      <div className={styles.spalteKopf} style={{ height: KOPFHOEHE }}>
        {label}
      </div>
      <div
        ref={ref}
        className={styles.spalteRad}
        style={{
          height: zeilenhoehe * SICHTBARE_ZEILEN,
          paddingTop: zeilenhoehe * HALB,
          paddingBottom: zeilenhoehe * HALB,
        }}
        onScroll={aufScroll}
        onKeyDown={aufTaste}
        tabIndex={0}
        role="listbox"
        aria-label={label}
      >
        {werte.map((wert, i) => (
          <div
            key={`${wert.wert}-${i}`}
            className={i === index ? styles.spalteZeileAktiv : styles.spalteZeile}
            style={{ height: zeilenhoehe }}
            role="option"
            aria-selected={i === index}
          >
            {wert.anzeige || " "}
          </div>
        ))}
      </div>
      {name ? <input type="hidden" name={name} value={werte[index]?.wert ?? ""} /> : null}
    </div>
  );
}

/**
 * Ein Namensfeld mit Vorschlagsrad -- Trainer-Wunsch: "fuer die Felder oben
 * schon eine Vorauswahl treffen, wenn ich das Feld anklicke kommt hier
 * auch ein Scroll, bei dem dann Vorgaben drin sind schon". Bleibt ein
 * normales Textfeld (frei ueberschreibbar); ein Klick/Fokus zeigt
 * zusaetzlich das Rad mit haeufigen Namen, ein Antippen darin fuellt das
 * Feld. Traegt selbst das Formularfeld (`name`) -- das Rad darunter dient
 * nur der Auswahl, nicht dem Absenden.
 */
export function NameFeld({
  name,
  label,
  value,
  onChange,
  vorschlaege,
  gross = false,
  required,
  placeholder,
  hint,
}: {
  name: string;
  label: string;
  value: string;
  onChange: (wert: string) => void;
  vorschlaege: RadWert[];
  gross?: boolean;
  required?: boolean;
  placeholder?: string;
  hint?: string;
}) {
  const [offen, setOffen] = useState(false);
  const id = useId();
  const hintId = hint ? `${id}-hint` : undefined;

  return (
    <div className={portalStyles.field}>
      <label className={portalStyles.label} htmlFor={id}>
        {label}
      </label>
      <input
        id={id}
        name={name}
        className={gross ? portalStyles.inputGross : portalStyles.input}
        value={value}
        onChange={(ereignis) => onChange(ereignis.target.value)}
        onFocus={() => setOffen(true)}
        required={required}
        placeholder={placeholder}
        autoComplete="off"
        aria-describedby={hintId}
      />
      {hint ? (
        <span id={hintId} className={portalStyles.hint}>
          {hint}
        </span>
      ) : null}
      {offen ? (
        <div className={styles.vorschlagRad}>
          <Rad
            gross={gross}
            spalten={[
              {
                label: "Vorschlag",
                werte: vorschlaege,
                start: value,
                onWahl: onChange,
              },
            ]}
          />
          <button
            type="button"
            className={gross ? portalStyles.secondaryGross : portalStyles.secondary}
            onClick={() => setOffen(false)}
          >
            Fertig
          </button>
        </div>
      ) : null}
    </div>
  );
}
