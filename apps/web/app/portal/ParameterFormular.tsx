"use client";

import { useId, useState } from "react";
import { AktionsFormular, Feld } from "./Form";
import { Rad, VorgabenListe } from "./bausteine/ParameterRad";
import {
  eigeneEinheitWerte,
  eigeneMinMaxWerte,
  eigeneSchrittWerte,
  parameterVorgaben,
  type GewichtsModell,
  type ParameterVorgabeId,
} from "./bausteine/parameterVorgaben";
import type { ActionResult } from "./actions";
import styles from "./portal.module.css";

/**
 * Zahlenparameter und Auswahl brauchen verschiedene Felder -- ein Sitz hat
 * einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 *
 * Bei "Zahl mit Bereich" waehlt der Trainer zuerst eine Vorgabe
 * (Wiederholungen/Gewicht/Winkel) oder "Eigener Parameter" -- eine Vorgabe
 * setzt Minimum/Maximum/Schritt/Einheit fest, "Eigener Parameter" zeigt
 * stattdessen ein Rad dafuer. Trainer-Wunsch: "so muss man weniger tippen
 * auf der Tastatur und gibt mehr direkt ein" -- bestaetigt als echtes
 * Scroll-Rad, nicht als Chip-Zeile.
 */
export function ParameterFormular({
  action,
  modell,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  modell: GewichtsModell;
}) {
  const [kind, setKind] = useState<"number" | "enum">("number");
  const [vorgabeId, setVorgabeId] = useState<ParameterVorgabeId>("eigen");
  const artId = useId();
  const werteId = useId();

  const vorgaben = parameterVorgaben(modell);
  // parameterVorgaben() liefert immer "eigen" -- vorgabeId zeigt garantiert
  // auf einen der vier Eintraege.
  const gewaehlt = vorgaben.find((eintrag) => eintrag.id === vorgabeId)!;

  return (
    <AktionsFormular action={action} submitLabel="Parameter anlegen">
      <div className={styles.grid}>
        <Feld
          name="key"
          label="Schlüssel"
          required
          placeholder="sitz"
          hint="Kurz und ohne Leerzeichen. Ändert sich später nicht."
        />
        <Feld name="label" label="Beschriftung" required placeholder="Sitzposition" />
        <div className={styles.field}>
          <label className={styles.label} htmlFor={artId}>
            Art
          </label>
          <select
            id={artId}
            name="kind"
            className={styles.select}
            value={kind}
            onChange={(ereignis) =>
              setKind(ereignis.target.value === "enum" ? "enum" : "number")
            }
          >
            <option value="number">Zahl mit Bereich</option>
            <option value="enum">Auswahl aus Werten</option>
          </select>
        </div>
      </div>

      {kind === "number" ? (
        <>
          <VorgabenListe vorgaben={vorgaben} gewaehlt={vorgabeId} onWahl={setVorgabeId} />
          {gewaehlt.bereich ? (
            <>
              <input type="hidden" name="minValue" value={gewaehlt.bereich.minValue} />
              <input type="hidden" name="maxValue" value={gewaehlt.bereich.maxValue} />
              <input type="hidden" name="stepValue" value={gewaehlt.bereich.stepValue} />
              <input type="hidden" name="unit" value={gewaehlt.bereich.unit} />
            </>
          ) : (
            <Rad
              spalten={[
                { name: "minValue", label: "Minimum", werte: eigeneMinMaxWerte(), start: "0" },
                { name: "maxValue", label: "Maximum", werte: eigeneMinMaxWerte(), start: "10" },
                { name: "stepValue", label: "Schritt", werte: eigeneSchrittWerte(), start: "1" },
                { name: "unit", label: "Einheit", werte: eigeneEinheitWerte(), start: "" },
              ]}
            />
          )}
        </>
      ) : (
        <div className={styles.field}>
          <label className={styles.label} htmlFor={werteId}>
            Erlaubte Werte
          </label>
          <textarea
            id={werteId}
            name="allowedValues"
            className={styles.textarea}
            placeholder={"eng\nweit"}
            aria-describedby={`${werteId}-hint`}
          />
          <span id={`${werteId}-hint`} className={styles.hint}>
            Ein Wert je Zeile, mindestens zwei verschiedene. Mit nur einem Wert
            wäre es keine Auswahl, sondern eine feste Einstellung.
          </span>
        </div>
      )}
    </AktionsFormular>
  );
}
