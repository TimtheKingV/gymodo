"use client";

import { useActionState } from "react";
import { beitreten } from "./actions";

export function BeitrittsFormular() {
  const [state, formAction] = useActionState(beitreten, null);

  return (
    <form action={formAction} data-testid="beitritt-formular">
      <p>Du bist noch in keinem Studio Mitglied.</p>
      <label htmlFor="code">Studio-Code</label>
      <input id="code" name="code" required autoCapitalize="characters" />
      <button type="submit">Beitreten</button>
      {state && !state.ok && <p>{state.error}</p>}
    </form>
  );
}
