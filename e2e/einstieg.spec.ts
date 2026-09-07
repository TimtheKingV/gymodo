import { expect, test } from "@playwright/test";
import {
  akzentflaechen,
  fehlermeldung,
  hauptlandmarken,
  zuKleineBedienelemente,
} from "./helpers/abnahme";
import { E2E_PASSWORD, adminClient, anmelden, latestOtpFor } from "./helpers/login";

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

  await expect(fehlermeldung(page)).toBeVisible();
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

  const meldung = fehlermeldung(page);
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

  const meldung = fehlermeldung(page);
  await expect(meldung).toBeVisible();
  await expect(meldung).toContainText(/stimmen nicht überein/);
  await expect(page).toHaveURL(/\/passwort-vergessen$/);
});

/*
 * /portal ist zwei Bildschirme auf einer Route, nicht zwei Zustaende
 * derselben Seite (Aufgabe-9-Brief): "kein Studio" bekommt die Einstieg-
 * Huelle, die Studiowahl die Portal-Bausteine. Beide Faelle brauchen daher
 * ein angemeldetes Konto -- anders als der Rest dieser Datei, die den
 * Einstieg bewusst ohne Konto prueft.
 */

test("Ein Konto ohne Studio erfaehrt, was fehlt und wer es beheben kann", async ({ page }) => {
  const admin = adminClient();
  const email = `e2e-ohne-studio-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await anmelden(page, email);
  await page.goto("/portal");

  await expect(page.getByRole("heading", { name: "Noch kein Studio" })).toBeVisible();
  await expect(page.getByText(/als Mitarbeiter hinzufügen/)).toBeVisible();
  // Der Weg heraus wird benannt, nicht verschwiegen.
  await expect(page.getByText(/Leute/)).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);
});

test("Ein Konto in mehreren Studios waehlt aus einer Liste, nicht aus einer Vorlage", async ({
  page,
}) => {
  const admin = adminClient();
  const email = `e2e-mehrere-studios-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error: nutzerError } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (nutzerError) throw nutzerError;

  const { data: studioEins, error: studioEinsError } = await admin
    .from("studios")
    .insert({ name: `E2E Studio Eins ${crypto.randomUUID()}` })
    .select("id")
    .single();
  if (studioEinsError) throw studioEinsError;

  const { data: studioZwei, error: studioZweiError } = await admin
    .from("studios")
    .insert({ name: `E2E Studio Zwei ${crypto.randomUUID()}` })
    .select("id")
    .single();
  if (studioZweiError) throw studioZweiError;

  const { error: mitgliedschaftenError } = await admin.from("studio_memberships").insert([
    { studio_id: studioEins.id, user_id: nutzer.user.id, role: "trainer" },
    { studio_id: studioZwei.id, user_id: nutzer.user.id, role: "trainer" },
  ]);
  if (mitgliedschaftenError) throw mitgliedschaftenError;

  await anmelden(page, email);
  await page.goto("/portal");

  await expect(page).toHaveURL(/\/portal$/);
  await expect(page.getByRole("heading", { name: "Studio wählen" })).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);

  // Zwei Zeilen, eine je Studio -- keine Weiterleitung, weil keins der
  // beiden Studios allein steht.
  await expect(page.getByRole("link", { name: "Öffnen" })).toHaveCount(2);
});
