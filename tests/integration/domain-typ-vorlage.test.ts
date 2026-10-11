import { afterAll, beforeAll, describe, expect, it } from "vitest";
import {
  PHOTO_BUCKET,
  copyTypeDefaults,
  createEquipmentModel,
  listCatalogTypes,
  uploadEquipmentPhoto,
} from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Spec 2026-10-10-gymtavo-katalog-geraeteeinrichtung-design.md, Abschnitt 5.
// Andere Testdateien legen ebenfalls Gymtavo-Typen an -- geprueft wird auf
// Enthaltensein, nie auf Gleichheit der Typliste.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID().slice(0, 8);

/** 1x1 PNG, gueltig genug fuer sniffMediaType und stripPngMetadata. */
const PNG_1X1 = Uint8Array.from(
  Buffer.from(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==",
    "base64",
  ),
);

let studioA: string;
let trainerA: string;
let mitgliedA: string;
let typKraft: string;
let typCardio: string;
let typKaputt: string;
const typFoto = `${GYMTAVO}/catalog/photos/t_${kennung}_kraft.png`;
const eigeneObjekte: string[] = [typFoto];

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: `Typvorlage ${kennung}` })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  trainerA = uniqueEmail("typvorlage-trainer");
  mitgliedA = uniqueEmail("typvorlage-mitglied");
  const { error: rolleError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" },
    { studio_id: studioA, user_id: await createTestUser(mitgliedA), role: "member" },
  ]);
  if (rolleError) throw rolleError;

  const { error: uploadError } = await admin.storage
    .from(PHOTO_BUCKET)
    .upload(typFoto, new Blob([PNG_1X1], { type: "image/png" }), { contentType: "image/png" });
  if (uploadError) throw uploadError;

  const { data: typen, error: typError } = await admin
    .from("equipment_models")
    .insert([
      {
        studio_id: GYMTAVO, name: `AA Brustpresse ${kennung}`, category: "kraft",
        load_unit: "kg", load_step: 5, load_min: 5, load_max: 100, photo_path: typFoto,
      },
      {
        studio_id: GYMTAVO, name: `AA Laufband ${kennung}`, category: "cardio",
        load_unit: "kmh", load_step: 0.1, load_min: 0, load_max: null,
        secondary_unit: "pct", secondary_step: 0.5, secondary_min: 0, secondary_max: 15,
      },
    ])
    .select("id");
  if (typError) throw typError;
  typKraft = typen[0]!.id;
  typCardio = typen[1]!.id;

  const { error: settingError } = await admin.from("equipment_setting_definitions").insert([
    { equipment_model_id: typKraft, key: "seat_height", label: "Sitzhöhe", kind: "number",
      min_value: 1, max_value: 10, step_value: 1, unit: null, sort_order: 0 },
    { equipment_model_id: typKraft, key: "grip", label: "Griff", kind: "enum",
      allowed_values: ["neutral", "pronated"], sort_order: 1 },
  ]);
  if (settingError) throw settingError;

  // Ein Typ, dessen Foto im Bucket fehlt: das Kopieren muss scheitern,
  // die Einstellungen sollen trotzdem ankommen.
  const { data: kaputt, error: kaputtError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: GYMTAVO, name: `AA Kaputt ${kennung}`, load_step: 5,
      photo_path: `${GYMTAVO}/catalog/photos/t_${kennung}_gibt_es_nicht.png`,
    })
    .select("id")
    .single();
  if (kaputtError) throw kaputtError;
  typKaputt = kaputt.id;
  const { error: kaputtSettingError } = await admin.from("equipment_setting_definitions").insert({
    equipment_model_id: typKaputt, key: "back_rest", label: "Lehne", kind: "number", sort_order: 0,
  });
  if (kaputtSettingError) throw kaputtSettingError;
});

afterAll(async () => {
  await serviceClient().storage.from(PHOTO_BUCKET).remove(eigeneObjekte);
});

describe("listCatalogTypes", () => {
  it("liefert Belastung, Nebenbelastung und Foto je Typ", async () => {
    const typen = await listCatalogTypes(await userClient(trainerA));
    expect(typen.find((t) => t.id === typKraft)).toMatchObject({
      category: "kraft", loadUnit: "kg", loadStep: 5, loadMin: 5, loadMax: 100,
      secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
      photoPath: typFoto,
    });
    expect(typen.find((t) => t.id === typCardio)).toMatchObject({
      category: "cardio", loadUnit: "kmh", loadStep: 0.1, loadMin: 0, loadMax: null,
      secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
      photoPath: null,
    });
  });
});

