import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  attachExerciseToModel,
  catalogTypeRequired,
  createEquipmentModel,
  createExercise,
  detachCatalogExercise,
  getStudioCatalog,
  listCatalogTypes,
  prepareInstructionVideoUpload,
  updateEquipmentModel,
} from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Nachtrag 10.1:
// Studio-Modelle zeigen auf einen Gymtavo-Typ, Gymtavo-Uebungen haengen per
// Verweis am Studio-Modell. Andere Testdateien legen ebenfalls Gymtavo-Typen
// an -- geprueft wird auf Enthaltensein, nie auf Gleichheit.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID().slice(0, 8);

let studioA: string;
let studioB: string;
let trainerA: string;
let typ1: string;
let typ2: string;
let fremdesModell: string;
let katalogUebung1: string;
let katalogUebung2: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: `Portal-Gymtavo A ${kennung}` }, { name: `Portal-Gymtavo B ${kennung}` }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("gymtavo-portal-trainer");
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" });
  if (rolleError) throw rolleError;

  const { data: typen, error: typError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: GYMTAVO, name: `AA Langhantel ${kennung}`, load_step: 2.5 },
      { studio_id: GYMTAVO, name: `AB Kabelzug ${kennung}`, load_step: 2.5 },
      { studio_id: studioB, name: `Fremdes Modell ${kennung}`, load_step: 2.5 },
    ])
    .select("id");
  if (typError) throw typError;
  typ1 = typen[0]!.id;
  typ2 = typen[1]!.id;
  fremdesModell = typen[2]!.id;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: GYMTAVO, name: `Bankdruecken ${kennung}`, target_min: 8, target_max: 12 },
      { studio_id: GYMTAVO, name: `Face Pull ${kennung}`, target_min: 12, target_max: 15 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  katalogUebung1 = uebungen[0]!.id;
  katalogUebung2 = uebungen[1]!.id;

  const { error: linkError } = await admin.from("equipment_model_exercises").insert([
    { equipment_model_id: typ1, exercise_id: katalogUebung1, sort_order: 1 },
    { equipment_model_id: typ2, exercise_id: katalogUebung2, sort_order: 1 },
  ]);
  if (linkError) throw linkError;
});

