"use client";

import { useId, useState } from "react";
import type { CatalogType } from "@fitretro/domain";
import { Auswahl } from "./Auswahl";
import { TYP_FELD } from "../gymtavoTyp";
import styles from "../portal.module.css";

/**
 * "Gymtavo-Gerätetyp" an beiden Modellformularen (Schreibtisch und Halle).
 * Pflicht schon im Browser (Auswahl `pflicht`); die Server-Action prueft
 * dieselbe Regel noch einmal (typAusFormular).
 * Ohne Typen im Katalog rendert es nichts -- dann gibt es auch keine Pflicht
 * (Nachtrag 10.1), und ein leeres Auswahlfeld waere eine Frage ohne Antwort.
 */
export function GymtavoTypFeld({
  typen,
  start,
  gross = false,
  onChange,
}: {
  /** `retired` fehlt bei den Vorlagen: typVorlagen hat sie schon gefiltert. */
  typen: (Pick<CatalogType, "id" | "name" | "manufacturer"> & { retired?: boolean })[];
  start: string | null;
  gross?: boolean;
  /** Das Modellformular fuellt damit vor (ModellVorlageFelder). */
  onChange?: (typId: string) => void;
}) {
  const [wert, setWert] = useState(start ?? "");
  const id = useId();
  // Abgeloeste Typen nicht mehr anbieten (Testnotiz 12.10., #1) -- den schon
  // zugeordneten aber stehen lassen, sonst verloere das Formular still die
  // Zuordnung beim naechsten Speichern.
  const angeboten = typen.filter((typ) => !typ.retired || typ.id === start);
  if (angeboten.length === 0) return null;

  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={id}>
        Gymtavo-Gerätetyp
      </label>
      <Auswahl
        id={id}
        name={TYP_FELD}
        value={wert}
        onChange={(neu) => {
          setWert(neu);
          onChange?.(neu);
        }}
        optionen={angeboten.map((typ) => ({
          wert: typ.id,
          anzeige: typ.manufacturer ? `${typ.name} · ${typ.manufacturer}` : typ.name,
        }))}
        platzhalter="Typ wählen"
        suche="Typ suchen"
        pflicht="Wähle den Gymtavo-Gerätetyp. Er bestimmt, welche Gymtavo-Übungen Mitglieder an diesem Gerät sehen."
        gross={gross}
      />
      <span className={styles.hint}>
        Bestimmt, welche Gymtavo-Übungen Mitglieder an diesem Gerät sehen.
      </span>
    </div>
  );
}
