import type { SupabaseClient } from "@supabase/supabase-js";

/**
 * Die Cardio-Werte des Gymtavo-Typs, dem ein Modell nach dem Speichern
 * zugeordnet ist -- damit cardioAusFormular "dieselben Werte wie der Typ"
 * als Erben speichern kann (Final-Review B). Der Typ kommt aus dem Formular;
 * fehlt er dort, gilt der bisherige des Modells. null ohne Typ.
 */
export async function typCardioListe(
  client: SupabaseClient,
  ort: { typId: string | undefined; modelId?: string },
): Promise<string[] | null> {
  let typId: string | null = ort.typId ?? null;
  if (!typId && ort.modelId) {
    const { data, error } = await client
      .from("equipment_models")
      .select("catalog_model_id")
      .eq("id", ort.modelId)
      .maybeSingle<{ catalog_model_id: string | null }>();
    if (error) throw new Error(error.message);
    typId = data?.catalog_model_id ?? null;
  }
  if (!typId) return null;
  const { data, error } = await client
    .from("equipment_models")
    .select("cardio_werte")
    .eq("id", typId)
    .maybeSingle<{ cardio_werte: string[] }>();
  if (error) throw new Error(error.message);
  return data?.cardio_werte ?? null;
}
