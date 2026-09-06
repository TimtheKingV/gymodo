import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { fehlermeldung } from "./helpers/abnahme";
import { E2E_PASSWORD, anmelden, latestOtpFor } from "./helpers/login";

/**
 * Lokal steht SUPABASE_AUTH_EMAIL_ENABLE_CONFIRMATIONS auf false
 * (.env.example) -- signUp liefert dort sofort eine Session, und die
 * Codeseite erscheint nie. Dieser Test prueft deshalb den lokalen Pfad; der
 * Codezweig aus registrierungBestaetigen bleibt dadurch echt ungetestet und
 * bewusst so, bis eine Umgebung mit aktiven Bestaetigungen existiert.
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

  // getByText matcht als Teilstring -- seit Aufgabe 7 steht der Passwort-
  // Hinweis ("Mindestens zehn Zeichen...") dauerhaft auf der Seite, dazu
  // die Fehlermeldung ("...mindestens zehn Zeichen."). Beide erfuellen den
  // alten Text-Selektor, Playwrights strict mode bricht dann mit zwei
  // Treffern ab. Ueber die Rolle bleibt eindeutig, welcher der beiden
  // gemeint ist: die Fehlermeldung traegt role="alert", der Hinweis nicht.
  await expect(fehlermeldung(page)).toContainText("mindestens zehn Zeichen");
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
  // Seit Aufgabe 8 hat der zweite Schritt ein drittes Feld (Befund 5,
  // PasswortNeu.dc.html) -- ohne diese Zeile bliebe das Formular durch die
  // required-Pruefung des Browsers auf der Seite stehen, und der folgende
  // waitForURL liefe in den Timeout. Nicht im Aufgabe-8-Brief gelistet,
  // aber derselbe Weg wie in onboarding.spec.ts: der Weg hat ein Feld mehr,
  // und der Test geht den Weg.
  await page.getByLabel("Wiederholen").fill("ein-neues-test-passwort");
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

/**
 * Befunde 42 und 18, beide auf einer Seite: /registrieren traegt den
 * Feldhinweis (.hint) und die Fehlermeldung (.error) aus Form.tsx.
 *
 * .hint stand in text-faint (3,6 : 1) und nennt die Passwortregel --
 * Pflichttext, den jemand lesen MUSS, und damit genau der Fall, den
 * Designsystem 2 fuer text-faint ausschliesst.
 *
 * Die Fehlermeldung dieser Seite ist NICHT .error: /registrieren ist keine
 * Portalseite und nimmt .fehlermeldung aus einstieg.module.css. Sie steht
 * hier trotzdem, und zwar als Bezugspunkt -- danger-Umriss auf --surface,
 * keine Toenung, so wie Zustaende.dc.html die Fehlerkarte zeichnet. Das
 * ist die Form, an die sich .error in Aufgabe 21 angleicht (Befund 18);
 * der Gegentest dazu steht in einstellungen.spec.ts, wo .error wirklich
 * rendert.
 *
 * Geprueft wird je auf GLEICHHEIT mit dem erwarteten Wert, nicht auf
 * Ungleichheit mit dem verbotenen: sonst kaeme jeder andere zu blasse Ton
 * und jede andere Toenung durch.
 */
test("Feldhinweis und Fehlermeldung halten den Kontrast der Regel", async ({ page }) => {
  await page.goto("/registrieren");

  const hinweis = page.getByText("Länge zählt mehr als Sonderzeichen");
  await expect(hinweis).toBeVisible();
  // --text-muted, #9ba3af
  expect(await hinweis.evaluate((el) => getComputedStyle(el).color)).toBe(
    "rgb(155, 163, 175)",
  );

  await page.getByLabel("E-Mail").fill(`e2e-kontrast-${crypto.randomUUID()}@example.test`);
  await page.getByLabel("Passwort").fill("kurz");
  await page.getByRole("button", { name: "Konto anlegen" }).click();

  const meldung = fehlermeldung(page);
  await expect(meldung).toContainText("mindestens zehn Zeichen");
  const form = await meldung.evaluate((el) => {
    const stil = getComputedStyle(el);
    return { rahmen: stil.borderTopColor, flaeche: stil.backgroundColor };
  });
  // --danger (#ff5a4e) als Umriss, --surface (#14161a) als Grund. Keine
  // getoente Flaeche: die gehoert laut Designsystem 5 zu OFFLINE, und
  // Offline gilt im Portal ausdruecklich nicht (Struktur-Spec 5).
  expect(form.rahmen).toBe("rgb(255, 90, 78)");
  expect(form.flaeche).toBe("rgb(20, 22, 26)");
});
