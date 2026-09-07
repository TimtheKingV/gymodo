"use client";

import { useEffect, useRef, useState } from "react";
import { usePathname } from "next/navigation";
import { NavInhalt } from "./NavInhalt";
import type { RailZahlen } from "./catalog";
import styles from "../portal.module.css";

/**
 * Das Hamburger-Menu -- ersetzt die seitlich scrollende Pillenreihe, die es
 * vorher unter 900 px gab (Befund 45 in
 * docs/superpowers/specs/2026-09-03-portal-frontend-design.md). Einheitlich
 * fuer Schreibtisch (hier, ueber Rail.tsx) und Halle (einrichten/layout.tsx):
 * dieselbe Schublade, dieselben sechs Bereiche.
 *
 * Die Schublade ist ein natives <dialog>-Element, nicht ein selbst gebautes
 * Overlay: showModal()/close() liefern Escape-zum-Schliessen, ::backdrop und
 * Top-Layer-Stacking ohne eigenes Fokus-Management. Im Repo gab es dafuer
 * noch kein Vorbild (kein Escape-/backdrop-/role=dialog-Treffer irgendwo
 * sonst) -- dies ist der erste.
 *
 * NavInhalt steht nur GERENDERT, waehrend die Schublade offen ist (offen-
 * State, nicht nur CSS): ein geschlossenes <dialog> ist zwar unsichtbar,
 * aber sein Inhalt bliebe im DOM stehen -- neben dem der festen Rail. Zwei
 * Kopien derselben E-Mail-Adresse/Nav-Punkte im selben Dokument sind fuer
 * textbasierte Abfragen (Tests, Screenreader-Suche) nicht unterscheidbar,
 * auch wenn nur eine sichtbar ist.
 */
export function MobileNav({
  studioId,
  studioName,
  email,
  zahlen,
  extra,
  nurMobil = true,
}: {
  studioId: string;
  studioName: string;
  email: string;
  zahlen: RailZahlen;
  /** Zusaetzlicher Inhalt am rechten Rand der Kopfleiste -- in der Halle
      die Uploads-Marke, sonst leer. */
  extra?: React.ReactNode;
  /** Ab 900 px ausblenden, weil die feste Rail uebernimmt -- Rail.tsx.
      false in der Halle (einrichten/layout.tsx): dort gibt es keine
      Desktop-Ansicht, die die Kopfleiste ersetzen koennte. */
  nurMobil?: boolean;
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const pfad = usePathname();
  const [offen, setOffen] = useState(false);

  // Ein Klick auf einen Link in der Schublade navigiert, schliesst sie aber
  // nicht von selbst -- <dialog> kennt keine "Route hat sich geaendert".
  useEffect(() => {
    dialogRef.current?.close();
  }, [pfad]);

  return (
    <div
      className={
        nurMobil
          ? `${styles.mobileTopbar} ${styles.mobileTopbarNurMobil}`
          : styles.mobileTopbar
      }
    >
      <button
        type="button"
        className={styles.hamburgerKnopf}
        aria-label="Menü öffnen"
        onClick={() => {
          dialogRef.current?.showModal();
          setOffen(true);
        }}
      >
        <svg
          width="22"
          height="22"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="2"
          strokeLinecap="round"
          strokeLinejoin="round"
        >
          <path d="M4 6h16" />
          <path d="M4 12h16" />
          <path d="M4 18h16" />
        </svg>
      </button>
      <div className={styles.mobileStudioName}>{studioName}</div>
      {extra}

      <dialog
        ref={dialogRef}
        className={styles.drawer}
        aria-label="Navigation"
        onClose={() => setOffen(false)}
        onClick={(event) => {
          // Klick auf den abgedunkelten Rest (das <dialog>-Element selbst,
          // nicht die Schublade darin) schliesst -- derselbe Griff wie
          // "Klick ausserhalb des Panels" in jedem anderen Overlay.
          if (event.target === dialogRef.current) dialogRef.current?.close();
        }}
      >
        <div className={styles.drawerPanel}>
          <div className={styles.drawerKopf}>
            <button
              type="button"
              className={styles.drawerSchliessen}
              aria-label="Menü schließen"
              onClick={() => dialogRef.current?.close()}
            >
              <svg
                width="20"
                height="20"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                strokeWidth="2"
                strokeLinecap="round"
                strokeLinejoin="round"
              >
                <path d="M6 6l12 12" />
                <path d="M18 6L6 18" />
              </svg>
            </button>
          </div>
          {offen ? (
            <NavInhalt
              studioId={studioId}
              studioName={studioName}
              email={email}
              zahlen={zahlen}
            />
          ) : null}
        </div>
      </dialog>
    </div>
  );
}
