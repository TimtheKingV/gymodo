"use client";

import type { Category } from "@fitretro/domain/belastung";
import { AktionsFormular, Feld } from "../../../Form";
import { ModellBelastungRad } from "../../../bausteine/ModellBelastungRad";
import type { ActionResult } from "../../../actions";
import styles from "../../../portal.module.css";

/**
 * Name/Hersteller bleiben getippt -- Kategorie, Belastung, Rastung und
 * Nebenbelastung kommen aus ModellBelastungRad, gleicher Stil wie bei den
 * Einstellungen. Eigene
 * Datei, weil das Rad Client-Interaktion braucht und GeraetePage ein
 * Server-Component ist.
 *
 * Schritt 1 des Ablaufs "Gerät hinzufügen" (geraete/neu): der Knopf heisst
 * "Weiter", weil das Anlegen hier kein Ende ist -- danach kommen
 * Einstellungen, Uebungen und die einzelnen Geraete (Testnotiz 23.09., #7).
 *
 * Kraft oder Cardio ist vorher gefragt (Testnotiz 03.10., #1) und kommt
 * fest herein -- das Formular zeigt nur die passenden Einheiten.
 */
export function ModellAnlegenFormular({
  action,
  kategorie,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  kategorie: Category;
}) {
  return (
    <AktionsFormular action={action} submitLabel="Weiter">
      <div className={styles.grid}>
        <Feld name="name" label="Name" required placeholder="Latzug" />
        <Feld name="manufacturer" label="Hersteller" placeholder="Technogym" />
      </div>
      <ModellBelastungRad kategorie={kategorie} />
    </AktionsFormular>
  );
}
