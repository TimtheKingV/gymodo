import styles from "./einstieg.module.css";

/**
 * Die Huelle der sechs Einstiegsbildschirme: Wortmarke, zentrierte Karte,
 * 28 px Seitenrand.
 *
 * Getrennt von portal.module.css aus demselben Grund, aus dem
 * halle.module.css getrennt entstand: hier gibt es keine Rail, keinen
 * 1000-px-Inhaltsstrom und einen anderen Seitenrand. In portal.module.css
 * gequetscht braeuchte jede Regel eine Ausnahme, und die Ausnahmen waeren
 * die Mehrheit.
 *
 * Rendert das <main> selbst -- anders als die Bausteine des Schreibtischs,
 * denn hier gibt es kein Layout, das es tut.
 *
 * Fix-Runde 1: die Wortmarke stand zuerst in der Karte, ueber dem Titel --
 * das Artboard traegt sie in einem eigenen Kopf ausserhalb der zentrierten
 * Karte, oben links am Seitenrand. <header> ist deshalb Geschwister von
 * <main>, nicht sein Kind: "genau ein <main>" bleibt so erhalten, und die
 * Marke sitzt wie im Artboard.
 */
export function Einstieg({
  titel,
  vorspann,
  children,
  fuss,
}: {
  titel: string;
  vorspann?: React.ReactNode;
  children: React.ReactNode;
  fuss?: React.ReactNode;
}) {
  return (
    <div className={styles.bildschirm}>
      <header className={styles.kopf}>
        <span className={styles.marke}>gymodo</span>
      </header>
      <main className={styles.seite}>
        <div className={styles.karte}>
          <h1 className={styles.titel}>{titel}</h1>
          {vorspann ? <p className={styles.vorspann}>{vorspann}</p> : null}
          {children}
          {fuss ? <div className={styles.fuss}>{fuss}</div> : null}
        </div>
      </main>
    </div>
  );
}
