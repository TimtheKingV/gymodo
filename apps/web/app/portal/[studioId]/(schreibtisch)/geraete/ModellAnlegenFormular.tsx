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
 *
 * Schritt 1 des Ablaufs "Gerät hinzufügen" (geraete/neu): der Knopf heisst
 * "Weiter", weil das Anlegen hier kein Ende ist -- danach kommen
 * Einstellungen, Uebungen und die einzelnen Geraete (Testnotiz 23.09., #7).
 */
export function ModellAnlegenFormular({
  action,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
}) {
  return (
    <AktionsFormular action={action} submitLabel="Weiter">
      <div className={styles.grid}>
        <Feld name="name" label="Name" required placeholder="Latzug" />
        <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />
      </div>
      <ModellGewichtRad />
    </AktionsFormular>
  );
}
