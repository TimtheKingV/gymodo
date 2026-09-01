import { beforeAll, describe, expect, it } from "vitest";
import {
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  createTagToken,
  getTagContext,
} from "@fitretro/domain";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberAId: string;
let machineA: string;
let breitId: string;
let engId: string;
let tokenA: string;
let tokenRevoked: string;
let tokenForeign: string;
let fotoPfad: string;
let videoPfad: string;

function newId(): string {
  return crypto.randomUUID();
}

function ascii(text: string): number[] {
  return [...text].map((character) => character.charCodeAt(0));
}

/** Kleinstes gueltiges JPEG. */
function jpegBytes() {
  return new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, ...ascii("JFIF"), 0x00, 0x01, 0x01,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
  ]);
}

/** Minimaler MP4-Rumpf mit ftyp-Box. */
function mp4Bytes() {
  return new Uint8Array([
    0x00, 0x00, 0x00, 0x18, ...ascii("ftyp"), ...ascii("isom"), 0x00, 0x00,
    0x02, 0x00, ...ascii("isomiso2"),
  ]);
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Kontext Studio A" }, { name: "Kontext Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;
  // Erster Pfadabschnitt ist die studio_id -- daran haengt die Policy aus 0020.
  fotoPfad = `${studioA}/models/${newId()}.jpg`;
  videoPfad = `${studioA}/exercises/${newId()}.mp4`;

  memberAEmail = uniqueEmail("kontext-member-a");
  memberAId = await createTestUser(memberAEmail);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: memberAId, role: "member" });
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Kabelzug",
      manufacturer: "Technogym",
      weight_step_kg: 2.5,
      min_weight_kg: 5,
      max_weight_kg: 100,
      photo_path: fotoPfad,
    })
    .select("id")
    .single();
  if (modelError) throw modelError;

  // Echte Objekte, keine erfundenen Pfade: eine signierte URL entsteht nur
  // fuer ein Objekt, das es gibt und das die Policy aus 0020 freigibt.
  const { error: fotoError } = await admin.storage
    .from(PHOTO_BUCKET)
    .upload(fotoPfad, new Blob([jpegBytes()], { type: "image/jpeg" }), {
      contentType: "image/jpeg",
      upsert: true,
    });
  if (fotoError) throw fotoError;

  const { error: videoError } = await admin.storage
    .from(VIDEO_BUCKET)
    .upload(videoPfad, new Blob([mp4Bytes()], { type: "video/mp4" }), {
      contentType: "video/mp4",
      upsert: true,
    });
  if (videoError) throw videoError;

  const { error: settingError } = await admin
    .from("equipment_setting_definitions")
    .insert([
      {
        equipment_model_id: model.id,
        key: "sitz",
        label: "Sitzposition",
        kind: "number",
        min_value: 1,
        max_value: 8,
        step_value: 1,
        sort_order: 1,
      },
      {
        equipment_model_id: model.id,
        key: "griff",
        label: "Griffstellung",
        kind: "enum",
        allowed_values: ["eng", "weit"],
        sort_order: 2,
      },
    ]);
  if (settingError) throw settingError;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Latzug breit",
        target_reps_min: 8,
        target_reps_max: 12,
      },
      {
        studio_id: studioA,
        name: "Latzug eng",
        target_reps_min: 8,
        target_reps_max: 12,
      },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;
  breitId = exercises[0]!.id;
  engId = exercises[1]!.id;

  const { data: links, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: model.id, exercise_id: breitId, sort_order: 1 },
      { equipment_model_id: model.id, exercise_id: engId, sort_order: 2 },
    ])
    .select("id, exercise_id");
  if (linkError) throw linkError;

  // Nur die erste Uebung bekommt ein Video. Vollstaendigkeit wird nie
  // erzwungen (Spec 6.8) -- die zweite muss trotzdem nutzbar bleiben.
  const { error: assetError } = await admin.from("instruction_assets").insert({
    equipment_model_exercise_id: links.find((l) => l.exercise_id === breitId)!.id,
    kind: "video",
    storage_path: videoPfad,
    duration_s: 25,
  });
  if (assetError) throw assetError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: model.id, label: "12" },
    ])
    .select("id");
  if (machineError) throw machineError;
  machineA = machines[0]!.id;

  const { data: foreignModel, error: foreignModelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioB, name: "Fremdgeraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (foreignModelError) throw foreignModelError;
  const { data: foreignMachine, error: foreignMachineError } = await admin
    .from("machines")
    .insert({
      studio_id: studioB,
      equipment_model_id: foreignModel.id,
      label: "99",
    })
    .select("id")
    .single();
  if (foreignMachineError) throw foreignMachineError;

  tokenA = createTagToken();
  tokenRevoked = createTagToken();
  tokenForeign = createTagToken();
  await tagsAnlegen(admin, [
    { studioId: studioA, machineId: machineA, token: tokenA, status: "active" },
    { studioId: studioA, token: tokenRevoked, status: "revoked" },
    { studioId: studioB, machineId: foreignMachine.id, token: tokenForeign, status: "active" },
  ]);
});

