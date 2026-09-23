"use client";

import { useActionState, useEffect, useId, useRef, useState, useTransition } from "react";
import { useFormStatus } from "react-dom";
import styles from "./portal.module.css";
import type { ActionResult } from "./actions";

/**
 * Ein Formular, ein Ergebnisformat: entweder es hat geklappt, oder es steht
 * ein Satz da, der sagt, was gilt -- nie nur "ungueltig" (Designsystem 5).
 */
export function AktionsFormular({
  action,
  submitLabel,
  children,
  onErfolg,
  gross,
  erfolgText,
  leertNachErfolg = false,
  nurBeiAenderung = false,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  submitLabel: string;
  children: React.ReactNode;
  onErfolg?: () => void;
  /** Groessere Trefferflaechen (56 px statt 44 px, volle Breite) fuer
      einhaendige Bedienung -- der Einrichten-Gang, nicht der Schreibtisch
      (Designsystem 1). Ersetzt die eigenen .haupt/.neben/.gefaehrlich aus
      halle.module.css. */
  gross?: boolean;
  /** Was nach dem Anlegen dasteht. Ohne diesen Text bleibt Erfolg stumm --
      richtig fuer ein Formular, das speichert, was schon da war (die
      Studio-Einstellungen), falsch fuer eines, das etwas Neues in eine
      Liste legt: dort war Erfolg bis hierher daran zu erkennen, dass
      irgendwo darueber eine Zeile dazugekommen ist. */
  erfolgText?: string;
  /** Anlegen heisst: gleich das naechste. Leert die Felder und setzt den
      Zeiger zurueck ins erste -- nur fuer Formulare, die mehrfach
      hintereinander abgesendet werden (Uebung, Einstellung, Geraet), nie
      fuer eines, das bestehende Werte zeigt. */
  leertNachErfolg?: boolean;
  /** Fuer Formulare, die Bestehendes zeigen ("Änderungen speichern"): der
      Knopf ist nur scharf, wenn sich seit dem Laden oder dem letzten
      Speichern etwas geaendert hat, und der Erfolgstext steht, bis wieder
      etwas geaendert wird. Testnotiz 22.09., #9: nach dem Speichern stand
      der Knopf unveraendert da, und es sah aus, als haette es nicht
      geklappt. */
  nurBeiAenderung?: boolean;
}) {
  const formRef = useRef<HTMLFormElement>(null);
  const gespeichert = useRef<string | null>(null);
  const [geaendert, setGeaendert] = useState(false);

  useEffect(() => {
    if (nurBeiAenderung && formRef.current) {
      gespeichert.current = momentaufnahme(formRef.current);
    }
  }, [nurBeiAenderung]);

  function aufEingabe() {
    if (!nurBeiAenderung || !formRef.current) return;
    setGeaendert(momentaufnahme(formRef.current) !== gespeichert.current);
  }

  const [ergebnis, formAction] = useActionState(
    async (prev: ActionResult | null, formData: FormData) => {
      const antwort = await action(prev, formData);
      if (antwort.ok) {
        if (nurBeiAenderung && formRef.current) {
          gespeichert.current = momentaufnahme(formRef.current);
          setGeaendert(false);
        }
        onErfolg?.();
        if (leertNachErfolg && formRef.current) {
          formRef.current.reset();
          // Das erste sichtbare Eingabefeld, nicht das erste Element
          // ueberhaupt: davor koennen versteckte Felder stehen, und ein
          // Rad (role="button") ist kein Feld, in dem jemand weitertippt.
          formRef.current
            .querySelector<HTMLInputElement>("input:not([type=hidden]), textarea")
            ?.focus();
        }
      }
      return antwort;
    },
    null,
  );

  return (
    <form
      ref={formRef}
      action={formAction}
      className={styles.sectionBody}
      onInput={aufEingabe}
    >
      {children}
      {ergebnis && !ergebnis.ok ? (
        <p className={styles.error} role="alert">
          {ergebnis.error}
        </p>
      ) : null}
      <div className={styles.actions}>
        <Absenden
          label={submitLabel}
          gross={gross ?? false}
          gesperrt={nurBeiAenderung && !geaendert}
        />
        {/* role="status" statt role="alert": Erfolg unterbricht keinen
            Screenreader mitten im Satz, er wird nachgereicht. Immer im
            DOM, damit die Ansage ueberhaupt kommt -- ein Element, das erst
            mit seinem Text erscheint, wird von manchen Lesern nicht
            gemeldet. */}
        <span className={styles.erfolg} role="status">
          {ergebnis?.ok && erfolgText && !geaendert ? erfolgText : ""}
        </span>
      </div>
    </form>
  );
}

/**
 * Der Formularstand als Vergleichswert: Felder samt versteckter Rad-Werte,
 * eine gewaehlte Datei als Name/Groesse/Datum (ihr Inhalt aendert am
 * Vergleich nichts).
 */
