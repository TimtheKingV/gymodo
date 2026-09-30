"use client";

import { useId, useState } from "react";
import { AktionsFormular, AktionsKnopf, Feld } from "../../../../../Form";
import { VideoUpload } from "../../../../../VideoUpload";
import { MedienVorschau } from "../../../../../bausteine/MedienVorschau";
import { VideoAbspieler } from "../../../../../bausteine/VideoAbspieler";
import { StiftKnopf } from "../../../../../bausteine/Stift";
import { UebungRepsRad } from "../../../../../bausteine/UebungRepsRad";
import type { ActionResult } from "../../../../../actions";
import styles from "../../../../../portal.module.css";
import eigene from "./uebungen.module.css";

/**
 * Eine Uebung in der Liste (Testnotiz 22.09., #12). Vorher trug jede Zeile
 * Video-Knopf, Hoch, Runter und Entfernen -- auf dem Telefon mehr Knoepfe
 * als Inhalt. Jetzt zeigt die Zeile nur, was ist, und rechts oben sitzt ein
 * Stift. Fehlt noch etwas (heute: das Einweisungsvideo), traegt er die
 * Anzahl als Marke. Ein Druck klappt genau diese Uebung darunter auf:
 * Name und Wiederholungen, Video, Entfernen.
 *
 * Die Reihenfolge steht nicht mehr hier, sondern im Dialog "Reihenfolge
 * ändern" ueber der Liste (ReihenfolgeDialog.tsx, #11).
 */
export function UebungZeile({
  studioId,
  modelId,
  uebung,
  nummer,
  videoUrl,
  aendern,
  loesen,
}: {
  studioId: string;
  modelId: string;
  uebung: {
    linkId: string;
    name: string;
    targetRepsMin: number;
    targetRepsMax: number;
    hasVideo: boolean;
    videoDurationS: number | null;
  };
  nummer: number;
  videoUrl: string | undefined;
  aendern: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  loesen: () => Promise<ActionResult>;
}) {
  const [offen, setOffen] = useState(false);
  const bereich = useId();
  const offenePunkte = uebung.hasVideo ? 0 : 1;

  return (
    <li className={eigene.zeile}>
      <div className={eigene.zeileKopf}>
        <div className={styles.zeileMitBild}>
          {/* Die Kachel spielt auf Tipp ab, im Vollbild (Testnotiz 23.09.,
              #6) -- ob die richtige Uebung zu sehen ist, beantwortet sich
              ohne Aufklappen. */}
          {videoUrl ? (
            <VideoAbspieler url={videoUrl} titel={uebung.name} groesse="zeile" />
          ) : (
            <MedienVorschau
              url={null}
              art="video"
              leerText={uebung.hasVideo ? "Video" : "Kein Video"}
              groesse="zeile"
            />
          )}
          <div className={styles.rowMain}>
            <div className={styles.rowTitle}>
              {nummer}. {uebung.name}
            </div>
            <div className={styles.rowMeta}>
              {uebung.targetRepsMin}–{uebung.targetRepsMax} Wiederholungen ·{" "}
              {uebung.hasVideo ? (
                `Video ${uebung.videoDurationS} s`
              ) : (
                <span className={styles.offenMarke}>ohne Video</span>
              )}
            </div>
            {nummer === 1 ? (
              <div className={styles.rowMarke}>
                <span className={styles.badge}>Vorauswahl am Gerät</span>
              </div>
            ) : null}
          </div>
        </div>
        <StiftKnopf
          label={`${uebung.name} bearbeiten`}
          offen={offenePunkte}
          gedrueckt={offen}
          controls={bereich}
          onClick={() => setOffen((bisher) => !bisher)}
        />
      </div>

      {offen ? (
        <div id={bereich} className={eigene.bearbeiten}>
          <AktionsFormular
            action={aendern}
            submitLabel="Übung speichern"
            erfolgText="Gespeichert ✓"
            nurBeiAenderung
          >
            <Feld name="name" label="Name" required defaultValue={uebung.name} />
            <UebungRepsRad
              abStart={String(uebung.targetRepsMin)}
              bisStart={String(uebung.targetRepsMax)}
            />
          </AktionsFormular>
          <div className={eigene.bearbeitenTeil}>
            <VideoUpload
              studioId={studioId}
              modelId={modelId}
              linkId={uebung.linkId}
              hatVideo={uebung.hasVideo}
              videoUrl={videoUrl}
              titel={uebung.name}
            />
          </div>
          <div className={eigene.entfernen}>
            <AktionsKnopf
              aktion={loesen}
              label="Übung entfernen"
              bestaetigung="Wirklich entfernen?"
              art="destructive"
            />
          </div>
        </div>
      ) : null}
    </li>
  );
}
