import type { SupabaseClient } from "@supabase/supabase-js";
import type { LoadUnit } from "./belastung.js";
import { cardioListeDesModells, type CardioGeraet } from "./cardio.js";
import { DomainError } from "./errors.js";

/**
 * Liste und Einheiten je Geraetemodell, die Liste vom Katalog-Typ geerbt
 * (Final-Review A). Die Lesewege brauchen das, um Saetze einer alten App an
 * einem Cardio-Geraet zu erkennen: an der Zeile allein (load gesetzt) sieht
 * man es nicht. Zwei Abfragen, unabhaengig von der Zahl der Modelle.
 *
 * Ein Modell, das RLS nicht mehr zeigt (nach einem Austritt), fehlt in der
 * Antwort -- seine Saetze gelten dann als Kraft, wie vor E2.
 */
export async function cardioGeraeteLaden(
  client: SupabaseClient,
  modellIds: readonly string[],
): Promise<Map<string, CardioGeraet>> {
  const ids = [...new Set(modellIds)];
  if (ids.length === 0) return new Map();

  const { data: modelle, error } = await client
    .from("equipment_models")
    .select("id, load_unit, secondary_unit, cardio_werte, catalog_model_id")
    .in("id", ids);
  if (error) throw new DomainError("internal", error.message);
  const zeilen = (modelle ?? []) as Array<{
    id: string;
    load_unit: LoadUnit;
    secondary_unit: LoadUnit | null;
    cardio_werte: string[];
    catalog_model_id: string | null;
  }>;

  const katalogIds = [
    ...new Set(
      zeilen
        .filter((m) => m.cardio_werte.length === 0 && m.catalog_model_id)
        .map((m) => m.catalog_model_id!),
    ),
  ];
  const katalog = new Map<string, string[]>();
  if (katalogIds.length > 0) {
    const { data: typen, error: typFehler } = await client
      .from("equipment_models")
      .select("id, cardio_werte")
      .in("id", katalogIds);
    if (typFehler) throw new DomainError("internal", typFehler.message);
    for (const typ of (typen ?? []) as Array<{ id: string; cardio_werte: string[] }>) {
      katalog.set(typ.id, typ.cardio_werte);
    }
  }

  return new Map(
    zeilen.map((m) => [
      m.id,
      {
        liste: cardioListeDesModells({
          eigene: m.cardio_werte,
          katalog: m.catalog_model_id ? katalog.get(m.catalog_model_id) ?? null : null,
        }),
        loadUnit: m.load_unit,
        secondaryUnit: m.secondary_unit,
      },
    ]),
  );
}

/** Ein Cardio-Geraet: eine nicht-leere geerbte Liste. */
export function istCardioModell(geraete: Map<string, CardioGeraet>, modellId: string): boolean {
  return (geraete.get(modellId)?.liste.length ?? 0) > 0;
}
