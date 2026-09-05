import { type Locator, expect, test } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";
import { akzentflaechen, hauptlandmarken } from "./helpers/abnahme";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Der Gang durch das Portal: Vorlage anlegen, Serie anlegen, Termin
 * oeffnen, absagen.
 *
 * Laeuft dieser Test lokal rot, pruefe ZUERST, was auf Port 3000
 * lauscht -- reuseExistingServer ist lokal true, und Playwright nimmt
 * einen haengengebliebenen Server samt Code von vor der Aenderung
 * (Fahrplan 4g).
 */

/**
 * fill() auf einem input[type=datetime-local|date] setzt den Wert zwar
 * im DOM -- real gemessen, dreimal in Folge reproduziert -- aber React
 * bemerkt es bei SerienVorschau.tsx nicht: der Wert landet nie in
 * useState, die Vorschau erscheint nie. Ursache ist der bekannte
 * React-"value tracker": fill() setzt .value auf einem Weg, der den
 * Tracker im selben Zug mitzieht, wodurch das folgende input-Event keine
 * Abweichung mehr findet und onChange ausbleibt -- bei Text-/Zahlenfeldern
 * tippt Playwright dagegen echte Tastatur-Events, die dieses Problem gar
 * nicht erst haben (siehe die Felder Name/Beschreibung/Dauer weiter oben,
 * die anstandslos funktionieren).
 *
 * Der Standardausweg (react-testing-library, verbreitet dokumentiert):
 * den Wert ueber den NATIVEN Prototyp-Setter schreiben -- der laesst den
 * Tracker auf dem alten Stand -- und danach selbst ein "input"-Event
 * feuern. Kein Fill-Aufruf, keine Anwendungsaenderung, nur der Weg, wie
 * der Testfall mit einem React-kontrollierten Feld dieses Typs spricht.
 */
async function setzeNativenWert(feld: Locator, wert: string): Promise<void> {
  await feld.evaluate((el: HTMLInputElement, wert: string) => {
    const setter = Object.getOwnPropertyDescriptor(
      window.HTMLInputElement.prototype,
      "value",
    )!.set!;
    setter.call(el, wert);
    el.dispatchEvent(new Event("input", { bubbles: true }));
  }, wert);
}

