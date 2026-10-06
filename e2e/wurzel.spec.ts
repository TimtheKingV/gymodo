import { expect, test } from "@playwright/test";
import { akzentflaechen, fehlermeldung, hauptlandmarken } from "./helpers/abnahme";
import { anmelden, adminClient, E2E_PASSWORD } from "./helpers/login";

/**
 * Die Wurzelseite ohne Konto. Bis zum 3. September stand hier "Nicht
 * angemeldet.", danach eine Landung fuer Trainer; seit Etappe 1 der neuen
 * Landeseite (Spec 2026-10-03) ist sie fuer Mitglieder da. Trainer finden
 * ihren Weg im Kopf und im Fuss.
 */
test("Ohne Konto: eine Hauptlandmarke und der Weg zur App", async ({ page }) => {
  await page.goto("/");
  expect(await hauptlandmarken(page)).toBe(1);
  await expect(page.getByRole("heading", { level: 1, name: "Nie wieder raten am Gerät." })).toBeVisible();
  const app = page.locator("#held-aktion");
  await expect(app).toHaveText("App laden");
  await expect(app).toHaveAttribute("href", /^https:\/\/apps\.apple\.com\//);
});

test("Hoechstens eine Akzentflaeche im Bild, an jeder Stelle der Seite", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const pruefen = async (wo: string) => {
    const f = await akzentflaechen(page, { nurViewport: true });
    expect(f.length, `${wo}: ${f.join(", ")}`).toBeLessThanOrEqual(1);
  };
  expect(await akzentflaechen(page, { nurViewport: true })).toHaveLength(1);
  for (const id of ["so-gehts", "landung-cta", "fragen", "landung-fuss"]) {
    await page.locator(`#${id}`).scrollIntoViewIfNeeded();
    // Kaufleiste: 240 ms Transition plus ein Frame.
    await page.waitForTimeout(400);
    await pruefen(id);
  }
});

// Mobil steht der Knopf unten im ersten Bild (Spec 2, Designsystem 4:
// Bedienbares im unteren Drittel). Das Bild nimmt nur den Platz, der
// zwischen Text und Knopf frei bleibt.
for (const [breite, hoehe] of [
  [390, 844],
  [375, 667],
] as const) {
  test(`Der Hero-Knopf steht auf ${breite} x ${hoehe} im ersten Bild`, async ({ page }) => {
    await page.setViewportSize({ width: breite, height: hoehe });
    await page.goto("/");
    await expect(page.locator("#held-aktion")).toBeInViewport({ ratio: 1 });
  });
}

test("Trainer kommen weiter zu Anmeldung und Konto", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("banner").getByRole("link", { name: "Anmelden", exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
  await page.goto("/");
  await page.getByRole("contentinfo").getByRole("link", { name: "Konto anlegen" }).click();
  await expect(page).toHaveURL(/\/registrieren$/);
});

/**
 * Befund 19 gilt weiter: die Produktgrenze steht sichtbar und in
 * text-muted, nicht in text-faint (Designsystem 2 und 10).
 */
test("Die Produktgrenze steht im Fuss, in text-muted", async ({ page }) => {
  await page.goto("/");
  const satz = page.getByRole("contentinfo").getByText(/Gymtavo misst nichts/);
  await satz.scrollIntoViewIfNeeded();
  await expect(satz).toBeVisible();
  expect(await satz.evaluate((el) => getComputedStyle(el).color)).toBe("rgb(155, 163, 175)");
});

test("Auf 320 px laeuft die ganze Landeseite nicht ueber", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await page.goto("/");
  for (const y of [0, 900, 1800, 100_000]) {
    await page.evaluate((y) => window.scrollTo(0, y), y);
    const ueberlauf = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(ueberlauf, `bei y=${y}`).toBe(0);
  }
});

/**
 * Der angemeldete Nicht-Mitarbeiter-Zweig: ein Konto ohne jede
 * Mitarbeiterrolle landet nicht im Portal, sondern hier -- entweder mit dem
 * Beitrittsformular (noch kein Studio) oder mit der Studioliste. Beide
 * Zustaende teilen den Kernsatz aus KeinStudio.dc.html, untere Haelfte ("Das
 * Portal ist fuer Studios, trainiert wird in der App") -- Titel und
 * Beitrittsaufforderung unterscheiden sich, weil nur der erste Zustand sie
 * noch braucht (Fix-Runde 1, Aufgabe 11).
 */
