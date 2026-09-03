"use client";

import { useActionState } from "react";
import { Einstieg } from "../einstieg/Einstieg";
import { Feld } from "../portal/Form";
import styles from "../einstieg/einstieg.module.css";
import { anmelden } from "./actions";

export default function LoginPage() {
  const [state, formAction] = useActionState(anmelden, null);

  return (
    <Einstieg titel="Anmelden">
      <form action={formAction}>
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
          <a href="/registrieren">Konto anlegen</a>
        </div>
      </form>
    </Einstieg>
  );
}
