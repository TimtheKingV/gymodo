import styles from "./bausteine.module.css";

/**
 * Erklaerender Fliesstext unter einem Abschnitt -- Inhalt, nicht Dekoration
 * (Tags.dc.html). Ein eigener Baustein statt einer Klasse in der jeweiligen
 * Seiten-CSS, weil dieses Muster (Abschnitt, danach ein erklaerender Satz,
 * der begruendet statt nur zu beschreiben) den Aufgaben 14-20 vorgegeben
 * ist -- eine neue Klasse in portal.module.css je Seite waere sieben
 * Kopien.
 */
export function Erlaeuterung({ children }: { children: React.ReactNode }) {
  return <p className={styles.erlaeuterung}>{children}</p>;
}
