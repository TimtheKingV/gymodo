import { type Locator, expect, test } from "@playwright/test";
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
  await page.getByRole("link", { name: "Kurse" }).click();
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/kurse$`));
});
