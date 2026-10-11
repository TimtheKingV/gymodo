import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { MEDIA_URL_TTL_SECONDS, PHOTO_BUCKET } from "./media.js";
import { signMediaUrls } from "./media-store.js";

export type MachinePhotos = {
  photos: Array<{ equipmentModelId: string; url: string }>;
};

type ModellMitFoto = { id: string; photo_path: string | null };

/**
 * Fotopfad je Modell, wie die Liste es zeigt: Gymtavo-Typen mit ihrem
 * eigenen Foto, Studio-Modelle mit ihrem -- und ohne eigenes mit dem Foto
 * ihres Typs (Testnotiz 11.10., #2). Vorher gingen Typen leer aus, weil nur
 * `machines` gelesen wurde; im freien Training zeigte die Liste deshalb
 * nur Platzhalter.
 */
export function fotoPfadJeModell(
  geraeteModelle: Array<ModellMitFoto & { catalog_model_id: string | null }>,
  katalogTypen: ModellMitFoto[],
): Map<string, string> {
  const typFoto = new Map<string, string>();
  for (const typ of katalogTypen) {
    if (typ.photo_path) typFoto.set(typ.id, typ.photo_path);
  }
  const pfadJeModell = new Map(typFoto);
  for (const modell of geraeteModelle) {
    const pfad =
      modell.photo_path ?? (modell.catalog_model_id ? typFoto.get(modell.catalog_model_id) : undefined);
    if (pfad) pfadJeModell.set(modell.id, pfad);
  }
  return pfadJeModell;
}

/**
 * Signierte Geraetefotos fuer die Geraeteliste der App.
 *
 * Eigene Anfrage statt eines Felds im Bootstrap: der Bootstrap ist ein
 * Vorrat, der Stunden haelt, eine signierte URL lebt 15 Minuten
 * (MEDIA_URL_TTL_SECONDS). Die App fragt deshalb erst, wenn die Liste
 * aufgeht -- dieselbe Linie wie beim Geraetekontext.
 *
 * Je Modell, nicht je Geraet: zwei Rudermaschinen desselben Modells tragen
 * dasselbe Foto, und es wird nur einmal signiert.
 */
export async function getMachinePhotos(
  client: SupabaseClient,
): Promise<MachinePhotos> {
  await requireUserId(client);

  // Dieselbe Geraetemenge wie getBootstrap: RLS beschraenkt auf die
  // eigenen Studios, gesperrte Geraete stehen in der Liste mit.
  const { data: rows } = await client
    .from("machines")
    .select("equipment_models (id, photo_path, catalog_model_id)");

  // Und dieselben Typen wie dessen Block catalog: alle Modelle des
  // Katalog-Studios, fuer jeden Angemeldeten lesbar (0047).
  const { data: katalogRow } = await client
    .from("studios")
    .select("id")
    .eq("is_catalog", true)
    .maybeSingle<{ id: string }>();
  const { data: typRows } = katalogRow
    ? await client
        .from("equipment_models")
        .select("id, photo_path")
        .eq("studio_id", katalogRow.id)
    : { data: [] };

  type Row = {
    equipment_models: ModellMitFoto & { catalog_model_id: string | null };
  };
  const pfadJeModell = fotoPfadJeModell(
    ((rows ?? []) as unknown as Row[]).map((row) => row.equipment_models),
    (typRows ?? []) as ModellMitFoto[],
  );

  const signiert = await signMediaUrls(
    client,
    PHOTO_BUCKET,
    [...new Set(pfadJeModell.values())],
    MEDIA_URL_TTL_SECONDS,
  );

  // Was sich nicht signieren laesst, fehlt -- ein verwaister Pfad macht die
  // Liste nicht kaputt, die Zeile bleibt nur ohne Bild.
  const photos = [...pfadJeModell].flatMap(([equipmentModelId, pfad]) => {
    const url = signiert.get(pfad);
    return url ? [{ equipmentModelId, url }] : [];
  });
  return { photos };
}
