// Planuebungen eines Studios als Kandidaten fuer den Generator (Etappe 2, Task 6).
// Die Zusammenfuehrung eigener und Katalog-Uebungen ist die des Bootstraps
// (uebungenMitKatalog) -- hier nicht nachgebaut, damit beide dieselbe Antwort geben.
import type { SupabaseClient } from "@supabase/supabase-js";
import { uebungenMitKatalog } from "./bootstrap.js";
import { DomainError } from "./errors.js";
import type { Kandidat } from "./trainingsplan-auswahl.js";
import type { Baustein, Bereich, PlanTyp } from "./trainingsplan-typen.js";

type PlanUebung = {
  id: string;
  muscles: Array<{ key: string; role: string }> | null;
  plan_baustein: Baustein | null;
  plan_typ: PlanTyp | null;
  plan_bereiche: Bereich[];
};

type MaschinenZeile = {
  id: string;
  equipment_models: { id: string; catalog_model_id: string | null };
};

/**
 * Alle Uebungen mit Planfreigabe an den aktiven Geraeten des Studios, je Geraet
 * ein Kandidat. Cardio laeuft ueber denselben Weg: seine Uebung traegt den
 * Baustein "cardio" und haengt am Cardiomodell oder dessen Gymtavo-Typ.
 * Sortiert nach exerciseId, dann machineId, damit der Generator deterministisch
 * bleibt (er nimmt je Uebung das erste Geraet).
 */
export async function ladeKandidaten(client: SupabaseClient, studioId: string): Promise<Kandidat[]> {
  const { data: maschinen, error } = await client
    .from("machines")
    .select("id, equipment_models (id, catalog_model_id)")
    .eq("studio_id", studioId)
    .eq("status", "active");
  if (error) throw new DomainError("internal", error.message);
  const zeilen = (maschinen ?? []) as unknown as MaschinenZeile[];
  if (zeilen.length === 0) return [];

  const modellIds = [
    ...new Set(zeilen.flatMap((m) => [m.equipment_models.id, m.equipment_models.catalog_model_id ?? []].flat())),
  ] as string[];
  const { data: links, error: linkFehler } = await client
    .from("equipment_model_exercises")
    .select("equipment_model_id, sort_order, exercises (id, muscles, plan_baustein, plan_typ, plan_bereiche)")
    .in("equipment_model_id", modellIds)
    .order("sort_order", { ascending: true });
  if (linkFehler) throw new DomainError("internal", linkFehler.message);

  const jeModell = new Map<string, PlanUebung[]>();
  for (const l of (links ?? []) as unknown as Array<{ equipment_model_id: string; exercises: PlanUebung }>) {
    const liste = jeModell.get(l.equipment_model_id) ?? [];
    liste.push(l.exercises);
    jeModell.set(l.equipment_model_id, liste);
  }

  const kandidaten: Kandidat[] = [];
  for (const m of zeilen) {
    const katalogId = m.equipment_models.catalog_model_id;
    const uebungen = uebungenMitKatalog(
      jeModell.get(m.equipment_models.id) ?? [],
      katalogId ? jeModell.get(katalogId) ?? [] : [],
    );
    for (const u of uebungen) {
      if (!u.plan_baustein || !u.plan_typ) continue;
      kandidaten.push({
        exerciseId: u.id,
        machineId: m.id,
        baustein: u.plan_baustein,
        typ: u.plan_typ,
        bereiche: u.plan_bereiche,
        hauptmuskeln: (u.muscles ?? []).filter((x) => x.role === "primary").map((x) => x.key),
      });
    }
  }
  // Plain-Vergleich statt localeCompare: unabhaengig von der Locale des Servers.
  const vergleich = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);
  return kandidaten.sort((a, b) => vergleich(a.exerciseId, b.exerciseId) || vergleich(a.machineId, b.machineId));
}
