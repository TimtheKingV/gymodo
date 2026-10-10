import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { DomainError } from "./errors.js";
import { PHOTO_BUCKET } from "./media.js";
import { uploadEquipmentPhoto } from "./media-store.js";
import { requireStudioStaff } from "./studio.js";

/**
 * Was der Gymtavo-Typ weiss, bekommt das Studio-Modell beim Anlegen als
 * Kopie (Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, G1):
 * Einstellungen und Typillustration. Kopie statt Verweis, weil ein
 * Studio-Geraet eigene Stufen und eine eigene Historie hat und
 * Katalogkorrekturen laufende Geraete nicht still aendern sollen. Die
 * Belastung kommt nicht von hier -- sie stand im Formular, der Trainer hat
 * sie gesehen.
 */
export async function copyTypeDefaults(
  client: SupabaseClient,
  equipmentModelId: string,
): Promise<{ settingsCopied: number; photoCopied: boolean }> {
  const userId = await requireUserId(client);
  const { data: modell } = await client
    .from("equipment_models")
    .select("studio_id, photo_path, catalog_model_id")
    .eq("id", equipmentModelId)
    .maybeSingle<{ studio_id: string; photo_path: string | null; catalog_model_id: string | null }>();
  if (!modell) throw new DomainError("not_found", "Dieses Geraetemodell gibt es nicht.");
  await requireStudioStaff(client, modell.studio_id, userId);
  // Im Gymtavo-Studio verbietet der Trigger aus 0047 eine Zuordnung --
  // dort endet die Funktion also immer hier.
  if (!modell.catalog_model_id) return { settingsCopied: 0, photoCopied: false };

  const settingsCopied = await einstellungenKopieren(
    client,
    modell.catalog_model_id,
    equipmentModelId,
  );
  // Foto zuletzt: es ist der Teil, der am ehesten scheitert (Storage), und
  // die Einstellungen sollen dann trotzdem da sein.
  const photoCopied = modell.photo_path
    ? false
    : await fotoKopieren(client, modell.catalog_model_id, equipmentModelId);
  return { settingsCopied, photoCopied };
}

type Einstellung = {
  key: string;
  label: string;
  kind: "number" | "enum";
  min_value: number | string | null;
  max_value: number | string | null;
  step_value: number | string | null;
  unit: string | null;
  allowed_values: string[] | null;
  sort_order: number;
};

async function einstellungenKopieren(
  client: SupabaseClient,
  typId: string,
  modelId: string,
): Promise<number> {
  const spalten =
    "key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order";
  const [{ data: vomTyp, error: typFehler }, { data: vorhanden, error: modellFehler }] =
    await Promise.all([
      client.from("equipment_setting_definitions").select(spalten).eq("equipment_model_id", typId),
      client.from("equipment_setting_definitions").select("key").eq("equipment_model_id", modelId),
    ]);
  const lesefehler = typFehler ?? modellFehler;
  if (lesefehler) throw new DomainError("internal", lesefehler.message);

  // Ein Schluessel, den das Modell schon hat, bleibt wie er ist: ein
  // zweiter Aufruf (Doppelklick, Wiederholung nach Fehler) darf weder
  // doppeln noch am unique (equipment_model_id, key) scheitern.
  const schonDa = new Set((vorhanden ?? []).map((zeile) => (zeile as { key: string }).key));
  const neu = ((vomTyp ?? []) as Einstellung[]).filter((zeile) => !schonDa.has(zeile.key));
  if (neu.length === 0) return 0;

  const { error } = await client
    .from("equipment_setting_definitions")
    .insert(neu.map((zeile) => ({ ...zeile, equipment_model_id: modelId })));
  if (error) throw new DomainError("internal", error.message);
  return neu.length;
}

async function fotoKopieren(
  client: SupabaseClient,
  typId: string,
  modelId: string,
): Promise<boolean> {
  const { data: typ } = await client
    .from("equipment_models")
    .select("photo_path")
    .eq("id", typId)
    .maybeSingle<{ photo_path: string | null }>();
  if (!typ?.photo_path) return false;

  const { data: datei, error } = await client.storage.from(PHOTO_BUCKET).download(typ.photo_path);
  if (error || !datei) {
    throw new DomainError("internal", "Das Foto des Gymtavo-Typs liess sich nicht laden.");
  }
  // Eigene Datei im Studioordner statt Pfad in den Gymtavo-Ordner (G5):
  // uploadEquipmentPhoto loescht beim Ersetzen das bisherige Objekt, und
  // is_media_published (0021) gibt ueber photo_path anonym frei.
  await uploadEquipmentPhoto(client, {
    equipmentModelId: modelId,
    bytes: new Uint8Array(await datei.arrayBuffer()),
  });
  return true;
}
