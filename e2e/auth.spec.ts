import { expect, test } from "@playwright/test";

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
