"use client";

import { useRef, useState } from "react";
import * as tus from "tus-js-client";
// Der Unterpfad statt des Barrels: index.ts zieht ueber tags.ts das
// node:crypto-Modul mit, und das laesst sich nicht in einen Browserbundle
// packen. media.ts haengt nur an errors.ts und ist frei davon.
import { MAX_VIDEO_BYTES, MAX_VIDEO_SECONDS } from "@fitretro/domain/media";
import { createBrowserSupabaseClient, storageUrl } from "@/lib/supabase/browser";
import { videoBestaetigen, videoUploadVorbereiten } from "./actions";
import styles from "./portal.module.css";

/**
 * Der einzige Pfad des Portals, der auf dem Telefon tragen muss: die
 * Aufnahme entsteht auf dem Trainerhandy und wird aus mobilem Safari
 * hochgeladen (Spec 6.8). Deshalb capture am Dateifeld und eine
 * Fortschrittsanzeige, die auch bei schlechtem Studio-WLAN etwas sagt.
 *
 * Der Upload laeuft ueber TUS direkt gegen den Storage-Dienst. Bricht die
 * Verbindung ab, setzt der naechste Versuch am letzten bestaetigten Offset
 * fort, statt 25 MiB noch einmal zu senden.
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
  const eingabe = useRef<HTMLInputElement>(null);

  async function starte(datei: File) {
    setFehler(null);

    if (datei.size > MAX_VIDEO_BYTES) {
      setFehler(
        `Die Datei ist ${(datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_VIDEO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
      );
      return;
    }

    const ziel = await videoUploadVorbereiten(linkId, datei.size);
    if (!ziel.ok) {
      setFehler(ziel.error);
      return;
    }

    const supabase = createBrowserSupabaseClient();
    const {
      data: { session },
    } = await supabase.auth.getSession();
    if (!session) {
      setFehler("Die Anmeldung ist abgelaufen. Bitte neu anmelden.");
      return;
    }

    setFortschritt(0);
    let abgebrochen = false;
    await new Promise<void>((fertig, gescheitert) => {
      const upload = new tus.Upload(datei, {
        endpoint: storageUrl(),
        headers: { authorization: `Bearer ${session.access_token}` },
        // Der Storage-Dienst verlangt genau diese Blockgroesse.
        chunkSize: 6 * 1024 * 1024,
        uploadDataDuringCreation: true,
        removeFingerprintOnSuccess: true,
        metadata: {
          bucketName: ziel.bucket,
          objectName: ziel.storagePath,
          contentType: datei.type || "video/mp4",
        },
        onProgress: (gesendet, gesamt) => {
          setFortschritt(gesamt > 0 ? gesendet / gesamt : 0);
        },
        onError: (ursache) => gescheitert(ursache),
        onSuccess: () => fertig(),
      });

      // Ein abgebrochener Upload derselben Datei wird fortgesetzt statt neu
      // begonnen -- genau dafuer ist TUS da.
      upload.findPreviousUploads().then((frueher) => {
        if (frueher.length > 0) upload.resumeFromPreviousUpload(frueher[0]!);
        upload.start();
      });
    }).catch((ursache: unknown) => {
      abgebrochen = true;
      setFortschritt(null);
      setFehler(
        ursache instanceof Error
          ? `Der Upload wurde unterbrochen: ${ursache.message}. Wähle dieselbe Datei noch einmal, er setzt fort.`
          : "Der Upload wurde unterbrochen. Wähle dieselbe Datei noch einmal, er setzt fort.",
      );
    });

    // Auf den Zustandswert zu schauen brächte hier nichts: setFehler wirkt
    // erst beim naechsten Rendern, nicht in diesem Durchlauf.
    if (abgebrochen) return;

    // Erst jetzt sieht der Server die Bytes: Format und Laufzeit werden am
    // Inhalt geprueft, nicht an dem, was der Browser behauptet.
    setFortschritt(1);
    setPruefung(true);
    const bestaetigt = await videoBestaetigen(
      studioId,
      modelId,
      linkId,
      ziel.storagePath,
    );
    setPruefung(false);
    setFortschritt(null);
    if (eingabe.current) eingabe.current.value = "";
    if (!bestaetigt.ok) setFehler(bestaetigt.error);
  }

  const laeuft = fortschritt !== null;

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={`video-${linkId}`}>
        {hatVideo ? "Video ersetzen" : "Einweisungsvideo"}
      </label>
      <input
        ref={eingabe}
        id={`video-${linkId}`}
        type="file"
        accept="video/mp4,video/quicktime"
        capture="environment"
        className={styles.input}
        disabled={laeuft}
        onChange={(ereignis) => {
          const datei = ereignis.target.files?.[0];
          if (datei) void starte(datei);
        }}
      />
      <span className={styles.hint}>
        Höchstens {MAX_VIDEO_SECONDS} Sekunden. Länger nimmt der Upload nicht
        an — die Länge wird an der Datei geprüft, nicht geschätzt.
      </span>

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
