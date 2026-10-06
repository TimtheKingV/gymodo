import { expect, test, type Page } from "@playwright/test";
import { akzentflaechen } from "./helpers/abnahme";

/**
 * Spec 7.3 und 7.6. Die Zustandstabelle prueft kaufleiste.logik.test.ts;
 * hier geht es darum, dass Observer, Scroll und CSS im echten Browser
 * dasselbe tun.
 */
test.use({ viewport: { width: 390, height: 844 } });

// Per Locator statt getByRole: versteckt ist die Leiste aria-hidden und
// faellt damit aus dem Rollenbaum.
const leiste = (page: Page) => page.locator('aside[aria-label="Schnellzugriff"]');

async function nach(page: Page, y: number) {
  await page.evaluate((y) => window.scrollTo(0, y), y);
}

async function ankerUnterkante(page: Page) {
  return await page.locator("#held-aktion").evaluate((el) => el.getBoundingClientRect().bottom + window.scrollY);
}

test("versteckt beim Laden, erscheint hinter dem Hero-Knopf", async ({ page }) => {
  await page.goto("/");
  await expect(leiste(page)).toHaveAttribute("aria-hidden", "true");
  await expect(leiste(page)).not.toBeInViewport();
  await nach(page, (await ankerUnterkante(page)) + 10);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
  await expect(leiste(page)).toBeInViewport();
});

test("weicht beim Runterscrollen, kommt beim Hochscrollen", async ({ page }) => {
  await page.goto("/");
  const start = (await ankerUnterkante(page)) + 10;
  await nach(page, start);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
  await nach(page, start + 600);
  await expect(leiste(page)).not.toHaveAttribute("data-sichtbar", "");
  await nach(page, start + 500);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
});

test("weicht der CTA-Section und dem Fuss, auch beim Hochscrollen", async ({ page }) => {
  await page.goto("/");
  await nach(page, 100_000);
  await page.waitForTimeout(100);
  await page.evaluate(() => window.scrollBy(0, -40));
  await expect(leiste(page)).not.toHaveAttribute("data-sichtbar", "");

  const cta = await page.locator("#landung-cta").evaluate((el) => el.getBoundingClientRect().top + window.scrollY);
  await nach(page, cta + 200);
  await page.waitForTimeout(100);
  await nach(page, cta - 200);
  await expect(leiste(page)).not.toHaveAttribute("data-sichtbar", "");
});

test("versteckt nicht fokussierbar, sichtbar fokussierbar", async ({ page }) => {
  await page.goto("/");
  const link = leiste(page).getByRole("link", { name: "App laden", includeHidden: true });
  await link.focus();
  await expect(link).not.toBeFocused();

  await nach(page, (await ankerUnterkante(page)) + 10);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
  await link.focus();
  await expect(link).toBeFocused();

  // Der Fokus haelt die Leiste, auch wenn jetzt nach unten gescrollt wird.
  await page.evaluate(() => window.scrollBy(0, 600));
  await page.waitForTimeout(300);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
});

// Der Kopf deckt den Hero-Knopf nicht ab: 8 px Rand, runde Ecken und Glas
// mit 72 % lassen ihn durchscheinen. Die Leiste darf erst kommen, wenn er
// ganz aus dem Viewport ist (Spec 4.2).
test("am Hero-Knopf nie zwei Akzentflaechen, Schritt fuer Schritt", async ({ page }) => {
  await page.goto("/");
  const unterkante = await ankerUnterkante(page);
  for (let y = unterkante - 80; y <= unterkante + 40; y += 10) {
    await nach(page, y);
    await page.waitForTimeout(350);
    const f = await akzentflaechen(page, { nurViewport: true });
    expect(f.length, `y=${y}: ${f.join(", ")}`).toBeLessThanOrEqual(1);
  }
});
