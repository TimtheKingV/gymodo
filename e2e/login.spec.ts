import { expect, test } from "@playwright/test";
import { createClient } from "@supabase/supabase-js";

const INBUCKET = "http://127.0.0.1:54324";

// Das lokale Supabase-Setup betreibt unter Port 54324 mittlerweile Mailpit
// statt des klassischen Inbucket (der Containername/die Env-Variable heissen
// weiterhin "inbucket"). Mailpit hat eine eigene API: Suche per Empfaenger-
// adresse und Detailabruf per Message-ID statt Mailbox-Ordnern.
async function latestOtpFor(email: string): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const list = await fetch(
      `${INBUCKET}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`,
    );
    const result = (await list.json()) as {
      messages: Array<{ ID: string }>;
    };
    const newest = result.messages.at(0);
    if (newest) {
      const detail = await fetch(`${INBUCKET}/api/v1/message/${newest.ID}`);
      const body = (await detail.json()) as { Text: string };
      const match = body.Text.match(/\b(\d{6})\b/);
      if (match) return match[1]!;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Kein OTP fuer ${email} in Inbucket/Mailpit gefunden`);
}

test("Mitglied meldet sich per E-Mail-Code an und sieht sein Studio", async ({
  page,
}) => {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `e2e-${crypto.randomUUID()}@example.test`;
  const { data: user, error: userError } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
  });
  if (userError) throw userError;

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "E2E Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({
      studio_id: studio.id,
      user_id: user.user.id,
      role: "member",
    });
  if (membershipError) throw membershipError;

  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const otp = await latestOtpFor(email);
  await page.getByLabel("Code aus der E-Mail").fill(otp);
  await page.getByRole("button", { name: "Anmelden" }).click();

  await expect(page.getByTestId("user-email")).toHaveText(email);
  await expect(page.getByTestId("studio-list")).toContainText("E2E Studio");
});
