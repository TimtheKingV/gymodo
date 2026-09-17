import styles from "./bausteine.module.css";

/**
 * Ein Anteil gegen eine Grenze: "9 von 12 Geräten erreichbar".
 *
 * Kachel.tsx haelt fest, warum die Kennzahlen des Ueberblicks KEINEN
 * Balken tragen: "der Ueberblick sagt, OB das Studio benutzt wird, nicht
 * wie weit es von irgendwas entfernt ist." Das gilt fuer aktive
 * Mitglieder, erfasste Saetze und gemeldete Probleme -- es gibt dort kein
 * Ziel, und ein Balken erfaende eines.
 *
 * Fuer die Erreichbarkeit gilt es nicht. Sie IST ein Anteil mit einem
 * Ziel, und das Ziel ist die Zahl der Geraete im Raum: jedes soll
 * auffindbar sein. Zwischen "9 von 12" und "12 von 12" liegt eine
 * Handlung, und die stand bislang als vierte von vier gleich grossen,
 * gleich grauen Zahlen da.
 *
 * Die Fuellung traegt --daten, nicht --accent: der Akzent markiert die
 * eine Handlung je Bildschirm, und der Ueberblick hat keine. Der Rest der
 * Bahn bleibt --surface-raised statt einer zweiten Stufe derselben Farbe
 * -- dasselbe Paar wie beim Upload-Fortschritt, das im Portal schon steht.
 */
export function Anteil({
  erreicht,
  gesamt,
  label,
  fuss,
}: {
  erreicht: number;
  gesamt: number;
  label: string;
  /** Was der Anteil bedeutet, wenn er nicht voll ist. Ein Satz. */
  fuss: React.ReactNode;
}) {
  const voll = gesamt > 0 && erreicht >= gesamt;
  const anteil = gesamt > 0 ? Math.min(1, Math.max(0, erreicht / gesamt)) : 0;

  return (
    <div className={styles.anteil}>
      <div className={styles.anteilKopf}>
        <div>
          <div className={styles.anteilZahl}>
            {erreicht} <span className={styles.anteilVon}>von {gesamt}</span>
          </div>
          <div className={styles.kachelLabel}>{label}</div>
        </div>
        <div className={voll ? styles.anteilFussVoll : styles.anteilFuss}>{fuss}</div>
      </div>
      {/* aria-hidden: die Zahl daneben sagt dasselbe genauer, und zwei
          Ansagen fuer einen Wert sind eine zu viel. */}
      <div className={styles.anteilBahn} aria-hidden="true">
        <div
          className={styles.anteilFuellung}
          style={{ width: `${Math.round(anteil * 100)}%` }}
        />
      </div>
    </div>
  );
}
