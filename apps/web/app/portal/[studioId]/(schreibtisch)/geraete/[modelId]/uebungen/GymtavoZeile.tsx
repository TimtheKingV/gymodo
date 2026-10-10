"use client";

import { useId, useState } from "react";
import { formatVolumeRange } from "@fitretro/domain/belastung";
import { AktionsKnopf } from "../../../../../Form";
import { VideoUpload } from "../../../../../VideoUpload";
import { MedienVorschau } from "../../../../../bausteine/MedienVorschau";
import { VideoAbspieler } from "../../../../../bausteine/VideoAbspieler";
import { StiftKnopf } from "../../../../../bausteine/Stift";
import type { ActionResult } from "../../../../../actions";
import type { GymtavoZeileDaten } from "./gymtavo";
import styles from "../../../../../portal.module.css";
import eigene from "./uebungen.module.css";

/**
 * Eine Gymtavo-Uebung am Modell. Name und Korridor gehoeren Gymtavo und
 * sind hier nicht aenderbar (Spec E2: Bankdruecken ist ueberall dieselbe
 * Uebung). Das Studio darf ein eigenes Video ergaenzen; es ersetzt am Geraet
 * das Katalogvideo (Spec 8.1, Geraetekontext).
 */
export function GymtavoZeile({
  studioId,
  modelId,
  zeile,
  eigeneVideoUrl,
  katalogVideoUrl,
  verknuepfen,
  loesen,
}: {
  studioId: string;
  modelId: string;
  zeile: GymtavoZeileDaten;
  eigeneVideoUrl: string | undefined;
  katalogVideoUrl: string | undefined;
  verknuepfen: () => Promise<ActionResult>;
  loesen: (() => Promise<ActionResult>) | null;
}) {
  const [offen, setOffen] = useState(false);
  const bereich = useId();
  const videoUrl = eigeneVideoUrl ?? katalogVideoUrl;
  const video = zeile.eigenesVideo ?? zeile.katalogVideo;

  return (
    <li className={eigene.zeile}>
      <div className={eigene.zeileKopf}>
        <div className={styles.zeileMitBild}>
          {videoUrl ? (
            <VideoAbspieler url={videoUrl} titel={zeile.name} groesse="zeile" />
          ) : (
            <MedienVorschau url={null} art="video" leerText="Kein Video" groesse="zeile" />
          )}
          <div className={styles.rowMain}>
            <div className={styles.rowTitle}>{zeile.name}</div>
            <div className={styles.rowMeta}>
              {formatVolumeRange(zeile.targetMin, zeile.targetMax, zeile.volumeKind)} ·{" "}
              {zeile.eigenesVideo
                ? `Eigenes Video ${zeile.eigenesVideo.durationS ?? "?"} s`
                : video
                  ? `Gymtavo-Video ${video.durationS ?? "?"} s`
                  : "ohne Video"}
            </div>
            <div className={styles.rowMarke}>
              <span className={styles.badge}>
                {zeile.herkunft === "typ" ? "vom Typ" : "angehängt"}
              </span>
            </div>
          </div>
        </div>
        <StiftKnopf
          label={`${zeile.name} bearbeiten`}
          gedrueckt={offen}
          controls={bereich}
          onClick={() => setOffen((bisher) => !bisher)}
        />
      </div>

      {offen ? (
        <div id={bereich} className={eigene.bearbeiten}>
          {zeile.linkId ? (
            <div className={eigene.bearbeitenTeil}>
              <VideoUpload
                studioId={studioId}
                modelId={modelId}
                linkId={zeile.linkId}
                hatVideo={zeile.eigenesVideo !== null}
                videoUrl={eigeneVideoUrl}
                titel={zeile.name}
              />
            </div>
          ) : (
            // Erst die Verknuepfung, dann der Upload: nach der Revalidierung
            // traegt die Zeile ihre linkId, und offen bleibt sie, weil React
            // die Zeile ueber exerciseId wiedererkennt.
            <AktionsKnopf aktion={verknuepfen} label="Eigenes Video ergänzen" />
          )}
          {loesen ? (
            <div className={eigene.entfernen}>
              <AktionsKnopf
                aktion={loesen}
                label="Übung lösen"
                bestaetigung={
                  zeile.eigenesVideo
                    ? "Das eigene Video wird mit gelöscht. Wirklich lösen?"
                    : "Wirklich lösen?"
                }
                art="destructive"
              />
            </div>
          ) : null}
        </div>
      ) : null}
    </li>
  );
}
