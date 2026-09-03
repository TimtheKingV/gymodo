import styles from "./halle.module.css";

const SCHRITTE = 6;

/**
 * Die Wegmarke des Gangs -- sechs Segmente und ein Satz. Bewusst ohne
 * Akzent: der gehoert auf jedem Bildschirm der einen Hauptaktion.
 *
 * Der Sucher und die Aufnahme tragen sie nicht, weil sie randlos ueber der
 * Kamera liegen; dort steht die Marke als blosse Zeile.
 */
export function Schrittleiste({
  nummer,
  titel,
}: {
  nummer: number;
  titel: string;
}) {
  return (
    <div className={styles.leiste}>
      <div className={styles.leisteSegmente} aria-hidden="true">
        {Array.from({ length: SCHRITTE }, (_, index) => (
          <div
            key={index}
            className={
              index < nummer ? styles.leisteSegmentVoll : styles.leisteSegment
            }
          />
        ))}
      </div>
      <span className={styles.label}>
        Schritt {nummer} von {SCHRITTE} · {titel}
      </span>
    </div>
  );
}
