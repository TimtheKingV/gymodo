import type { SupabaseClient } from "@supabase/supabase-js";
import { requireUserId } from "./auth.js";
import { MEDIA_URL_TTL_SECONDS, VIDEO_BUCKET } from "./media.js";
import { signMediaUrls } from "./media-store.js";

export type ExerciseVideos = {
  /**
   * `pfad` ist der Speicherpfad. Die App legt die Datei darunter ab: die
   * URL wechselt mit jeder Signatur, der Pfad erst, wenn das Video
   * ersetzt wird.
   */
  videos: Array<{ exerciseId: string; url: string; pfad: string }>;
};

type LinkZeile = {
  equipment_model_id: string;
  exercises: { id: string };
  instruction_assets: Array<{ storage_path: string }>;
};

/**
 * Ein Video je Uebung. Das eigene Video eines Studios schlaegt das des
 * Katalogs -- dieselbe Regel wie uebungenZusammenfuehren im Geraetekontext,
 * damit die Liste zeigt, was die Einweisung spaeter abspielt.
 */
export function videoPfadJeUebung(
  links: LinkZeile[],
  katalogModelle: Set<string>,
): Map<string, string> {
  const studio = new Map<string, string>();
  const katalog = new Map<string, string>();
  for (const link of links) {
    const pfad = link.instruction_assets[0]?.storage_path;
    if (!pfad) continue;
    const ziel = katalogModelle.has(link.equipment_model_id) ? katalog : studio;
    if (!ziel.has(link.exercises.id)) ziel.set(link.exercises.id, pfad);
  }
  return new Map([...katalog, ...studio]);
}

/**
 * Signierte Uebungsvideos fuer die Geraeteliste und die Uebungszeilen der
 * App (Testnotiz 11.10., #1, #5, #7). Eine Anfrage fuer alle statt einer je
 * Geraet: die Liste zeigt Dutzende Kacheln zugleich.
 */
export async function getExerciseVideos(
  client: SupabaseClient,
): Promise<ExerciseVideos> {
  await requireUserId(client);

  // RLS laesst nur Verknuepfungen der eigenen Studios und des Katalogs durch
  // -- dieselbe Menge, die der Bootstrap als Uebungen liefert.
  const { data: links } = await client
    .from("equipment_model_exercises")
    .select("equipment_model_id, exercises (id), instruction_assets (storage_path)")
    .order("sort_order", { ascending: true });

  const { data: katalogRow } = await client
    .from("studios")
    .select("id")
    .eq("is_catalog", true)
    .maybeSingle<{ id: string }>();
  const { data: typRows } = katalogRow
    ? await client.from("equipment_models").select("id").eq("studio_id", katalogRow.id)
    : { data: [] };

  const pfade = videoPfadJeUebung(
    (links ?? []) as unknown as LinkZeile[],
    new Set(((typRows ?? []) as Array<{ id: string }>).map((typ) => typ.id)),
  );

  const signiert = await signMediaUrls(
    client,
    VIDEO_BUCKET,
    [...new Set(pfade.values())],
    MEDIA_URL_TTL_SECONDS,
  );

  // Was sich nicht signieren laesst, fehlt; die Kachel zeigt dann das Foto.
  const videos = [...pfade].flatMap(([exerciseId, pfad]) => {
    const url = signiert.get(pfad);
    return url ? [{ exerciseId, url, pfad }] : [];
  });
  return { videos };
}
