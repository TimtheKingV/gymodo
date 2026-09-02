import { expect, test } from "@playwright/test";
import { studioMitTrainer } from "./helpers/studio";

test("Der Einstieg zaehlt den Bestand und fuehrt in den Gang", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "einrichten-einstieg");

  await page.goto(`/portal/${studioId}/einrichten`);
  await expect(page.getByRole("heading", { name: "Einrichten" })).toBeVisible();

  // Ein frisches Studio hat nichts -- und sagt das, statt eine leere Liste
  // zu zeigen.
  await expect(page.getByText("Kein Tag vorrätig")).toBeVisible();
  await expect(
    page.getByText("Noch keine Lieferung angekommen."),
  ).toBeVisible();

  // Die Rail des Schreibtischs darf hier nicht stehen.
  await expect(page.getByRole("navigation", { name: "Katalog" })).toHaveCount(0);

  await page.getByRole("link", { name: "Gerät einrichten" }).click();
  await expect(page).toHaveURL(
    new RegExp(`/portal/${studioId}/einrichten/modell$`),
  );
});
