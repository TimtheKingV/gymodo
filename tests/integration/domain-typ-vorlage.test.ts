import { afterAll, beforeAll, describe, expect, it } from "vitest";
import { PHOTO_BUCKET, listCatalogTypes } from "@fitretro/domain";
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
