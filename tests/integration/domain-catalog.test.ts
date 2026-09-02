import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  assignTag,
  attachExerciseToModel,
  createEquipmentModel,
  createExercise,
  createMachine,
  createSettingDefinition,
  createTagToken,
  deactivateMachine,
  detachExercise,
  getStudioCatalog,
  hashTagToken,
  reorderModelExercises,
  revokeTag,
  updateEquipmentModel,
} from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { tagAnlegen } from "../helpers/tags.js";
import { chargeAnlegen, lieferungAnlegen } from "@fitretro/domain/chargen";

let studioA: string;
let studioB: string;
let trainerA: string;
let memberA: string;

/** Ein frisches Geraetemodell in Studio A, per Trainer angelegt. */
async function modell(name = "Katalog-Modell"): Promise<string> {
  const client = await userClient(trainerA);
  const { id } = await createEquipmentModel(client, {
    studioId: studioA,
    name: `${name} ${crypto.randomUUID().slice(0, 8)}`,
    weightStepKg: 2.5,
  });
  return id;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Katalog-Studio A" }, { name: "Katalog-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("katalog-trainer-a");
  memberA = uniqueEmail("katalog-member-a");
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" },
      { studio_id: studioA, user_id: await createTestUser(memberA), role: "member" },
    ]);
  if (membershipError) throw membershipError;
});

