import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let staffAEmail: string;
let memberBEmail: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Equipment Studio A" }, { name: "Equipment Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("eq-member-a");
  staffAEmail = uniqueEmail("eq-staff-a");
  memberBEmail = uniqueEmail("eq-member-b");

  const memberAId = await createTestUser(memberAEmail);
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
  ]);
  if (membershipError) throw membershipError;
});

describe("RLS auf equipment_models", () => {
  it("positiv: Staff kann ein Geraetemodell anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { data, error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Beinpresse", weight_step_kg: 5 })
      .select("id")
      .single();
    expect(error).toBeNull();
    expect(data?.id).toBeDefined();
  });

  it("negativ: Mitglied kann kein Geraetemodell anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Verboten", weight_step_kg: 5 });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B kann in Studio A nichts anlegen", async () => {
    const client = await userClient(memberBEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Fremd", weight_step_kg: 5 });
    expect(error).not.toBeNull();
  });

  it("positiv: Mitglied sieht Geraetemodelle seines Studios", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client.from("equipment_models").select("id");
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht Studio-A-Geraete nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("equipment_models")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });

  it("negativ: Staff kann kein Geraetemodell mit Gewichtsschritt <= 0 anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Ungueltig", weight_step_kg: 0 });
    expect(error).not.toBeNull();
  });
});

describe("RLS auf equipment_setting_definitions", () => {
  let modelId: string;

  beforeAll(async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Latzug", weight_step_kg: 2.5 })
      .select("id")
      .single();
    if (error) throw error;
    modelId = data.id;
  });

  it("positiv: Staff kann eine Einstelldefinition anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelId,
      key: "seat_position",
      label: "Sitzposition",
      kind: "number",
      min_value: 1,
      max_value: 8,
      step_value: 1,
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Einstelldefinition anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelId,
      key: "verboten",
      label: "Verboten",
      kind: "number",
    });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Mitglied aus Studio B sieht die Einstelldefinition nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("equipment_setting_definitions")
      .select("id")
      .eq("equipment_model_id", modelId);
    expect(data).toEqual([]);
  });
});
