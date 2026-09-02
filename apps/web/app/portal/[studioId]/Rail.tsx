"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import styles from "../portal.module.css";

type ModelEintrag = {
  id: string;
  name: string;
  geraete: number;
  erreichbar: number;
};

/**
 * Die Rail nennt je Modell, wie viele seiner Geraete fuer Mitglieder
 * erreichbar sind -- erreichbar heisst: ein aktiver Tag klebt daran.
 *
 * Bewusst kein Vollstaendigkeitsgrad und keine Fortschrittsanzeige. Foto,
 * Video und Einstellparameter machen ein Geraet besser, aber ein Geraet ohne
 * sie ist vollstaendig nutzbar (Spec 6.8). Ein Balken, der auf 100 % zeigt,
 * waere eine Aufforderung, die das Produkt nicht stellt. Der aktive Tag ist
 * die einzige Bedingung, ohne die ein Mitglied das Geraet nicht findet --
 * und deshalb die einzige Zahl, die hier steht.
 */
export function Rail({
  studioId,
  studioName,
  models,
  offeneTags,
}: {
  studioId: string;
  studioName: string;
  models: ModelEintrag[];
  offeneTags: number;
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
        <Link href={basis} className={klasse(pfad === basis)}>
          <span className={styles.navItemTitle}>Überblick</span>
        </Link>
      </div>

      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Gerätemodelle</h2>
        {models.length === 0 ? (
          <p className={`${styles.navItem} ${styles.absent}`}>Noch keines angelegt</p>
        ) : (
          models.map((modell) => (
            <Link
              key={modell.id}
              href={`${basis}/modelle/${modell.id}`}
              className={klasse(pfad === `${basis}/modelle/${modell.id}`)}
            >
              <span className={styles.navItemTitle}>{modell.name}</span>
              <span className={styles.navItemMeta}>
                {modell.geraete === 0
                  ? "Noch kein Gerät"
                  : `${modell.geraete} ${modell.geraete === 1 ? "Gerät" : "Geräte"} · ${modell.erreichbar} erreichbar`}
              </span>
            </Link>
          ))
        )}
        <Link href={`${basis}/modelle`} className={klasse(pfad === `${basis}/modelle`)}>
          <span className={styles.navItemTitle}>Modell anlegen</span>
        </Link>
      </div>

      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Übersicht</h2>
        <Link href={`${basis}/geraete`} className={klasse(pfad === `${basis}/geraete`)}>
          <span className={styles.navItemTitle}>Geräte</span>
        </Link>
        <Link href={`${basis}/tags`} className={klasse(pfad === `${basis}/tags`)}>
          <span className={styles.navItemTitle}>Tags</span>
          <span className={styles.navItemMeta}>
            {offeneTags === 0 ? "Keine vorrätig" : `${offeneTags} vorrätig`}
          </span>
        </Link>
      </div>

      <div className={styles.group}>
        <h2 className={styles.groupLabel}>Verwaltung</h2>
        <Link href={`${basis}/leute`} className={klasse(pfad === `${basis}/leute`)}>
          <span className={styles.navItemTitle}>Leute</span>
        </Link>
        <Link
          href={`${basis}/einstellungen`}
          className={klasse(pfad.startsWith(`${basis}/einstellungen`))}
        >
          <span className={styles.navItemTitle}>Einstellungen</span>
        </Link>
      </div>
    </nav>
  );
}
