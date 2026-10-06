"use client";
import { useEffect, useRef, useState } from "react";
import { KAUFLEISTE_START, naechsterZustand, type KaufleistenZustand } from "./kaufleiste.logik";
import styles from "./Kaufleiste.module.css";

type Props = {
  anker: string;
  verdecker: readonly string[];
  titel: string;
  merkmale: readonly string[];
  aktion: { href: string; text: string };
};

/**
 * Spec 7.3. Observer statt Messung in jedem Frame fuer Anker und
 * Verdecker; nur die Scrollrichtung braucht den Scroll-Listener, rAF-
 * gedrosselt. Die Entscheidung trifft naechsterZustand().
 */
export function Kaufleiste({ anker, verdecker, titel, merkmale, aktion }: Props) {
  const leiste = useRef<HTMLElement>(null);
  // Der Automat lebt in einer Ref: er rechnet in jedem Scroll-Frame, neu
  // gerendert wird nur, wenn sich die Sichtbarkeit aendert.
  const zustand = useRef<KaufleistenZustand>(KAUFLEISTE_START);
  const [sichtbar, setSichtbar] = useState(false);
  const verdeckerSchluessel = verdecker.join(",");

  useEffect(() => {
    const el = leiste.current;
    const ankerEl = document.getElementById(anker);
    if (!el || !ankerEl) return;
    const lage = { ankerVorbei: false, schwelleY: 0 };
    const sichtbareVerdecker = new Set<Element>();
    let raf = 0;
    // Eigener Merker statt raf !== 0: liefe der Callback sofort, setzte die
    // Zuweisung danach raf wieder und sperrte jede weitere Messung.
    let geplant = false;

    // Inert nimmt der Leiste den Fokus; ohne Weitergabe faellt er auf body
    // und die Tastatur beginnt oben neu (WCAG 2.4.3). Ziel ist, was die
    // Leiste gerade verdraengt: der sichtbare Verdecker oder der Hero-Knopf.
    const fokusWeitergeben = () => {
      const verdraenger = sichtbareVerdecker.values().next().value as HTMLElement | undefined;
      const ziel = verdraenger
        ? verdraenger.querySelector<HTMLElement>("a[href], button:not([disabled])")
        : ankerEl;
      ziel?.focus({ preventScroll: true });
    };

    const messen = () => {
      geplant = false;
      // Live gelesen statt per focusout gemerkt: ob focusout feuert, wenn
      // inert den Fokus nimmt, ist je nach Browser verschieden.
      const fokusDrin = el.contains(document.activeElement);
      const vorher = zustand.current;
      const naechster = naechsterZustand(vorher, {
        y: window.scrollY,
        maxY: document.documentElement.scrollHeight - window.innerHeight,
        ankerVorbei: lage.ankerVorbei,
        schwelleY: lage.schwelleY,
        verdeckt: sichtbareVerdecker.size > 0,
        fokusDrin,
      });
      zustand.current = naechster;
      if (vorher.sichtbar && !naechster.sichtbar && fokusDrin) fokusWeitergeben();
      setSichtbar(naechster.sichtbar);
    };
    const anfordern = () => {
      if (geplant) return;
      geplant = true;
      raf = requestAnimationFrame(messen);
    };

    // Ohne rootMargin: Der Kopf deckt den Knopf nicht ab -- 8 px Rand, runde
    // Ecken und Glas mit 72 % lassen ihn durchscheinen. Die Leiste kommt
    // erst, wenn er ganz aus dem Viewport ist (Spec 4.2, eine Akzentflaeche).
    const ankerIO = new IntersectionObserver(([e]) => {
      if (!e) return;
      lage.ankerVorbei = !e.isIntersecting && e.boundingClientRect.top < 0;
      lage.schwelleY = e.boundingClientRect.bottom + window.scrollY;
      anfordern();
    });
    ankerIO.observe(ankerEl);

    const verdeckerIO = new IntersectionObserver(
      (eintraege) => {
        for (const e of eintraege) {
          if (e.isIntersecting) sichtbareVerdecker.add(e.target);
          else sichtbareVerdecker.delete(e.target);
        }
        anfordern();
      },
      { threshold: 0.15 },
    );
    for (const id of verdeckerSchluessel.split(",")) {
      const v = document.getElementById(id);
      if (v) verdeckerIO.observe(v);
    }

    el.addEventListener("focusin", anfordern);
    el.addEventListener("focusout", anfordern);
    window.addEventListener("scroll", anfordern, { passive: true });

    return () => {
      ankerIO.disconnect();
      verdeckerIO.disconnect();
      el.removeEventListener("focusin", anfordern);
      el.removeEventListener("focusout", anfordern);
      window.removeEventListener("scroll", anfordern);
      if (geplant) cancelAnimationFrame(raf);
    };
  }, [anker, verdeckerSchluessel]);

  const versteckt = !sichtbar;
  return (
    <aside
      ref={leiste}
      aria-label="Schnellzugriff"
      className={styles.leiste}
      data-sichtbar={sichtbar ? "" : undefined}
      inert={versteckt}
      aria-hidden={versteckt ? "true" : undefined}
    >
      <div className={styles.text}>
        <p className={styles.titel}>{titel}</p>
        <p className={styles.merkmale}>{merkmale.join(" · ")}</p>
      </div>
      <a href={aktion.href} className={styles.aktion}>
        {aktion.text}
      </a>
    </aside>
  );
}
