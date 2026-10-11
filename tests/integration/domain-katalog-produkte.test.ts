import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  PHOTO_BUCKET,
  copyCatalogDefaults,
  createEquipmentModel,
  getStudioCatalog,
  listCatalogTypes,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, 6.4.
// Geteilte lokale Datenbank: eigene Typen und Produkte mit Praefix, am Ende
// nur eigene Zeilen und Objekte weg -- Studio-Modelle vor Produkten, Produkte
// vor Typen (restrict).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const p = `t_${crypto.randomUUID().slice(0, 8)}_`;
const admin = serviceClient();

/** 1x1 PNG, gueltig fuer sniffMediaType und stripPngMetadata. */
const PNG_1X1 = Uint8Array.from(
  Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==", "base64"),
);

const typFoto = `${GYMTAVO}/catalog/photos/${p}typ.png`;
const produktFoto = `${GYMTAVO}/catalog/products/${p}geklaert-00000000.png`;
const eigeneObjekte = [typFoto, produktFoto];

let studioId: string;
let trainer: string;
let typA: string;
let typB: string;
let typOhneFotoDatei: string;
let geklaert: string;
let offen: string;
let fremd: string;

beforeAll(async () => {
  for (const pfad of [typFoto, produktFoto]) {
    const { error } = await admin.storage.from(PHOTO_BUCKET).upload(pfad, new Blob([PNG_1X1], { type: "image/png" }), { contentType: "image/png" });
    if (error) throw error;
  }

  const typen = await admin
    .from("equipment_models")
    .insert([
      { studio_id: GYMTAVO, name: `${p}Brustpresse`, load_step: 1, photo_path: typFoto },
      { studio_id: GYMTAVO, name: `${p}Butterfly`, load_step: 1 },
      // Foto zeigt ins Leere: kopiert copyCatalogDefaults trotzdem ein Foto,
      // kann es nur vom Produkt kommen.
      { studio_id: GYMTAVO, name: `${p}Ruderzug`, load_step: 1, photo_path: `${GYMTAVO}/catalog/photos/${p}gibt_es_nicht.png` },
    ])
    .select("id");
  if (typen.error) throw typen.error;
  [typA, typB, typOhneFotoDatei] = typen.data.map((t) => t.id) as [string, string, string];
  const einstellung = await admin
    .from("equipment_setting_definitions")
    .insert({ equipment_model_id: typA, key: "seat_height", label: "Sitzhöhe", kind: "number", sort_order: 0 });
  if (einstellung.error) throw einstellung.error;

  const produkte = await admin
    .from("catalog_products")
    .insert([
      {
        catalog_key: `${p}geklaert`, manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", model_code: "4345",
        note: "Scheibenbeladen.", photo_path: produktFoto, photo_rights: "cleared",
        load_unit: "kg", load_step: 2.5, load_min: 5, load_max: 150,
      },
      { catalog_key: `${p}offen`, manufacturer: "Technogym", name: "Chest Press", photo_rights: "pending" },
      { catalog_key: `${p}fremd`, manufacturer: "gym80", name: "Butterfly", photo_rights: "pending" },
    ])
    .select("id");
  if (produkte.error) throw produkte.error;
  [geklaert, offen, fremd] = produkte.data.map((x) => x.id) as [string, string, string];
  const links = await admin.from("catalog_product_types").insert([
    { product_id: geklaert, equipment_model_id: typA },
    { product_id: geklaert, equipment_model_id: typOhneFotoDatei },
    { product_id: offen, equipment_model_id: typA },
    { product_id: offen, equipment_model_id: typB },
    { product_id: fremd, equipment_model_id: typB },
  ]);
  if (links.error) throw links.error;

  const studio = await admin.from("studios").insert({ name: `Produkte ${p}` }).select("id").single();
  if (studio.error) throw studio.error;
  studioId = studio.data.id;
  trainer = uniqueEmail("katalog-produkte");
  const rolle = await admin.from("studio_memberships").insert({ studio_id: studioId, user_id: await createTestUser(trainer), role: "trainer" });
  if (rolle.error) throw rolle.error;
});

