import type { Page } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";

export const GYMTAVO = "00000000-0000-4000-8000-000000000001";

/**
 * Ein eigener Gymtavo-Typ je Test, mit eindeutigem Namen. Er macht den
 * Test unabhaengig davon, ob der geteilte Katalog gerade leer ist: sobald
 * es einen Typ gibt, ist das Feld "Gymtavo-Gerätetyp" Pflicht (Nachtrag
 * 10.1), und in der CI fuellen die Integrationstests den Katalog ohnehin.
 */
export async function gymtavoTyp(
  admin: SupabaseClient,
  name: string,
  uebungen: string[] = [],
): Promise<{ typId: string; typName: string; uebungen: { id: string; name: string }[] }> {
  const typName = `${name} ${crypto.randomUUID().slice(0, 6)}`;
  const { data: typ, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: typName, load_step: 2.5 })
    .select("id")
    .single();
  if (error) throw error;

  const angelegt: { id: string; name: string }[] = [];
  for (const [index, uebungName] of uebungen.entries()) {
    const eindeutig = `${uebungName} ${crypto.randomUUID().slice(0, 6)}`;
    const { data: uebung, error: uebungFehler } = await admin
      .from("exercises")
      .insert({ studio_id: GYMTAVO, name: eindeutig, target_min: 8, target_max: 12 })
      .select("id")
      .single();
    if (uebungFehler) throw uebungFehler;
    const { error: linkFehler } = await admin
      .from("equipment_model_exercises")
      .insert({ equipment_model_id: typ.id, exercise_id: uebung.id, sort_order: index + 1 });
    if (linkFehler) throw linkFehler;
    angelegt.push({ id: uebung.id, name: eindeutig });
  }
  return { typId: typ.id, typName, uebungen: angelegt };
}

/** Typ ueber die Suche waehlen -- die Liste kann hunderte Testtypen tragen. */
export async function typWaehlen(page: Page, typName: string): Promise<void> {
  await page.getByRole("button", { name: "Gymtavo-Gerätetyp" }).click();
  await page.getByRole("searchbox", { name: "Typ suchen" }).fill(typName);
  await page.getByRole("option", { name: typName }).click();
}
