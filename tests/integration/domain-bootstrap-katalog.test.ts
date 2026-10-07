import { beforeAll, describe, expect, it } from "vitest";
import { getBootstrap } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 8.1:
// der Bootstrap liefert den Katalog, die Zuordnung und die Gymtavo-Uebungen
// am Studio-Geraet. Andere Testdateien legen ebenfalls Gymtavo-Typen an --
// geprueft wird deshalb auf Enthaltensein, nie auf Gleichheit der Liste.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

let ohneStudioEmail: string;
let mitgliedEmail: string;
let typ: string;
let katalogUebung1: string;
let katalogUebung2: string;
let studioModell: string;
let eigeneUebung: string;
let maschine: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: `Katalog-Bootstrap ${kennung}` })
    .select("id")
    .single();
  if (studioError) throw studioError;

  ohneStudioEmail = uniqueEmail("boot-katalog-ohne");
  mitgliedEmail = uniqueEmail("boot-katalog-mitglied");
  await createTestUser(ohneStudioEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: mitgliedId, role: "member" });
  if (rolleError) throw rolleError;

  const { data: typRow, error: typError } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: `Kabelzug ${kennung}`, load_step: 2.5, load_min: 2.5 })
    .select("id")
    .single();
  if (typError) throw typError;
  typ = typRow.id;

  const { error: einstellungError } = await admin.from("equipment_setting_definitions").insert({
    equipment_model_id: typ,
    key: "hoehe",
    label: "Höhe",
    kind: "number",
    min_value: 1,
    max_value: 20,
    step_value: 1,
  });
  if (einstellungError) throw einstellungError;

  const { data: modellRow, error: modellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: `Kabelturm ${kennung}`, load_step: 5, catalog_model_id: typ })
    .select("id")
    .single();
  if (modellError) throw modellError;
  studioModell = modellRow.id;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: GYMTAVO, name: `Face Pull ${kennung}`, target_min: 12, target_max: 15 },
      { studio_id: GYMTAVO, name: `Trizepsdruecken ${kennung}`, target_min: 10, target_max: 12 },
      { studio_id: studio.id, name: `Hausuebung ${kennung}`, target_min: 8, target_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  katalogUebung1 = uebungen[0]!.id;
  katalogUebung2 = uebungen[1]!.id;
  eigeneUebung = uebungen[2]!.id;

  // Am Typ beide Gymtavo-Uebungen; am Studio-Modell die eigene und --
  // ausdruecklich angehaengt -- die zweite Gymtavo-Uebung. Sie darf unter
  // dem Geraet trotzdem nur einmal erscheinen.
  const { error: linkError } = await admin.from("equipment_model_exercises").insert([
    { equipment_model_id: typ, exercise_id: katalogUebung1, sort_order: 1 },
    { equipment_model_id: typ, exercise_id: katalogUebung2, sort_order: 2 },
    { equipment_model_id: studioModell, exercise_id: eigeneUebung, sort_order: 1 },
    { equipment_model_id: studioModell, exercise_id: katalogUebung2, sort_order: 2 },
  ]);
  if (linkError) throw linkError;

  const { data: maschineRow, error: maschineError } = await admin
    .from("machines")
    .insert({ studio_id: studio.id, equipment_model_id: studioModell, label: "K1" })
    .select("id")
    .single();
  if (maschineError) throw maschineError;
  maschine = maschineRow.id;

  // Eine Einheit im Studio am Geraet, eine im Freien Training ohne Geraet.
  const studioEinheit = crypto.randomUUID();
  const freieEinheit = crypto.randomUUID();
  const { error: einheitError } = await admin.from("workout_sessions").insert([
    { id: studioEinheit, studio_id: studio.id, user_id: mitgliedId },
    { id: freieEinheit, studio_id: GYMTAVO, user_id: mitgliedId },
  ]);
  if (einheitError) throw einheitError;

  const { error: satzError } = await admin.from("workout_sets").insert([
    {
      id: crypto.randomUUID(),
      studio_id: studio.id,
      user_id: mitgliedId,
      session_id: studioEinheit,
      machine_id: maschine,
      exercise_id: katalogUebung1,
      set_index: 1,
      load: 20,
      volume: 12,
      performed_at: "2026-10-01T18:00:00Z",
    },
    {
      id: crypto.randomUUID(),
      studio_id: GYMTAVO,
      user_id: mitgliedId,
      session_id: freieEinheit,
      equipment_model_id: typ,
      exercise_id: katalogUebung1,
      set_index: 1,
      load: 12.5,
      volume: 15,
      performed_at: "2026-10-02T18:00:00Z",
    },
  ]);
  if (satzError) throw satzError;
});

describe("getBootstrap -- Gymtavo-Katalog", () => {
  it("liefert auch ohne Studio den Katalog mit Typen, Einstellungen und Uebungen", async () => {
    const client = await userClient(ohneStudioEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.studios).toEqual([]);
    expect(bootstrap.catalog?.studioId).toBe(GYMTAVO);
    const kabelzug = bootstrap.catalog?.equipmentTypes.find((t) => t.id === typ);
    expect(kabelzug).toMatchObject({
      name: `Kabelzug ${kennung}`,
      loadUnit: "kg",
      loadStep: 2.5,
      settingDefinitions: [expect.objectContaining({ key: "hoehe", label: "Höhe" })],
    });
    expect(kabelzug?.exercises.map((u) => u.id)).toEqual([katalogUebung1, katalogUebung2]);
  });

  it("fuehrt Studio-Modelle nicht als Gymtavo-Typen", async () => {
    const client = await userClient(mitgliedEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.catalog?.equipmentTypes.map((t) => t.id)).not.toContain(studioModell);
  });

  it("nennt am Studio-Modell den zugeordneten Gymtavo-Typ", async () => {
    const client = await userClient(mitgliedEmail);

    const bootstrap = await getBootstrap(client);

    const geraet = bootstrap.machines.find((m) => m.id === maschine);
    expect(geraet?.equipmentModel.catalogModelId).toBe(typ);
  });

  it("zeigt unter dem Geraet erst die eigenen, dann die Gymtavo-Uebungen -- jede einmal", async () => {
    const client = await userClient(mitgliedEmail);

    const bootstrap = await getBootstrap(client);

    const geraet = bootstrap.machines.find((m) => m.id === maschine);
    expect(geraet?.exercises.map((u) => u.id)).toEqual([
      eigeneUebung,
      katalogUebung2,
      katalogUebung1,
    ]);
  });

  it("trennt letzte Saetze am Geraet von denen am Typ ohne Geraet", async () => {
    const client = await userClient(mitgliedEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.lastSets).toEqual([
      expect.objectContaining({ machineId: maschine, exerciseId: katalogUebung1, load: 20 }),
    ]);
    expect(bootstrap.lastTypeSets).toEqual([
      expect.objectContaining({ equipmentModelId: typ, exerciseId: katalogUebung1, load: 12.5 }),
    ]);
  });

  it("zaehlt als Besuch am Geraet nur Einheiten mit Satz an diesem Geraet", async () => {
    const client = await userClient(mitgliedEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.machines.find((m) => m.id === maschine)?.visitCount).toBe(1);
  });
});
