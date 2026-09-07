import styles from "./bausteine.module.css";

/**
 * Fortschritt eines mehrstufigen Ablaufs -- verallgemeinert aus
 * einrichten/Schrittleiste.tsx, wo SCHRITTE fest auf 6 stand. `von` ist
 * jetzt ein Prop statt einer Konstante (Default 6, die sechs bestehenden
 * Aufrufstellen im Einrichten-Gang bleiben unveraendert), damit ein
 * zweiter mehrstufiger Ablauf denselben Baustein nutzen kann, ohne die
 * Datei zu kopieren.
 *
 * Bewusst ohne Akzent: der gehoert auf jedem Bildschirm der einen
 * Hauptaktion, nicht der Wegmarke.
 */
export function Schrittleiste({
  nummer,
  titel,
  von = 6,
}: {
  nummer: number;
  titel: string;
  von?: number;
}) {
  return (
    <div className={styles.leiste}>
      <div className={styles.leisteSegmente} aria-hidden="true">
        {Array.from({ length: von }, (_, index) => (
          <div
            key={index}
            className={
              index < nummer ? styles.leisteSegmentVoll : styles.leisteSegment
            }
          />
        ))}
      </div>
      <span className={styles.label}>
        Schritt {nummer} von {von} · {titel}
      </span>
    </div>
  );
}
