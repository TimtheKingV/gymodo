import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";

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
    const { data, error } = await admin
      .from("machine_tags")
      .insert({
        studio_id: studioId,
        machine_id: machineId,
        token_hash: hashTagToken(createTagToken()),
        status: "active",
      })
      .select("kind")
      .single();
    expect(error).toBeNull();
    expect(data?.kind).toBe("machine");
  });

  it("speichert einen aktiven Aushang ohne Geraet", async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("machine_tags")
      .insert({
        studio_id: studioId,
        kind: "studio",
        token_hash: hashTagToken(createTagToken()),
        status: "active",
      })
      .select("id, kind, machine_id")
      .single();
    expect(error).toBeNull();
    expect(data?.kind).toBe("studio");
    expect(data?.machine_id).toBeNull();
  });

  it("lehnt einen Aushang mit Geraet ab", async () => {
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioId,
      kind: "studio",
      machine_id: machineId,
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });

  it("lehnt einen aktiven Geraetetag ohne Geraet weiterhin ab", async () => {
    // Der Schutz aus 0008 darf beim Umbau nicht verloren gehen.
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioId,
      kind: "machine",
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });
});
