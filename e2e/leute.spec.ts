import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./helpers/login";
import { studioMitTrainer } from "./helpers/studio";

function admin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
}

/**
 * Der Weg von aussen nach innen, in einem Stueck: ein Konto tritt per
 * Studio-Code bei, erscheint als Mitglied und wird zum Trainer gemacht.
 *
 * Seit Aufgabe 19 laeuft er ueber zwei Routen. Beitreten und die
 * Mitgliederliste stehen auf /leute; das Hochstufen ist Rechteverwaltung
 * und steht auf /leute/mitarbeiter (Struktur-Spec Abschnitt 2). Der Test
 * geht denselben Weg wie vorher, nur ueber beide Reiter -- und prueft
 * damit zugleich, dass die Person den Reiter wechselt, wenn sich ihre
 * Rolle aendert.
 */
test("ein Trainer sieht ein neu beigetretenes Mitglied in Leute und stuft es hoch", async ({
  page,
  context,
}) => {
  const client = admin();

  const trainerEmail = `e2e-leute-trainer-${crypto.randomUUID()}@example.test`;
  const { data: trainerUser, error: trainerError } = await client.auth.admin.createUser({
    email: trainerEmail,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (trainerError) throw trainerError;

  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "Leute-E2E-Studio" })
    .select("id, join_code")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await client
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: trainerUser.user.id, role: "trainer" });
  if (membershipError) throw membershipError;

  const mitgliedEmail = `e2e-leute-mitglied-${crypto.randomUUID()}@example.test`;
  const { error: mitgliedError } = await client.auth.admin.createUser({
    email: mitgliedEmail,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (mitgliedError) throw mitgliedError;

  // Das Mitglied tritt in einer eigenen Seite per Code bei.
  const mitgliedPage = await context.newPage();
  await anmelden(mitgliedPage, mitgliedEmail);
  await mitgliedPage.getByLabel("Studio-Code").fill(studio.join_code);
  await mitgliedPage.getByRole("button", { name: "Beitreten" }).click();
  await expect(mitgliedPage.getByTestId("studio-list")).toContainText("Leute-E2E-Studio");
  await mitgliedPage.close();

  // Reiter Mitglieder: die Person steht da, mit ihrem Beitrittsdatum.
  await anmelden(page, trainerEmail);
  await page.goto(`/portal/${studio.id}/leute`);
  const zeile = page.locator("li", { hasText: mitgliedEmail });
  await expect(zeile).toBeVisible();
  // "Seit Di., 25. August 2026" -- dasselbe Format wie in tags/page.tsx
  // und im Ueberblick, in der Studio-Zeitzone gerechnet. Ein hartkodiertes
  // Datum waere am naechsten Testlauftag falsch; geprueft wird die Form.
  await expect(zeile.getByText(/^Seit \w{2,4}\.?, \d{1,2}\. \w+ \d{4}$/)).toBeVisible();

  // Reiter Mitarbeiter: dort wird hochgestuft -- und zwar erst, nachdem
  // der Knopf gesagt hat, was das bedeutet (Befund 23; vorher stand dort
  // "Wirklich?", ein Klick mehr ohne eine Information mehr).
  //
  // Hochgestuft wird ueber ein Auswahlfeld und EINEN Knopf, nicht ueber
  // einen Knopf je Zeile (LeuteMitarbeiter.dc.html; dasselbe Muster wie
  // tags/TagBinden.tsx). selectOption ist trotzdem ausgeschrieben, obwohl
  // die einzige Person schon vorausgewaehlt ist: sonst pruefte der Test
  // nicht, dass das Feld die richtige Person ueberhaupt anbietet.
  await page.goto(`/portal/${studio.id}/leute/mitarbeiter`);
  await page.getByLabel("Mitglied").selectOption({ label: mitgliedEmail });
  await page.getByRole("button", { name: "Zum Trainer machen" }).click();
  await page
    .getByRole("button", { name: "Hochstufen gibt Zugriff auf den ganzen Katalog." })
    .click();

  // Danach steht dieselbe Person im Abschnitt "Alle Mitarbeiter", mit dem
  // Rollenkennzeichen "Trainer" -- ohne page.reload().
  const mitarbeiter = page.locator("section").filter({ hasText: "Alle Mitarbeiter" });
  const trainerZeile = mitarbeiter.locator("li", { hasText: mitgliedEmail });
  await expect(trainerZeile).toBeVisible();
  // exact: true, weil "Trainer" sonst als Teilstring auch die E-Mail des
  // angemeldeten Kontos trifft (e2e-leute-trainer-...@example.test) --
  // ohne das waere die Zuordnung mehrdeutig (Playwrights strict mode).
  await expect(trainerZeile.getByText("Trainer", { exact: true })).toBeVisible();
});

