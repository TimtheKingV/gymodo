/**
 * Pflichtregel fuer den Gymtavo-Typ (Nachtrag 10.1) als reine Funktion --
 * die Server-Actions fragen nur noch `pflicht` ab (catalogTypeRequired) und
 * geben das Ergebnis weiter. Ohne Datenbank pruefbar, deshalb nicht in
 * actions.ts.
 */
export const TYP_FELD = "catalogModelId";

const PFLICHT =
  "Wähle den Gymtavo-Gerätetyp. Er bestimmt, welche Gymtavo-Übungen Mitglieder an diesem Gerät sehen.";

export function typAusFormular(
  formData: FormData,
  pflicht: boolean,
): { ok: true; catalogModelId: string | undefined } | { ok: false; error: string } {
  const wert = String(formData.get(TYP_FELD) ?? "").trim();
  if (wert.length > 0) return { ok: true, catalogModelId: wert };
  // Auch ein fehlendes Feld zaehlt als leer: das Formular kann geladen worden
  // sein, als der Katalog noch leer war.
  return pflicht ? { ok: false, error: PFLICHT } : { ok: true, catalogModelId: undefined };
}
