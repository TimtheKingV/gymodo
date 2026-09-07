"use client";

import { useActionState, useId, useState, useTransition } from "react";
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
}) {
  const [ergebnis, formAction] = useActionState(
    async (prev: ActionResult | null, formData: FormData) => {
      const antwort = await action(prev, formData);
      if (antwort.ok) onErfolg?.();
      return antwort;
    },
    null,
  );

  return (
    <form action={formAction} className={styles.sectionBody}>
      {children}
      {ergebnis && !ergebnis.ok ? (
        <p className={styles.error} role="alert">
          {ergebnis.error}
        </p>
      ) : null}
      <div className={styles.actions}>
        <Absenden label={submitLabel} gross={gross ?? false} />
      </div>
    </form>
  );
}

function Absenden({ label, gross }: { label: string; gross?: boolean }) {
  const { pending } = useFormStatus();
  return (
    <button
      type="submit"
      className={gross ? styles.primaryGross : styles.primary}
      disabled={pending}
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
}: {
  aktion: () => Promise<ActionResult>;
  label: string;
  laufendLabel?: string;
  art?: "secondary" | "destructive";
  bestaetigung?: string;
  gross?: boolean;
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
        className={
          art === "destructive"
            ? gross
              ? styles.destructiveGross
              : styles.destructive
            : gross
              ? styles.secondaryGross
              : styles.secondary
        }
        disabled={laeuft}
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
