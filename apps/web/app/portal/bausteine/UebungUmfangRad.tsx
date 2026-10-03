"use client";

import { useId, useState } from "react";
import type { VolumeKind } from "@fitretro/domain/belastung";
import { Auswahl } from "./Auswahl";
import { Rad } from "./EinstellungRad";
import { UMFANG_OPTIONEN, istUmfangsart, umfangWerte } from "./einstellungVorschlaege";
import styles from "../portal.module.css";

/**
 * Umfangsart und Korridor einer Uebung -- der Nachfolger von UebungRepsRad
 * (Cardio-Spec Abschnitt 3.2 und 7). Wiederholungen, Minuten oder Meter;
 * das Rad bekommt die Art als `key`, damit ein Wechsel Liste, Beschriftung
 * und Startwerte neu laedt. Minuten gehen als Minuten ins Formular und
 * werden erst in der Server-Action zu Sekunden (formfelder.ts).
 *
 * Die Vorgabe bleibt "Wiederholungen ab 8 bis 12" -- wer eine Kraftuebung
 * anlegt, fasst die Auswahl nicht an.
 */
export function UebungUmfangRad({
  gross = false,
  start,
}: {
  gross?: boolean;
  /** Bestandswerte beim Bearbeiten (UebungZeile), so gespeichert, wie
      die Datenbank sie haelt -- Sekunden, nicht Minuten. */
  start?: { volumeKind: VolumeKind; targetMin: number; targetMax: number };
}) {
  const [kind, setKind] = useState<VolumeKind>(start?.volumeKind ?? "reps");
  const artId = useId();
  const umfang = umfangWerte(kind);
  // Bestandswerte nur fuer die Art, in der sie gespeichert wurden; das
  // Rad zaehlt Minuten, die Datenbank Sekunden (formfelder.ts rechnet
  // beim Speichern zurueck).
  const faktor = kind === "seconds" ? 60 : 1;
  const radStart =
    start && start.volumeKind === kind
      ? {
          min: String(Math.round(start.targetMin / faktor)),
          max: String(Math.round(start.targetMax / faktor)),
        }
      : umfang.start;

  return (
    <>
      <div className={styles.field}>
        <label className={styles.label} htmlFor={artId}>
          Umfang
        </label>
        <Auswahl
          id={artId}
          name="volumeKind"
          gross={gross}
          value={kind}
          onChange={(wert) => setKind(istUmfangsart(wert) ? wert : "reps")}
          optionen={UMFANG_OPTIONEN}
        />
      </div>
      <Rad
        key={kind}
        gross={gross}
        spalten={[
          { name: "targetMin", label: umfang.labelAb, werte: umfang.liste, start: radStart.min },
          { name: "targetMax", label: umfang.labelBis, werte: umfang.liste, start: radStart.max },
        ]}
      />
    </>
  );
}
