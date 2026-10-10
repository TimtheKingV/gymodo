"use client";

import { useState } from "react";
import type { Category } from "@fitretro/domain/belastung";
import { Feld } from "../Form";
import { GymtavoTypFeld } from "./GymtavoTypFeld";
import { ModellBelastungRad } from "./ModellBelastungRad";
import { belastungStart, nameNachTypwahl, type TypVorlage } from "./typVorlage";
import styles from "../portal.module.css";

/**
 * Name, Hersteller, Gymtavo-Typ und Belastung beider Modellformulare
 * (Schreibtisch und Halle). Der Typ fuellt vor, was er weiss (Spec
 * 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 5.2) -- der
 * Trainer korrigiert nur Abweichungen.
 *
 * Das Rad bekommt die Typ-ID als `key`: nur ein Neuaufbau laedt seine
 * Startwerte neu (siehe Kopfkommentar ModellBelastungRad). Ohne Typ steht
 * es auf seinen eigenen Vorgaben wie bisher.
 */
export function ModellVorlageFelder({
  typen,
  gross = false,
  kategorie,
  onTyp,
}: {
  typen: TypVorlage[];
  gross?: boolean;
  /** Vorher gefragt (geraete/neu); fehlt in der Halle. */
  kategorie?: Category;
  /** Die Halle macht davon die Fotopflicht abhaengig. */
  onTyp?: (typ: TypVorlage | null) => void;
}) {
  const [typ, setTyp] = useState<TypVorlage | null>(null);
  const [name, setName] = useState("");

  function typGewaehlt(typId: string) {
    const neu = typen.find((t) => t.id === typId) ?? null;
    setName((aktuell) => nameNachTypwahl(aktuell, typ, neu));
    setTyp(neu);
    onTyp?.(neu);
  }

  return (
    <>
      <div className={gross ? undefined : styles.grid}>
        <Feld
          gross={gross}
          name="name"
          label="Name"
          required
          placeholder="Latzug"
          value={name}
          onChange={(e) => setName(e.target.value)}
        />
        <Feld gross={gross} name="manufacturer" label="Hersteller" placeholder="Technogym" />
      </div>
      <GymtavoTypFeld gross={gross} typen={typen} start={null} onChange={typGewaehlt} />
      {typ ? (
        <p className={styles.hint} role="status">
          {`Werte vom Typ ${typ.name} übernommen – bitte ans Gerät anpassen.`}
        </p>
      ) : null}
      <ModellBelastungRad
        key={typ?.id ?? "ohne-typ"}
        gross={gross}
        kategorie={kategorie}
        start={typ ? belastungStart(typ) : undefined}
      />
    </>
  );
}
