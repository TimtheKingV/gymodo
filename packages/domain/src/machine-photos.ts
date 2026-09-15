import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { MEDIA_URL_TTL_SECONDS, PHOTO_BUCKET } from "./media.js";
import { signMediaUrls } from "./media-store.js";

export type MachinePhotos = {
  photos: Array<{ equipmentModelId: string; url: string }>;
};

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
    .select("equipment_models (id, photo_path)");

  type Row = { equipment_models: { id: string; photo_path: string | null } };
  const pfadJeModell = new Map<string, string>();
  for (const row of (rows ?? []) as unknown as Row[]) {
    const pfad = row.equipment_models.photo_path;
    if (pfad) pfadJeModell.set(row.equipment_models.id, pfad);
  }

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
