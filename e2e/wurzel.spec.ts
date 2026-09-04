import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken } from "./helpers/abnahme";

/**
 * Die Wurzelseite ohne Konto. Bis zum 3. September stand hier "Nicht
 * angemeldet." und sonst nichts -- die erste Seite, die ein Mensch von
 * gymodo im Web sieht, war ein Satz auf schwarzem Grund.
 */
test("Wer ohne Konto auf die Wurzelseite kommt, findet beide Wege hinein", async ({ page }) => {
  await page.goto("/");

  expect(await hauptlandmarken(page)).toBe(1);

  // Genau eine Akzentflaeche: die Hauptaktion. "Konto anlegen" steht
  // daneben als Nebenaktion, nicht als zweiter Akzent -- zwei Flaechen
  // wuerden beide behaupten, DER Weg zu sein.
  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);

  await page.getByRole("link", { name: "Als Trainer anmelden" }).click();
  await expect(page).toHaveURL(/\/login$/);

  await page.goto("/");
  await page.getByRole("link", { name: "Konto anlegen" }).click();
  await expect(page).toHaveURL(/\/registrieren$/);
});

test("Die Landeseite nennt die Produktgrenze, ohne dass man danach sucht", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByText(/gymodo misst nichts/)).toBeVisible();
});

test("Sie sagt einem Mitglied, dass es im Web nichts zu tun hat", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByText(/im Web gibt es nichts für dich zu tun/)).toBeVisible();
});