test("Vom leeren Kursplan bis zum abgesagten Termin", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "kurse");
  const basis = `/portal/${studioId}/kurse`;

  // Ein frisches Studio hat nichts -- und sagt das je Tag, statt eine
  // leere Tabelle zu zeigen.
  await page.goto(basis);
  await expect(page.getByRole("heading", { name: "Kurse", level: 1 })).toBeVisible();
  await expect(page.getByText("Keine Kurse").first()).toBeVisible();

  // Ohne Vorlage gibt es nichts anzulegen, und die Seite sagt, was fehlt.
  await page.goto(`${basis}/termin/neu`);
  await expect(page.getByText("Es gibt noch keine Kursvorlage.")).toBeVisible();

  // Vorlage anlegen.
  await page.goto(`${basis}/vorlagen`);
  await expect(page.getByText("Noch keine Vorlage angelegt.")).toBeVisible();
  // exact: true, weil "Standard-Trainer (Anzeigename)" als Label die
  // Zeichenkette "name" enthaelt -- getByLabel matcht sonst als Teilstring
  // und trifft auf beide Felder (strict-mode violation, real gemessen).
  await page.getByLabel("Name", { exact: true }).fill("Kraftzirkel");
  await page.getByLabel("Beschreibung").fill("Sechs Stationen im Wechsel.");
  await page.getByLabel("Dauer in Minuten").fill("60");
  await page.getByLabel("Plätze").fill("16");
  await page.getByLabel("Standard-Trainer (Anzeigename)").fill("Marek T.");
  await page.getByRole("button", { name: "Vorlage anlegen" }).click();

  await expect(page.getByRole("heading", { name: "Kraftzirkel" })).toBeVisible();
  // Das Foto ist deaktiviert, aber nicht stumm.
  await expect(page.getByText("Noch kein Foto")).toBeVisible();
  await expect(page.getByText(/dafür fehlt noch der Ablageort/)).toBeVisible();

  // Serie anlegen -- und die Vorschau zeigt sie, BEVOR sie entsteht.
  await page.goto(`${basis}/termin/neu`);
  await setzeNativenWert(page.getByLabel("Beginn"), "2026-11-05T18:00");
  await expect(page.getByText("Dieser eine Termin wird angelegt.")).toBeVisible();

  await setzeNativenWert(page.getByLabel(/Wöchentlich wiederholen bis/), "2026-12-03");
  await expect(page.getByText("Diese 5 Termine werden angelegt.")).toBeVisible();
  await expect(
    page.getByText(/bleiben diese Termine unverändert/),
  ).toBeVisible();

  await page.getByRole("button", { name: "Termine anlegen" }).click();
  // Auf die Umleitung warten, BEVOR der naechste goto kommt:
  // terminAnlegenAction endet mit redirect() auf den Kursplan
  // (kurse-actions.ts). Ohne dieses Warten bricht der goto die noch
  // laufende Server Action ab, und der Test fand danach keinen Termin --
  // real gemessen, mit und ohne die Aenderungen dieser Aufgabe, auch am
  // Stand 6f60799. Eine Zusicherung kommt hinzu (die Umleitung landet auf
  // dem Kursplan), keine faellt weg.
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/kurse$`));

  // Zurueck auf der Wochenansicht -- in der Woche des ersten Termins.
  await page.goto(`${basis}?woche=2026-11-05`);
  await expect(page.getByText("Donnerstag, 5. November")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();
  await expect(page.getByText("0 von 16")).toBeVisible();

  // Termin oeffnen: noch niemand da, und die Liste sagt, wem sie gehoert.
  await page.getByRole("link", { name: /18:00 · Kraftzirkel/ }).click();
  await expect(page.getByText("Noch niemand angemeldet.")).toBeVisible();
  await expect(
    page.getByText("Diese Liste ist eine Anwesenheitsliste. Andere Mitglieder sehen sie nicht."),
  ).toBeVisible();

  // Absagen ist eine bestaetigte Handlung.
  await page.getByRole("button", { name: "Termin absagen" }).click();
  await expect(
    page.getByText(/Der Termin bleibt sichtbar und wird als abgesagt gekennzeichnet/),
  ).toBeVisible();
  await page.getByRole("button", { name: "Ja, Termin absagen" }).click();

  await expect(page.getByText(/Dieser Termin ist abgesagt/)).toBeVisible();

  // Und in der Wochenansicht steht "abgesagt" statt einer Belegung.
  await page.goto(`${basis}?woche=2026-11-05`);
  await expect(page.getByText("abgesagt")).toBeVisible();

  // Die uebrigen vier Termine der Serie stehen unberuehrt.
  await page.goto(`${basis}?woche=2026-11-12`);
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();
  await expect(page.getByText("0 von 16")).toBeVisible();
});

test("Die Rail führt zu den Kursen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "kurse-rail");
  await page.goto(`/portal/${studioId}`);
  // exact: true, weil der Ueberblick seit d6cd1c4 einen zweiten Link
  // auf dieselbe Route traegt ("Zu den Kursen") -- getByRole matcht den
  // Namen sonst als Teilstring und trifft beide (strict-mode violation,
  // real gemessen, ebenso am Stand 6f60799). Gemeint ist die Rail-Zeile,
  // und die heisst genau "Kurse".
  await page.getByRole("link", { name: "Kurse", exact: true }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/kurse$`));
});