describe("createEquipmentModel", () => {
  it("positiv: der Trainer legt ein Geraetemodell im eigenen Studio an", async () => {
    const client = await userClient(trainerA);

    const { id } = await createEquipmentModel(client, {
      studioId: studioA,
      name: "Latzug",
      manufacturer: "Technogym",
      weightStepKg: 2.5,
      minWeightKg: 5,
      maxWeightKg: 100,
    });

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_models")
      .select("studio_id, name, weight_step_kg")
      .eq("id", id)
      .single();
    expect(data?.studio_id).toBe(studioA);
    expect(data?.name).toBe("Latzug");
    expect(Number(data?.weight_step_kg)).toBe(2.5);
  });

  it("negativ: ein einfaches Mitglied legt kein Modell an", async () => {
    const client = await userClient(memberA);

    await expect(
      createEquipmentModel(client, {
        studioId: studioA,
        name: "Verbotenes Modell",
        weightStepKg: 5,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("cross-tenant: nicht im fremden Studio", async () => {
    const client = await userClient(trainerA);

    await expect(
      createEquipmentModel(client, {
        studioId: studioB,
        name: "Fremdes Modell",
        weightStepKg: 5,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein leerer Name wird abgewiesen, bevor die Datenbank ihn sieht", async () => {
    const client = await userClient(trainerA);

    await expect(
      createEquipmentModel(client, { studioId: studioA, name: "   ", weightStepKg: 5 }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein Gewichtsschritt von null ergibt keine Progression", async () => {
    const client = await userClient(trainerA);

    await expect(
      createEquipmentModel(client, { studioId: studioA, name: "Ohne Schritt", weightStepKg: 0 }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein Maximum unter dem Minimum wird abgewiesen", async () => {
    const client = await userClient(trainerA);

    await expect(
      createEquipmentModel(client, {
        studioId: studioA,
        name: "Verdreht",
        weightStepKg: 5,
        minWeightKg: 50,
        maxWeightKg: 10,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("positiv: ein Modell laesst sich nachtraeglich aendern", async () => {
    const client = await userClient(trainerA);
    const id = await modell();

    await updateEquipmentModel(client, id, { manufacturer: "Gym80", maxWeightKg: 120 });

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_models")
      .select("manufacturer, max_weight_kg")
      .eq("id", id)
      .single();
    expect(data?.manufacturer).toBe("Gym80");
    expect(Number(data?.max_weight_kg)).toBe(120);
  });
});

describe("createSettingDefinition", () => {
  it("positiv: ein Zahlenparameter mit Bereich und Schritt", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();

    const { id } = await createSettingDefinition(client, {
      equipmentModelId: modelId,
      key: "sitz",
      label: "Sitzposition",
      kind: "number",
      minValue: 1,
      maxValue: 8,
      stepValue: 1,
    });

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_setting_definitions")
      .select("kind, min_value, allowed_values")
      .eq("id", id)
      .single();
    expect(data?.kind).toBe("number");
    expect(Number(data?.min_value)).toBe(1);
    expect(data?.allowed_values).toBeNull();
  });

  it("positiv: eine Auswahl mit erlaubten Werten", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();

    const { id } = await createSettingDefinition(client, {
      equipmentModelId: modelId,
      key: "griff",
      label: "Griffstellung",
      kind: "enum",
      allowedValues: ["eng", "weit"],
    });

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_setting_definitions")
      .select("allowed_values")
      .eq("id", id)
      .single();
    expect(data?.allowed_values).toEqual(["eng", "weit"]);
  });

  it("negativ: eine Auswahl ohne Werte scheitert schon an der Eingabepruefung", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();

    await expect(
      createSettingDefinition(client, {
        equipmentModelId: modelId,
        key: "leer",
        label: "Leer",
        kind: "enum",
      }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein Zahlenparameter mit Werteliste ist widerspruechlich", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();

    await expect(
      createSettingDefinition(client, {
        equipmentModelId: modelId,
        key: "widerspruch",
        label: "Widerspruch",
        kind: "number",
        allowedValues: ["a", "b"],
      }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein einfaches Mitglied definiert keine Parameter", async () => {
    const trainer = await userClient(trainerA);
    const modelId = await modell();
    const client = await userClient(memberA);

    await expect(
      createSettingDefinition(client, {
        equipmentModelId: modelId,
        key: "verboten",
        label: "Verboten",
        kind: "number",
      }),
    ).rejects.toThrow(DomainError);
    expect(trainer).toBeDefined();
  });
});

describe("Uebungen und ihre Reihenfolge", () => {
  it("positiv: Uebung anlegen, zuordnen und die Reihenfolge festlegen", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();

    const erste = await createExercise(client, {
      studioId: studioA,
      name: "Latzug breit",
      targetRepsMin: 8,
      targetRepsMax: 12,
    });
    const zweite = await createExercise(client, {
      studioId: studioA,
      name: "Latzug eng",
      targetRepsMin: 8,
      targetRepsMax: 12,
    });

    const linkErste = await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: erste.id,
    });
    const linkZweite = await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: zweite.id,
    });

    await reorderModelExercises(client, {
      equipmentModelId: modelId,
      orderedLinkIds: [linkZweite.id, linkErste.id],
    });

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_model_exercises")
      .select("id, sort_order")
      .eq("equipment_model_id", modelId)
      .order("sort_order", { ascending: true });
    expect(data?.map((row) => row.id)).toEqual([linkZweite.id, linkErste.id]);
  });

  it("negativ: eine Wiederholungsspanne mit Maximum unter Minimum wird abgewiesen", async () => {
    const client = await userClient(trainerA);

    await expect(
      createExercise(client, {
        studioId: studioA,
        name: "Verdreht",
        targetRepsMin: 12,
        targetRepsMax: 8,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("cross-tenant: eine Uebung aus einem fremden Studio laesst sich nicht zuordnen", async () => {
    const admin = serviceClient();
    const { data: fremd, error } = await admin
      .from("exercises")
      .insert({
        studio_id: studioB,
        name: "Fremde Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (error) throw error;

    const client = await userClient(trainerA);
    const modelId = await modell();

    await expect(
      attachExerciseToModel(client, {
        equipmentModelId: modelId,
        exerciseId: fremd.id,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("positiv: eine Zuordnung ohne Video laesst sich wieder loesen", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();
    const uebung = await createExercise(client, {
      studioId: studioA,
      name: "Zu loesen",
      targetRepsMin: 8,
      targetRepsMax: 12,
    });
    const link = await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: uebung.id,
    });

    await detachExercise(client, link.id);

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_model_exercises")
      .select("id")
      .eq("id", link.id);
    expect(data).toEqual([]);
  });

  it("negativ: eine Zuordnung mit Einweisungsvideo laesst sich nicht loesen", async () => {
    // 0019: das Video muss zuerst bewusst weg. Der Editor darf daraus keinen
    // stillen Datenverlust machen.
    const client = await userClient(trainerA);
    const modelId = await modell();
    const uebung = await createExercise(client, {
      studioId: studioA,
      name: "Mit Video",
      targetRepsMin: 8,
      targetRepsMax: 12,
    });
    const link = await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: uebung.id,
    });

    const admin = serviceClient();
    const { error } = await admin.from("instruction_assets").insert({
      equipment_model_exercise_id: link.id,
      kind: "video",
      storage_path: `${studioA}/exercises/${link.id}/video.mp4`,
      duration_s: 20,
    });
    if (error) throw error;

    await expect(detachExercise(client, link.id)).rejects.toThrow(DomainError);
  });
});

describe("Geraeteinstanzen", () => {
  it("positiv: eine Instanz zu einem Modell anlegen", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();

    const { id } = await createMachine(client, {
      studioId: studioA,
      equipmentModelId: modelId,
      label: "12",
      locationNote: "Rueckwand links",
    });

    const admin = serviceClient();
    const { data } = await admin
      .from("machines")
      .select("label, status, location_note")
      .eq("id", id)
      .single();
    expect(data?.label).toBe("12");
    expect(data?.status).toBe("active");
    expect(data?.location_note).toBe("Rueckwand links");
  });

  it("negativ: ein einfaches Mitglied legt keine Instanz an", async () => {
    const modelId = await modell();
    const client = await userClient(memberA);

    await expect(
      createMachine(client, {
        studioId: studioA,
        equipmentModelId: modelId,
        label: "verboten",
      }),
    ).rejects.toThrow(DomainError);
  });

  it("stilllegen statt loeschen -- auch wenn das Geraet je einen Tag getragen hat", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();
    const { id: machineId } = await createMachine(client, {
      studioId: studioA,
      equipmentModelId: modelId,
      label: "13",
    });
    await tagAnlegen(serviceClient(), { studioId: studioA, machineId, status: "active" });

    await deactivateMachine(client, machineId);

    const admin = serviceClient();
    const { data } = await admin
      .from("machines")
      .select("status")
      .eq("id", machineId)
      .single();
    expect(data?.status).toBe("inactive");
  });
});

describe("Tags", () => {
  it("liefert den Token genau einmal -- gespeichert wird nur sein Hash", async () => {
    const client = await userClient(trainerA);

    const { id, token } = await tagAnlegen(serviceClient(), { studioId: studioA });

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("token_hash, status, machine_id")
      .eq("id", id)
      .single();
    expect(data?.token_hash).toBe(hashTagToken(token));
    expect(JSON.stringify(data)).not.toContain(token);
    expect(data?.status).toBe("unassigned");
    expect(data?.machine_id).toBeNull();
  });

  it("positiv: anlegen und zuweisen in einem Zug ergibt einen aktiven Tag", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();
    const { id: machineId } = await createMachine(client, {
      studioId: studioA,
      equipmentModelId: modelId,
      label: "14",
    });

    const { id } = await tagAnlegen(serviceClient(), { studioId: studioA, machineId, status: "active" });

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("status, machine_id")
      .eq("id", id)
      .single();
    expect(data?.status).toBe("active");
    expect(data?.machine_id).toBe(machineId);
  });

  it("positiv: ein vorraetiger Tag laesst sich spaeter zuweisen", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();
    const { id: machineId } = await createMachine(client, {
      studioId: studioA,
      equipmentModelId: modelId,
      label: "15",
    });
    const { id: tagId } = await tagAnlegen(serviceClient(), { studioId: studioA });

    await assignTag(client, { tagId, machineId });

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("status, machine_id")
      .eq("id", tagId)
      .single();
    expect(data?.status).toBe("active");
    expect(data?.machine_id).toBe(machineId);
  });

  it("positiv: ein Tag laesst sich sperren und traegt danach einen Sperrzeitpunkt", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell();
    const { id: machineId } = await createMachine(client, {
      studioId: studioA,
      equipmentModelId: modelId,
      label: "16",
    });
    const { id: tagId } = await tagAnlegen(serviceClient(), { studioId: studioA, machineId, status: "active" });

    await revokeTag(client, tagId);

    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("status, revoked_at")
      .eq("id", tagId)
      .single();
    expect(data?.status).toBe("revoked");
    expect(data?.revoked_at).not.toBeNull();
  });
});

describe("getStudioCatalog", () => {
  it("liefert Modelle, Parameter, Uebungen, Instanzen und Tags in einem Baum", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell("Baum-Modell");

    await createSettingDefinition(client, {
      equipmentModelId: modelId,
      key: "sitz",
      label: "Sitzposition",
      kind: "number",
      minValue: 1,
      maxValue: 8,
    });
    const uebung = await createExercise(client, {
      studioId: studioA,
      name: "Baum-Uebung",
      targetRepsMin: 8,
      targetRepsMax: 12,
    });
    await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: uebung.id,
    });
    const { id: machineId } = await createMachine(client, {
      studioId: studioA,
      equipmentModelId: modelId,
      label: "17",
    });
    await tagAnlegen(serviceClient(), { studioId: studioA, machineId, status: "active" });

    const katalog = await getStudioCatalog(client, studioA);

    const modell1 = katalog.models.find((m) => m.id === modelId);
    expect(modell1).toBeDefined();
    expect(modell1?.settingDefinitions.map((s) => s.key)).toContain("sitz");
    expect(modell1?.exercises.map((e) => e.name)).toContain("Baum-Uebung");

    const geraet = modell1?.machines.find((m) => m.id === machineId);
    expect(geraet?.label).toBe("17");
    expect(geraet?.activeTagCount).toBe(1);
  });

  it("zeigt, was einer Uebung noch fehlt -- ohne Vollstaendigkeit zu erzwingen", async () => {
    const client = await userClient(trainerA);
    const modelId = await modell("Ohne-Video-Modell");
    const uebung = await createExercise(client, {
      studioId: studioA,
      name: "Noch ohne Video",
      targetRepsMin: 8,
      targetRepsMax: 12,
    });
    await attachExerciseToModel(client, {
      equipmentModelId: modelId,
      exerciseId: uebung.id,
    });

    const katalog = await getStudioCatalog(client, studioA);
    const gefunden = katalog.models
      .find((m) => m.id === modelId)
      ?.exercises.find((e) => e.exerciseId === uebung.id);

    expect(gefunden?.hasVideo).toBe(false);
  });

  it("listet die vorraetigen Tags des Studios -- sie warten auf ein Geraet", async () => {
    const client = await userClient(trainerA);
    const { id: tagId } = await tagAnlegen(serviceClient(), { studioId: studioA });

    const katalog = await getStudioCatalog(client, studioA);

    const vorraetig = katalog.tags.find((tag) => tag.id === tagId);
    expect(vorraetig?.status).toBe("unassigned");
    expect(vorraetig?.machineId).toBeNull();
  });

  it("cross-tenant: der Katalog eines fremden Studios bleibt leer", async () => {
    const client = await userClient(trainerA);

    await expect(getStudioCatalog(client, studioB)).rejects.toThrow(DomainError);
  });
});

describe("Tag-Sorte im Katalog", () => {
  it("liefert die Sorte im Katalog mit", async () => {
    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, studioA);
    expect(katalog.tags.every((tag) => tag.kind === "machine" || tag.kind === "studio")).toBe(true);
  });

  it("fuehrt einen Aushang-Tag mit kind=studio und ohne Geraet", async () => {
    const admin = serviceClient();
    await tagAnlegen(admin, { studioId: studioA, kind: "studio", status: "active" });

    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, studioA);
    const aushang = katalog.tags.find((tag) => tag.kind === "studio");
    expect(aushang).toBeDefined();
    expect(aushang?.machineId).toBeNull();
  });
});

describe("Lieferungen im Katalog", () => {
  it("liefert Charge und Nummer je Tag", async () => {
    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, studioA);
    expect(katalog.tags.length).toBeGreaterThan(0);
    expect(katalog.tags.every((tag) => tag.batchCode !== "")).toBe(true);
    expect(katalog.tags.every((tag) => tag.batchIndex >= 1)).toBe(true);
  });

  it("liefert die Lieferungen des Studios mit", async () => {
    const admin = serviceClient();
    const code = `katalog-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 100 });
    await lieferungAnlegen(admin, { chargeCode: code, studioId: studioA, menge: 100 });

    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, studioA);
    const lieferung = katalog.shipments.find((zeile) => zeile.batchCode === code);
    expect(lieferung?.quantity).toBe(100);
    expect(lieferung?.kind).toBe("machine");
  });

  it("zeigt die Charge auch ohne eigene Lieferung, wenn ein Tag aus ihr gebunden ist", async () => {
    const admin = serviceClient();
    const code = `ohne-lieferung-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "machine", menge: 1 });

    // Kein lieferungAnlegen hier -- absichtlich keine tag_shipments-Zeile fuer
    // studioA zu dieser Charge. Die Sichtbarkeit soll trotzdem ueber den
    // gebundenen Tag selbst entstehen (machine_tags-Zweig von 0029), nicht nur
    // ueber eine Lieferung.
    const { data: geraetZeile, error: geraetFehler } = await admin
      .from("machines")
      .select("id")
      .eq("studio_id", studioA)
      .limit(1)
      .single();
    if (geraetFehler) throw geraetFehler;

    // chargeAnlegen(menge: 1) hat bereits batch_index 1 studiolos angelegt --
    // die eigene Zeile braucht die naechste Nummer, sonst schlaegt der
    // Unique-Constraint (batch_id, batch_index) fehl.
    const { error: tagFehler } = await admin.from("machine_tags").insert({
      studio_id: studioA,
      machine_id: geraetZeile.id,
      kind: "machine",
      status: "active",
      token: createTagToken(),
      batch_id: charge.id,
      batch_index: 2,
    });
    if (tagFehler) throw tagFehler;

    const client = await userClient(trainerA);
    const katalog = await getStudioCatalog(client, studioA);
    const gebundenerTag = katalog.tags.find((tag) => tag.batchCode === code);
    expect(gebundenerTag).toBeDefined();
  });
});
