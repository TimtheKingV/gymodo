import { expect, test } from "@playwright/test";
import { hauptlandmarken } from "./helpers/abnahme";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Die Landmarke ist die einzige der drei Abnahmen, die heute schon rot ist.
 *
 * Betroffen sind vier der sechs geprueften Seiten -- die, die ein eigenes
 * <main className={styles.content}> im <main> des Layouts rendern:
 * (schreibtisch)/page.tsx, leute, einstellungen und einstellungen/konto.
 * Die uebrigen zwei, geraete und tags, tragen an derselben Stelle ein
 * <div> und liefern heute schon 1.
 *
 * Geprueft werden trotzdem alle sechs: nach Aufgabe 4 gehoert die
 * Landmarke dem Layout allein, und dann muss jede Seite genau eine haben --
 * auch die, die vorher unauffaellig waren. Der Lauf bricht beim ersten
 * Fehlschlag ab, deshalb belegt ein roter Lauf nur den ersten Fall, nicht
 * alle vier.
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