async function modellMitTyp(typId: string | undefined, name: string): Promise<string> {
  const { id } = await createEquipmentModel(await userClient(trainerA), {
    studioId: studioA, name: `${name} ${kennung}`, loadStep: 5, catalogModelId: typId,
  });
  return id;
}

async function einstellungen(modelId: string) {
  const { data, error } = await serviceClient()
    .from("equipment_setting_definitions")
    .select("key, label, kind, min_value, max_value, step_value, unit, allowed_values, sort_order")
    .eq("equipment_model_id", modelId)
    .order("sort_order");
  if (error) throw error;
  return data;
}

async function fotoPfad(modelId: string): Promise<string | null> {
  const { data, error } = await serviceClient()
    .from("equipment_models").select("photo_path").eq("id", modelId).single();
  if (error) throw error;
  return data.photo_path;
}

describe("copyTypeDefaults", () => {
  it("kopiert die Einstellungen des Typs samt Werteliste und Reihenfolge", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse");
    const ergebnis = await copyTypeDefaults(await userClient(trainerA), modelId);
    expect(ergebnis.settingsCopied).toBe(2);
    eigeneObjekte.push((await fotoPfad(modelId))!);
    const zeilen = await einstellungen(modelId);
    expect(zeilen).toEqual([
      expect.objectContaining({ key: "seat_height", label: "Sitzhöhe", kind: "number", sort_order: 0 }),
      expect.objectContaining({ key: "grip", kind: "enum",
        allowed_values: ["neutral", "pronated"], sort_order: 1 }),
    ]);
    // numeric kann als Text kommen -- verglichen wird der Wert.
    expect([zeilen[0]!.min_value, zeilen[0]!.max_value, zeilen[0]!.step_value].map(Number))
      .toEqual([1, 10, 1]);
  });

  it("kopiert die Typillustration in den Studioordner, nicht als Verweis", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse Foto");
    const ergebnis = await copyTypeDefaults(await userClient(trainerA), modelId);
    expect(ergebnis.photoCopied).toBe(true);
    const pfad = await fotoPfad(modelId);
    expect(pfad?.startsWith(`${studioA}/models/${modelId}/`)).toBe(true);
    eigeneObjekte.push(pfad!);
  });

  it("laesst ein eigenes Foto stehen", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse eigenes Foto");
    const client = await userClient(trainerA);
    const { storagePath } = await uploadEquipmentPhoto(client, {
      equipmentModelId: modelId, bytes: PNG_1X1,
    });
    eigeneObjekte.push(storagePath);
    const ergebnis = await copyTypeDefaults(client, modelId);
    expect(ergebnis.photoCopied).toBe(false);
    expect(await fotoPfad(modelId)).toBe(storagePath);
  });

  it("ein zweiter Aufruf legt nichts doppelt an und meldet keinen Konflikt", async () => {
    const modelId = await modellMitTyp(typKraft, "Brustpresse doppelt");
    const client = await userClient(trainerA);
    const erster = await copyTypeDefaults(client, modelId);
    eigeneObjekte.push((await fotoPfad(modelId))!);
    const zweiter = await copyTypeDefaults(client, modelId);
    expect(erster.settingsCopied).toBe(2);
    expect(zweiter).toEqual({ settingsCopied: 0, photoCopied: false });
    expect(await einstellungen(modelId)).toHaveLength(2);
  });

  it("ein Modell ohne Typ bleibt unveraendert", async () => {
    const modelId = await modellMitTyp(undefined, "Ohne Typ");
    const ergebnis = await copyTypeDefaults(await userClient(trainerA), modelId);
    expect(ergebnis).toEqual({ settingsCopied: 0, photoCopied: false });
    expect(await einstellungen(modelId)).toHaveLength(0);
    expect(await fotoPfad(modelId)).toBeNull();
  });

  it("negativ: ein Mitglied darf nicht kopieren", async () => {
    const modelId = await modellMitTyp(typKraft, "Mitglied");
    await expect(copyTypeDefaults(await userClient(mitgliedA), modelId)).rejects.toMatchObject({
      code: "unauthorized",
    });
    expect(await einstellungen(modelId)).toHaveLength(0);
  });

  it("ein fehlendes Typfoto ist ein Fehler, die Einstellungen sind trotzdem da", async () => {
    const modelId = await modellMitTyp(typKaputt, "Kaputt");
    await expect(copyTypeDefaults(await userClient(trainerA), modelId)).rejects.toMatchObject({
      code: "internal",
    });
    expect(await einstellungen(modelId)).toEqual([expect.objectContaining({ key: "back_rest" })]);
    expect(await fotoPfad(modelId)).toBeNull();
  });
});
