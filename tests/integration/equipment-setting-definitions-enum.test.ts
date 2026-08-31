import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// kind = 'enum' stand seit 0004 im Check-Constraint, war aber unbenutzbar:
// es gab keine Spalte fuer die erlaubten Werte. Eine Definition "Sitzposition
// = A|B|C" liess sich nicht ausdruecken, und der Einstellparameter-Editor
// haette eine Auswahl anbieten muessen, die nirgends steht.

let studioA: string;
let trainerA: string;
let modelA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Enum-Studio A" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  trainerA = uniqueEmail("enum-trainer-a");
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({
      studio_id: studioA,
      user_id: await createTestUser(trainerA),
      role: "trainer",
    });
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Enum-Modell A", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;
  modelA = model.id;
});

/** Postgres check_violation -- so kann kein Test bestehen, weil die Spalte fehlt. */
const CHECK_VIOLATION = "23514";

/** Eindeutiger Key je Testfall -- unique (equipment_model_id, key). */
function key(name: string): string {
  return `${name}-${crypto.randomUUID().slice(0, 8)}`;
}

describe("equipment_setting_definitions: erlaubte Werte fuer kind = 'enum'", () => {
  it("positiv: der Trainer legt eine Auswahl mit erlaubten Werten an und liest sie zurueck", async () => {
    const client = await userClient(trainerA);
    const k = key("sitzposition");

    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: k,
      label: "Sitzposition",
      kind: "enum",
      allowed_values: ["A", "B", "C"],
    });
    expect(error).toBeNull();

    const { data } = await client
      .from("equipment_setting_definitions")
      .select("kind, allowed_values")
      .eq("equipment_model_id", modelA)
      .eq("key", k)
      .single();
    expect(data?.kind).toBe("enum");
    expect(data?.allowed_values).toEqual(["A", "B", "C"]);
  });

  it("negativ: eine Auswahl ohne erlaubte Werte ist nicht speicherbar", async () => {
    const client = await userClient(trainerA);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: key("ohne-werte"),
      label: "Ohne Werte",
      kind: "enum",
    });
    expect(error?.code).toBe(CHECK_VIOLATION);
  });

  it("negativ: eine Auswahl mit nur einem Wert ist keine Auswahl", async () => {
    const client = await userClient(trainerA);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: key("ein-wert"),
      label: "Ein Wert",
      kind: "enum",
      allowed_values: ["A"],
    });
    expect(error?.code).toBe(CHECK_VIOLATION);
  });

  it("negativ: leere oder nur aus Leerzeichen bestehende Werte sind nicht speicherbar", async () => {
    const client = await userClient(trainerA);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: key("leerer-wert"),
      label: "Leerer Wert",
      kind: "enum",
      allowed_values: ["A", "   "],
    });
    expect(error?.code).toBe(CHECK_VIOLATION);
  });

  it("negativ: doppelte Werte sind nicht speicherbar", async () => {
    const client = await userClient(trainerA);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: key("doppelt"),
      label: "Doppelt",
      kind: "enum",
      allowed_values: ["A", "A"],
    });
    expect(error?.code).toBe(CHECK_VIOLATION);
  });

  it("negativ: ein Zahlenparameter traegt keine erlaubten Werte", async () => {
    const client = await userClient(trainerA);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: key("zahl-mit-werten"),
      label: "Zahl mit Werten",
      kind: "number",
      allowed_values: ["A", "B"],
    });
    expect(error?.code).toBe(CHECK_VIOLATION);
  });

  it("positiv: ein Zahlenparameter bleibt unveraendert speicherbar", async () => {
    const client = await userClient(trainerA);
    const k = key("lehne");

    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelA,
      key: k,
      label: "Lehne",
      kind: "number",
      min_value: 1,
      max_value: 10,
      step_value: 1,
    });
    expect(error).toBeNull();

    const { data } = await client
      .from("equipment_setting_definitions")
      .select("allowed_values")
      .eq("equipment_model_id", modelA)
      .eq("key", k)
      .single();
    expect(data?.allowed_values).toBeNull();
  });
});
