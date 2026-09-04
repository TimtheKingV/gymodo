import styles from "./bausteine.module.css";

/**
 * Der Satz ueber die Produktgrenze von gymodo ("gymodo misst nichts ...") --
 * Befund 19: er stand an drei Stellen (Ueberblick, Wurzelseite, /t/<token>)
 * und ueberall in text-faint, einem Kontrast, den Designsystem 2 fuer
 * Pflichttext ausdruecklich verbietet. Dieser Baustein traegt Kontrast
 * (text-muted) und Abstand an einer Stelle.
 *
 * Der Wortlaut selbst kommt als `children`, nicht von hier: er ist je Ort
 * verschieden (der Ueberblick sagt einen kurzen Satz, die Landeseite die
 * lange Fassung aus Start.dc.html) -- der Baustein erfindet keinen
 * gemeinsamen Text, den kein Artboard zeigt.
 */
export function Produktgrenze({ children }: { children: React.ReactNode }) {
  return <p className={styles.produktgrenze}>{children}</p>;
}
