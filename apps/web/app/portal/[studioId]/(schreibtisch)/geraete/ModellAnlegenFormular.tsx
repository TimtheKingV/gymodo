"use client";

import { AktionsFormular, Feld } from "../../../Form";
import { ModellGewichtRad } from "../../../bausteine/ModellGewichtRad";
import type { ActionResult } from "../../../actions";
import styles from "../../../portal.module.css";

/**
 * Name/Hersteller bleiben getippt -- nur Minimum/Maximum/Schritt kommen als
 * Rad (ModellGewichtRad), gleicher Stil wie bei den Einstellungen. Eigene
 * Datei, weil das Rad Client-Interaktion braucht und GeraetePage ein
 * Server-Component ist.
 */
export function ModellAnlegenFormular({
  action,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
}) {
  return (
    <AktionsFormular action={action} submitLabel="Modell anlegen">
      <div className={styles.grid}>
        <Feld name="name" label="Name" required placeholder="Latzug" />
        <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />
      </div>
      <ModellGewichtRad />
    </AktionsFormular>
  );
}
