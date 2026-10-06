"use client";
import { useEffect, useState } from "react";
import styles from "./Schritte.module.css";
import { useReduzierteBewegung } from "./useMedienabfrage";

/**
 * Aktive Folie per Observer (threshold .6) statt Gpaths "Scroll-Ende +
 * 150 ms": kein Timer, und die Anzeige stimmt schon waehrend des Wischens.
 */
export function SchritteIndikatoren({ ids, titel }: { ids: readonly string[]; titel: readonly string[] }) {
  const [aktiv, setAktiv] = useState(0);
  const reduziert = useReduzierteBewegung();

  useEffect(() => {
    const folien = ids.map((id) => document.getElementById(id)).filter((el): el is HTMLElement => el !== null);
    const io = new IntersectionObserver(
      (eintraege) => {
        for (const e of eintraege) if (e.isIntersecting) setAktiv(ids.indexOf(e.target.id));
      },
      { root: folien[0]?.parentElement ?? null, threshold: 0.6 },
    );
    folien.forEach((f) => io.observe(f));
    return () => io.disconnect();
  }, [ids]);

  return (
    <div className={styles.indikatoren}>
      {ids.map((id, i) => (
        <button
          key={id}
          type="button"
          className={styles.indikator}
          aria-label={`Schritt ${i + 1}: ${titel[i]}`}
          aria-current={aktiv === i ? "step" : undefined}
          onClick={() =>
            document.getElementById(id)?.scrollIntoView({
              behavior: reduziert ? "auto" : "smooth",
              block: "nearest",
              inline: "start",
            })
          }
        >
          {i + 1}
        </button>
      ))}
    </div>
  );
}
