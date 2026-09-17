import Link from "next/link";
import type { OffenerPunkt } from "../[studioId]/offen";
import styles from "./bausteine.module.css";
import portalStyles from "../portal.module.css";

/**
 * Was an einem Objekt noch fehlt, als Weg statt als Zaehlstand.
 *
 * Der Gang durch die Halle traegt eine Schrittleiste: "Schritt 2 von 6 ·
 * Einstellungen". Der Schreibtisch kann die nicht uebernehmen -- dort ist
 * die Einrichtung keine Abfolge, sondern ein Objekt, an dem jemand Wochen
 * spaeter ein Video nachreicht. Was bleibt, ist die Restliste: dieselben
 * Pflichten, in derselben Aufbaureihenfolge, aber ohne Nummer und ohne
 * Zwang, sie jetzt zu erledigen.
 *
 * Bis hierher stand an dieser Stelle die Reiterleiste allein, und die zeigt
 * Zaehlstaende ("3 Einstellungen", "2 · 0 ohne Tag"). Ein Zaehlstand sagt,
 * wie viel da ist -- nicht, was fehlt, und schon gar nicht, was als
 * Naechstes dran ist. Bei einem frisch angelegten Modell las sie sich als
 * vier Nullen ohne einen einzigen Satz.
 *
 * Keine Akzentflaeche: die gehoert der Hauptaktion des jeweiligen Reiters.
 * Die Marke links ist `warn` als 2-px-Kante, nicht als Flaeche
 * (Designsystem 2: warn nie flaechig -- was fehlt, ist kein Fehlverhalten).
 */
export function NochZuTun({
  punkte,
  fertigText,
}: {
  punkte: OffenerPunkt[];
  /** Was dasteht, wenn nichts offen ist. Ohne Text bleibt die Karte weg --
      auf einer Liste mit vielen Objekten waere eine Fertig-Meldung je
      Objekt nur Rauschen. */
  fertigText?: string;
}) {
  if (punkte.length === 0) {
    return fertigText ? (
      <p className={styles.nochZuTunFertig}>{fertigText}</p>
    ) : null;
  }

  return (
    <section className={styles.nochZuTun} aria-labelledby="noch-zu-tun">
      <div className={styles.nochZuTunKopf}>
        <h2 className={styles.abschnittTitel} id="noch-zu-tun">
          Noch zu tun
        </h2>
        <span className={styles.abschnittNotiz}>
          {punkte.length === 1 ? "1 Punkt offen" : `${punkte.length} Punkte offen`}
        </span>
      </div>
      <ul className={styles.zeilen} aria-label="Noch zu tun">
        {punkte.map((punkt) => (
          <li key={punkt.href + punkt.titel} className={styles.zeile}>
            <div className={styles.zeileHaupt}>
              <div className={styles.zeileTitel}>
                {/* Der Punkt sagt, ob es aufhaelt: warn haelt auf, faint
                    nicht. Als Zeichen IN der Zeile und nicht als Streifen
                    daneben -- die Zeile schiebt Titel und Aktion
                    auseinander (justify-content: space-between), ein
                    eigenes Flex-Kind landete dort als einsamer Strich am
                    linken Rand. */}
                <span
                  className={
                    punkt.art === "blockiert"
                      ? styles.nochZuTunMarke
                      : styles.nochZuTunMarkeSanft
                  }
                  aria-hidden="true"
                />
                {punkt.titel}
              </div>
              <div className={styles.zeileMeta}>{punkt.grund}</div>
            </div>
            <div className={styles.zeileAktionen}>
              <Link href={punkt.href} className={portalStyles.secondary}>
                {punkt.label}
              </Link>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
