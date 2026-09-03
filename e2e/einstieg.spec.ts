import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";

/**
 * Der Einstieg wird ohne Konto geprueft -- das ist sein Normalfall. Kein
 * studioMitTrainer, keine Anmeldung: wer hier steht, hat noch nichts.
 */
test("Die Anmeldeseite traegt eine Landmarke, eine Akzentflaeche und lesbare Namen", async ({
  page,
}) => {
  await page.goto("/login");

  expect(await hauptlandmarken(page)).toBe(1);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);

  // Die Namen, an denen sechs Testdateien haengen. Sie sind ab hier
  // Schnittstelle, nicht Beschriftung.
  await expect(page.getByLabel("E-Mail")).toBeVisible();
  await expect(page.getByLabel("Passwort")).toBeVisible();
  await expect(page.getByRole("button", { name: "Anmelden" })).toBeVisible();

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu klein: ${zuKlein.join(", ")}`).toHaveLength(0);
});

test("Von der Anmeldung fuehren beide Wege weiter, die das Artboard zeichnet", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByRole("link", { name: "Konto anlegen" }).click();
  await expect(page).toHaveURL(/\/registrieren$/);

  await page.goto("/login");
  await page.getByRole("link", { name: "Passwort vergessen" }).click();
  await expect(page).toHaveURL(/\/passwort-vergessen$/);
});

test("Ein falsches Passwort meldet sich als Warnung, nicht als stiller Text", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill("gibt-es-nicht@example.test");
  await page.getByLabel("Passwort").fill("falsch-falsch-falsch");
  await page.getByRole("button", { name: "Anmelden" }).click();

  await expect(page.getByRole("alert")).toBeVisible();
  await expect(page).toHaveURL(/\/login$/);
});
