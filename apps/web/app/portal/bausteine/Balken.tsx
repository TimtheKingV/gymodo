import styles from "./bausteine.module.css";

/**
 * Der Balken unter einer Zeile der Rangliste.
 *
 * "Meistgenutzt" war eine Rangliste ohne Rang: 212 / 198 / 164 / 140
 * Saetze als rechtsbuendige Zahlen, und der Vergleich -- der ganze Zweck
 * der Liste -- fand im Kopf des Lesers statt. Die Laenge macht ihn
 * sichtbar, die Zahl daneben bleibt genau.
 *
 * `anteil` ist immer relativ zum groessten Wert der Liste, nicht zu einer
 * gedachten Obergrenze: die Frage ist "welches Geraet laeuft am meisten",
 * nicht "wie weit ist es von irgendetwas entfernt".
 *
 * Farbe: --daten-leise, die dunklere Stufe derselben Primaerfarbe. Vier
 * gleich helle Balken neben dem Anteil oben haetten vier gleich laute
 * Stimmen ergeben; die Reihe ist Zusammenhang, nicht Aufforderung.
 *
 * aria-hidden, weil die Zahl in derselben Zeile steht. Ein Screenreader,
 * der erst "212 Sätze" und dann "87 Prozent" sagt, gibt keine zweite
 * Auskunft, sondern dieselbe zweimal.
 */
export function Balken({ anteil }: { anteil: number }) {
  const breite = Math.round(Math.min(1, Math.max(0, anteil)) * 100);
  return (
    <div className={styles.balkenBahn} aria-hidden="true">
      <div className={styles.balken} style={{ width: `${breite}%` }} />
    </div>
  );
}
