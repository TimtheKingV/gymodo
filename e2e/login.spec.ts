import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";
import { E2E_PASSWORD } from "./helpers/login";

function admin() {
  return createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );
}

test("Mitglied meldet sich mit E-Mail und Passwort an und sieht sein Studio", async ({
  page,
}) => {
  const client = admin();
  const email = `e2e-${crypto.randomUUID()}@example.test`;
  const { data: user, error: userError } = await client.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await client
    .from("studios")
    .insert({ name: "E2E Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await client
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: user.user.id, role: "member" });
  if (membershipError) throw membershipError;

  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(E2E_PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();

  await expect(page.getByTestId("user-email")).toHaveText(email);
  await expect(page.getByTestId("studio-list")).toContainText("E2E Studio");
});

test("ein falsches Passwort bleibt auf der Login-Seite mit einer Fehlermeldung", async ({
  page,
}) => {
  const email = `e2e-falsch-${crypto.randomUUID()}@example.test`;
  const { error } = await admin().auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill("falsches-passwort");
  await page.getByRole("button", { name: "Anmelden" }).click();

  await expect(page.getByText("E-Mail oder Passwort ist falsch.")).toBeVisible();
});
