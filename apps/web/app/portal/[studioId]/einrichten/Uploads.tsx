"use client";

import Link from "next/link";
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useRef,
  useState,
} from "react";
import * as tus from "tus-js-client";
// Der Unterpfad statt des Barrels: index.ts zieht ueber tags.ts das
// node:crypto-Modul mit, und das laesst sich nicht in einen Browserbundle
// packen. media.ts haengt nur an errors.ts und ist frei davon.
import { MAX_VIDEO_BYTES, MAX_VIDEO_SECONDS } from "@fitretro/domain/media";
import { createBrowserSupabaseClient, storageUrl } from "@/lib/supabase/browser";
import { videoBestaetigen, videoUploadVorbereiten } from "../../actions";
import styles from "./halle.module.css";

export type Auftrag = {
  id: string;
  titel: string;
  modelId: string;
  linkId: string;
  datei: File;
  stand: "wartet" | "laeuft" | "prueft" | "fertig" | "fehler";
  anteil: number;
  fehler?: string;
};

type Schlange = {
  auftraege: Auftrag[];
  offen: number;
  einreihen: (auftrag: {
    titel: string;
    modelId: string;
    linkId: string;
    datei: File;
  }) => void;
};

const Kontext = createContext<Schlange | null>(null);

export function useUploads(): Schlange {
  const wert = useContext(Kontext);
  if (!wert) throw new Error("useUploads ausserhalb des UploadsProvider");
  return wert;
}

/**
 * Die Warteschlange lebt im Layout des Gangs, nicht in der Uebungsseite:
 * der Trainer geht weiter, waehrend hochgeladen wird (TelefonUploads).
 *
 * Eins nach dem anderen. Vier gleichzeitige TUS-Uploads ueber Studio-WLAN
 * teilen sich dieselbe Bandbreite und werden alle vier langsam; nacheinander
 * ist der erste nach einer Minute durch.
 *
 * Sie ueberlebt einen Seitenwechsel INNERHALB des Gangs, weil Next das
 * Layout dabei nicht neu montiert. Ein Neuladen ueberlebt sie nicht -- die
 * File-Objekte leben im Speicher des Tabs. Das ist die Grenze, die der
 * Bildschirm auch benennt: "Lass diesen Bildschirm offen."
 */
export function UploadsProvider({
  studioId,
  children,
}: {
  studioId: string;
  children: React.ReactNode;
}) {
  const [auftraege, setAuftraege] = useState<Auftrag[]>([]);
  // Zustand statt Ref: das Zuruecksetzen muss ein Rendern ausloesen, sonst
  // laeuft der Effekt nicht noch einmal und der naechste Auftrag bliebe
  // liegen.
  const [aktiv, setAktiv] = useState<string | null>(null);
  const studioRef = useRef(studioId);
  studioRef.current = studioId;

  const einreihen = useCallback(
    (neu: { titel: string; modelId: string; linkId: string; datei: File }) => {
      setAuftraege((bisher) => [
        ...bisher,
        {
          id: crypto.randomUUID(),
          titel: neu.titel,
          modelId: neu.modelId,
          linkId: neu.linkId,
          datei: neu.datei,
          stand: "wartet",
          anteil: 0,
        },
      ]);
    },
    [],
  );

  useEffect(() => {
    if (aktiv !== null) return;
    const naechster = auftraege.find((auftrag) => auftrag.stand === "wartet");
    if (!naechster) return;

    setAktiv(naechster.id);
    void (async () => {
      try {
        await sende(naechster);
      } finally {
        setAktiv(null);
      }
    })();

    function setze(id: string, aenderung: Partial<Auftrag>) {
      setAuftraege((bisher) =>
        bisher.map((auftrag) =>
          auftrag.id === id ? { ...auftrag, ...aenderung } : auftrag,
        ),
      );
    }

    async function sende(auftrag: Auftrag) {
      setze(auftrag.id, { stand: "laeuft", anteil: 0 });

      if (auftrag.datei.size > MAX_VIDEO_BYTES) {
        setze(auftrag.id, {
          stand: "fehler",
          fehler: `Die Datei ist ${(auftrag.datei.size / 1024 / 1024).toFixed(0)} MiB groß. Mehr als ${MAX_VIDEO_BYTES / 1024 / 1024} MiB nimmt der Upload nicht an.`,
        });
        return;
      }

      const ziel = await videoUploadVorbereiten(
        auftrag.linkId,
        auftrag.datei.size,
      );
      if (!ziel.ok) {
        setze(auftrag.id, { stand: "fehler", fehler: ziel.error });
        return;
      }

      const supabase = createBrowserSupabaseClient();
      const {
        data: { session },
      } = await supabase.auth.getSession();
      if (!session) {
        setze(auftrag.id, {
          stand: "fehler",
          fehler: "Die Anmeldung ist abgelaufen. Bitte neu anmelden.",
        });
        return;
      }

      try {
        await new Promise<void>((fertig, gescheitert) => {
          const upload = new tus.Upload(auftrag.datei, {
            endpoint: storageUrl(),
            headers: { authorization: `Bearer ${session.access_token}` },
            // Der Storage-Dienst verlangt genau diese Blockgroesse.
            chunkSize: 6 * 1024 * 1024,
            uploadDataDuringCreation: true,
            removeFingerprintOnSuccess: true,
            metadata: {
              bucketName: ziel.bucket,
              objectName: ziel.storagePath,
              contentType: auftrag.datei.type || "video/mp4",
            },
            onProgress: (gesendet, gesamt) => {
              setze(auftrag.id, { anteil: gesamt > 0 ? gesendet / gesamt : 0 });
            },
            onError: (ursache) => gescheitert(ursache),
            onSuccess: () => fertig(),
          });
          // Ein abgebrochener Upload derselben Datei wird fortgesetzt statt
          // neu begonnen -- genau dafuer ist TUS da.
          upload.findPreviousUploads().then((frueher) => {
            if (frueher.length > 0) upload.resumeFromPreviousUpload(frueher[0]!);
            upload.start();
          });
        });
      } catch (ursache) {
        setze(auftrag.id, {
          // Nie "fehlgeschlagen": der Gang ist die Halle, und dort heisst es
          // "gespeichert, wird gesendet" (Spec 4).
          stand: "fehler",
          fehler:
            ursache instanceof Error
              ? `Unterbrochen: ${ursache.message}. Wähle dieselbe Datei noch einmal, sie setzt fort.`
              : "Unterbrochen. Wähle dieselbe Datei noch einmal, sie setzt fort.",
        });
        return;
      }

      // Erst jetzt sieht der Server die Bytes: Format und Laufzeit werden am
      // Inhalt geprueft, nicht an dem, was der Browser behauptet.
      setze(auftrag.id, { stand: "prueft", anteil: 1 });
      const bestaetigt = await videoBestaetigen(
        studioRef.current,
        auftrag.modelId,
        auftrag.linkId,
        ziel.storagePath,
      );
      setze(
        auftrag.id,
        bestaetigt.ok
          ? { stand: "fertig" }
          : { stand: "fehler", fehler: bestaetigt.error },
      );
    }
  }, [auftraege, aktiv]);

  // Ein gescheiterter Upload zaehlt als offen: er ist unerledigte Arbeit, und
  // ihn zu verstecken waere genau der stille Fehlschlag, den das Portal
  // sonst ueberall vermeidet.
  const offen = auftraege.filter((auftrag) => auftrag.stand !== "fertig").length;

  return (
    <Kontext.Provider value={{ auftraege, offen, einreihen }}>
      {children}
    </Kontext.Provider>
  );
}

