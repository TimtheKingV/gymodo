import styles from "../../portal.module.css";

/**
 * "Laedt" heisst hier: der Bildschirm reagiert sofort, aber er erfindet
 * nichts.
 *
 * Keine Skelettzeilen. Designsystem Abschnitt 5 laesst das Skelett
 * ausschliesslich fuer Medien zu, und der Grund traegt auch am
 * Schreibtisch: die Zahl der Zeilen waere geraten, und eine geratene Zahl
 * ist eine Aussage ueber Daten, die noch niemand kennt. Der Titel dagegen
 * steht in der Route, nicht in der Datenbank -- er darf sofort da sein.
 */
export default function Laedt() {
  return <div className={styles.pageLead}>Lädt …</div>;
}