/**
 * Ab hier Aufgabe 22a: die drei gestalteten Bildschirme (Kursplan,
 * Kursvorlagen, Kursvorlage).
 *
 * Die Fixtures legen ihre Daten mit dem Dienstschluessel an, wie
 * schreibtisch.spec.ts es fuer den Kurstermin des Ueberblicks tut -- der
 * Weg durch die Oberflaeche (Vorlage anlegen, Serie anlegen) steht im
 * Gang-Test oben und braucht dort seine Zeit; ein Test, der nur einen
 * fertigen Bildschirm ansieht, soll ihn nicht noch einmal gehen.
 */

async function vorlageAnlegen(
  admin: SupabaseClient,
  studioId: string,
  name: string,
): Promise<string> {
  const { data, error } = await admin
    .from("course_templates")
    .insert({
      studio_id: studioId,
      name,
      description: "Sechs Stationen im Wechsel.",
      default_duration_min: 60,
      default_capacity: 16,
      default_instructor_name: "Marek T.",
    })
    .select("id")
    .single<{ id: string }>();
  if (error) throw error;
  return data!.id;
}

async function terminAnlegen(
  admin: SupabaseClient,
  studioId: string,
  templateId: string,
  startsAt: string,
): Promise<string> {
  const { data, error } = await admin
    .from("course_sessions")
    .insert({
      studio_id: studioId,
      course_template_id: templateId,
      starts_at: startsAt,
      duration_min: 60,
      capacity: 16,
      room: "Kursraum 2",
      instructor_name: "Marek T.",
    })
    .select("id")
    .single<{ id: string }>();
  if (error) throw error;
  return data!.id;
}

/**
 * Befund 41: alle fuenf Kurse-Dateien tragen ein eigenes
 * <main className={styles.content}> INNERHALB der <main> aus
 * (schreibtisch)/layout.tsx. Aufgabe 4 hat die Landmarke ins Layout
 * gezogen; die Kurse-Seiten entstanden parallel auf einem eigenen Zweig
 * gegen das alte Layout und haben es nicht mitbekommen.
 *
 * Zwei Folgen: ein Screenreader zaehlt zwei Hauptbereiche und kann bei
 * "zum Hauptteil springen" nicht sagen, welcher gemeint ist, und die
 * .content-Polsterung liegt doppelt -- der Kursplan steht 40 px weiter
 * innen als jede andere Seite des Portals. bausteine.spec.ts faehrt
 * dieselbe Abnahme fuer sechs aeltere Schreibtischseiten ab, aber fuer
 * keine Kurse-Route.
 */
test("Die Kurse-Routen tragen genau eine Hauptlandmarke", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-landmarke");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");

  for (const pfad of ["/kurse", "/kurse/vorlagen", `/kurse/vorlagen/${vorlageId}`]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    expect(
      await hauptlandmarken(page),
      `/portal/<id>${pfad} traegt nicht genau eine <main>-Landmarke`,
    ).toBe(1);
  }
});

/**
 * Je Bildschirm genau eine Akzentflaeche, am Markup der Artboards
 * nachgezaehlt: Kurse -> "Termin anlegen", Kursvorlagen ->
 * "Vorlage anlegen", Kursvorlage -> "Änderungen speichern".
 *
 * toHaveLength(1), nicht toBeLessThanOrEqual(1): die zweite Fassung
 * bleibt auch gruen, wenn die Flaeche ganz verschwindet.
 */
test("Jeder der drei Kurse-Bildschirme traegt genau eine Akzentflaeche", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-akzent");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");

  for (const pfad of ["/kurse", "/kurse/vorlagen", `/kurse/vorlagen/${vorlageId}`]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    const flaechen = await akzentflaechen(page);
    expect(
      flaechen,
      `/portal/<id>${pfad}: ${flaechen.length} statt 1 -- ${flaechen.join(", ")}`,
    ).toHaveLength(1);
  }
});

/**
 * Kursvorlage.dc.html zeichnet zwei Reiter -- Stammdaten und
 * "Termine (16)" mit dem Zusatz "in den naechsten 4 Wochen" UNTER der
 * Beschriftung. Der Fliesstext des Artboards verraet das nicht, das
 * Markup schon.
 *
 * Die Leiste braucht einen Namen: die Seite traegt zwei Navigationen
 * (Rail und Reiter), und "Navigation" zweimal ist keine Auskunft.
 */
