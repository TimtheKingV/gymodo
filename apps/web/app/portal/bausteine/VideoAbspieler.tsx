"use client";

import { useRef } from "react";
import styles from "./Medien.module.css";

/**
 * Ein gespeichertes (oder gerade gewaehltes) Einweisungsvideo, das man
 * ansehen kann (Testnotiz 23.09., #6). Vorher war die Vorschau 96 px breit,
 * und abgespielt wurde darin -- auf dem Telefon eine Briefmarke mit
 * Bedienleiste. Jetzt steht das Standbild in voller Breite (oder als
 * Kachel in der Zeile), und ein Tipp oeffnet den Player im Vollbild.
 *
 * Der Player steht immer im DOM und wird im Klick selbst gestartet, nicht
 * per autoPlay nach einem Render: iOS laesst Ton nur zu, wenn play() in der
 * Geste des Nutzers faellt. Ohne playsInline geht iOS-Safari damit in
 * seinen eigenen Vollbild-Player; am Rechner fuellt der Dialog den
 * Bildschirm.
 *
 * `#t=0.001` am Standbild: iOS zeichnet mit preload="metadata" sonst kein
 * erstes Bild, nur eine schwarze Flaeche.
 */
export function VideoAbspieler({
  url,
  titel,
  groesse = "voll",
}: {
  url: string;
  /** Wofuer das Video ist -- steht im Namen des Knopfs. */
  titel: string;
  groesse?: "voll" | "zeile";
}) {
  const dialogRef = useRef<HTMLDialogElement>(null);
  const playerRef = useRef<HTMLVideoElement>(null);

  function oeffnen() {
    dialogRef.current?.showModal();
    const player = playerRef.current;
    if (player) {
      player.currentTime = 0;
      void player.play().catch(() => {
        // Verweigert der Browser das Abspielen, bleibt die Bedienleiste --
        // ein Tipp auf Play startet es dann von Hand.
      });
    }
  }

  return (
    <>
      <button
        type="button"
        className={groesse === "voll" ? styles.abspielenVoll : styles.abspielenZeile}
        aria-label={`Video ${titel} abspielen`}
        onClick={oeffnen}
      >
        <video
          className={styles.abspielenStandbild}
          src={`${url}#t=0.001`}
          muted
          playsInline
          preload="metadata"
          tabIndex={-1}
          aria-hidden="true"
        />
        <span className={styles.abspielenSymbol} aria-hidden="true">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="currentColor">
            <path d="M8 5.5v13a1 1 0 0 0 1.5.86l10.5-6.5a1 1 0 0 0 0-1.72L9.5 4.64A1 1 0 0 0 8 5.5Z" />
          </svg>
        </span>
      </button>

      <dialog
        ref={dialogRef}
        className={styles.player}
        aria-label={`Video ${titel}`}
        onClose={() => playerRef.current?.pause()}
        onClick={(event) => {
          // Klick auf den schwarzen Rand um das Video schliesst.
          if (event.target === dialogRef.current) dialogRef.current?.close();
        }}
      >
        <button
          type="button"
          className={styles.playerSchliessen}
          aria-label="Video schließen"
          onClick={() => dialogRef.current?.close()}
        >
          <svg
            width="22"
            height="22"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            strokeWidth="2"
            strokeLinecap="round"
            aria-hidden="true"
          >
            <path d="M6 6l12 12" />
            <path d="M18 6L6 18" />
          </svg>
        </button>
        <video
          ref={playerRef}
          className={styles.playerVideo}
          src={url}
          controls
          preload="none"
        />
      </dialog>
    </>
  );
}
