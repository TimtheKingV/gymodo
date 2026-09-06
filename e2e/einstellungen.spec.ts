import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { akzentflaechen, fehlermeldung } from "./helpers/abnahme";
import { E2E_PASSWORD, anmelden } from "./helpers/login";
import { studioMitTrainer } from "./helpers/studio";

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
  // leeren Route-Announcer mit role="alert" ins Dokument. Genau dafuer gibt
  // es fehlermeldung() -- der Befund stand seit Phase 2 hier als Kommentar
  // und ist seit Aufgabe 14 ein Helfer.
  await page.getByLabel("Stornofrist").fill("200");
  await page.getByRole("button", { name: "Änderungen speichern" }).click();
  await expect(fehlermeldung(page)).toContainText("168");

  // Befund 18: .error trug eine 10-prozentige danger-Flaeche und haengt an
  // acht Stellen, darunter beide Fehlerpfade in Form.tsx -- also an jeder
  // Formularfehlermeldung des Portals. Designsystem 5 ordnet die getoente
  // Flaeche dem Zustand OFFLINE zu; FEHLER ist dort danger-Umriss bei
  // vollem Kontrast, und Zustaende.dc.html zeichnet die Fehlerkarte auf
  // #14161a. Bis Aufgabe 21 zeigte das Portal deshalb zwei verschiedene
  // Fehlerflaechen: den Zustand-Baustein richtig, das Formularfeld nicht.
  const form = await fehlermeldung(page).evaluate((el) => {
    const stil = getComputedStyle(el);
    return { rahmen: stil.borderTopColor, flaeche: stil.backgroundColor };
  });
  expect(form.rahmen).toBe("rgb(255, 90, 78)");
  expect(form.flaeche).toBe("rgb(20, 22, 26)");

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

  // Zwei "Abmelden" seit Aufgabe 12: der Rail-Fusszeile (jede Seite) und
  // die eigene Sektion der Kontoseite (EinstellungenKonto.dc.html zeigt
  // beide). Scope auf "main", damit der Test die Kontoseite trifft.
  await page.getByRole("main").getByRole("button", { name: "Abmelden" }).click();
  await expect(page).toHaveURL(/\/login/);
});

/**
 * Drei Karten auf einem Bildschirm (Stammdaten, Kurse, Studio-Code) --
 * genau eine davon traegt die Akzentflaeche. "Kopieren", "Neuen Code
 * erzeugen" und "Code sperren" sind Nebenaktionen, der Warnkasten unter
 * dem Code ist ueberhaupt nicht bedienbar.
 */
test("Einstellungen Studio traegt trotz mehrerer Abschnitte eine Akzentflaeche", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einst-akzent");
  await page.goto(`/portal/${studioId}/einstellungen`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);
});

/**
 * Wortlaut aus EinstellungenStudio.dc.html. Der zweite Satz ist der
 * eigentliche: er sagt, was NICHT kaputtgeht.
 *
 * Und die Form gehoert dazu. Der Satz stand schon als Fliesstext auf der
 * Seite -- sichtbar allein ist hier zu wenig: er kuendigt eine Folge an,
 * die kein Zurueck hat, und das Artboard zeichnet dafuer einen Umriss in
 * --warn bei vollem Kontrast. Geprueft wird auf GLEICHHEIT mit dem
 * erwarteten Ton (#ffb020), nicht auf Ungleichheit mit einem verbotenen.
 */
test("Der Studio-Code sagt, was ein neuer Code kostet", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "einst-code");
  await page.goto(`/portal/${studioId}/einstellungen`);

  const kasten = page.getByText(/macht den alten sofort ungültig/);
  await expect(kasten).toBeVisible();
  await expect(page.getByText(/Aushangschilder tragen keinen Code/)).toBeVisible();

  const form = await kasten.evaluate((el) => {
    const stil = getComputedStyle(el);
    return {
      farbe: stil.color,
      rahmen: stil.borderTopColor,
      breite: stil.borderTopWidth,
      flaeche: stil.backgroundColor,
    };
  });
  // --warn, #ffb020. Umriss bei vollem Kontrast, keine getoente Flaeche.
  expect(form.farbe).toBe("rgb(255, 176, 32)");
  expect(form.rahmen).toBe("rgb(255, 176, 32)");
  expect(form.breite).toBe("1px");
  expect(form.flaeche).toBe("rgba(0, 0, 0, 0)");
});

test("Der Konto-Reiter traegt den Passwortwechsel mit Wiederholung", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "einst-konto");
  await page.goto(`/portal/${studioId}/einstellungen/konto`);

  await expect(page.getByLabel("Aktuelles Passwort")).toBeVisible();
  await expect(page.getByLabel("Neues Passwort")).toBeVisible();
  await expect(page.getByLabel("Wiederholen")).toBeVisible();
});

/**
 * Befund 29. Designsystem 2: text-faint (3,6 : 1) ist fuer Text
 * verboten, der gelesen werden muss. Der Absatz ueber den Studio-Code
 * erklaert, wer mit dem Code hereinkommt und wer nicht -- er muss
 * gelesen werden.
 *
 * Geprueft wird auf Gleichheit mit dem erwarteten Wert (--text-muted,
 * #9ba3af), nicht auf Ungleichheit mit dem verbotenen --text-faint:
 * sonst liesse der Test jeden anderen zu blassen Ton durch. Vorbild:
 * schreibtisch.spec.ts, "Die Produktgrenze steht in text-muted".
 */
test("Der Satz zum Studio-Code steht in text-muted, nicht in text-faint", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einst-kontrast");
  await page.goto(`/portal/${studioId}/einstellungen`);

  const satz = page.getByText(/Der zweite Weg ins Studio/);
  const farbe = await satz.evaluate((el) => getComputedStyle(el).color);
  expect(farbe).toBe("rgb(155, 163, 175)");
});

/**
 * Die Reiter sind Nebenaktionen und werden mit dem Finger getroffen wie
 * jeder Knopf. Alle Artboards zeichnen sie mit 12px 16px Innenabstand;
 * der Code stand auf 8px 16px, und damit blieb der Reiter unter dem
 * Schreibtischmass von 40 px fuer eine Nebenaktion.
 *
 * zuKleineBedienelemente() findet das nicht: der Selektor kennt button,
 * role=button, input, select und textarea -- ein Reiter ist ein <a>.
 * Textlinks im Fliesstext sind dort bewusst ausgenommen, weil sie keine
 * 44 px hoch sein koennen, ohne die Zeile aufzureissen. Ein Reiter ist
 * aber kein Textlink, sondern ein Bedienelement in eigener Zeile.
 */
test("Die Reiter sind hoch genug, um sie zu treffen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "einst-reiter");
  await page.goto(`/portal/${studioId}/einstellungen`);

  const reiter = page.locator('nav[aria-label="Einstellungen"] a');
  await expect(reiter.first()).toBeVisible();

  const zuKlein: string[] = [];
  for (const eintrag of await reiter.all()) {
    const kasten = await eintrag.boundingBox();
    if (!kasten) continue;
    if (kasten.height + 0.5 < 40) {
      const text = ((await eintrag.textContent()) ?? "").trim();
      zuKlein.push(`${text} — ${Math.round(kasten.height)} px`);
    }
  }
  expect(zuKlein, `zu flache Reiter: ${zuKlein.join(", ")}`).toHaveLength(0);
});
