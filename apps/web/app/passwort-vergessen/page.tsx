"use client";

import { useActionState } from "react";
import { Einstieg } from "../einstieg/Einstieg";
import { Feld } from "../portal/Form";
import styles from "../einstieg/einstieg.module.css";
import { passwortVergessenAnfordern, passwortZuruecksetzen } from "./actions";

/**
 * Ein Ablauf, kein Ortswechsel: zwei Artboards (PasswortVergessen.dc.html,
 * PasswortNeu.dc.html), eine Route -- dasselbe Muster wie registrieren.
 *
 * PasswortVergessen.dc.html zeichnet "Link anfordern". Der Code schickt
 * einen sechsstelligen Code, den e2e/onboarding.spec.ts aus Mailpit liest --
 * der Knopf bleibt "Code anfordern", wie er heute schon heisst.
 *
 * PasswortNeu.dc.html zeigt Neues Passwort und Wiederholen, aber kein
 * Codefeld. Ohne den Code funktioniert der laufende Weg nicht, das Feld
 * bleibt. Das Artboard beschriftet den Knopf "Passwort speichern" -- der
 * Code (und die Tests, die ihn pruefen) nennen ihn "Passwort setzen"; dabei
 * bleibt es aus demselben Grund wie beim Knopf oben.
 */
export default function PasswortVergessenPage() {
  const [anfordernState, anfordernAction] = useActionState(passwortVergessenAnfordern, null);
  const [zuruecksetzenState, zuruecksetzenAction] = useActionState(passwortZuruecksetzen, null);

  if (anfordernState && "sentTo" in anfordernState && anfordernState.sentTo) {
    const adresse = anfordernState.sentTo;
    return (
      <Einstieg titel="Neues Passwort">
        <form action={zuruecksetzenAction}>
          <input type="hidden" name="email" value={adresse} />
          <div className={styles.felder}>
            <Feld
              name="token"
              label="Code aus der E-Mail"
              inputMode="numeric"
              autoComplete="one-time-code"
              required
            />
            <Feld
              name="password"
              label="Neues Passwort"
              type="password"
              autoComplete="new-password"
              required
              hint="Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen."
            />
            <Feld
              name="password2"
              label="Wiederholen"
              type="password"
              autoComplete="new-password"
              required
            />
          </div>
          {zuruecksetzenState && "error" in zuruecksetzenState ? (
            <p className={styles.fehlermeldung} role="alert">
              {zuruecksetzenState.error}
            </p>
          ) : null}
          <button type="submit" className={styles.knopf}>
            Passwort setzen
          </button>
        </form>
      </Einstieg>
    );
  }

  return (
    <Einstieg
      titel="Passwort vergessen"
      fuss={
        <p className={styles.hinweis}>
          Wenn es zu dieser Adresse ein Konto gibt, ist die Mail unterwegs.
        </p>
      }
    >
      <form action={anfordernAction}>
        <div className={styles.felder}>
          <Feld name="email" label="E-Mail" type="email" autoComplete="email" required />
        </div>
        {anfordernState && "error" in anfordernState ? (
          <p className={styles.fehlermeldung} role="alert">
            {anfordernState.error}
          </p>
        ) : null}
        <button type="submit" className={styles.knopf}>
          Code anfordern
        </button>
      </form>
    </Einstieg>
  );
}
