import { beforeAll, describe, expect, it } from "vitest";
import { getEquipmentModelContext, getMachineContext } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 8.1:
// der Kontext eines Gymtavo-Typs ohne Geraet, und die Gymtavo-Uebungen im
// Kontext eines zugeordneten Studio-Geraets.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

let ohneStudioEmail: string;
let mitgliedEmail: string;
let ohneStudioId: string;
let mitgliedId: string;
let studioA: string;
let studioB: string;
let typ: string;
let katalogUebung: string;
let eigeneUebung: string;
let maschine: string;
let fremdesModell: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: `Typkontext A ${kennung}` }, { name: `Typkontext B ${kennung}` }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  ohneStudioEmail = uniqueEmail("typkontext-ohne");
  mitgliedEmail = uniqueEmail("typkontext-mitglied");
  ohneStudioId = await createTestUser(ohneStudioEmail);
  mitgliedId = await createTestUser(mitgliedEmail);
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: mitgliedId, role: "member" });
  if (rolleError) throw rolleError;

  const { data: typRow, error: typError } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: `Langhantel ${kennung}`, load_step: 2.5, load_min: 20 })
    .select("id")
    .single();
  if (typError) throw typError;
  typ = typRow.id;

  const { error: einstellungError } = await admin.from("equipment_setting_definitions").insert({
    equipment_model_id: typ,
    key: "ablage",
    label: "Ablage",
    kind: "number",
    min_value: 1,
    max_value: 10,
    step_value: 1,
  });
  if (einstellungError) throw einstellungError;

  const { data: modelle, error: modellError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: `Hantelbank ${kennung}`, load_step: 2.5, load_min: 20, catalog_model_id: typ },
      { studio_id: studioB, name: `Fremdbank ${kennung}`, load_step: 2.5, load_min: 20 },
    ])
    .select("id");
  if (modellError) throw modellError;
  fremdesModell = modelle[1]!.id;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: GYMTAVO, name: `Bankdruecken LH ${kennung}`, target_min: 6, target_max: 10 },
      { studio_id: studioA, name: `Hausbankdruecken ${kennung}`, target_min: 8, target_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  katalogUebung = uebungen[0]!.id;
  eigeneUebung = uebungen[1]!.id;

  const { data: verknuepfungen, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: typ, exercise_id: katalogUebung, sort_order: 1 },
      { equipment_model_id: modelle[0]!.id, exercise_id: eigeneUebung, sort_order: 1 },
    ])
    .select("id, equipment_model_id");
  if (linkError) throw linkError;
  const katalogVerknuepfung = verknuepfungen.find((v) => v.equipment_model_id === typ)!.id;

  const videoPfad = `${GYMTAVO}/${katalogVerknuepfung}/${kennung}.mp4`;
  const { error: uploadError } = await admin.storage
    .from("instruction-videos")
    .upload(videoPfad, new Blob([new Uint8Array(16)], { type: "video/mp4" }), {
      contentType: "video/mp4",
    });
  if (uploadError) throw uploadError;
  const { error: assetError } = await admin.from("instruction_assets").insert({
    equipment_model_exercise_id: katalogVerknuepfung,
    kind: "video",
    storage_path: videoPfad,
    duration_s: 30,
  });
  if (assetError) throw assetError;

  const { data: maschineRow, error: maschineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: modelle[0]!.id, label: "B2" })
    .select("id")
    .single();
  if (maschineError) throw maschineError;
  maschine = maschineRow.id;

  // Mitglied: zwei Tage frei am Typ, dazu ein Satz am Studio-Geraet mit
  // derselben Uebung -- der gehoert zu einer anderen Station.
  const freiTag1 = crypto.randomUUID();
  const freiTag2 = crypto.randomUUID();
  const imStudio = crypto.randomUUID();
  const { error: einheitError } = await admin.from("workout_sessions").insert([
    { id: freiTag1, studio_id: GYMTAVO, user_id: mitgliedId, started_at: "2026-10-01T17:00:00Z" },
    { id: freiTag2, studio_id: GYMTAVO, user_id: mitgliedId, started_at: "2026-10-03T17:00:00Z" },
    { id: imStudio, studio_id: studioA, user_id: mitgliedId, started_at: "2026-10-04T17:00:00Z" },
  ]);
  if (einheitError) throw einheitError;

  const freierSatz = (sessionId: string, tag: string, load: number) => ({
    id: crypto.randomUUID(),
    studio_id: GYMTAVO,
    user_id: mitgliedId,
    session_id: sessionId,
    equipment_model_id: typ,
    exercise_id: katalogUebung,
    set_index: 1,
    load,
    volume: 8,
    performed_at: `${tag}T17:30:00Z`,
  });
  const { error: satzError } = await admin.from("workout_sets").insert([
    freierSatz(freiTag1, "2026-10-01", 60),
    freierSatz(freiTag2, "2026-10-03", 62.5),
    {
      id: crypto.randomUUID(),
      studio_id: studioA,
      user_id: mitgliedId,
      session_id: imStudio,
      machine_id: maschine,
      exercise_id: katalogUebung,
      set_index: 1,
      load: 90,
      volume: 8,
      performed_at: "2026-10-04T17:30:00Z",
    },
  ]);
  if (satzError) throw satzError;
});

