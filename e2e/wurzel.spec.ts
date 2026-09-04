import { expect, test } from "@playwright/test";
import { akzentflaechen, fehlermeldung, hauptlandmarken } from "./helpers/abnahme";
import { anmelden, adminClient, E2E_PASSWORD } from "./helpers/login";

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