test("Ein Mitglied ohne Studio bekommt den Beitrittsweg und die Wahrheit dazu", async ({
  page,
}) => {
  const admin = adminClient();
  const email = `e2e-wurzel-mitglied-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await anmelden(page, email);

  expect(await hauptlandmarken(page)).toBe(1);
  await expect(page.getByTestId("beitritt-formular")).toBeVisible();
  await expect(page.getByLabel("Studio-Code")).toBeVisible();

  // Der Satz aus dem Artboard: das Web ist nicht der Ort zum Trainieren.
  await expect(page.getByText(/Trainieren läuft in der App/)).toBeVisible();
});

/**
 * Fix-Runde 1: bisher ungetestet. login.spec.ts meldet ein Konto mit
 * Studio an und prueft die Liste -- aber nie, was ueber ihr steht. Genau
 * dort stand bis eben "Noch kein Studio", waehrend die Liste darunter das
 * Gegenteil zeigte.
 */
test("Ein Mitglied mit Studio sieht seine Studioliste, nicht die Aufforderung beizutreten", async ({
  page,
}) => {
  const admin = adminClient();
  const email = `e2e-wurzel-hatstudio-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error: nutzerError } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (nutzerError) throw nutzerError;

  const studioName = `Wurzel-Mitglied-E2E-Studio-${crypto.randomUUID()}`;
  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: studioName })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { error: mitgliedschaftError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: nutzer.user.id, role: "member" });
  if (mitgliedschaftError) throw mitgliedschaftError;

  await anmelden(page, email);

  await expect(page.getByTestId("studio-list")).toContainText(studioName);

  // Die eigentliche Unwahrheit waere hier: eine Liste zeigen und im selben
  // Atemzug behaupten, es gaebe noch keine.
  await expect(page.getByRole("heading", { name: "Noch kein Studio" })).toHaveCount(0);
  await expect(page.getByTestId("beitritt-formular")).toHaveCount(0);
  await expect(page.getByText(/Aufkleber an einem Gerät scannst/)).toHaveCount(0);
});

test("Ein falscher Studio-Code meldet sich als Warnung", async ({ page }) => {
  const admin = adminClient();
  const email = `e2e-wurzel-code-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await anmelden(page, email);
  await page.getByLabel("Studio-Code").fill("GIBTESNICHT");
  await page.getByRole("button", { name: "Beitreten" }).click();

  // fehlermeldung() statt getByRole("alert"): Next legt einen leeren
  // Route-Announcer mit role="alert" ins Dokument, der Selektor ist damit
  // immer mehrdeutig -- und bricht genau im Fehlerfall ab.
  await expect(fehlermeldung(page)).toBeVisible();
});

/**
 * GYMTAVO-Wortmarke statt Textschriftzug. Als Bild mit Namen, damit
 * Screenreader die Marke lesen, und auf 320 px ohne Querscrollen --
 * der Kopf traegt links Marke, rechts "Anmelden" bei 48 px Rand.
 */
test("Die Landeseite zeigt die GYMTAVO-Wortmarke", async ({ page }) => {
  await page.goto("/");
  const marke = page.getByRole("banner").getByRole("img", { name: "GYMTAVO" });
  await expect(marke).toBeVisible();
  expect(await marke.evaluate((el: HTMLImageElement) => el.naturalWidth)).toBeGreaterThan(0);
});

test("Die Einstiegsseiten zeigen dieselbe Wortmarke", async ({ page }) => {
  await page.goto("/login");
  await expect(page.getByRole("banner").getByRole("img", { name: "GYMTAVO" })).toBeVisible();
});

test("Auf 320 px laeuft der Kopf der Landeseite nicht ueber", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await page.goto("/");
  const ueberlauf = await page.evaluate(
    () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
  );
  expect(ueberlauf).toBe(0);
  const knopf = page.getByRole("link", { name: "Anmelden", exact: true });
  await expect(knopf).toBeInViewport();

  // Kein Ueberlauf reicht nicht: bei 2 x 48 px Rand stiess der Punkt der
  // Marke am 03.10. ohne Luft an den Knopf.
  const marke = await page.getByRole("banner").getByRole("img", { name: "GYMTAVO" }).boundingBox();
  const ziel = await knopf.boundingBox();
  expect(ziel!.x - (marke!.x + marke!.width)).toBeGreaterThanOrEqual(16);
});

test("Der Browsertab heisst Gymtavo", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Gymtavo/);
});
