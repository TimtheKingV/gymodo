"use client";

import { useActionState } from "react";
import { anmelden } from "./actions";

export default function LoginPage() {
  const [state, formAction] = useActionState(anmelden, null);

  return (
    <form action={formAction}>
      <label htmlFor="email">E-Mail</label>
      <input id="email" name="email" type="email" required />
      <label htmlFor="password">Passwort</label>
      <input id="password" name="password" type="password" required />
      <button type="submit">Anmelden</button>
      {state && "error" in state && <p>{state.error}</p>}
      <p>
        Kein Konto? <a href="/registrieren">Registrieren</a> ·{" "}
        <a href="/passwort-vergessen">Passwort vergessen?</a>
      </p>
    </form>
  );
}
