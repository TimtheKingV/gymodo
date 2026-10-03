"use client";

import { useEffect, useRef, useState } from "react";
import styles from "./testnotiz.module.css";

const DURCHMESSER = 44;
const SCHLUESSEL = "testnotiz.knopf";

/** Unter 6 px Weg ist es ein Klick, kein Zug. */
export function istKlick(weg: number): boolean {
  return Math.abs(weg) < 6;
}

/** Klemmt die Knopfmitte so, dass der ganze Kreis sichtbar bleibt. */
export function mitteY(gewuenscht: number, hoehe: number): number {
  const halb = DURCHMESSER / 2;
  return Math.min(Math.max(gewuenscht, halb), Math.max(hoehe - halb, halb));
}

/**
 * Der schwebende Kreis am rechten Rand, senkrecht verschiebbar -- wie in der
 * App. Die Hoehe bleibt gemerkt: wer ihn einmal aus dem Weg geschoben hat,
 * findet ihn nach dem naechsten Neuladen dort wieder.
 */
export function TestnotizKnopf({ anzahl, beiKlick }: { anzahl: number; beiKlick: () => void }) {
  const [y, setY] = useState<number | null>(null);
  const zug = useRef<{ zeiger: number; start: number; mitte: number } | null>(null);
  /** Ein Zug endet auch in einem Klick -- der darf das Menue nicht oeffnen. */
  const gezogen = useRef(false);

  useEffect(() => {
    const gemerkt = Number(window.localStorage.getItem(SCHLUESSEL));
    setY(mitteY(gemerkt > 0 ? gemerkt : window.innerHeight * 0.62, window.innerHeight));
  }, []);

  if (y === null) return null;

  return (
    <button
      type="button"
      className={styles.knopf}
      style={{ top: `${y}px` }}
      aria-label={anzahl > 0 ? `Testnotiz (${anzahl} Einträge)` : "Testnotiz"}
      title="Testnotiz"
      onPointerDown={(ereignis) => {
        ereignis.currentTarget.setPointerCapture(ereignis.pointerId);
        zug.current = { zeiger: ereignis.pointerId, start: ereignis.clientY, mitte: y };
        gezogen.current = false;
      }}
      onPointerMove={(ereignis) => {
        if (zug.current?.zeiger !== ereignis.pointerId) return;
        const weg = ereignis.clientY - zug.current.start;
        if (istKlick(weg)) return;
        gezogen.current = true;
        setY(mitteY(zug.current.mitte + weg, window.innerHeight));
      }}
      onPointerUp={(ereignis) => {
        const lauf = zug.current;
        zug.current = null;
        if (lauf?.zeiger !== ereignis.pointerId) return;
        if (gezogen.current) window.localStorage.setItem(SCHLUESSEL, String(y));
        else setY(lauf.mitte);
      }}
      // Das Oeffnen haengt am Klick, nicht am Zeiger: ein Fingertipp am Handy
      // erzeugt nicht verlaesslich ein pointerup am Knopf (gemessen), und mit
      // der Tastatur gaebe es ueberhaupt keines. Der Zug unterdrueckt ihn.
      onClick={() => {
        if (gezogen.current) {
          gezogen.current = false;
          return;
        }
        beiKlick();
      }}
    >
      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" aria-hidden="true">
        <path
          d="M4 5.5A1.5 1.5 0 0 1 5.5 4h13A1.5 1.5 0 0 1 20 5.5v9L14.5 20h-9A1.5 1.5 0 0 1 4 18.5v-13Z"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinejoin="round"
        />
        <path d="M8 9h8M8 13h5" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
      </svg>
      {anzahl > 0 ? <span className={styles.zaehler}>{anzahl}</span> : null}
    </button>
  );
}
