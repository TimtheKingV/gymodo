"use client";

import { useActionState } from "react";
import { Einstieg } from "../einstieg/Einstieg";
import { Feld } from "../portal/Form";
import styles from "../einstieg/einstieg.module.css";
import { anmelden } from "./actions";

/**
 * `weiter` ist der Rueckweg nach der Anmeldung -- heute nur die
 * Einladung (einladung/weiter.ts), sonst "/". Er reist als verstecktes
 * Feld mit, die Aktion prueft ihn noch einmal selbst.
 */
export function LoginFormular({ weiter }: { weiter: string }) {
  const [state, formAction] = useActionState(anmelden, null);
  const mitWeiter = weiter === "/" ? "" : `?weiter=${encodeURIComponent(weiter)}`;

  return (
    <Einstieg titel="Anmelden">
      <form action={formAction}>
        <input type="hidden" name="weiter" value={weiter} />
        <div className={styles.felder}>
          <Feld
            name="email"
            label="E-Mail"
            type="email"
            autoComplete="email"
            required
          />
          <Feld
            name="password"
            label="Passwort"
            type="password"
            autoComplete="current-password"
            required
          />
        </div>
        {state && "error" in state ? (
          <p className={styles.fehlermeldung} role="alert">
            {state.error}
          </p>
        ) : null}
        <button type="submit" className={styles.knopf}>
          Anmelden
        </button>
        <div className={styles.links}>
          <a href="/passwort-vergessen">Passwort vergessen</a>
          <a href={`/registrieren${mitWeiter}`}>Konto anlegen</a>
        </div>
      </form>
    </Einstieg>
  );
}
