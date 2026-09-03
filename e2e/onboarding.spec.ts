import { expect, test } from "@playwright/test";
import { latestOtpFor } from "./helpers/login";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Der Weg, den ein Mensch geht -- und den bis zum 3. September kein Test
 * ging: die uebrigen Dateien melden sich an und springen dann per goto auf
 * ihr Ziel. Genau deshalb blieb unbemerkt, dass "/" eine Sackgasse ist:
 * die M0-Rauchprobe ohne Stylesheet und ohne einen Link weiter.
 */
test("Ein Trainer landet nach der Anmeldung im Portal, ohne die Adresse zu kennen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "onboarding-trainer");

  // studioMitTrainer meldet an und wartet, bis die Login-Seite verlassen ist.
  // Ab hier wird NICHT navigiert -- gemessen wird, wo der Login hinfuehrt.
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}$`));
  await expect(page.getByRole("navigation", { name: "Katalog" })).toBeVisible();

  // Die nackte M0-Seite darf ein angemeldeter Trainer nie zu sehen bekommen.
  await expect(page.getByTestId("user-email")).toHaveCount(0);
});

/**
 * Der zweite Weg auf dieselbe Seite. Aufgabe 2 heilt ihn mit, und genau
 * deshalb steht er hier: eine mitgeheilte Strecke, die niemand nachmisst,
 * ist eine Behauptung.
 */
test("Nach dem Passwortwechsel steht ein Trainer im Portal, nicht im Schwarzen", async ({
  page,
}) => {
  const { email, studioId } = await studioMitTrainer(page, "onboarding-reset");

  const angefordert = new Date();
  await page.goto("/passwort-vergessen");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const code = await latestOtpFor(email, angefordert);
  await page.getByLabel("Code aus der E-Mail").fill(code);
  await page.getByLabel("Neues Passwort").fill("neues-passwort-1234");
  await page.getByRole("button", { name: "Passwort setzen" }).click();

  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}$`));
});
