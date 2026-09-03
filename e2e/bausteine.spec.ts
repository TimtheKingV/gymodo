import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";
import { studioMitMitglied, studioMitTrainer } from "./helpers/studio";

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

/**
 * Aufgabe 5: die Tags-Seite als Referenz. Sie hat keine Hauptaktion und
 * traegt deshalb keine Akzentflaeche -- die ungewoehnlichste Akzentzahl im
 * Portal (Canvas-Notiz note-akzent).
 */
test("Die Tags-Seite traegt keine Akzentflaeche -- sie legt nichts an", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags");
  await page.goto(`/portal/${studioId}/tags`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `zu viele Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(0);
});

test("Ein Studio ohne Tags sagt, was zu tun ist, statt eine leere Liste zu zeigen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags-leer");
  await page.goto(`/portal/${studioId}/tags`);

  await expect(page.getByText("Noch keine Lieferung")).toBeVisible();
  await expect(page.locator("[role=alert]")).toHaveCount(0);
});

test("Ein Mitglied sieht auf der Tags-Seite einen Satz, keinen Absturz", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "abnahme-tags-recht");
  await page.goto(`/portal/${studioId}/tags`);

  await expect(page.getByRole("heading", { name: "Tags" })).toBeVisible();
  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
});

test("Die Bedienelemente der Tags-Seite sind gross genug zum Treffen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags-treffer");
  await page.goto(`/portal/${studioId}/tags`);

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu kleine Bedienelemente: ${zuKlein.join(", ")}`).toHaveLength(0);
});