describe("Zuordnung zum Gymtavo-Typ", () => {
  it("positiv: ein Modell wird mit Typ angelegt und der Katalog nennt ihn", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Hantelbank ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ1,
    });

    const katalog = await getStudioCatalog(client, studioA);
    expect(katalog.isCatalog).toBe(false);
    expect(katalog.models.find((m) => m.id === id)?.catalogModelId).toBe(typ1);
  });

  it("positiv: ohne Typ angelegt, nachtraeglich zugeordnet und gewechselt", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Altbestand ${kennung}`,
      loadStep: 2.5,
    });
    let katalog = await getStudioCatalog(client, studioA);
    expect(katalog.models.find((m) => m.id === id)?.catalogModelId).toBeNull();

    await updateEquipmentModel(client, id, { catalogModelId: typ1 });
    await updateEquipmentModel(client, id, { catalogModelId: typ2 });
    katalog = await getStudioCatalog(client, studioA);
    expect(katalog.models.find((m) => m.id === id)?.catalogModelId).toBe(typ2);
  });

  it("negativ: ein Modell eines anderen Studios ist kein Gymtavo-Typ", async () => {
    const client = await userClient(trainerA);
    await expect(
      createEquipmentModel(client, {
        studioId: studioA,
        name: `Falsch zugeordnet ${kennung}`,
        loadStep: 2.5,
        catalogModelId: fremdesModell,
      }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("negativ: eine erfundene id ergibt dieselbe Antwort", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Erfunden ${kennung}`,
      loadStep: 2.5,
    });
    const fehler = await updateEquipmentModel(client, id, {
      catalogModelId: crypto.randomUUID(),
    }).catch((e: unknown) => e);
    expect(fehler).toBeInstanceOf(DomainError);
    expect((fehler as DomainError).code).toBe("validation_failed");
  });

  it("das Gymtavo-Studio liest jeder Angemeldete als Katalog", async () => {
    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, GYMTAVO);
    expect(katalog.isCatalog).toBe(true);
    expect(katalog.models.map((m) => m.id)).toEqual(expect.arrayContaining([typ1, typ2]));
  });
});
describe("Gymtavo-Uebung am Studio-Modell", () => {
  it("positiv: eine Gymtavo-Uebung haengt am Studio-Modell und ist als Verweis markiert", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Anhaengen ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ1,
    });
    const eigene = await createExercise(client, {
      studioId: studioA,
      name: `Hausuebung ${kennung}`,
      targetMin: 8,
      targetMax: 12,
    });
    await attachExerciseToModel(client, { equipmentModelId: id, exerciseId: eigene.id });
    await attachExerciseToModel(client, { equipmentModelId: id, exerciseId: katalogUebung2 });

    const katalog = await getStudioCatalog(client, studioA);
    const uebungen = katalog.models.find((m) => m.id === id)!.exercises;
    expect(uebungen.find((u) => u.exerciseId === eigene.id)?.fromCatalog).toBe(false);
    expect(uebungen.find((u) => u.exerciseId === katalogUebung2)?.fromCatalog).toBe(true);
  });

  it("negativ: die Uebung eines dritten Studios bleibt unsichtbar", async () => {
    const admin = serviceClient();
    const { data: fremd, error } = await admin
      .from("exercises")
      .insert({ studio_id: studioB, name: `Fremduebung ${kennung}`, target_min: 8, target_max: 12 })
      .select("id")
      .single();
    if (error) throw error;

    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Fremd anhaengen ${kennung}`,
      loadStep: 2.5,
    });
    await expect(
      attachExerciseToModel(client, { equipmentModelId: id, exerciseId: fremd.id }),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("das eigene Video zu einer Gymtavo-Uebung liegt im Ordner des Studios", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Video ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ1,
    });
    const link = await attachExerciseToModel(client, {
      equipmentModelId: id,
      exerciseId: katalogUebung1,
    });
    const ziel = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: link.id,
      sizeBytes: 1024,
    });
    expect(ziel.storagePath.startsWith(`${studioA}/exercises/${link.id}/`)).toBe(true);
  });
});

describe("listCatalogTypes", () => {
  it("liefert die Gymtavo-Typen mit ihren Uebungen und Katalogvideo, nach Namen", async () => {
    const admin = serviceClient();
    const { data: link } = await admin
      .from("equipment_model_exercises")
      .select("id")
      .eq("equipment_model_id", typ1)
      .eq("exercise_id", katalogUebung1)
      .single();
    const { error } = await admin.from("instruction_assets").insert({
      equipment_model_exercise_id: link!.id,
      kind: "video",
      storage_path: `${GYMTAVO}/exercises/${link!.id}/${kennung}.mp4`,
      duration_s: 20,
    });
    if (error) throw error;

    const client = await userClient(trainerA);
    const typen = await listCatalogTypes(client);
    const eigene = typen.filter((t) => t.id === typ1 || t.id === typ2);
    expect(eigene.map((t) => t.id)).toEqual([typ1, typ2]);
    expect(eigene[0]!.exercises).toEqual([
      expect.objectContaining({
        exerciseId: katalogUebung1,
        name: `Bankdruecken ${kennung}`,
        videoStoragePath: `${GYMTAVO}/exercises/${link!.id}/${kennung}.mp4`,
        videoDurationS: 20,
      }),
    ]);
    expect(typen.some((t) => t.id === fremdesModell)).toBe(false);
  });
});

describe("catalogTypeRequired", () => {
  it("ist im Studio wahr, sobald es Typen gibt -- im Gymtavo-Studio nie", async () => {
    const client = await userClient(trainerA);
    expect(await catalogTypeRequired(client, studioA)).toBe(true);
    expect(await catalogTypeRequired(client, GYMTAVO)).toBe(false);
  });
});

describe("detachCatalogExercise", () => {
  // Nach einem Typwechsel steht eine Gymtavo-Uebung mit eigenem Video als
  // "angehaengt" da. Loesen muss gehen, sonst sehen Mitglieder sie fuer
  // immer -- das Portal kennt kein eigenes Video-Loeschen (Nachtrag 10.1).
  it("loest eine Gymtavo-Uebung samt eigenem Video", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Loesen ${kennung}`,
      loadStep: 2.5,
      catalogModelId: typ2,
    });
    const link = await attachExerciseToModel(client, {
      equipmentModelId: id,
      exerciseId: katalogUebung1,
    });
    const admin = serviceClient();
    const { error } = await admin.from("instruction_assets").insert({
      equipment_model_exercise_id: link.id,
      kind: "video",
      storage_path: `${studioA}/exercises/${link.id}/${kennung}.mp4`,
      duration_s: 12,
    });
    if (error) throw error;

    await detachCatalogExercise(client, link.id);

    const { data: links } = await admin
      .from("equipment_model_exercises")
      .select("id")
      .eq("id", link.id);
    const { data: videos } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", link.id);
    expect(links).toEqual([]);
    expect(videos).toEqual([]);
  });

  it("negativ: eine eigene Uebung bleibt beim bisherigen Weg", async () => {
    const client = await userClient(trainerA);
    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: `Eigene loesen ${kennung}`,
      loadStep: 2.5,
    });
    const eigene = await createExercise(client, {
      studioId: studioA,
      name: `Eigene ${kennung}`,
      targetMin: 8,
      targetMax: 12,
    });
    const link = await attachExerciseToModel(client, { equipmentModelId: id, exerciseId: eigene.id });
    await expect(detachCatalogExercise(client, link.id)).rejects.toMatchObject({
      code: "validation_failed",
    });
  });
});

