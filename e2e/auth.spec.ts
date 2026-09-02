import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden, latestOtpFor } from "./helpers/login";

/**
 * Lokal steht SUPABASE_AUTH_EMAIL_ENABLE_CONFIRMATIONS auf false
 * (.env.example) -- signUp liefert dort sofort eine Session, und die
 * Codeseite erscheint nie. Dieser Test prueft deshalb den lokalen Pfad; der
 * Codezweig aus registrierungBestaetigen ist derselbe verifyOtp-Aufruf wie
 * im bestehenden Login (type: "email" statt "signup", dort e2e getestet)
 * und bleibt bewusst ungetestet, bis eine Umgebung mit aktiven
 * Bestaetigungen existiert.
 */
test("ein neues Konto registriert sich und landet angemeldet auf der Wurzelseite", async ({
  page,
}) => {
  const email = `e2e-reg-${crypto.randomUUID()}@example.test`;

  await page.goto("/registrieren");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill("ein-langes-test-passwort");
  await page.getByRole("button", { name: "Konto anlegen" }).click();

  await page.waitForURL((url) => !url.pathname.startsWith("/registrieren"), {
    timeout: 15_000,
  });
  await expect(page.getByTestId("user-email")).toHaveText(email);
});

test("eine zu kurze Passworteingabe bleibt auf der Registrierungsseite", async ({ page }) => {
  await page.goto("/registrieren");
  await page.getByLabel("E-Mail").fill(`e2e-kurz-${crypto.randomUUID()}@example.test`);
  await page.getByLabel("Passwort").fill("kurz");
  await page.getByRole("button", { name: "Konto anlegen" }).click();

  await expect(page.getByText("mindestens zehn Zeichen")).toBeVisible();
});

test("ein Mitglied setzt ein neues Passwort per Code und ist danach angemeldet", async ({
  page,
}) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `e2e-reset-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: "ein-altes-test-passwort",
    email_confirm: true,
  });
  if (error) throw error;

  await page.goto("/passwort-vergessen");
  await page.getByLabel("E-Mail").fill(email);
  const angefordert = new Date(Date.now() - 1000);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const code = await latestOtpFor(email, angefordert);
  await page.getByLabel("Code aus der E-Mail").fill(code);
  await page.getByLabel("Neues Passwort").fill("ein-neues-test-passwort");
  await page.getByRole("button", { name: "Passwort setzen" }).click();

  await page.waitForURL((url) => !url.pathname.startsWith("/passwort-vergessen"), {
    timeout: 15_000,
  });
  await expect(page.getByTestId("user-email")).toHaveText(email);
});

test("ein Konto ohne Studio tritt per Code bei", async ({ page }) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `e2e-beitritt-${crypto.randomUUID()}@example.test`;
  const { error: userError } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Beitritts-E2E-Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;

  await anmelden(page, email);
  await expect(page.getByTestId("beitritt-formular")).toBeVisible();
  await page.getByLabel("Studio-Code").fill(studio.join_code);
  await page.getByRole("button", { name: "Beitreten" }).click();

  await expect(page.getByTestId("studio-list")).toContainText("Beitritts-E2E-Studio");
});
