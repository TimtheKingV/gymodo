import type { Locator, Page } from "@playwright/test";

/**
 * Eine Zeile in der eigenen Auswahl-Komponente waehlen
 * (bausteine/Auswahl.tsx) -- ersetzt `.selectOption(...)` fuer die fuenf
 * nativen `<select>`, die jetzt ein eigenes Panel statt der
 * Betriebssystem-Liste oeffnen. `ausloeser` ist der sichtbare Knopf (z. B.
 * `page.getByRole("button", { name: "Art" })`), `anzeige` der angezeigte
 * Text der Zielzeile.
 */
export async function auswaehlen(page: Page, ausloeser: Locator, anzeige: string) {
  await ausloeser.click();
  await page.getByRole("option", { name: anzeige, exact: true }).click();
}
