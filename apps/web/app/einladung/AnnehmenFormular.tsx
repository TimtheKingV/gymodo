"use client";

import { useActionState } from "react";
import styles from "../einstieg/einstieg.module.css";
import { einladungAnnehmen } from "./actions";

export function AnnehmenFormular({ token }: { token: string }) {
  const [state, formAction, laeuft] = useActionState(einladungAnnehmen.bind(null, token), null);

  return (
    <form action={formAction}>
      {state ? (
        <p className={styles.fehlermeldung} role="alert">
          {state.error}
        </p>
      ) : null}
      <button type="submit" className={styles.knopf} disabled={laeuft}>
        {laeuft ? "Wird angenommen …" : "Einladung annehmen"}
      </button>
    </form>
  );
}
