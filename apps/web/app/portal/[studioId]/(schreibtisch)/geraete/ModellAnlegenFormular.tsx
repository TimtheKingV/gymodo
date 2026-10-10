"use client";

import type { Category } from "@fitretro/domain/belastung";
import { AktionsFormular } from "../../../Form";
import { ModellVorlageFelder } from "../../../bausteine/ModellVorlageFelder";
import type { TypVorlage } from "../../../bausteine/typVorlage";
import type { ActionResult } from "../../../actions";

/**
 * Name/Hersteller bleiben getippt -- Kategorie, Belastung, Rastung und
 * Nebenbelastung kommen aus ModellBelastungRad, gleicher Stil wie bei den
 * Einstellungen. Name und Belastung fuellt der Gymtavo-Typ vor
 * (ModellVorlageFelder). Eigene
 * Datei, weil das Rad Client-Interaktion braucht und GeraetePage ein
 * Server-Component ist.
 *
 * Schritt 1 des Ablaufs "Gerät hinzufügen" (geraete/neu): der Knopf heisst
 * "Weiter", weil das Anlegen hier kein Ende ist -- danach kommen
 * Einstellungen, Uebungen und die einzelnen Geraete (Testnotiz 23.09., #7).
 *
 * Kraft oder Cardio ist vorher gefragt (Testnotiz 03.10., #1) und kommt
 * fest herein -- das Formular zeigt nur die passenden Einheiten und Typen.
 */
export function ModellAnlegenFormular({
  action,
  kategorie,
  typen,
}: {
  action: (prev: unknown, formData: FormData) => Promise<ActionResult>;
  kategorie: Category;
  typen: TypVorlage[];
}) {
  return (
    <AktionsFormular action={action} submitLabel="Weiter">
      <ModellVorlageFelder typen={typen} kategorie={kategorie} />
    </AktionsFormular>
  );
}
