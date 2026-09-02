"use client";

import { useActionState } from "react";
import { registrieren, registrierungBestaetigen } from "./actions";

export default function RegistrierenPage() {
  const [registrierenState, registrierenAction] = useActionState(registrieren, null);
  const [bestaetigenState, bestaetigenAction] = useActionState(registrierungBestaetigen, null);

  if (registrierenState && "sentTo" in registrierenState && registrierenState.sentTo) {
    return (
      <form action={bestaetigenAction}>
        <input type="hidden" name="email" value={registrierenState.sentTo} />
        <label htmlFor="token">Code aus der E-Mail</label>
        <input id="token" name="token" inputMode="numeric" required />
        <button type="submit">Konto bestaetigen</button>
        {bestaetigenState && "error" in bestaetigenState && <p>{bestaetigenState.error}</p>}
      </form>
    );
  }

  return (
    <form action={registrierenAction}>
      <label htmlFor="email">E-Mail</label>
      <input id="email" name="email" type="email" required />
      <label htmlFor="password">Passwort</label>
      <input id="password" name="password" type="password" required />
      <button type="submit">Konto anlegen</button>
      {registrierenState && "error" in registrierenState && <p>{registrierenState.error}</p>}
      <p>
        Schon ein Konto? <a href="/login">Anmelden</a>
      </p>
    </form>
  );
}
