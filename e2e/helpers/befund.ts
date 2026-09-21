import type { Page } from "@playwright/test";
import { fehlermeldung } from "./abnahme";

/**
 * Der Seitenabzug in den Fehlertext, nicht ins Artefakt.
 *
 * Die error-context.md aus dem Playwright-Artefakt ist aus der
 * Arbeitsumgebung nicht ladbar (Egress-Policy) -- ein roter Lauf sagt dann
 * nur, DASS etwas fehlte. Das hat schon mehrere Runden gekostet: der
 * Einstellungs-Schritt in trainerportal.spec.ts trug deshalb seit dem
 * 17. September seinen eigenen Abzug (ea0ba76). Hier steht er einmal, statt
 * an jeder Stelle neu.
 *
 * Ohne die option-Zeilen: die Raeder tragen je bis zu 202 Werte, und
 * vierhundert Zeilen Rauschen verdecken die Auskunft. Ohne <main> --
 * etwa auf der 404-Seite -- faellt der Abzug auf den Rumpf zurueck, denn
 * genau dort will man wissen, WELCHE Seite dastand.
 */
export async function seitenBefund(page: Page, satz: string): Promise<Error> {
  const meldungen = fehlermeldung(page);
  const haupt = page.getByRole("main");
  const wurzel = (await haupt.count()) === 1 ? haupt : page.locator("body");
  const abzug = (await wurzel.ariaSnapshot())
    .split("\n")
    .filter((zeile) => !/^\s*- option "/.test(zeile))
    .join("\n");

  return new Error(
    [
      satz,
      `Adresse: ${page.url()}`,
      `Meldungen (${await meldungen.count()}): ${JSON.stringify(await meldungen.allInnerTexts())}`,
      `Seite:\n${abzug}`,
    ].join("\n"),
  );
}
