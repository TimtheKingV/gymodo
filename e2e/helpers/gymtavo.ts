import type { Page } from "@playwright/test";
import type { SupabaseClient } from "@supabase/supabase-js";

export const GYMTAVO = "00000000-0000-4000-8000-000000000001";

/**
 * Ein eigener Gymtavo-Typ je Test, mit eindeutigem Namen. Er macht den
 * Test unabhaengig davon, ob der geteilte Katalog gerade leer ist: sobald
 * es einen Typ gibt, ist das Feld "Gymtavo-Gerätetyp" Pflicht (Nachtrag
 * 10.1), und in der CI fuellen die Integrationstests den Katalog ohnehin.
 */
/**
 * Vorlagewerte des Typs fuer die Geraeteeinrichtung (Spec 2026-10-10
 * ..., 5): ohne Angaben bleibt der Typ wie bisher bei 2,5 kg ohne Foto.
 */
export type TypOptionen = {
  werte?: {
    category?: "kraft" | "cardio";
    load_unit?: string;
    load_step?: number;
    load_min?: number;
    load_max?: number | null;
  };
  einstellungen?: { key: string; label: string; kind: "number" | "enum"; allowed_values?: string[] }[];
  foto?: boolean;
};

export async function gymtavoTyp(
  admin: SupabaseClient,
  name: string,
  uebungen: string[] = [],
  optionen: TypOptionen = {},
): Promise<{ typId: string; typName: string; uebungen: { id: string; name: string }[] }> {
  const typName = `${name} ${crypto.randomUUID().slice(0, 6)}`;
  const { data: typ, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: typName, load_step: 2.5, ...optionen.werte })
    .select("id")
    .single();
  if (error) throw error;

  if (optionen.einstellungen?.length) {
    const { error: einstellungFehler } = await admin.from("equipment_setting_definitions").insert(
      optionen.einstellungen.map((e, index) => ({
        equipment_model_id: typ.id,
        key: e.key,
        label: e.label,
        kind: e.kind,
        allowed_values: e.allowed_values ?? null,
        sort_order: index,
      })),
    );
    if (einstellungFehler) throw einstellungFehler;
  }
  if (optionen.foto) {
    // Ein echtes, kleines PNG -- uploadEquipmentPhoto prueft den Inhalt.
    const pfad = `${GYMTAVO}/catalog/photos/e2e-${crypto.randomUUID()}.png`;
    const png = Buffer.from(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
      "base64",
    );
    const { error: uploadFehler } = await admin.storage
      .from("equipment-photos")
      .upload(pfad, png, { contentType: "image/png" });
    if (uploadFehler) throw uploadFehler;
    const { error: fotoFehler } = await admin
      .from("equipment_models")
      .update({ photo_path: pfad })
      .eq("id", typ.id);
    if (fotoFehler) throw fotoFehler;
  }

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
