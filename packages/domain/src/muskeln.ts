/** Ein Muskel einer Uebung, wie ihn `exercises.muscles` (Migration 0056) ablegt. */
export type UebungsMuskel = {
  key: string;
  name: string;
  role: "primary" | "secondary";
};

/** Die Spalte ist `not null default '[]'`; null/fehlend wird trotzdem zu [], damit die Antwort nie null enthaelt. */
export function muskelnAusSpalte(wert: UebungsMuskel[] | null | undefined): UebungsMuskel[] {
  return Array.isArray(wert) ? wert : [];
}