describe("getTagContext", () => {
  it("loest den Tag auf und liefert Geraet, Modell und Einstellparameter", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.machine.id).toBe(machineA);
    expect(context.machine.label).toBe("12");
    expect(context.equipmentModel.name).toBe("Kabelzug");
    expect(context.equipmentModel.weightStepKg).toBe(2.5);
    expect(context.settingDefinitions).toHaveLength(2);
    expect(context.settingDefinitions[0]!.key).toBe("sitz");
  });

  it("liefert das Foto als signierte URL, nicht als Speicherpfad", async () => {
    // Der Bucket ist privat: ein Pfad allein nuetzt dem Screen nichts, er
    // koennte damit nichts laden.
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.equipmentModel.photoUrl).toContain(fotoPfad);
    expect(context.equipmentModel.photoUrl).toContain("token=");

    const antwort = await fetch(context.equipmentModel.photoUrl!);
    expect(antwort.ok).toBe(true);
  });

  it("liefert das Einweisungsvideo als signierte URL", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    const mitVideo = context.exercises.find((uebung) => uebung.id === breitId);
    expect(mitVideo?.instructionVideoUrl).toContain(videoPfad);

    const antwort = await fetch(mitVideo!.instructionVideoUrl!);
    expect(antwort.ok).toBe(true);
  });

  it("eine Uebung ohne Video bleibt vollstaendig nutzbar", async () => {
    // Spec 6.8: Vollstaendigkeit wird nie erzwungen. Ein Alles-oder-nichts-
    // Setup stellt kein Studio fertig.
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    const ohneVideo = context.exercises.find((uebung) => uebung.id === engId);
    expect(ohneVideo).toBeDefined();
    expect(ohneVideo?.instructionVideoUrl).toBeNull();
    expect(ohneVideo?.name).toBe("Latzug eng");
  });

  it("liefert die erlaubten Werte einer Auswahl mit -- ohne sie kann der Screen kein Auswahlfeld zeichnen", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    const zahl = context.settingDefinitions.find((s) => s.key === "sitz");
    expect(zahl?.allowedValues).toBeNull();

    const auswahl = context.settingDefinitions.find((s) => s.key === "griff");
    expect(auswahl?.kind).toBe("enum");
    expect(auswahl?.allowedValues).toEqual(["eng", "weit"]);
  });

  it("liefert die Uebungen in der vom Studio gepflegten Reihenfolge", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.exercises.map((exercise) => exercise.id)).toEqual([
      breitId,
      engId,
    ]);
  });

  it("waehlt beim Erstkontakt die erste Uebung vor und schlaegt nichts vor", async () => {
    const client = await userClient(memberAEmail);

    const context = await getTagContext(client, tokenA);

    expect(context.selectedExerciseId).toBe(breitId);
    expect(context.suggestion.resultWeightKg).toBeNull();
    expect(context.suggestion.reasonCode).toBe("kein_verlauf");
  });

  it("waehlt die zuletzt genutzte Uebung vor", async () => {
    const admin = serviceClient();
    const sessionId = newId();
    const { error: sessionError } = await admin
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (sessionError) throw sessionError;
    const { error: setError } = await admin.from("workout_sets").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionId,
      machine_id: machineA,
      exercise_id: engId,
      set_index: 1,
      weight_kg: 45,
      reps: 12,
      performed_at: new Date("2026-08-27T18:00:00Z").toISOString(),
    });
    if (setError) throw setError;

    const client = await userClient(memberAEmail);
    const context = await getTagContext(client, tokenA);

    expect(context.selectedExerciseId).toBe(engId);
  });

  it("berechnet den Vorschlag aus der eigenen Historie und haelt ihn fest", async () => {
    const admin = serviceClient();
    const sessionId = newId();
    const { error: sessionError } = await admin
      .from("workout_sessions")
      .insert({ id: sessionId, studio_id: studioA, user_id: memberAId });
    if (sessionError) throw sessionError;
    // Korridor 8-12 mit Reserve ausgeschoepft -- die Regel steigert.
    const { error: setError } = await admin.from("workout_sets").insert({
      id: newId(),
      studio_id: studioA,
      user_id: memberAId,
      session_id: sessionId,
      machine_id: machineA,
      exercise_id: engId,
      set_index: 2,
      weight_kg: 45,
      reps: 12,
      rir: 2,
      performed_at: new Date("2026-08-28T18:00:00Z").toISOString(),
    });
    if (setError) throw setError;

    const client = await userClient(memberAEmail);
    const context = await getTagContext(client, tokenA);

    expect(context.suggestion.reasonCode).toBe("korridor_oben_erreicht");
    expect(context.suggestion.resultWeightKg).toBe(47.5);

    const { data } = await admin
      .from("progression_suggestions")
      .select("reason_code, result_weight_kg")
      .eq("user_id", memberAId)
      .eq("machine_id", machineA)
      .eq("exercise_id", engId)
      .order("created_at", { ascending: false })
      .limit(1);
    expect(data?.[0]?.reason_code).toBe("korridor_oben_erreicht");
  });

  it("liefert die eigenen Einstellwerte mit", async () => {
    const admin = serviceClient();
    const { error } = await admin
      .from("member_machine_calibrations")
      .insert({
        studio_id: studioA,
        user_id: memberAId,
        machine_id: machineA,
        exercise_id: engId,
        setting_values: { sitz: 6 },
        schema_version: 1,
      });
    if (error) throw error;

    const client = await userClient(memberAEmail);
    const context = await getTagContext(client, tokenA);

    expect(context.calibration?.settingValues).toEqual({ sitz: 6 });
  });

  it("weist einen gesperrten Tag zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(getTagContext(client, tokenRevoked)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("weist einen unbekannten Tag zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      getTagContext(client, createTagToken()),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("cross-tenant: der Tag eines fremden Studios ist nicht aufloesbar", async () => {
    const client = await userClient(memberAEmail);

    await expect(getTagContext(client, tokenForeign)).rejects.toMatchObject({
      code: "not_found",
    });
  });

  it("weist ein unbrauchbares Tokenformat als Eingabefehler zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(getTagContext(client, "viel-zu-kurz")).rejects.toMatchObject({
      code: "validation_failed",
    });
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(getTagContext(anonClient(), tokenA)).rejects.toMatchObject({
      code: "unauthorized",
    });
  });
});
