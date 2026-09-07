import type { RailZahlen } from "./catalog";
import { NavInhalt } from "./NavInhalt";
import { MobileNav } from "./MobileNav";
import styles from "../portal.module.css";

/**
 * Die feste Navigation des Portals -- sechs Bereiche in drei Gruppen, nicht
 * mehr je ein Eintrag pro Geraetemodell (Struktur-Spec Abschnitt 1: bei
 * fuenfzig Geraeten waere die alte Liste unbrauchbar geworden). Objekte
 * leben jetzt auf ihren Listenseiten (/modelle, /geraete, /tags); die Rail
 * zeigt nur noch Zahlen, die den Blick lenken.
 *
 * Ab 900 px eine feste Spalte (NavInhalt direkt); darunter das
 * Hamburger-Menu (MobileNav) -- beide zeigen dieselbe NavInhalt, nur die
 * CSS-Media-Query in portal.module.css entscheidet, welche Huelle sichtbar
 * ist.
 */
export function Rail({
  studioId,
  studioName,
  email,
  zahlen,
}: {
  studioId: string;
  studioName: string;
  email: string;
  zahlen: RailZahlen;
}) {
  return (
    <>
      <MobileNav
        studioId={studioId}
        studioName={studioName}
        email={email}
        zahlen={zahlen}
      />
      <nav className={styles.rail} aria-label="Katalog">
        <NavInhalt
          studioId={studioId}
          studioName={studioName}
          email={email}
          zahlen={zahlen}
        />
      </nav>
    </>
  );
}
