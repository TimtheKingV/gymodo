import { expect, test, type Page } from "@playwright/test";

/** Kartenmitte auf einen Anteil der Viewporthoehe scrollen. */
async function karteAuf(page: Page, anteil: number) {
  await page.getByTestId("ohnemit-karte").evaluate((el, anteil) => {
    const r = el.getBoundingClientRect();
    window.scrollTo(0, window.scrollY + r.top + r.height / 2 - window.innerHeight * anteil);
  }, anteil);
}

test.use({ viewport: { width: 390, height: 844 } });

test("Ohne/Mit schaltet beim Scrollen in beide Richtungen", async ({ page }) => {
  await page.goto("/");
  const schalter = page.getByRole("switch", { name: "Mit Gymtavo" });
  await expect(schalter).toHaveAttribute("aria-checked", "false");
  await karteAuf(page, 0.3);
  await expect(schalter).toHaveAttribute("aria-checked", "true");
  await page.evaluate(() => window.scrollTo(0, 0));
  await karteAuf(page, 0.8);
  await expect(schalter).toHaveAttribute("aria-checked", "false");
});

test("Ein Tipp haelt, bis die Karte den Bildschirm verlaesst", async ({ page }) => {
  await page.goto("/");
  const schalter = page.getByRole("switch", { name: "Mit Gymtavo" });
  await karteAuf(page, 0.8);
  await schalter.click();
  await expect(schalter).toHaveAttribute("aria-checked", "true");
  await karteAuf(page, 0.75);
  await page.waitForTimeout(200);
  await expect(schalter).toHaveAttribute("aria-checked", "true");
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect(schalter).toHaveAttribute("aria-checked", "false");
});

test("Mit reduzierter Bewegung steht der Feed als Liste da", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await karteAuf(page, 0.3);
  const feed = page.getByRole("list", { name: "Mit Gymtavo" });
  for (const text of ["Sitz 5 · Lehne 3", "Zuletzt 42,5 kg × 10", "Vorschlag +2,5 kg", "Einweisung ansehen"]) {
    await expect(feed.getByText(text)).toBeInViewport();
  }
});
