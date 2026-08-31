"use client";

import { useState, useTransition } from "react";
import { tagAnlegen } from "../actions";
import styles from "../portal.module.css";

/**
 * Der Token steht genau einmal auf dem Bildschirm.
 *
 * Gespeichert ist nur sein Hash -- es gibt keinen Weg, ihn spaeter noch
 * einmal anzuzeigen, und das ist Absicht: waere er abrufbar, koennte
 * jeder mit Lesezugriff auf die Datenbank jeden Tag klonen. Wer ihn
 * verliert, legt einen neuen Tag an und sperrt den alten.
 */
export function TagAnlegen({
  studioId,
  pfad,
  machineId,
}: {
  studioId: string;
  pfad: string;
  machineId: string | null;
}) {
  const [token, setToken] = useState<string | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [kopiert, setKopiert] = useState(false);
  const [laeuft, starte] = useTransition();

  if (token) {
    return (
      <div className={styles.field}>
        <span className={styles.label}>Token — nur jetzt sichtbar</span>
        <code className={styles.token} data-testid="tag-token">
          {token}
        </code>
        <span className={styles.hint}>
          Schreib ihn auf den NFC-Tag oder den QR-Code. Danach ist er nicht
          mehr abrufbar — gespeichert ist nur seine Prüfsumme.
        </span>
        <div className={styles.actions}>
          <button
            type="button"
            className={styles.secondary}
            onClick={() => {
              void navigator.clipboard
                ?.writeText(token)
                .then(() => setKopiert(true))
                .catch(() => setKopiert(false));
            }}
          >
            {kopiert ? "Kopiert" : "Kopieren"}
          </button>
          <button
            type="button"
            className={styles.secondary}
            onClick={() => {
              setToken(null);
              setKopiert(false);
            }}
          >
            Fertig
          </button>
        </div>
      </div>
    );
  }

  return (
    <span className={styles.rowActions}>
      {fehler ? (
        <span className={styles.error} role="alert">
          {fehler}
        </span>
      ) : null}
      <button
        type="button"
        className={styles.secondary}
        disabled={laeuft}
        onClick={() => {
          setFehler(null);
          starte(async () => {
            const antwort = await tagAnlegen(studioId, pfad, machineId);
            if (antwort.ok) setToken(antwort.token);
            else setFehler(antwort.error);
          });
        }}
      >
        {laeuft ? "Wird angelegt …" : machineId ? "Tag anlegen" : "Tag auf Vorrat"}
      </button>
    </span>
  );
}
