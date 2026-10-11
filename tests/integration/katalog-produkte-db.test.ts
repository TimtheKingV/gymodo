import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.1.
// Geteilte lokale Datenbank: eigene Schluessel mit Praefix, am Ende werden
// nur eigene Zeilen entfernt -- Produkte vor Typen, weil die Verknuepfung
// den Typ mit restrict haelt.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const p = `t_${crypto.randomUUID().slice(0, 8)}_`;
const admin = serviceClient();

let typId: string;
let studioId: string;
let studioModellId: string;
let trainer: string;

async function produkt(werte: Record<string, unknown> = {}) {
  return admin
    .from("catalog_products")
    .insert({ catalog_key: `${p}${crypto.randomUUID().slice(0, 6)}`, manufacturer: "gym80", name: "Brustpresse", ...werte })
    .select("id")
    .single();
}

beforeAll(async () => {
  const typ = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: `${p}Brustpresse`, load_step: 2.5 })
    .select("id")
    .single();
  if (typ.error) throw typ.error;
  typId = typ.data.id;

  const studio = await admin.from("studios").insert({ name: `Produkte ${p}` }).select("id").single();
  if (studio.error) throw studio.error;
  studioId = studio.data.id;
  trainer = uniqueEmail("produkte-trainer");
  const rolle = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: await createTestUser(trainer), role: "trainer" });
  if (rolle.error) throw rolle.error;
  const modell = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Brustpresse", load_step: 5 })
    .select("id")
    .single();
  if (modell.error) throw modell.error;
  studioModellId = modell.data.id;
});

afterAll(async () => {
  // Herkunft zeigt mit restrict auf das Produkt: erst das Studio-Modell.
  await admin.from("equipment_models").delete().eq("studio_id", studioId);
  await admin.from("catalog_products").delete().like("catalog_key", `${p.replaceAll("_", "\\_")}%`);
  await admin.from("equipment_models").delete().eq("id", typId);
});

describe("catalog_products", () => {
  it("nimmt ein Produkt mit Verknuepfung zum Gymtavo-Typ an", async () => {
    const { data, error } = await produkt({ series: "Pure Kraft", model_code: "4345", product_url: "https://gym80.de/4345" });
    expect(error).toBeNull();
    const link = await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: typId });
    expect(link.error).toBeNull();
  });

  it("verbietet ein Foto ohne geklaerte Rechte", async () => {
    const offen = await produkt({ photo_path: `${GYMTAVO}/catalog/products/x-1.png` });
    expect(offen.error?.message).toContain("catalog_products_foto_nur_geklaert");
    const geklaert = await produkt({ photo_path: `${GYMTAVO}/catalog/products/x-2.png`, photo_rights: "cleared" });
    expect(geklaert.error).toBeNull();
  });

  it("verlangt die Belastung ganz oder gar nicht", async () => {
    const halb = await produkt({ load_unit: "kg", load_step: 5 });
    expect(halb.error?.message).toContain("catalog_products_load_all_or_none");
    const ganz = await produkt({ load_unit: "kg", load_step: 5, load_min: 5, load_max: 100 });
    expect(ganz.error).toBeNull();
  });

  it("verbietet leere Texte und eine Adresse ohne https", async () => {
    expect((await produkt({ manufacturer: " " })).error).not.toBeNull();
    expect((await produkt({ series: "" })).error).not.toBeNull();
    expect((await produkt({ product_url: "http://gym80.de" })).error).not.toBeNull();
    expect((await produkt({ catalog_key: "Gross-Buchstaben" })).error).not.toBeNull();
  });

  it("verknuepft nur mit Typen des Gymtavo-Studios", async () => {
    const { data } = await produkt();
    const link = await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: studioModellId });
    expect(link.error?.message).toContain("gymtavo_produkttyp_ungueltig");
  });

  it("haelt einen verknuepften Typ fest", async () => {
    const typ = await admin.from("equipment_models").insert({ studio_id: GYMTAVO, name: `${p}Fest`, load_step: 2.5 }).select("id").single();
    const { data } = await produkt();
    await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: typ.data!.id });
    const loeschen = await admin.from("equipment_models").delete().eq("id", typ.data!.id);
    expect(loeschen.error?.message).toContain("catalog_product_types");
    await admin.from("catalog_products").delete().eq("id", data!.id);
    expect((await admin.from("equipment_models").delete().eq("id", typ.data!.id)).error).toBeNull();
  });
});

describe("equipment_models.catalog_product_id", () => {
  it("merkt sich am Studio-Modell die Herkunft", async () => {
    const { data } = await produkt();
    const { error } = await admin.from("equipment_models").update({ catalog_product_id: data!.id }).eq("id", studioModellId);
    expect(error).toBeNull();
  });

  it("verbietet eine Herkunft im Gymtavo-Studio", async () => {
    const { data } = await produkt();
    const { error } = await admin.from("equipment_models").update({ catalog_product_id: data!.id }).eq("id", typId);
    expect(error?.message).toContain("gymtavo_herkunft_ungueltig");
  });
});

describe("RLS", () => {
  it("Angemeldete lesen Produkte und Verknuepfungen, schreiben aber nicht", async () => {
    const { data } = await produkt();
    await admin.from("catalog_product_types").insert({ product_id: data!.id, equipment_model_id: typId });
    const client = await userClient(trainer);

    const gelesen = await client.from("catalog_products").select("id, catalog_product_types(equipment_model_id)").eq("id", data!.id).single();
    expect(gelesen.data?.catalog_product_types).toEqual([{ equipment_model_id: typId }]);

    const neu = await client.from("catalog_products").insert({ catalog_key: `${p}fremd`, manufacturer: "x", name: "y" });
    expect(neu.error).not.toBeNull();
    const geaendert = await client.from("catalog_products").update({ name: "Gekapert" }).eq("id", data!.id).select("id");
    expect(geaendert.data ?? []).toEqual([]);
    const link = await client.from("catalog_product_types").delete().eq("product_id", data!.id).select("product_id");
    expect(link.data ?? []).toEqual([]);
    const danach = await admin.from("catalog_products").select("name").eq("id", data!.id).single();
    expect(danach.data?.name).toBe("Brustpresse");
  });
});