/**
 * Befund 22 an der Domaene, nicht an der Oberflaeche.
 *
 * Der Reiter Mitarbeiter laesst die eigene Zeile ohne Knopf (geprueft in
 * schreibtisch.spec.ts). Das ist eine Oberflaeche, kein Riegel: ein
 * direkter Aufruf von setMembershipRole auf die eigene Zeile kommt
 * weiterhin durch. Dieser Test haelt diesen Stand fest, damit "verdeckt"
 * nicht als "behoben" durchgeht -- er geht ueber den nutzergebundenen
 * Client, also genau ueber den Weg, den auch die Server-Aktion nimmt.
 *
 * Er ist bewusst so geschrieben, dass er ROT wird, sobald jemand den
 * Riegel einbaut. Dann ist er die Stelle, an der der Bericht nachgezogen
 * wird -- nicht eine Zusicherung, die den Riegel verhindert.
 */
test("die Domaene laesst eine Selbstherabstufung weiterhin zu", async () => {
  const client = admin();

  const email = `e2e-leute-selbst-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error: nutzerFehler } = await client.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (nutzerFehler) throw nutzerFehler;

  const { data: studio, error: studioFehler } = await client
    .from("studios")
    .insert({ name: "Leute-E2E-Selbst" })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;

  const { error: mitgliedFehler } = await client
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: nutzer.user.id, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const alsTrainer = createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_ANON_KEY!, {
    auth: { persistSession: false },
  });
  const { error: anmeldeFehler } = await alsTrainer.auth.signInWithPassword({
    email,
    password: E2E_PASSWORD,
  });
  if (anmeldeFehler) throw anmeldeFehler;

  const { data, error } = await alsTrainer
    .from("studio_memberships")
    .update({ role: "member" })
    .eq("studio_id", studio.id)
    .eq("user_id", nutzer.user.id)
    .select("id, role");

  expect(error).toBeNull();
  expect(data, "Die Domaene haelt die Selbstherabstufung inzwischen auf — Bericht nachziehen.")
    .toHaveLength(1);
});

/**
 * Befund 37. globals.css:97 nimmt jedem <a> Farbe und Unterstreichung, und
 * "underline" kommt in der ganzen Anwendung sonst kein einziges Mal vor.
 * Fuer Rail, Reiter und Knopf-Links ist das richtig -- die tragen eigene
 * Klassen und sehen aus wie Bedienelemente. Ein Link MITTEN IM SATZ hat
 * ohne sie null Unterschied zum Text daneben: gleiche Farbe, gleiche
 * Schrift, keine Linie. Er ist dann nur noch durch Draufzeigen zu finden.
 *
 * Der Akzent scheidet als Mittel aus -- er markiert die eine Hauptaktion
 * (Designsystem 5.1), und ein Hinweissatz ist keine. Bleibt die
 * Unterstreichung, und die ist ohnehin die Antwort, die nicht auf Farbe
 * allein baut.
 *
 * Nach den Aufgaben 22a und 22b ist dies die letzte der urspruenglich
 * sechzehn Stellen: die fuenfzehn in den Kurse-Routen sind dort zu
 * Reitern und Zeilen-Links geworden, die ihre eigene Klasse tragen.
 */
test("Ein Link im Fliesstext ist als Link zu erkennen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "leute-link");
  await page.goto(`/portal/${studioId}/leute`);

  // In der Rail steht ebenfalls ein Link "Einstellungen" -- gemeint ist
  // der im Satz unter der Liste, also der innerhalb der Hauptlandmarke.
  const link = page.getByRole("main").getByRole("link", { name: "Einstellungen" });
  await expect(link).toBeVisible();

  const strich = await link.evaluate((el) => getComputedStyle(el).textDecorationLine);
  expect(strich).toBe("underline");
});
