"use client";

import { useId, useState } from "react";
import { AktionsFormular } from "./Form";
import { Auswahl } from "./bausteine/Auswahl";
import { NameFeld, Rad } from "./bausteine/EinstellungRad";
import {
  einheitWerte,
  minMaxWerte,
  nameVorschlaege,
  schluesselAus,
  schrittWerte,
} from "./bausteine/einstellungVorschlaege";
import type { ActionResult } from "./actions";
import styles from "./portal.module.css";

/**
 * Zahleneinstellung und Auswahl brauchen verschiedene Felder -- ein Sitz
 * hat einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 *
 * Nur EIN Namensfeld statt Schluessel + Beschriftung (Befund: zwei Felder
 * fuer dieselbe Sache waren unnoetig) -- der Schluessel leitet sich aus
 * dem Namen ab (schluesselAus()) und wird nicht mehr eingetippt. Ein Klick
 * ins Namensfeld zeigt zusaetzlich ein Rad mit haeufigen Namen.
 *
 * Der Bereich (Minimum/Maximum/Schritt/Einheit) steht immer als Rad da --
 * keine Vorgabe mit festem Bereich mehr davor (Trainer-Wunsch: "man muss
 * das einfach immer einstellen"), bestaetigt als echtes Scroll-Rad statt
 * Chip-Zeile oder Tastatur.
 */
export function EinstellungFormular({
  action,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
}) {
  const [kind, setKind] = useState<"number" | "enum">("number");
  const [label, setLabel] = useState("");
  const artId = useId();
  const werteId = useId();

  return (
    <AktionsFormular action={action} submitLabel="Einstellung anlegen">
      <input type="hidden" name="key" value={schluesselAus(label)} />
      <div className={styles.grid}>
        <NameFeld
          name="label"
          label="Beschriftung"
          required
          placeholder="Sitzhöhe"
          value={label}
          onChange={setLabel}
          vorschlaege={nameVorschlaege()}
        />
        <div className={styles.field}>
          <label className={styles.label} htmlFor={artId}>
            Art
          </label>
          <Auswahl
            id={artId}
            name="kind"
            value={kind}
            onChange={(wert) => setKind(wert === "enum" ? "enum" : "number")}
            optionen={[
              { wert: "number", anzeige: "Zahl mit Bereich" },
              { wert: "enum", anzeige: "Auswahl aus Werten" },
            ]}
          />
        </div>
      </div>

      {kind === "number" ? (
        <Rad
          spalten={[
            { name: "minValue", label: "Minimum", werte: minMaxWerte(), start: "0" },
            { name: "maxValue", label: "Maximum", werte: minMaxWerte(), start: "10" },
            { name: "stepValue", label: "Schritt", werte: schrittWerte(), start: "1" },
            { name: "unit", label: "Einheit", werte: einheitWerte(), start: "" },
          ]}
        />
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
