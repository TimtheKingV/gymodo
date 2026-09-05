"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { abmelden } from "../actions";
import type { RailZahlen } from "./catalog";
import styles from "../portal.module.css";

/**
 * Die feste Navigation des Portals -- sechs Bereiche in drei Gruppen, nicht
 * mehr je ein Eintrag pro Geraetemodell (Struktur-Spec Abschnitt 1: bei
 * fuenfzig Geraeten waere die alte Liste unbrauchbar geworden). Objekte
 * leben jetzt auf ihren Listenseiten (/modelle, /geraete, /tags); die Rail
 * zeigt nur noch Zahlen, die den Blick lenken.
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
  const pfad = usePathname();
  const basis = `/portal/${studioId}`;

  const klasse = (aktiv: boolean) =>
    aktiv ? `${styles.navItem} ${styles.navItemActive}` : styles.navItem;

  return (
    <nav className={styles.rail} aria-label="Katalog">
      <div className={styles.studio}>
        <div className={styles.studioName}>{studioName}</div>
        <div className={styles.studioMeta}>Trainerportal</div>
      </div>

      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Studio</h2>
        <Link
          href={basis}
          className={klasse(pfad === basis)}
          aria-current={pfad === basis ? "page" : undefined}
        >
          <span className={styles.navItemTitle}>Überblick</span>
        </Link>
        <Link
          href={`${basis}/kurse`}
          className={klasse(pfad.startsWith(`${basis}/kurse`))}
          aria-current={pfad.startsWith(`${basis}/kurse`) ? "page" : undefined}
        >
          <span className={styles.navItemTitle}>Kurse</span>
        </Link>
      </div>

      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Katalog</h2>
        <Link
          href={`${basis}/geraete`}
          className={klasse(pfad === `${basis}/geraete`)}
          aria-current={pfad === `${basis}/geraete` ? "page" : undefined}
        >
          <span className={styles.navItemTitle}>Geräte</span>
          <span className={styles.navItemMeta}>
            {zahlen.geraete === 0 ? "Noch kein Gerät" : `${zahlen.geraete} · ${zahlen.erreichbar} erreichbar`}
          </span>
        </Link>
        <Link
          href={`${basis}/tags`}
          className={klasse(pfad === `${basis}/tags`)}
          aria-current={pfad === `${basis}/tags` ? "page" : undefined}
        >
          <span className={styles.navItemTitle}>Tags</span>
          <span className={styles.navItemMeta}>
            {zahlen.vorrat === 0 ? "Keine vorrätig" : `${zahlen.vorrat} vorrätig`}
          </span>
        </Link>
      </div>

      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Verwaltung</h2>
        {/* startsWith, nicht Gleichheit: Leute traegt seit Aufgabe 19 zwei
            Reiter auf zwei Routen (/leute und /leute/mitarbeiter). Mit
            Gleichheit verloere die Rail auf dem zweiten Reiter ihre
            Markierung -- so wie Kurse und Einstellungen es aus demselben
            Grund schon halten. */}
        <Link
          href={`${basis}/leute`}
          className={klasse(pfad.startsWith(`${basis}/leute`))}
          aria-current={pfad.startsWith(`${basis}/leute`) ? "page" : undefined}
        >
          <span className={styles.navItemTitle}>Leute</span>
          {zahlen.mitglieder === null || zahlen.mitarbeiter === null ? null : (
            <span className={styles.navItemMeta}>
              {zahlen.mitglieder} Mitglieder · {zahlen.mitarbeiter} Mitarbeiter
            </span>
          )}
        </Link>
        <Link
          href={`${basis}/einstellungen`}
          className={klasse(pfad.startsWith(`${basis}/einstellungen`))}
          aria-current={pfad.startsWith(`${basis}/einstellungen`) ? "page" : undefined}
        >
          <span className={styles.navItemTitle}>Einstellungen</span>
        </Link>
      </div>

      <div className={styles.railFooter}>
        <div className={styles.railEmail}>{email}</div>
        <form action={abmelden}>
          <button type="submit" className={styles.railAbmelden}>
            Abmelden
          </button>
        </form>
      </div>
    </nav>
  );
}
