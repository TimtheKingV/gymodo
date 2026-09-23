"use client";

import { createContext, useContext } from "react";

/**
 * Meldeweg von einem Anlege-Formular (Hinzufuegen.tsx) hinauf in den
 * Ablauf "Gerät hinzufügen" (ModellRahmen.tsx): Steht das Formular offen,
 * gibt es unten kein "Weiter" (Testnotiz 23.09., zweite Sitzung, #1).
 *
 * Ein Kontext statt eines Props, weil dazwischen die Reiterseite liegt --
 * eine Server-Komponente, die keine Funktionen weiterreichen kann. Ohne
 * Anbieter (ausserhalb des Ablaufs) meldet das Formular ins Leere.
 */
export const FormularOffenKontext = createContext<(offen: boolean) => void>(() => {});

export function useFormularOffen(): (offen: boolean) => void {
  return useContext(FormularOffenKontext);
}
