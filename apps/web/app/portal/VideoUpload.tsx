"use client";

import { useEffect, useState } from "react";
// Der Unterpfad statt des Barrels: index.ts zieht ueber tags.ts das
// node:crypto-Modul mit, und das laesst sich nicht in einen Browserbundle
// packen. media.ts haengt nur an errors.ts und ist frei davon.
import { MAX_VIDEO_SECONDS } from "@fitretro/domain/media";
import { videoBestaetigen } from "./actions";
import { DateiKnopf } from "./bausteine/DateiKnopf";
import { MedienVorschau } from "./bausteine/MedienVorschau";
import { ladeVideoHoch } from "./bausteine/videoUpload";
import styles from "./portal.module.css";

/**
 * Der einzige Pfad des Portals, der auf dem Telefon tragen muss: die
 * Aufnahme entsteht auf dem Trainerhandy und wird aus mobilem Safari
 * hochgeladen (Spec 6.8). Deshalb capture am Dateifeld und eine
 * Fortschrittsanzeige, die auch bei schlechtem Studio-WLAN etwas sagt.
 *
 * Der Upload laeuft ueber TUS direkt gegen den Storage-Dienst
 * (ladeVideoHoch() in bausteine/videoUpload.ts). Bricht die Verbindung ab,
 * setzt der naechste Versuch am letzten bestaetigten Offset fort, statt
 * 25 MiB noch einmal zu senden.
 *
 * Die Vorschau zeigt die gerade gewaehlte Datei sofort per Objekt-URL, noch
 * waehrend sie hochlaedt -- Trainer-Wunsch: "wenn Bild oder Video drin ist
 * dann das oben als Mini-Vorschau anzeigen".
 */
export function VideoUpload({
  studioId,
  modelId,
  linkId,
  hatVideo,
}: {
  studioId: string;
  modelId: string;
  linkId: string;
  hatVideo: boolean;
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [fortschritt, setFortschritt] = useState<number | null>(null);
  const [pruefung, setPruefung] = useState(false);
  const [objektUrl, setObjektUrl] = useState<string | null>(null);

  useEffect(() => {
    return () => {
      if (objektUrl) URL.revokeObjectURL(objektUrl);
    };
  }, [objektUrl]);

  async function starte(datei: File) {
    setFehler(null);
    setObjektUrl((bisherige) => {
      if (bisherige) URL.revokeObjectURL(bisherige);
      return URL.createObjectURL(datei);
    });

    setFortschritt(0);
    const ergebnis = await ladeVideoHoch({ linkId, datei, onFortschritt: setFortschritt });
    if (!ergebnis.ok) {
      setFortschritt(null);
      setFehler(ergebnis.error);
      return;
    }

    // Erst jetzt sieht der Server die Bytes: Format und Laufzeit werden am
    // Inhalt geprueft, nicht an dem, was der Browser behauptet.
    setFortschritt(1);
    setPruefung(true);
    const bestaetigt = await videoBestaetigen(studioId, modelId, linkId, ergebnis.storagePath);
    setPruefung(false);
    setFortschritt(null);
    if (!bestaetigt.ok) setFehler(bestaetigt.error);
  }

  const laeuft = fortschritt !== null;

  return (
    <div className={styles.field}>
      <div className={styles.mediaRow}>
        <MedienVorschau url={objektUrl} art="video" leerText="Kein Video" mini />
        <div style={{ display: "flex", flexDirection: "column", gap: 8 }}>
          <DateiKnopf
            label={hatVideo ? "Video ersetzen" : "Einweisungsvideo"}
            accept="video/mp4,video/quicktime"
            capture="environment"
            disabled={laeuft}
            onDatei={(datei) => {
              if (datei) void starte(datei);
            }}
          />
          <span className={styles.hint}>
            Höchstens {MAX_VIDEO_SECONDS} Sekunden. Länger nimmt der Upload nicht
            an — die Länge wird an der Datei geprüft, nicht geschätzt.
          </span>
        </div>
      </div>

      {laeuft ? (
        <>
          <div
            className={styles.progressTrack}
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={Math.round(fortschritt * 100)}
            aria-label="Upload-Fortschritt"
          >
            <div
              className={styles.progressBar}
              style={{ width: `${Math.round(fortschritt * 100)}%` }}
            />
          </div>
          <span className={styles.hint} aria-live="polite">
            {pruefung
              ? "Wird geprüft …"
              : `${Math.round(fortschritt * 100)} % übertragen`}
          </span>
        </>
      ) : null}

      {fehler ? (
        <p className={styles.error} role="alert">
          {fehler}
        </p>
      ) : null}
    </div>
  );
}
