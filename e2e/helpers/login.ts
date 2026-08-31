import type { Page } from "@playwright/test";

const INBUCKET = "http://127.0.0.1:54324";

/**
 * Das lokale Supabase-Setup betreibt unter Port 54324 Mailpit (der
 * Containername heisst weiterhin "inbucket"). Mailpit hat eine eigene API:
 * Suche per Empfaengeradresse, Detailabruf per Message-ID.
 */
export async function latestOtpFor(email: string): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const list = await fetch(
      `${INBUCKET}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`,
    );
    const result = (await list.json()) as { messages: Array<{ ID: string }> };
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

export async function anmelden(page: Page, email: string): Promise<void> {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const otp = await latestOtpFor(email);
  await page.getByLabel("Code aus der E-Mail").fill(otp);
  await page.getByRole("button", { name: "Anmelden" }).click();

  // verifyOtp setzt die Sitzungscookies und leitet auf "/" um. Wer vorher
  // weiternavigiert, ist noch nicht angemeldet und landet wieder am Login.
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), {
    timeout: 15_000,
  });
  // Die Umleitung laeuft noch, wenn sich die URL schon geaendert hat. Wer
  // jetzt navigiert, bricht sie ab (ERR_ABORTED).
  await page.waitForLoadState("networkidle");
}
