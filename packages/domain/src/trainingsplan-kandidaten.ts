// Planuebungen des Gymtavo-Katalogs als Kandidaten fuer den Generator.
// Der Plan gehoert dem Katalog-Studio und nennt Katalogmodelle, keine Geraete eines
// Studios; die Merkliste des Mitglieds (nicht_vorhanden, gefaellt_nicht) filtert und
// sortiert nur. Deren Inhalt ist eine Angabe zur Person und wird nie geloggt.
import type { SupabaseClient } from "@supabase/supabase-js";
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

/** Uebungs-IDs: am Ort nicht vorhanden bzw. ueberall unbeliebt. */
export type Merkliste = { nichtVorhanden: string[]; gefaelltNicht: string[] };

export const LEERE_MERKLISTE: Merkliste = { nichtVorhanden: [], gefaelltNicht: [] };

/** Das Katalog-Studio (studios.is_catalog); jeder darf es lesen. */
export async function ladeKatalogStudioId(client: SupabaseClient): Promise<string> {
  const { data, error } = await client.from("studios").select("id").eq("is_catalog", true).maybeSingle<{ id: string }>();
  if (error || !data) throw new DomainError("internal", "Das Katalog-Studio konnte nicht gelesen werden.");
  return data.id;
}

/** Merkliste des Mitglieds: "nicht vorhanden" nur fuer den Ort, "gefaellt nicht" ueberall. */
export async function ladeMerkliste(client: SupabaseClient, userId: string, ortId: string): Promise<Merkliste> {
  const { data, error } = await client
    .from("plan_merkliste")
    .select("exercise_id, art, studio_id")
    .eq("user_id", userId);
  if (error) throw new DomainError("internal", "Die Merkliste konnte nicht gelesen werden.");
  const zeilen = (data ?? []) as Array<{ exercise_id: string; art: string; studio_id: string | null }>;
  return {
    nichtVorhanden: zeilen.filter((z) => z.art === "nicht_vorhanden" && z.studio_id === ortId).map((z) => z.exercise_id),
    gefaelltNicht: zeilen.filter((z) => z.art === "gefaellt_nicht").map((z) => z.exercise_id),
  };
}

const SEITE = 1000;

// Plain-Vergleich statt localeCompare: unabhaengig von der Locale des Servers.
const vergleich = (a: string, b: string) => (a < b ? -1 : a > b ? 1 : 0);

/**
 * Je Uebung mit Planfreigabe ein Kandidat, mit dem ersten Katalogmodell der Uebung
 * (sort_order, dann Modell-ID). Cardio laeuft ueber denselben Weg: seine Uebung
 * traegt den Baustein "cardio". Sortiert nach exerciseId, damit der Generator
 * deterministisch bleibt.
 */
export async function ladeKandidaten(client: SupabaseClient, merkliste: Merkliste): Promise<Kandidat[]> {
  const katalogId = await ladeKatalogStudioId(client);
  const { data: modelle, error } = await client.from("equipment_models").select("id").eq("studio_id", katalogId);
  if (error) throw new DomainError("internal", error.message);
  const modellIds = ((modelle ?? []) as Array<{ id: string }>).map((m) => m.id);
  if (modellIds.length === 0) return [];

  type Link = { equipment_model_id: string; sort_order: number; exercises: PlanUebung };
  const links: Link[] = [];
  for (let von = 0; ; von += SEITE) {
    const { data, error: linkFehler } = await client
      .from("equipment_model_exercises")
      .select("equipment_model_id, sort_order, exercises (id, muscles, plan_baustein, plan_typ, plan_bereiche)")
      .in("equipment_model_id", modellIds)
      .order("sort_order", { ascending: true })
      .order("equipment_model_id", { ascending: true })
      .order("exercise_id", { ascending: true })
      .range(von, von + SEITE - 1);
    if (linkFehler) throw new DomainError("internal", linkFehler.message);
    const seite = (data ?? []) as unknown as Link[];
    links.push(...seite);
    if (seite.length < SEITE) break;
  }

  const fehlt = new Set(merkliste.nichtVorhanden);
  const unbeliebt = new Set(merkliste.gefaelltNicht);
  const erste = new Map<string, Link>();
  for (const l of links) {
    const u = l.exercises;
    if (!u || !u.plan_baustein || !u.plan_typ || fehlt.has(u.id)) continue;
    const bisher = erste.get(u.id);
    if (
      !bisher ||
      l.sort_order < bisher.sort_order ||
      (l.sort_order === bisher.sort_order && vergleich(l.equipment_model_id, bisher.equipment_model_id) < 0)
    ) {
      erste.set(u.id, l);
    }
  }

  const kandidaten: Kandidat[] = [];
  for (const l of erste.values()) {
    const u = l.exercises;
    kandidaten.push({
      exerciseId: u.id,
      modelId: l.equipment_model_id,
      baustein: u.plan_baustein!,
      typ: u.plan_typ!,
      bereiche: u.plan_bereiche,
      hauptmuskeln: (u.muscles ?? []).filter((x) => x.role === "primary").map((x) => x.key),
      ...(unbeliebt.has(u.id) ? { gefaelltNicht: true } : {}),
    });
  }
  return kandidaten.sort((a, b) => vergleich(a.exerciseId, b.exerciseId));
}
