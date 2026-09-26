"use client";

import { useEffect, useId, useState, useTransition } from "react";
import { einladungErstellen } from "../../../actions";
import { einladungsPfad } from "../../../../einladung/weiter";
import styles from "../../../portal.module.css";

/**
 * "Mitarbeiter einladen" (Testnotiz 25.09., #6 -- Moeglichkeit 2).
 *
 * Ein Druck erzeugt einen Link fuer eine Person, sieben Tage gueltig. Er
 * steht danach genau einmal da: gespeichert ist nur der Hash des Tokens
 * (0045), wer die Seite verlaesst, bekommt ihn nicht wieder -- dann eben
 * einen neuen erzeugen und den alten zurueckziehen.
 *
 * Kopieren ueber die Zwischenablage; "Teilen" nur, wo es navigator.share
 * gibt (Safari auf dem iPhone: das Teilen-Blatt mit Nachrichten und
 * WhatsApp). Ob es das gibt, entscheidet erst der Browser nach dem
 * Laden -- sonst zeichnete der Server einen Knopf, den der Client
 * wieder wegnimmt.
 */
export function EinladungErstellen({ studioId, pfad }: { studioId: string; pfad: string }) {
  const [link, setLink] = useState<string | null>(null);
  const [fehler, setFehler] = useState<string | null>(null);
  const [kopiert, setKopiert] = useState(false);
  const [teilenMoeglich, setTeilenMoeglich] = useState(false);
  const [laeuft, starte] = useTransition();
  const feldId = useId();

  useEffect(() => {
    setTeilenMoeglich(typeof navigator.share === "function");
  }, []);

  return (
    <div>
      {fehler ? (
        <p className={styles.error} role="alert">
          {fehler}
        </p>
      ) : null}

      {link ? (
        <div className={styles.field}>
          <label className={styles.label} htmlFor={feldId}>
            Einladungslink
          </label>
          <input
            id={feldId}
            className={styles.input}
            value={link}
            readOnly
            onFocus={(ereignis) => ereignis.currentTarget.select()}
          />
          <span className={styles.hint}>
            Gilt 7 Tage für eine Person. Der Link wird nur jetzt angezeigt — schick ihn ab,
            bevor du die Seite verlässt.
          </span>
          <div className={styles.rowActions}>
            <button
              type="button"
              className={styles.secondary}
              onClick={async () => {
                await navigator.clipboard.writeText(link);
                setKopiert(true);
              }}
            >
              {kopiert ? "Kopiert ✓" : "Link kopieren"}
            </button>
            {teilenMoeglich ? (
              <button
                type="button"
                className={styles.secondary}
                onClick={() => {
                  // Abbrechen im Teilen-Blatt wirft AbortError -- kein Fehler.
                  navigator.share({ title: "Einladung zu gymodo", url: link }).catch(() => {});
                }}
              >
                Teilen
              </button>
            ) : null}
          </div>
        </div>
      ) : null}

      <div className={styles.actions}>
        <button
          type="button"
          className={styles.primary}
          disabled={laeuft}
          onClick={() => {
            setFehler(null);
            starte(async () => {
              const antwort = await einladungErstellen(studioId, pfad);
              if (antwort.ok) {
                setLink(`${window.location.origin}${einladungsPfad(antwort.token)}`);
                setKopiert(false);
              } else {
                setLink(null);
                setFehler(antwort.error);
              }
            });
          }}
        >
          {laeuft
            ? "Wird erstellt …"
            : link
              ? "Weiteren Link erstellen"
              : "Einladungslink erstellen"}
        </button>
      </div>
    </div>
  );
}
