"use client";
import { useEffect, useReducer, useRef, useState, type CSSProperties } from "react";
import {
  OHNE_MIT_START,
  RUECKFLUG_MS,
  feedLage,
  feedZeitplan,
  ohneMitZustand,
  pillenFlug,
} from "./ohnemit.logik";
import styles from "./OhneMit.module.css";

export type Pille = { text: string; x: number; y: number };

type Props = { titel: string; marke: string; ohne: readonly Pille[]; mit: readonly string[] };

/**
 * Die eine Inszenierung der Seite, Modell "Schwelle" (Spec 7.2.2). Die
 * Werte je Pille und Feed-Eintrag stehen am Element selbst, nicht als
 * Variable am Elternteil -- sonst rechnete jeder Wechsel die Stile aller
 * Kinder neu.
 */
export function OhneMit({ titel, marke, ohne, mit }: Props) {
  const karte = useRef<HTMLDivElement>(null);
  const sonde = useRef<HTMLSpanElement>(null);
  const [zustand, melden] = useReducer(ohneMitZustand, OHNE_MIT_START);
  const [feedIndex, setFeedIndex] = useState(0);

  useEffect(() => {
    const k = karte.current;
    const s = sonde.current;
    if (!k || !s) return;
    const sondeIO = new IntersectionObserver(
      ([e]) => {
        if (e) melden({ art: "sonde", schneidet: e.isIntersecting });
      },
      { rootMargin: "0px 0px -42% 0px" },
    );
    const karteIO = new IntersectionObserver(([e]) => {
      if (e && !e.isIntersecting) melden({ art: "karteWeg" });
    });
    sondeIO.observe(s);
    karteIO.observe(k);
    return () => {
      sondeIO.disconnect();
      karteIO.disconnect();
    };
  }, []);

  useEffect(() => {
    if (!zustand.mit) {
      const t = setTimeout(() => setFeedIndex(0), RUECKFLUG_MS);
      return () => clearTimeout(t);
    }
    const timer = feedZeitplan(mit.length).map((ms, i) => setTimeout(() => setFeedIndex(i + 1), ms));
    return () => timer.forEach(clearTimeout);
  }, [zustand.mit, mit.length]);

  return (
    <section className={styles.abschnitt} aria-labelledby="ohnemit-titel">
      <div
        ref={karte}
        className={styles.karte}
        data-mit={zustand.mit ? "" : undefined}
        data-testid="ohnemit-karte"
      >
        <span ref={sonde} className={styles.sonde} aria-hidden="true" data-testid="ohnemit-sonde" />
        <div className={styles.kopf}>
          <h2 id="ohnemit-titel" className={styles.titel}>
            {titel}
          </h2>
          <div className={styles.schalterZeile}>
            <span className={styles.seiteOhne} aria-hidden="true">
              Ohne {marke}
            </span>
            <button
              type="button"
              role="switch"
              aria-checked={zustand.mit}
              aria-label={`Mit ${marke}`}
              className={styles.schalter}
              onClick={() => melden({ art: "tipp" })}
            >
              <span className={styles.knopf} />
            </button>
            <span className={styles.seiteMit} aria-hidden="true">
              Mit {marke}
            </span>
          </div>
          <p className={styles.hinweis}>Scroll, oder tipp auf den Schalter.</p>
        </div>
        <div className={styles.buehne}>
          <ul className={styles.pillen} aria-label={`Ohne ${marke}`}>
            {ohne.map((p, i) => {
              const f = pillenFlug(p.x, p.y, i);
              const stil = {
                left: `${p.x}%`,
                top: `${p.y}%`,
                "--sx": `${f.sx}px`,
                "--sy": `${f.sy}px`,
                "--r": `${f.r}deg`,
                "--d": `${f.verzoegerung}ms`,
              } as CSSProperties;
              return (
                <li key={p.text} className={styles.pille} style={stil}>
                  {p.text}
                </li>
              );
            })}
          </ul>
          <ol className={styles.feed} aria-label={`Mit ${marke}`}>
            {mit.map((text, i) => {
              const l = feedLage(i - feedIndex);
              const stil = { "--o": l.versatz, "--s": l.skala, "--a": l.deckkraft } as CSSProperties;
              return (
                <li key={text} style={stil}>
                  {text}
                </li>
              );
            })}
          </ol>
        </div>
      </div>
    </section>
  );
}