function momentaufnahme(form: HTMLFormElement): string {
  return JSON.stringify(
    [...new FormData(form).entries()]
      .filter(([name]) => !name.startsWith("$ACTION"))
      .map(([name, wert]) => [
        name,
        wert instanceof File ? `${wert.name}:${wert.size}:${wert.lastModified}` : wert,
      ]),
  );
}

function Absenden({
  label,
  gross,
  gesperrt = false,
}: {
  label: string;
  gross?: boolean;
  gesperrt?: boolean;
}) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      className={gross ? styles.primaryGross : styles.primary}
      disabled={pending || gesperrt}
    >
      {pending ? "Wird gespeichert …" : label}
    </button>
  );
}

/**
 * Eine Aktion ohne Formular -- loeschen, sperren, stilllegen. Der Fehler
 * erscheint neben dem Knopf, nicht als Dialog: der Trainer soll sehen,
 * welche Zeile gemeint ist.
 */
export function AktionsKnopf({
  aktion,
  label,
  laufendLabel,
  art = "secondary",
  bestaetigung,
  gross,
  deaktiviert = false,
}: {
  aktion: () => Promise<ActionResult>;
  label: string;
  laufendLabel?: string;
  art?: "secondary" | "destructive";
  bestaetigung?: string;
  gross?: boolean;
  /** Fuer Aktionen, die an ihrem Rand folgenlos waeren -- "Hoch" in der
      ersten Zeile, "Runter" in der letzten. Sie liefen bisher durch:
      Server-Aktion, Revalidierung, dieselbe Liste. Ein abgeschalteter
      Knopf sagt vorher, dass da nichts mehr kommt. */
  deaktiviert?: boolean;
}) {
  const [fehler, setFehler] = useState<string | null>(null);
  const [laeuft, starte] = useTransition();
  const [bestaetigt, setBestaetigt] = useState(false);

  // Zweistufig statt window.confirm: ein Dialog reisst den Kontext weg, und
  // der zweite Klick sagt im Klartext, was passiert.
  const brauchtBestaetigung = Boolean(bestaetigung) && !bestaetigt;

  return (
    <span className={styles.rowActions}>
      {fehler ? (
        <span className={styles.error} role="alert">
          {fehler}
        </span>
      ) : null}
      <button
        type="button"
        // Die danger-Farbe erst, wenn der Knopf scharf ist. Eine Liste mit
        // sechs Zeilen trug vorher sechs rote Umrisse, gleichmaessig
        // verteilt -- die auffaelligste Farbe des Bildschirms gehoerte dem
        // Loeschen, und die eine Akzentflaeche der Hauptaktion verlor
        // gegen sie (Befund 7 der UX-Challenge). Ohne Bestaetigungsstufe
        // bleibt es wie bisher: dort ist der erste Druck schon der echte.
        className={
          art === "destructive" && !brauchtBestaetigung
            ? gross
              ? styles.destructiveGross
              : styles.destructive
            : gross
              ? styles.secondaryGross
              : styles.secondary
        }
        disabled={laeuft || deaktiviert}
        onClick={() => {
          if (brauchtBestaetigung) {
            setBestaetigt(true);
            return;
          }
          setFehler(null);
          starte(async () => {
            const antwort = await aktion();
            setBestaetigt(false);
            if (!antwort.ok) setFehler(antwort.error);
          });
        }}
      >
        {laeuft
          ? (laufendLabel ?? "…")
          : brauchtBestaetigung
            ? label
            : (bestaetigung ?? label)}
      </button>
    </span>
  );
}

/**
 * Beschriftetes Eingabefeld. Der Hinweis steht unter dem Feld, nicht darin.
 *
 * Die id kommt aus useId und nicht aus dem Feldnamen: auf der Modellseite
 * stehen mehrere Formulare untereinander, und "name" heisst dort sowohl das
 * Feld der Stammdaten als auch das der Uebung. Zwei gleiche ids machen die
 * zweite Beschriftung wirkungslos -- ein Screenreader liest dann den
 * Platzhalter statt des Labels.
 */
export function Feld({
  name,
  label,
  hint,
  gross,
  ...rest
}: {
  name: string;
  label: string;
  hint?: string;
  /** 52 px statt 44 px -- der Einrichten-Gang, einhaendig bedient
      (Designsystem 1). Ersetzt die eigene .eingabe aus halle.module.css. */
  gross?: boolean;
} & React.InputHTMLAttributes<HTMLInputElement>) {
  const id = useId();
  const hintId = hint ? `${id}-hint` : undefined;
  return (
    <div className={styles.field}>
      <label className={styles.label} htmlFor={id}>
        {label}
      </label>
      <input
        id={id}
        name={name}
        className={gross ? styles.inputGross : styles.input}
        aria-describedby={hintId}
        {...rest}
      />
      {hint ? (
        <span id={hintId} className={styles.hint}>
          {hint}
        </span>
      ) : null}
    </div>
  );
}
