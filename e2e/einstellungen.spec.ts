import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./helpers/login";

/**
 * Der Gang durch die Einstellungen: Stammdaten speichern, Stornofrist
 * setzen, Code erneuern, Passwort aendern. Was hier belegt wird, ist der
 * Weg des Trainers durch die Oberflaeche -- die Grenzen selbst stehen in
 * tests/integration/rls-studio-einstellungen.test.ts.
 */
test("ein Trainer pflegt die Studio-Einstellungen", async ({ page }) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `einst-${crypto.randomUUID()}@example.test`;
  const { data: user, error: userError } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Einstellungen E2E Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await admin.from("studio_memberships").insert({
    studio_id: studio.id,
    user_id: user.user.id,
    role: "trainer",
  });
  if (membershipError) throw membershipError;

  await anmelden(page, email);
  await page.goto(`/portal/${studio.id}/einstellungen`);

  // Stammdaten und Stornofrist -- ein Formular, ein Knopf.
  await expect(page.getByRole("heading", { name: "Einstellungen" })).toBeVisible();
  await page.getByLabel("Name").fill("Kraftwerk Nord");
  await page.getByLabel("Stornofrist").fill("6");
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  // Die Server Action laeuft asynchron und der Knopf zeigt waehrenddessen
  // "Wird gespeichert ...". Ohne auf die Rueckkehr der Beschriftung zu
  // warten, reisst ein sofortiges reload() die noch laufende Anfrage ab,
  // und die Werte blieben die alten -- unter Last (paralleler Testlauf)
  // reicht ein blosses networkidle dafuer nicht zuverlaessig.
  await expect(page.getByRole("button", { name: "Änderungen speichern" })).toBeEnabled();

  await page.reload();
  await expect(page.getByLabel("Name")).toHaveValue("Kraftwerk Nord");
  await expect(page.getByLabel("Stornofrist")).toHaveValue("6");

  // Die Fehlermeldung sagt, was gilt -- nicht nur, dass es nicht ging.
  // getByRole("alert") allein ist mehrdeutig: Next legt zusaetzlich einen
  // leeren Route-Announcer mit role="alert" ins Dokument. Der Filter auf den
  // erwarteten Text laesst nur die echte Fehlermeldung durch.
  await page.getByLabel("Stornofrist").fill("200");
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  await expect(page.getByRole("alert").filter({ hasText: "168" })).toContainText("168");

  // Der Code erneuert sich: nach dem Erzeugen steht der alte nicht mehr
  // auf der Seite. Dass er auch beim Beitritt nicht mehr traegt, prueft
  // die Fachschicht (tests/integration), nicht dieser Durchgang.
  await page.reload();
  await expect(page.getByText(studio.join_code)).toBeVisible();
  await page.getByRole("button", { name: "Neuen Code erzeugen" }).click();
  await page.getByRole("button", { name: /Wirklich/ }).click();
  await expect(page.getByText(studio.join_code)).toBeHidden();

  // Der Reiter Konto: Passwort aendern.
  await page.getByRole("link", { name: "Konto" }).click();
  await expect(page.getByText(email)).toBeVisible();

  const neuesPasswort = `e2e-neu-${crypto.randomUUID()}`;
  await page.getByLabel("Aktuelles Passwort").fill(E2E_PASSWORD);
  await page.getByLabel("Neues Passwort").fill(neuesPasswort);
  await page.getByLabel("Wiederholen").fill(neuesPasswort);
  await page.getByRole("button", { name: "Passwort ändern" }).click();
  await expect(page.getByText("Das Passwort ist geändert.")).toBeVisible();

  // Die Erfolgsmeldung allein beweist nichts -- sie stuende auch bei einem
  // reinen Anzeigefehler da. Ein frischer anon-Client prueft beide
  // Richtungen: das alte Passwort muss abgewiesen werden, das neue muss
  // tragen. Nur beide Haelften zusammen beweisen die Aenderung -- die eine
  // allein liesse auch ein kaputtes oder ein unveraendertes Konto zu.
  const anon = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_ANON_KEY!,
    { auth: { persistSession: false } },
  );

  // Das alte Passwort traegt nicht mehr ...
  const { error: altFehler } = await anon.auth.signInWithPassword({
    email,
    password: E2E_PASSWORD,
  });
  expect(altFehler).not.toBeNull();

  // ... und das neue traegt.
  const { error: neuFehler } = await anon.auth.signInWithPassword({
    email,
    password: neuesPasswort,
  });
  expect(neuFehler).toBeNull();

  await page.getByRole("button", { name: "Abmelden" }).click();
  await expect(page).toHaveURL(/\/login/);
});
