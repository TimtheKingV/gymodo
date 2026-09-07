import Link from "next/link";
import styles from "./bausteine.module.css";

/**
 * Reiterleiste. Links auf eigene Routen, kein Umschalter im selben
 * Dokument (Struktur-Spec Abschnitt 1): ein Reiter je Bildschirm heisst ein
 * Formular je Bildschirm, und erst dadurch gibt es genau eine
 * Akzentflaeche. Die alte Modellseite zeigte fuenf gleichzeitig.
 *
 * `name` benennt die Leiste fuer Screenreader -- eine Seite kann zwei
 * Navigationen tragen (Rail und Reiter), und "Navigation" zweimal ist
 * keine Auskunft.
 *
 * `zusatz` traegt den Zustand in der Beschriftung ("2 · 1 mit Video"), als
 * Block unter dem Label -- Geschwister, wie in Rail.tsx `.navItemTitle`
 * und `.navItemMeta` schon nebeneinanderstehen, nicht als Text in einer
 * Zeile mit dem Label.
 *
 * Server-Komponente: `aktiv` kommt als Eigenschaft von aussen, weil die
 * Seite ihre eigene Route schon kennt. Die alte Fassung unter
 * einstellungen/Reiter.tsx ist "use client" und ermittelt den aktiven
 * Reiter per usePathname im Browser -- hier reicht das Serverwissen.
 */
export function Reiter({
  name,
  eintraege,
}: {
  name: string;
  eintraege: { href: string; label: string; zusatz?: string; aktiv: boolean }[];
}) {
  return (
    <nav className={styles.reiter} aria-label={name}>
      {eintraege.map((eintrag) => (
        <Link
          key={eintrag.href}
          href={eintrag.href}
          className={eintrag.aktiv ? `${styles.reiterEintrag} ${styles.reiterAktiv}` : styles.reiterEintrag}
          aria-current={eintrag.aktiv ? "page" : undefined}
        >
          <span className={styles.reiterLabel}>{eintrag.label}</span>
          {eintrag.zusatz ? <span className={styles.reiterZusatz}>{eintrag.zusatz}</span> : null}
        </Link>
      ))}
    </nav>
  );
}
