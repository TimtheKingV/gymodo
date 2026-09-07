import styles from "./bausteine.module.css";

/**
 * Gerahmter Block mit Kopf (Titel, optional Notiz) und Rumpf.
 *
 * Die Karte, in der die meisten Bildschirme des Portals leben --
 * Geraeteliste, Tag-Liste, Team, Kontoformular. Kopf und Rumpf sind hier
 * feste Slots statt freier Kinder, weil jede bestehende Verwendung genau
 * diese Aufteilung schon von Hand nachbaut (portal.module.css .sectionHead
 * / .sectionBody).
 */
export function Abschnitt({
  titel,
  notiz,
  children,
}: {
  titel: string;
  notiz?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <section className={styles.abschnitt}>
      <div className={styles.abschnittKopf}>
        <h2 className={styles.abschnittTitel}>{titel}</h2>
        {notiz ? <span className={styles.abschnittNotiz}>{notiz}</span> : null}
      </div>
      <div className={styles.abschnittRumpf}>{children}</div>
    </section>
  );
}
