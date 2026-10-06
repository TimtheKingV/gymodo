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
  const [zustand, setZustand] = useState<KaufleistenZustand>(KAUFLEISTE_START);
  const verdeckerSchluessel = verdecker.join(",");

  useEffect(() => {
    const el = leiste.current;
    const ankerEl = document.getElementById(anker);
    if (!el || !ankerEl) return;
    const kopfHoehe = parseFloat(getComputedStyle(el).getPropertyValue("--kopf-hoehe")) || 0;
    const lage = { ankerVorbei: false, schwelleY: 0, fokusDrin: false };
    const sichtbareVerdecker = new Set<Element>();
    let raf = 0;
    // Eigener Merker statt raf !== 0: liefe der Callback sofort, setzte die
    // Zuweisung danach raf wieder und sperrte jede weitere Messung.
    let geplant = false;

    const messen = () => {
      geplant = false;
      setZustand((vorher) =>
        naechsterZustand(vorher, {
          y: window.scrollY,
          maxY: document.documentElement.scrollHeight - window.innerHeight,
          ankerVorbei: lage.ankerVorbei,
          schwelleY: lage.schwelleY,
          verdeckt: sichtbareVerdecker.size > 0,
          fokusDrin: lage.fokusDrin,
        }),
      );
    };
    const anfordern = () => {
      if (geplant) return;
      geplant = true;
      raf = requestAnimationFrame(messen);
    };

    const ankerIO = new IntersectionObserver(
      ([e]) => {
        if (!e) return;
        lage.ankerVorbei = !e.isIntersecting && e.boundingClientRect.top < kopfHoehe;
        lage.schwelleY = e.boundingClientRect.bottom + window.scrollY - kopfHoehe;
        anfordern();
      },
      // Unter dem Kopf ist der Knopf schon nicht mehr zu sehen.
      { rootMargin: `-${kopfHoehe}px 0px 0px 0px` },
    );
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

    // Laege der Fokus in einer Leiste, die inert wird, waere er verloren.
    const fokus = () => {
      lage.fokusDrin = el.contains(document.activeElement);
      anfordern();
    };
    el.addEventListener("focusin", fokus);
    el.addEventListener("focusout", fokus);
    window.addEventListener("scroll", anfordern, { passive: true });

    return () => {
      ankerIO.disconnect();
      verdeckerIO.disconnect();
      el.removeEventListener("focusin", fokus);
      el.removeEventListener("focusout", fokus);
      window.removeEventListener("scroll", anfordern);
      if (geplant) cancelAnimationFrame(raf);
    };
  }, [anker, verdeckerSchluessel]);

  const versteckt = !zustand.sichtbar;
  return (
    <aside
      ref={leiste}
      aria-label="Schnellzugriff"
      className={styles.leiste}
      data-sichtbar={zustand.sichtbar ? "" : undefined}
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
