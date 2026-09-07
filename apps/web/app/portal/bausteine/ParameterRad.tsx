"use client";

import { useEffect, useRef, useState } from "react";
import type { ParameterVorgabe, RadWert } from "./parameterVorgaben";
import styles from "./ParameterRad.module.css";

const SICHTBARE_ZEILEN = 5; // ungerade -- sonst gibt es keine Mitte
const HALB = Math.floor(SICHTBARE_ZEILEN / 2);
const KOPFHOEHE = 32;

export type RadSpalte = {
  name: string;
  label: string;
  werte: RadWert[];
  /** Muss zu einem RadWert.wert passen, sonst zaehlt die erste Zeile. */
  start?: string;
};

/**
 * Ein echtes Scroll-Rad je Spalte -- kein Chip, kein Eingabefeld mit
 * Tastatur. Trainer-Wunsch: "diese wollte ich dann als scroll haben und
 * nicht als Eingabefeld mit Keyboard", bestaetigt als Scroll-*Rad*, nicht
 * als scrollende Chip-Zeile ("ja daran hab ich gedacht").
 *
 * Jede Spalte traegt ihren Wert ueber ein verstecktes Eingabefeld -- das
 * Formular sieht denselben Feldnamen wie zuvor (minValue/maxValue/
 * stepValue/unit), nur die Eingabe ist jetzt eine Auswahl statt Tastatur.
 * Werte aus ModellEinstellungen.dc.html / TelefonParameterNeu.dc.html
 * (docs/superpowers/design/portal/, /design-Runde "Vorgaben-Rad").
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
      {spalten.map((spalte) => (
        <RadSpalte key={spalte.name} {...spalte} zeilenhoehe={zeilenhoehe} />
      ))}
      <div
        className={styles.band}
        style={{ top: KOPFHOEHE + zeilenhoehe * HALB, height: zeilenhoehe }}
        aria-hidden
      />
    </div>
  );
}

function RadSpalte({
  name,
  label,
  werte,
  start,
  zeilenhoehe,
}: RadSpalte & { zeilenhoehe: number }) {
  const startIndex = Math.max(
    0,
    start !== undefined ? werte.findIndex((wert) => wert.wert === start) : 0,
  );
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
            {wert.anzeige || " "}
          </div>
        ))}
      </div>
      <input type="hidden" name={name} value={werte[index]?.wert ?? ""} />
    </div>
  );
}

function Haken() {
  return (
    <svg
      width="18"
      height="18"
      viewBox="0 0 24 24"
      fill="none"
      stroke="var(--accent)"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
    >
      <path d="M20 6L9 17l-5-5" />
    </svg>
  );
}

/**
 * Die Vorgaben-Liste -- Wiederholungen/Gewicht/Winkel/Eigener Parameter.
 * Eine Auswahl ersetzt Minimum/Maximum/Schritt/Einheit durch feste Werte
 * (Trainer-Wunsch: "so muss man weniger tippen"); "Eigener Parameter"
 * bleibt der freie Weg und zeigt stattdessen das Rad.
 */
export function VorgabenListe({
  vorgaben,
  gewaehlt,
  onWahl,
  gross = false,
}: {
  vorgaben: ParameterVorgabe[];
  gewaehlt: string;
  onWahl: (id: ParameterVorgabe["id"]) => void;
  gross?: boolean;
}) {
  return (
    <div className={styles.kasten}>
      <div className={styles.kastenKopf}>Vorgabe</div>
      <div className={styles.kastenListe}>
        {vorgaben.map((vorgabe) => {
          const aktiv = vorgabe.id === gewaehlt;
          const klasse = gross
            ? aktiv
              ? styles.zeileAktivGross
              : styles.zeileGross
            : aktiv
              ? styles.zeileAktiv
              : styles.zeile;
          return (
            <button
              key={vorgabe.id}
              type="button"
              className={klasse}
              onClick={() => onWahl(vorgabe.id)}
            >
              <div style={{ minWidth: 0 }}>
                <div className={styles.zeileName}>{vorgabe.name}</div>
                <div className={styles.zeileMeta}>{vorgabe.meta}</div>
              </div>
              <span className={styles.zeileHaken}>{aktiv ? <Haken /> : null}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
