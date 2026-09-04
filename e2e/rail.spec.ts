import { expect, test } from "@playwright/test";
import { hauptlandmarken } from "./helpers/abnahme";
import { studioMitMitglied, studioMitTrainer } from "./helpers/studio";

test("Die Rail zeigt sechs feste Bereiche in drei Gruppen, nicht jedes Modell", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "rail-fest");

  // Drei Modelle anlegen -- frueher waeren das drei Rail-Eintraege gewesen.
  // weight_step_kg ist in equipment_models NOT NULL ohne Default (0004) --
  // ohne den Wert bricht der Insert an der Datenbank, nicht am Test.
  for (const name of ["Latzug", "Beinpresse", "Brustpresse"]) {
    const { error } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioId, name, weight_step_kg: 5 });
    if (error) throw error;
  }

  await page.goto(`/portal/${studioId}`);
  const rail = page.getByRole("navigation", { name: "Katalog" });

  for (const eintrag of ["Überblick", "Geräte", "Tags", "Leute", "Einstellungen"]) {
    await expect(rail.getByRole("link", { name: new RegExp(eintrag) })).toBeVisible();
  }

  // Die Modelle stehen NICHT mehr in der Rail.
  await expect(rail.getByRole("link", { name: /Latzug/ })).toHaveCount(0);
  await expect(rail.getByRole("link", { name: /Modell anlegen/ })).toHaveCount(0);
});

test("Kurse steht in der Rail und bleibt auf seinen Unterrouten markiert", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "rail-kurse");
  const rail = page.getByRole("navigation", { name: "Katalog" });

  await page.goto(`/portal/${studioId}/kurse`);
  await expect(rail.getByRole("link", { name: /Kurse/ })).toHaveAttribute(
    "aria-current",
    "page",
  );

  // Die Kurse haben Unterrouten. Ein Gleichheitsvergleich auf den Pfad
  // wuerde die Zeile hier nicht mehr markieren -- der Trainer saehe nicht,
  // wo er ist.
  await page.goto(`/portal/${studioId}/kurse/vorlagen`);
  await expect(rail.getByRole("link", { name: /Kurse/ })).toHaveAttribute(
    "aria-current",
    "page",
  );
});

test("Die Rail traegt die Abmeldung und die eigene Adresse", async ({ page }) => {
  const { studioId, email } = await studioMitTrainer(page, "rail-fuss");
  await page.goto(`/portal/${studioId}`);

  const rail = page.getByRole("navigation", { name: "Katalog" });
  await expect(rail.getByText(email)).toBeVisible();
  await expect(rail.getByRole("button", { name: "Abmelden" })).toBeVisible();
});

test("Ein Mitglied bekommt eine Rail ohne Zahlen statt einer kaputten Seite", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "rail-recht");
  await page.goto(`/portal/${studioId}`);

  // Die Rail steht. Das ist der ganze Test: listStudioMembers wirft fuer
  // ein Mitglied "unauthorized", und ohne Abfangen faellt damit die
  // Navigation jeder Seite gleichzeitig aus.
  await expect(page.getByRole("navigation", { name: "Katalog" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Leute/ })).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);
});