/**
 * Die Aufnahme entsteht auf dem Trainerhandy und geht aus mobilem Safari
 * hoch (Spec 6.8). Sie wird eingereiht, nicht abgewartet -- der Trainer geht
 * zum naechsten Geraet weiter.
 */
export function VideoAufnehmen({
  modelId,
  linkId,
  uebungName,
  titel,
  hatVideo,
}: {
  modelId: string;
  linkId: string;
  /** Fuer die Beschriftung am Feld -- der Trainer sieht das Geraet ja. */
  uebungName: string;
  /** Fuer die Warteschlange, die Uebungen mehrerer Geraete fuehrt. */
  titel: string;
  hatVideo: boolean;
}) {
  const { einreihen } = useUploads();
  const eingabe = useRef<HTMLInputElement>(null);

  return (
    <div className={styles.feld}>
      <label className={styles.label} htmlFor={`video-${linkId}`}>
        {hatVideo ? `Video ersetzen für ${uebungName}` : `Video für ${uebungName}`}
      </label>
      <input
        ref={eingabe}
        id={`video-${linkId}`}
        type="file"
        accept="video/mp4,video/quicktime"
        capture="environment"
        className={styles.eingabe}
        onChange={(ereignis) => {
          const datei = ereignis.target.files?.[0];
          if (!datei) return;
          einreihen({ titel, modelId, linkId, datei });
          if (eingabe.current) eingabe.current.value = "";
        }}
      />
      <span className={styles.notiz}>
        Höchstens {MAX_VIDEO_SECONDS} Sekunden. Die Länge wird an der Datei
        geprüft, nicht geschätzt — eine zu lange Aufnahme wird abgelehnt, nicht
        beschnitten.
      </span>
    </div>
  );
}

/**
 * Die Marke im Kopf des Gangs, solange etwas offen ist.
 *
 * Bewusst next/link und kein blankes a: eine harte Navigation montiert das
 * Layout neu und loescht damit genau die Warteschlange, zu der sie fuehrt.
 */
export function UploadsMarke({ studioId }: { studioId: string }) {
  const { offen } = useUploads();
  if (offen === 0) return null;
  return (
    <Link
      href={`/portal/${studioId}/einrichten/uploads`}
      className={styles.marke}
      aria-label={`Uploads: ${offen} offen`}
    >
      Uploads · {offen}
    </Link>
  );
}