test("Die Kursvorlage hat zwei Reiter, und Termine zeigt die Terminliste", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-reiter");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  const terminId = await terminAnlegen(
    admin,
    studioId,
    vorlageId,
    new Date(Date.now() + 3 * 24 * 3_600_000).toISOString(),
  );
  const basis = `/portal/${studioId}/kurse`;

  await page.goto(`${basis}/vorlagen/${vorlageId}`);
  await expect(page.getByRole("navigation", { name: "Kursvorlage" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Stammdaten/ })).toBeVisible();
  await expect(page.getByRole("link", { name: /Termine \(1\)/ })).toBeVisible();
  await expect(page.getByText("in den nächsten 4 Wochen")).toBeVisible();

  // Stammdaten ist der erste Reiter: das Formular steht hier, die
  // Terminliste nicht.
  await expect(page.getByLabel("Name", { exact: true })).toBeVisible();
  await expect(page.locator(`a[href="${basis}/termin/${terminId}"]`)).toHaveCount(0);

  await page.getByRole("link", { name: /Termine \(1\)/ }).click();
  await expect(page).toHaveURL(new RegExp(`/kurse/vorlagen/${vorlageId}/termine$`));
  await expect(page.locator(`a[href="${basis}/termin/${terminId}"]`)).toBeVisible();
  await expect(page.getByLabel("Name", { exact: true })).toHaveCount(0);
  // Der Kopf bleibt stehen -- er gehoert dem Layout, nicht dem Reiter.
  await expect(page.getByRole("heading", { name: "Kraftzirkel", level: 1 })).toBeVisible();
});

/**
 * Der vierte Test, selbst gewaehlt: der Wochenwechsel.
 *
 * Warum dieser. Die Kopfzeile des Kursplans ist genau das Stueck, das
 * diese Aufgabe umbaut -- aus zwei nackten Textlinks werden zwei
 * Nebenaktionen neben der Hauptaktion. Geprueft wird der Wechsel heute
 * von keinem Test: der Gang-Test oben springt mit ?woche=2026-11-05
 * direkt in die Zielwoche und umgeht damit genau die Rechnung, die
 * wochenFenster fuer "vorige" und "naechste" anstellt, UND deren
 * Verdrahtung an die beiden Links. woche.test.ts prueft die Rechnung als
 * Einheit, nie den Weg vom href zum Bildschirm. Ein beim Umbau
 * verlorenes href faellt sonst nirgends auf -- der Link saehe richtig
 * aus und taete nichts.
 *
 * Feste Daten statt "heute": der Anker steht in der URL, also ist der
 * Bildschirm ohne Zeitzonenrechnerei im Test reproduzierbar. 17:00 UTC
 * sind im November 18:00 in Europe/Berlin, der Vorgabe-Zeitzone eines
 * neuen Studios.
 */
test("Der Wochenwechsel wechselt wirklich die Woche", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "kurse-woche");
  const vorlageId = await vorlageAnlegen(admin, studioId, "Kraftzirkel");
  await terminAnlegen(admin, studioId, vorlageId, "2026-11-04T17:00:00.000Z");
  const basis = `/portal/${studioId}/kurse`;

  await page.goto(`${basis}?woche=2026-11-04`);
  await expect(page.getByText("Mo., 2. November – So., 8. November 2026")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();

  await page.getByRole("link", { name: /Nächste Woche/ }).click();
  await expect(page.getByText("Mo., 9. November – So., 15. November 2026")).toBeVisible();
  await expect(page.getByText("Mittwoch, 11. November")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toHaveCount(0);

  await page.getByRole("link", { name: /Vorige Woche/ }).click();
  await expect(page.getByText("Mo., 2. November – So., 8. November 2026")).toBeVisible();
  await expect(page.getByRole("link", { name: /18:00 · Kraftzirkel/ })).toBeVisible();
});
