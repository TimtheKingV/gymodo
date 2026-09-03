import { expect, test } from "@playwright/test";
import { hauptlandmarken } from "./helpers/abnahme";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Die Landmarke ist die einzige der drei Abnahmen, die heute schon rot ist
 * -- und sie ist es auf jeder Schreibtischseite gleichzeitig. Aufgabe 4
 * heilt sie an einer Stelle: die Seiten geben ihr <main> ab, das Layout
 * behaelt seines.
 */
test("Jede Schreibtischseite hat genau eine Hauptlandmarke", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-landmarke");

  for (const pfad of ["", "/geraete", "/tags", "/leute", "/einstellungen", "/einstellungen/konto"]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    expect(
      await hauptlandmarken(page),
      `/portal/<id>${pfad} traegt nicht genau eine <main>-Landmarke`,
    ).toBe(1);
  }
});
