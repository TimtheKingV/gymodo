import { expect, test } from "@playwright/test";
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
