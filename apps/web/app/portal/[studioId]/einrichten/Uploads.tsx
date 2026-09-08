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
// Der Unterpfad statt des Barrels: index.ts zieht ueber tags.ts das
// node:crypto-Modul mit, und das laesst sich nicht in einen Browserbundle
// packen. media.ts haengt nur an errors.ts und ist frei davon.
import { MAX_VIDEO_SECONDS } from "@fitretro/domain/media";
import { videoBestaetigen } from "../../actions";
import { DateiKnopf } from "../../bausteine/DateiKnopf";
import { MedienVorschau } from "../../bausteine/MedienVorschau";
import { ladeVideoHoch } from "../../bausteine/videoUpload";
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

      const ergebnis = await ladeVideoHoch({
        linkId: auftrag.linkId,
        datei: auftrag.datei,
        onFortschritt: (anteil) => setze(auftrag.id, { anteil }),
        // Nie "fehlgeschlagen": der Gang ist die Halle, und dort heisst es
        // "gespeichert, wird gesendet" (Spec 4).
        meldungAbbruch: (ursache) =>
          ursache instanceof Error
            ? `Unterbrochen: ${ursache.message}. Wähle dieselbe Datei noch einmal, sie setzt fort.`
            : "Unterbrochen. Wähle dieselbe Datei noch einmal, sie setzt fort.",
      });
      if (!ergebnis.ok) {
        setze(auftrag.id, { stand: "fehler", fehler: ergebnis.error });
        return;
      }

      // Erst jetzt sieht der Server die Bytes: Format und Laufzeit werden am
      // Inhalt geprueft, nicht an dem, was der Browser behauptet.
      setze(auftrag.id, { stand: "prueft", anteil: 1 });
      const bestaetigt = await videoBestaetigen(
        studioRef.current,
        auftrag.modelId,
        auftrag.linkId,
        ergebnis.storagePath,
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
  const [objektUrl, setObjektUrl] = useState<string | null>(null);

  useEffect(() => {
    return () => {
      if (objektUrl) URL.revokeObjectURL(objektUrl);
    };
  }, [objektUrl]);

  return (
    <div className={styles.feld}>
      <span className={styles.label}>
        {hatVideo ? `Video ersetzen für ${uebungName}` : `Video für ${uebungName}`}
      </span>
      <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
        <MedienVorschau url={objektUrl} art="video" leerText="Kein Video" mini />
        <DateiKnopf
          label={hatVideo ? "Ersetzen" : "Aufnehmen"}
          ariaLabel={hatVideo ? `Video ersetzen für ${uebungName}` : `Video für ${uebungName}`}
          accept="video/mp4,video/quicktime"
          capture="environment"
          gross
          onDatei={(datei) => {
            if (!datei) return;
            setObjektUrl((bisherige) => {
              if (bisherige) URL.revokeObjectURL(bisherige);
              return URL.createObjectURL(datei);
            });
            einreihen({ titel, modelId, linkId, datei });
          }}
        />
      </div>
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
