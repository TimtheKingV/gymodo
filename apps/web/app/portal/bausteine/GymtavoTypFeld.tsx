"use client";

import { useId, useState } from "react";
import type { CatalogType } from "@fitretro/domain";
import { Auswahl } from "./Auswahl";
import { TYP_FELD } from "../gymtavoTyp";
import styles from "../portal.module.css";

/**
 * "Gymtavo-Gerätetyp" an beiden Modellformularen (Schreibtisch und Halle).
 * Ohne Typen im Katalog rendert es nichts -- dann gibt es auch keine Pflicht
 * (Nachtrag 10.1), und ein leeres Auswahlfeld waere eine Frage ohne Antwort.
 */
export function GymtavoTypFeld({
  typen,
  start,
  gross = false,
}: {
  typen: Pick<CatalogType, "id" | "name" | "manufacturer">[];
  start: string | null;
  gross?: boolean;
}) {
  const [wert, setWert] = useState(start ?? "");
  const id = useId();
  if (typen.length === 0) return null;

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={id}>
        Gymtavo-Gerätetyp
      </label>
      <Auswahl
        id={id}
        name={TYP_FELD}
        value={wert}
        onChange={setWert}
        optionen={typen.map((typ) => ({
          wert: typ.id,
          anzeige: typ.manufacturer ? `${typ.name} · ${typ.manufacturer}` : typ.name,
        }))}
        platzhalter="Typ wählen"
        suche="Typ suchen"
        gross={gross}
      />
      <span className={styles.hint}>
        Bestimmt, welche Gymtavo-Übungen Mitglieder an diesem Gerät sehen.
      </span>
    </div>
  );
}
