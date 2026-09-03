import styles from "./bausteine.module.css";

export type ZustandArt = "leer" | "fehler" | "keinRecht" | "deaktiviert";

/**
 * Die vier Zustaende des Portals an einer Stelle.
 *
 * Designsystem Abschnitt 5 und trainerportal-struktur-design.md Abschnitt 5
 * geben die Regeln vor; sie stehen hier, weil ein Baustein sie tragen kann
 * und vier Kopien nicht -- so viele Kein-Recht-Bloecke standen vorher
 * wortgleich im Code (portal/page.tsx, (schreibtisch)/page.tsx, leute,
 * einstellungen):
 *
 *   leer          Ueberschrift plus naechster Schritt. NIE eine leere
 *                 Statistik mit Nullen -- vier Kacheln, die viermal 0
 *                 zeigen, sagen ueber ein neues Studio nichts.
 *   fehler        Sagt, was falsch ist UND was gilt ("Das Gewicht liegt
 *                 ueber dem Geraetemaximum von 100,0 kg"), nie nur
 *                 "ungueltig". danger-Umriss bei vollem Kontrast -- KEINE
 *                 getoente Flaeche: die 10-%-Flaeche gehoert zu Offline,
 *                 und Offline gilt im Portal nicht.
 *   deaktiviert   NIE stumm -- daneben steht, was fehlt.
 *   keinRecht     Ein einfaches Mitglied sieht einen Satz, keinen Absturz.
 *                 Kein neuer Zustand, sondern die benannte Fassung von
 *                 etwas, das vorher vier Mal ad hoc im Code stand.
 *
 * "Offline" gilt im Portal nicht -- ein Konzept der Halle, nicht des
 * Schreibtischs. "Skelett" gilt nur fuer Medien und ist deshalb kein
 * Zustand hier, sondern eine Flaeche in der Medienzeile.
 *
 * Nur `fehler` traegt role="alert": ein leeres Studio ist kein Fehler, und
 * ein Screenreader, der jede leere Liste als Warnung ansagt, wird
 * abgeschaltet.
 */
export function Zustand({
  art,
  titel,
  naechsterSchritt,
  aktion,
}: {
  art: ZustandArt;
  titel: string;
  naechsterSchritt?: React.ReactNode;
  aktion?: React.ReactNode;
}) {
  return (
    <div
      className={`${styles.zustand} ${styles[art]}`}
      role={art === "fehler" ? "alert" : undefined}
    >
      {art === "deaktiviert" ? (
        // "Zuweisen" ist hier keine Ueberschrift, sondern eine deaktivierte
        // Pille -- der Grund steht daneben in derselben Zeile, nicht darunter
        // (Artboard).
        <div className={styles.zustandDeaktiviert}>
          <button type="button" className={styles.zustandPille} disabled>
            {titel}
          </button>
          {naechsterSchritt ? (
            <span className={styles.zustandSchritt}>{naechsterSchritt}</span>
          ) : null}
        </div>
      ) : (
        <>
          <p className={styles.zustandTitel}>{titel}</p>
          {naechsterSchritt ? (
            <p className={styles.zustandSchritt}>{naechsterSchritt}</p>
          ) : null}
        </>
      )}
      {aktion ? <div className={styles.zustandAktion}>{aktion}</div> : null}
    </div>
  );
}
