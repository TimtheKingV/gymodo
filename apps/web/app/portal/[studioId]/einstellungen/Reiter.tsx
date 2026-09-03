"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import styles from "../../portal.module.css";

/**
 * Zwei Routen, kein Umschalter im selben Dokument: ein Reiter je Bildschirm
 * bedeutet ein Formular je Bildschirm (Spec Abschnitt 1), und damit haelt
 * die Regel des Designsystems, dass es genau eine Akzentflaeche gibt.
 */
export function Reiter({ studioId }: { studioId: string }) {
  const pfad = usePathname();
  const basis = `/portal/${studioId}/einstellungen`;

  const klasse = (aktiv: boolean) =>
    aktiv ? `${styles.tab} ${styles.tabActive}` : styles.tab;

  return (
    <nav className={styles.tabs} aria-label="Einstellungen">
      <Link href={basis} className={klasse(pfad === basis)}>
        Studio
      </Link>
      <Link href={`${basis}/konto`} className={klasse(pfad === `${basis}/konto`)}>
        Konto
      </Link>
    </nav>
  );
}
