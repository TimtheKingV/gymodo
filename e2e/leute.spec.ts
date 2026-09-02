import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./helpers/login";

function admin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
}

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

  // Der Trainer sieht die Person in Leute und stuft sie hoch.
  await anmelden(page, trainerEmail);
  await page.goto(`/portal/${studio.id}/leute`);
  const zeile = page.locator("li", { hasText: mitgliedEmail });
  await expect(zeile).toBeVisible();
  // exact: true, weil "Mitglied" sonst als Teilstring auch die eigene
  // E-Mail-Adresse trifft (e2e-leute-mitglied-...@example.test) -- ohne das
  // waere die Zuordnung mehrdeutig (Playwrights strict mode schlaegt fehl).
  await expect(zeile.getByText("Mitglied", { exact: true })).toBeVisible();

  await zeile.getByRole("button", { name: "Zu Trainer hochstufen" }).click();
  await zeile.getByRole("button", { name: "Wirklich?" }).click();
  await expect(zeile.getByText("Trainer", { exact: true })).toBeVisible();
});