afterAll(async () => {
  const modelle = await admin.from("equipment_models").select("photo_path").eq("studio_id", studioId);
  const studioFotos = (modelle.data ?? []).flatMap((m) => (m.photo_path ? [m.photo_path as string] : []));
  await admin.from("equipment_models").delete().eq("studio_id", studioId);
  await admin.from("catalog_products").delete().like("catalog_key", `${p.replaceAll("_", "\\_")}%`);
  await admin.from("equipment_models").delete().in("id", [typA, typB, typOhneFotoDatei]);
  await admin.storage.from(PHOTO_BUCKET).remove([...eigeneObjekte, ...studioFotos]);
});

async function anlegen(werte: { typ: string; produkt?: string; name?: string }) {
  return createEquipmentModel(await userClient(trainer), {
    studioId, name: werte.name ?? "Brustpresse", loadStep: 2.5, catalogModelId: werte.typ, catalogProductId: werte.produkt,
  });
}

describe("listCatalogTypes Produkte", () => {
  it("liefert je Typ seine Produkte, ein Produkt an zwei Typen bei beiden", async () => {
    const typen = await listCatalogTypes(await userClient(trainer));
    const a = typen.find((t) => t.id === typA)!;
    const b = typen.find((t) => t.id === typB)!;
    expect(a.products.map((x) => x.id)).toEqual([geklaert, offen]);
    expect(b.products.map((x) => x.id)).toEqual([fremd, offen]);
    expect(a.products[0]).toEqual({
      id: geklaert, key: `${p}geklaert`, manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345",
      note: "Scheibenbeladen.", load: { unit: "kg", step: 2.5, min: 5, max: 150 }, secondary: null, photoPath: produktFoto,
    });
    expect(a.products[1]).toMatchObject({ manufacturer: "Technogym", series: null, modelCode: null, load: null, photoPath: null });
  });
});

describe("createEquipmentModel mit Produkt", () => {
  it("merkt sich die Herkunft, der Katalog zeigt sie", async () => {
    const { id } = await anlegen({ typ: typA, produkt: geklaert, name: "Pure Kraft Brustpresse 4345" });
    const katalog = await getStudioCatalog(await userClient(trainer), studioId);
    expect(katalog.models.find((m) => m.id === id)?.catalogProduct).toEqual({
      manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345",
    });
  });

  it("lehnt ein Produkt ab, das nicht zum Typ passt, unbekannt ist oder ohne Typ kommt", async () => {
    for (const werte of [
      { typ: typA, produkt: fremd },
      { typ: typA, produkt: crypto.randomUUID() },
    ]) {
      await expect(anlegen(werte)).rejects.toMatchObject({ code: "validation_failed", message: "Dieses Herstellermodell passt nicht zum Gymtavo-Typ." });
    }
    const ohneTyp = createEquipmentModel(await userClient(trainer), { studioId, name: "X", loadStep: 2.5, catalogProductId: geklaert });
    await expect(ohneTyp).rejects.toBeInstanceOf(DomainError);
    const { count } = await admin.from("equipment_models").select("id", { count: "exact", head: true }).eq("studio_id", studioId).eq("catalog_product_id", fremd);
    expect(count).toBe(0);
  });
});

describe("copyCatalogDefaults", () => {
  async function fotoPfad(id: string): Promise<string | null> {
    const { data } = await admin.from("equipment_models").select("photo_path").eq("id", id).single();
    return data?.photo_path ?? null;
  }

  it("nimmt das geklaerte Produktfoto vor der Typillustration, als Kopie im Studioordner", async () => {
    const { id } = await anlegen({ typ: typOhneFotoDatei, produkt: geklaert });
    // Das Typfoto fehlt im Bucket -- ein Erfolg kann nur vom Produkt kommen.
    expect(await copyCatalogDefaults(await userClient(trainer), id)).toEqual({ settingsCopied: 0, photoCopied: true });
    expect(await fotoPfad(id)).toMatch(new RegExp(`^${studioId}/`));
  });

  it("nimmt bei offenem Produktfoto die Typillustration, Einstellungen immer vom Typ", async () => {
    const { id } = await anlegen({ typ: typA, produkt: offen });
    expect(await copyCatalogDefaults(await userClient(trainer), id)).toEqual({ settingsCopied: 1, photoCopied: true });
    expect(await fotoPfad(id)).toMatch(new RegExp(`^${studioId}/`));
  });
});
