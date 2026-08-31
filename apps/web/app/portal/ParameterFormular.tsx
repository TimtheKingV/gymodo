"use client";

import { useId, useState } from "react";
import { AktionsFormular, Feld } from "./Form";
import type { ActionResult } from "./actions";
import styles from "./portal.module.css";

/**
 * Zahlenparameter und Auswahl brauchen verschiedene Felder -- ein Sitz hat
 * einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 */
export function ParameterFormular({
  action,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
}) {
  const [kind, setKind] = useState<"number" | "enum">("number");
  const artId = useId();
  const werteId = useId();

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
        <div className={styles.grid}>
          <Feld name="minValue" label="Minimum" inputMode="decimal" placeholder="1" />
          <Feld name="maxValue" label="Maximum" inputMode="decimal" placeholder="8" />
          <Feld name="stepValue" label="Schritt" inputMode="decimal" placeholder="1" />
          <Feld name="unit" label="Einheit" placeholder="Stufe" />
        </div>
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
