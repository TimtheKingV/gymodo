import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";
import { E2E_PASSWORD, adminClient, latestOtpFor } from "./helpers/login";

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

test("Registrieren nennt die Passwortregel, bevor sie jemand verletzt", async ({ page }) => {
  await page.goto("/registrieren");

  expect(await hauptlandmarken(page)).toBe(1);
  expect(await akzentflaechen(page)).toHaveLength(1);

  // Zehn Zeichen sind seit dem 3. September der Mindestwert -- der Push der
  // Mailvorlagen hob minimum_password_length von 6 auf 10. Wer das erst
  // nach dem Absenden erfaehrt, tippt zweimal.
  await expect(page.getByText(/Mindestens zehn Zeichen/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Konto anlegen" })).toBeVisible();
});

test("Ein zu kurzes Passwort sagt, was gilt -- nicht nur, dass etwas falsch ist", async ({
  page,
}) => {
  await page.goto("/registrieren");
  await page.getByLabel("E-Mail").fill(`kurz-${crypto.randomUUID()}@example.test`);
  await page.getByLabel("Passwort").fill("kurz");
  await page.getByRole("button", { name: "Konto anlegen" }).click();

  const meldung = page.getByRole("alert");
  await expect(meldung).toBeVisible();
  await expect(meldung).toContainText(/zehn|10/);
});

test("Passwort vergessen fordert einen Code an, keinen Link", async ({ page }) => {
  await page.goto("/passwort-vergessen");

  expect(await hauptlandmarken(page)).toBe(1);
  await expect(page.getByRole("button", { name: "Code anfordern" })).toBeVisible();

  // Der Satz aus dem Artboard: er sagt bewusst nicht, ob es das Konto gibt.
  await expect(page.getByText(/ist die Mail unterwegs/)).toBeVisible();
});

test("Zwei verschiedene neue Passwoerter werden abgelehnt, bevor eines gesetzt wird", async ({
  page,
}) => {
  const admin = adminClient();
  const email = `e2e-wiederholen-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  const angefordert = new Date();
  await page.goto("/passwort-vergessen");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const code = await latestOtpFor(email, angefordert);
  await page.getByLabel("Code aus der E-Mail").fill(code);
  await page.getByLabel("Neues Passwort").fill("passwort-eins-1234");
  await page.getByLabel("Wiederholen").fill("passwort-zwei-1234");
  await page.getByRole("button", { name: "Passwort setzen" }).click();

  const meldung = page.getByRole("alert");
  await expect(meldung).toBeVisible();
  await expect(meldung).toContainText(/stimmen nicht überein/);
  await expect(page).toHaveURL(/\/passwort-vergessen$/);
});
