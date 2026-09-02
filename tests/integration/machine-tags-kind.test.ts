import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";
import { tagAnlegen } from "../helpers/tags.js";

let studioId: string;
let machineId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Tag-Sorten Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Tag-Sorten Geraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: model.id, label: "01" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineId = machine.id;
});

describe("machine_tags.kind", () => {
  it("legt bestehende und neue Zeilen als 'machine' an", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId, machineId, status: "active" });

    const { data } = await admin
      .from("machine_tags")
      .select("kind")
      .eq("id", id)
      .single();
    expect(data?.kind).toBe("machine");
  });

  it("speichert einen aktiven Aushang ohne Geraet", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId, kind: "studio", status: "active" });

    const { data } = await admin
      .from("machine_tags")
      .select("id, kind, machine_id")
      .eq("id", id)
      .single();
    expect(data?.kind).toBe("studio");
    expect(data?.machine_id).toBeNull();
  });

  it("lehnt einen Aushang mit Geraet ab", async () => {
    const admin = serviceClient();
    let error: unknown = null;
    try {
      await tagAnlegen(admin, { studioId, kind: "studio", machineId, status: "active" });
    } catch (e) {
      error = e;
    }
    expect(error).not.toBeNull();
  });

  it("lehnt einen aktiven Geraetetag ohne Geraet weiterhin ab", async () => {
    // Der Schutz aus 0008 darf beim Umbau nicht verloren gehen.
    const admin = serviceClient();
    let error: unknown = null;
    try {
      await tagAnlegen(admin, { studioId, kind: "machine", status: "active" });
    } catch (e) {
      error = e;
    }
    expect(error).not.toBeNull();
  });
});