describe("Gymtavo-Uebungen im Geraetekontext", () => {
  it("zeigt am zugeordneten Studio-Geraet erst die eigene, dann die Gymtavo-Uebung samt Katalogvideo", async () => {
    const client = await userClient(mitgliedEmail);

    const kontext = await getMachineContext(client, maschine);

    expect(kontext.exercises.map((u) => u.id)).toEqual([eigeneUebung, katalogUebung]);
    expect(kontext.exercises[1]?.instructionVideoUrl).toBeTruthy();
  });
});

describe("getEquipmentModelContext", () => {
  it("liefert ohne Studio Typ, Einstellungen und Uebungen, ohne Geraet und Kalibrierung", async () => {
    const client = await userClient(ohneStudioEmail);

    const kontext = await getEquipmentModelContext(client, typ);

    expect(kontext.machine).toBeNull();
    expect(kontext.calibration).toBeNull();
    expect(kontext.equipmentModel).toMatchObject({ id: typ, loadStep: 2.5, loadMin: 20 });
    expect(kontext.settingDefinitions.map((e) => e.key)).toEqual(["ablage"]);
    expect(kontext.exercises.map((u) => u.id)).toEqual([katalogUebung]);
    expect(kontext.exercises[0]?.instructionVideoUrl).toBeTruthy();
    expect(kontext.history).toEqual([]);
  });

  it("rechnet nur auf eigenen Saetzen ohne Geraet an diesem Typ", async () => {
    const client = await userClient(mitgliedEmail);

    const kontext = await getEquipmentModelContext(client, typ);

    expect(kontext.selectedExerciseId).toBe(katalogUebung);
    expect(kontext.history.map((h) => h.load).sort()).toEqual([60, 62.5]);
    expect(kontext.suggestion.inputs.currentLoad).toBe(62.5);
  });

  it("haelt den Vorschlag am Typ fest, ohne Geraet", async () => {
    const client = await userClient(ohneStudioEmail);
    await getEquipmentModelContext(client, typ);

    const admin = serviceClient();
    const { data } = await admin
      .from("progression_suggestions")
      .select("studio_id, machine_id, equipment_model_id")
      .eq("user_id", ohneStudioId)
      .eq("equipment_model_id", typ);

    expect(data).toContainEqual({ studio_id: GYMTAVO, machine_id: null, equipment_model_id: typ });
  });

  it("nimmt das eigene Studio als Ort des Vorschlags", async () => {
    const client = await userClient(mitgliedEmail);
    await getEquipmentModelContext(client, typ, studioA);

    const admin = serviceClient();
    const { data } = await admin
      .from("progression_suggestions")
      .select("studio_id")
      .eq("user_id", mitgliedId)
      .eq("equipment_model_id", typ)
      .is("machine_id", null);

    expect(data).toContainEqual({ studio_id: studioA });
  });

  it("weist den Typ eines fremden Studios zurueck", async () => {
    const client = await userClient(mitgliedEmail);

    await expect(getEquipmentModelContext(client, fremdesModell)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("weist ein fremdes Studio als Ort zurueck", async () => {
    const client = await userClient(mitgliedEmail);

    await expect(getEquipmentModelContext(client, typ, studioB)).rejects.toMatchObject({
      code: "not_found",
    });
  });
});
