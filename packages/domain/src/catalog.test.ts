import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";
import { listCatalogTypes } from "./catalog.js";

// Gespielter Client: studios liefert den Katalog, equipment_models eine Zeile.
function clientMit(uebung: Record<string, unknown>): SupabaseClient {
  const modell = {
    id: "t1", name: "Kabelzug", manufacturer: null, category: "kraft", retired: false, load_unit: "kg", load_step: 2.5, load_min: 2.5, load_max: null,
    secondary_unit: null, secondary_step: null, secondary_min: null, secondary_max: null, cardio_werte: [], photo_path: null,
    equipment_model_exercises: [{ sort_order: 1, exercises: { id: "e1", name: "Kniebeuge", description: null, volume_kind: "reps", target_min: 8, target_max: 12, geraet_label: null, ...uebung }, instruction_assets: [] }],
    catalog_product_types: [],
  };
  const kette = (ergebnis: unknown) => {
    const k: Record<string, unknown> = {};
    k.select = () => k;
    k.eq = () => k;
    k.order = () => Promise.resolve({ data: ergebnis, error: null });
    k.maybeSingle = () => Promise.resolve({ data: ergebnis, error: null });
    return k;
  };
  return {
    auth: { getUser: async () => ({ data: { user: { id: "u1" } }, error: null }) },
    from: (tabelle: string) => kette(tabelle === "studios" ? { id: "s1" } : [modell]),
  } as unknown as SupabaseClient;
}

describe("listCatalogTypes", () => {
  it("ohne die sieben Spalten sind kamera und tempo null", async () => {
    const [typ] = await listCatalogTypes(clientMit({}));
    expect(typ?.exercises[0]).toMatchObject({ kamera: null, tempo: null });
  });

  it("liest Kameraprofil und Tempo aus den Spalten", async () => {
    const [typ] = await listCatalogTypes(
      clientMit({ kamera_profil: "ganzkoerper_stehend", kamera_signal: "knie", kamera_seite: "beide",
        tempo_senken_s: "3.0", tempo_halten_s: "1.0", tempo_heben_s: "2.0", tempo_beginnt_mit: "senken" }),
    );
    expect(typ?.exercises[0]).toMatchObject({
      kamera: { profil: "ganzkoerper_stehend", signal: "knie", seite: "beide", beginntMit: "senken" },
      tempo: { senkenS: 3, haltenS: 1, hebenS: 2 },
    });
  });
});
