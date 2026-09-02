"use client";

import { useActionState } from "react";
import { passwortVergessenAnfordern, passwortZuruecksetzen } from "./actions";

export default function PasswortVergessenPage() {
  const [anfordernState, anfordernAction] = useActionState(passwortVergessenAnfordern, null);
  const [zuruecksetzenState, zuruecksetzenAction] = useActionState(passwortZuruecksetzen, null);

  if (anfordernState && "sentTo" in anfordernState && anfordernState.sentTo) {
    return (
      <form action={zuruecksetzenAction}>
        <input type="hidden" name="email" value={anfordernState.sentTo} />
        <label htmlFor="token">Code aus der E-Mail</label>
        <input id="token" name="token" inputMode="numeric" required />
        <label htmlFor="password">Neues Passwort</label>
        <input id="password" name="password" type="password" required />
        <button type="submit">Passwort setzen</button>
        {zuruecksetzenState && "error" in zuruecksetzenState && <p>{zuruecksetzenState.error}</p>}
      </form>
    );
  }

  return (
    <form action={anfordernAction}>
      <label htmlFor="email">E-Mail</label>
      <input id="email" name="email" type="email" required />
      <button type="submit">Code anfordern</button>
      {anfordernState && "error" in anfordernState && <p>{anfordernState.error}</p>}
    </form>
  );
}
