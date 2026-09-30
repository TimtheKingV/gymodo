"use client";

import { useId, useState } from "react";
import { AktionsFormular } from "./Form";
import { Auswahl } from "./bausteine/Auswahl";
import { useHinzufuegen } from "./bausteine/Hinzufuegen";
import { Rad } from "./bausteine/EinstellungRad";
import {
  SONSTIGES,
  einheitWerte,
  minMaxWerte,
  nameRadWerte,
  schluesselAus,
  schrittWerte,
  vorgabeFuer,
} from "./bausteine/einstellungVorschlaege";
import type { ActionResult } from "./actions";
import styles from "./portal.module.css";

/**
 * Zahleneinstellung und Auswahl brauchen verschiedene Felder -- ein Sitz
 * hat einen Bereich, eine Griffstellung eine Liste. Beides gleichzeitig zu
 * zeigen hiesse, den Trainer raten zu lassen, welche Haelfte gilt.
 *
 * Nur EIN Name statt Schluessel + Beschriftung (Befund: zwei Felder fuer
 * dieselbe Sache waren unnoetig) -- der Schluessel leitet sich aus dem
 * Namen ab (schluesselAus()) und wird nicht mehr eingetippt.
 *
 * Der Name kommt zuerst aus einem Rad (Testnotiz 23.09., zweite Sitzung,
 * #2): der gewaehlte Vorschlag IST die Beschriftung. Ein Textfeld gibt es
 * erst bei "Sonstiges …". Die Wahl stellt zugleich Bereich, Schritt und
 * Einheit vor (vorgabeFuer(): Winkel -> Grad in 5er-Schritten); dafuer
 * haengt das Zahlenrad mit `key` am Namen und startet neu. Danach ist
 * jede Spalte frei drehbar.
 *
 * Minimum und Maximum zaehlen im Takt des Schritts (#3): bei Schritt 5
 * stehen dort 0, 5, 10 … statt jeder ganzen Zahl.
 *
 * Der Bereich (Minimum/Maximum/Schritt/Einheit) steht immer als Rad da --
 * keine Vorgabe mit festem Bereich mehr davor (Trainer-Wunsch: "man muss
 * das einfach immer einstellen"), bestaetigt als echtes Scroll-Rad statt
 * Chip-Zeile oder Tastatur.
 *
 * Im Hinzufuegen mit abbrechenImFormular (Testnotiz 23.09., zweite
 * Sitzung, #1) traegt es unten "Abbrechen" und klappt nach dem Speichern
 * zu: die neue Einstellung steht dann oben in der Liste, und erst jetzt
 * gibt der Ablauf "Weiter" frei. Das fruehere "Angelegt. Nächste?" mit
 * offen bleibendem Formular entfaellt damit.
 */
export function EinstellungFormular({
  action,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
}) {
  const [kind, setKind] = useState<"number" | "enum">("number");
  const [auswahl, setAuswahl] = useState(nameRadWerte()[0]!.wert);
  const [eigenerName, setEigenerName] = useState("");
  const [schritt, setSchritt] = useState(vorgabeFuer(auswahl).schritt);
  const sonstiges = auswahl === SONSTIGES;
  const label = sonstiges ? eigenerName : auswahl;
  const vorgabe = vorgabeFuer(auswahl);
  const namenId = useId();
  const artId = useId();
  const werteId = useId();
  const hinzufuegen = useHinzufuegen();

  return (
    <AktionsFormular
      action={action}
      submitLabel="Einstellung speichern"
      onErfolg={() => hinzufuegen?.schliessen()}
      nebenAktion={
        hinzufuegen ? (
          <button type="button" className={styles.secondary} onClick={hinzufuegen.schliessen}>
            Abbrechen
          </button>
        ) : null
      }
    >
      <input type="hidden" name="key" value={schluesselAus(label)} />
      <Rad
        spalten={[
          {
            label: "Einstellung",
            werte: nameRadWerte(),
            start: auswahl,
            onWahl: (wert) => {
              setAuswahl(wert);
              setSchritt(vorgabeFuer(wert).schritt);
            },
          },
        ]}
      />
      {sonstiges ? (
        <div className={styles.field}>
          <label className={styles.label} htmlFor={namenId}>
            Beschriftung
          </label>
          <input
            id={namenId}
            name="label"
            className={styles.input}
            value={eigenerName}
            onChange={(ereignis) => setEigenerName(ereignis.target.value)}
            required
            placeholder="Fußstütze"
            autoComplete="off"
          />
        </div>
      ) : (
        <input type="hidden" name="label" value={auswahl} />
      )}
      <div className={styles.grid}>
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
          key={auswahl}
          spalten={[
            { name: "minValue", label: "Minimum", werte: minMaxWerte(schritt), start: vorgabe.min },
            { name: "maxValue", label: "Maximum", werte: minMaxWerte(schritt), start: vorgabe.max },
            {
              name: "stepValue",
              label: "Schritt",
              werte: schrittWerte(),
              start: vorgabe.schritt,
              onWahl: setSchritt,
            },
            { name: "unit", label: "Einheit", werte: einheitWerte(), start: vorgabe.einheit },
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
