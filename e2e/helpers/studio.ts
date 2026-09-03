import type { Page } from "@playwright/test";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import { E2E_PASSWORD, anmelden } from "./login";

export type Halle = {
  admin: SupabaseClient;
  studioId: string;
  email: string;
  userId: string;
};

/**
 * Ein Studio mit angemeldetem Trainer -- der Ausgangspunkt jedes Tests im
 * Gang. Ohne ihn baut jede Datei dieselben vierzig Zeilen noch einmal.
 */
export async function studioMitTrainer(
  page: Page,
  praefix: string,
): Promise<Halle> {
  const admin = createClient(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } },
  );

  const email = `${praefix}-${crypto.randomUUID()}@example.test`;
  const { data: nutzer, error: nutzerFehler } = await admin.auth.admin.createUser(
    { email, password: E2E_PASSWORD, email_confirm: true },
  );
  if (nutzerFehler) throw nutzerFehler;

  const { data: studio, error: studioFehler } = await admin
    .from("studios")
    .insert({ name: `${praefix} Studio` })
    .select("id")
    .single();
  if (studioFehler) throw studioFehler;

  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({
      studio_id: studio.id,
      user_id: nutzer.user.id,
      role: "trainer",
    });
  if (mitgliedFehler) throw mitgliedFehler;

  await anmelden(page, email);
  return { admin, studioId: studio.id, email, userId: nutzer.user.id };
}
