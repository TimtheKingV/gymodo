"use client";

import { useActionState } from "react";
import { Feld } from "./portal/Form";
import styles from "./einstieg/einstieg.module.css";
import { beitreten } from "./actions";

export function BeitrittsFormular() {
  const [state, formAction] = useActionState(beitreten, null);

  return (
    <form action={formAction} data-testid="beitritt-formular">
      <div className={styles.felder}>
        <Feld name="code" label="Studio-Code" required autoCapitalize="characters" />
      </div>
      {state && !state.ok ? (
        <p className={styles.fehlermeldung} role="alert">
          {state.error}
        </p>
      ) : null}
      <button type="submit" className={styles.knopf}>
        Beitreten
      </button>
    </form>
  );
}
