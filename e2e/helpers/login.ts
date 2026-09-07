import type { Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";

const INBUCKET = "http://127.0.0.1:54324";

/**
 * Der Service-Role-Client fuer per Admin-API angelegte Testkonten. Stand
 * vor dieser Aufgabe wortgleich in sieben Dateien (helpers/studio.ts,
 * auth-, einstellungen-, leute-, login-, tag-fallback-, trainerportal.spec.ts).
 * Aufgabe 8 zieht ihn hierher fuer ihre eigenen neuen Tests -- die sieben
 * Bestandsstellen bleiben bewusst unangetastet (siehe Aufgabe-8-Bericht):
 * sechs von ihnen haben mit dem Passwortpfad nichts zu tun, und sie dort
 * anzufassen waere das groesste Bruchrisiko dieser Aufgabe fuer den
 * kleinsten Nutzen. Der Umbau auf diese Funktion ist ein eigener Befund.
 */
export function adminClient(): SupabaseClient {
  return createClient(process.env.SUPABASE_URL!, process.env.SUPABASE_SERVICE_ROLE_KEY!, {
    auth: { persistSession: false },
  });
}

/**
 * Test-Passwort fuer per Service-Role angelegte Konten -- dieselbe Rolle wie
 * TEST_PASSWORD in tests/integration/helpers/clients.ts, hier eigenstaendig,
 * weil e2e- und Integrationstests getrennte Laufzeiten sind.
 */
export const E2E_PASSWORD = "e2e-test-passwort-1234";

/**
 * Das lokale Supabase-Setup betreibt unter Port 54324 mittlerweile Mailpit
 * statt des klassischen Inbucket (der Containername/die Env-Variable heissen
 * weiterhin "inbucket"). Mailpit hat eine eigene API: Suche per Empfaenger-
 * adresse und Detailabruf per Message-ID statt Mailbox-Ordnern.
 *
 * `nichtVor` verwirft Mails, die vor der Anforderung eintrafen -- sonst
 * nimmt die Funktion bei einer wiederverwendeten Adresse den schon
 * verbrauchten Code der vorigen Anmeldung.
 */
export async function latestOtpFor(
  email: string,
  nichtVor = new Date(0),
): Promise<string> {
  for (let attempt = 0; attempt < 20; attempt++) {
    const list = await fetch(
      `${INBUCKET}/api/v1/search?query=${encodeURIComponent(`to:${email}`)}`,
    );
    const result = (await list.json()) as {
      messages: Array<{ ID: string; Created: string }>;
    };
    const neueste = result.messages
      .filter((mail) => new Date(mail.Created) >= nichtVor)
      .sort((a, b) => Date.parse(b.Created) - Date.parse(a.Created))
      .at(0);
    if (neueste) {
      const detail = await fetch(`${INBUCKET}/api/v1/message/${neueste.ID}`);
      const body = (await detail.json()) as { Text: string };
      const match = body.Text.match(/\b(\d{6})\b/);
      if (match) return match[1]!;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error(`Kein Code fuer ${email} in Inbucket/Mailpit gefunden`);
}

/** Meldet ein per Service-Role mit E2E_PASSWORD angelegtes Konto an. */
export async function anmelden(page: Page, email: string): Promise<void> {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByLabel("Passwort").fill(E2E_PASSWORD);
  await page.getByRole("button", { name: "Anmelden" }).click();

  // signInWithPassword setzt die Sitzungscookies und leitet auf "/" um. Wer
  // vorher weiternavigiert, ist noch nicht angemeldet und landet wieder am
  // Login.
  await page.waitForURL((url) => !url.pathname.startsWith("/login"), {
    timeout: 15_000,
  });
  await page.waitForLoadState("networkidle");
}
