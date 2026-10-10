import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  createEquipmentModel,
  getStudioCatalog,
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
