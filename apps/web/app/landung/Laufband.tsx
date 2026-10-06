import styles from "./Laufband.module.css";

/**
 * Etappe 1 ruhend (E7): drei Fakten als umbrechende Zeile. Das Laufen
 * kommt erst mit Live-Zahlen (Etappe 3) -- Saetze, die vorbeiziehen, waeren
 * Bewegung ohne Zweck neben der einen Inszenierung (Ohne/Mit).
 */
export function Laufband({ eintraege }: { eintraege: readonly string[] }) {
  return (
    <section className={styles.laufband} aria-label="Kurz gesagt">
      <ul className={styles.liste}>
        {eintraege.map((e) => (
          <li key={e}>{e}</li>
        ))}
      </ul>
    </section>
  );
}
