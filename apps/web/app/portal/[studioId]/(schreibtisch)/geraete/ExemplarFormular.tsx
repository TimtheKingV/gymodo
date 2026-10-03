"use client";

import { useId, useState } from "react";
import { AktionsFormular, Feld } from "../../../Form";
import { Auswahl } from "../../../bausteine/Auswahl";
import type { ActionResult } from "../../../actions";
import styles from "../../../portal.module.css";

/**
 * Ein weiteres Geraet eines vorhandenen Typs (Testnotiz 25.09., #7).
 *
 * Nichts wird kopiert: das neue Geraet ist eine Zeile in `machines`, die
 * auf dasselbe Modell verweist wie die schon vorhandenen. Stammdaten,
 * Einstellungen, Uebungen und Videos gelten damit fuer alle Geraete des
 * Typs -- abgefragt wird nur, was je Geraet verschieden ist: Nummer und
 * Standort. Dasselbe, was der Reiter "Einzelne Geräte" schon konnte, nur
 * am Anfang des Ablaufs statt an seinem Ende.
 *
 * Die schon vergebenen Nummern stehen unter der Auswahl, damit die neue
 * nicht geraten werden muss.
 */
export function ExemplarFormular({
  action,
  typen,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  typen: { id: string; name: string; geraete: string[] }[];
}) {
  const [modelId, setModelId] = useState(typen[0]?.id ?? "");
  const auswahlId = useId();
  const gewaehlt = typen.find((typ) => typ.id === modelId);

  return (
    <AktionsFormular action={action} submitLabel="Gerät anlegen">
      <div className={styles.field}>
        <label className={styles.label} htmlFor={auswahlId}>
          Gerätetyp
        </label>
        <Auswahl
          id={auswahlId}
          name="modelId"
          value={modelId}
          onChange={setModelId}
          ariaLabel="Gerätetyp"
          optionen={typen.map((typ) => ({ wert: typ.id, anzeige: typ.name }))}
        />
        {gewaehlt && gewaehlt.geraete.length > 0 ? (
          <span className={styles.hint}>Schon vergeben: {gewaehlt.geraete.join(", ")}</span>
        ) : null}
      </div>
      <div className={styles.grid}>
        <Feld name="label" label="Nummer" required placeholder="z. B. 3" />
        <Feld name="locationNote" label="Standort" placeholder="Obergeschoss" />
      </div>
    </AktionsFormular>
  );
}
