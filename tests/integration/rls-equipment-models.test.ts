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
let staffBEmail: string;

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
  staffBEmail = uniqueEmail("eq-staff-b");

  const memberAId = await createTestUser(memberAEmail);
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);
  const staffBId = await createTestUser(staffBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
    { studio_id: studioB, user_id: staffBId, role: "trainer" },
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

  it("cross-tenant (Rolle statt Mandant): Staff aus Studio B kann in Studio A nichts anlegen", async () => {
    const client = await userClient(staffBEmail);
    const { error } = await client
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Fremd-Staff", weight_step_kg: 5 });
    expect(error).not.toBeNull();
  });

  describe("update/delete", () => {
    let updateModelId: string;
    let moveModelId: string;
    let deleteModelId: string;
    let deleteDenyModelId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data, error } = await admin
        .from("equipment_models")
        .insert([
          { studio_id: studioA, name: "Update-Ziel", weight_step_kg: 5 },
          { studio_id: studioA, name: "Move-Ziel", weight_step_kg: 5 },
          { studio_id: studioA, name: "Delete-Ziel", weight_step_kg: 5 },
          { studio_id: studioA, name: "Delete-Verboten-Ziel", weight_step_kg: 5 },
        ])
        .select("id");
      if (error) throw error;
      updateModelId = data[0]!.id;
      moveModelId = data[1]!.id;
      deleteModelId = data[2]!.id;
      deleteDenyModelId = data[3]!.id;
    });

    it("positiv: Staff kann ein Geraetemodell aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("equipment_models")
        .update({ name: "Update-Ziel (bearbeitet)" })
        .eq("id", updateModelId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateModelId);
    });

    it("negativ: Mitglied kann kein Geraetemodell aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_models")
        .update({ name: "Verboten-Update" })
        .eq("id", updateModelId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);
    });

    it("negativ (with check): Staff kann sein Geraetemodell nicht in ein fremdes Studio verschieben", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("equipment_models")
        .update({ studio_id: studioB })
        .eq("id", moveModelId);
      expect(error).not.toBeNull();
    });

    it("positiv: Staff kann ein Geraetemodell loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("equipment_models").delete().eq("id", deleteModelId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_models")
        .select("id")
        .eq("id", deleteModelId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann kein Geraetemodell loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_models")
        .delete()
        .eq("id", deleteDenyModelId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_models")
        .select("id")
        .eq("id", deleteDenyModelId);
      expect(remaining).toHaveLength(1);
    });
  });
});

describe("RLS auf equipment_setting_definitions", () => {
  let modelId: string;
  let modelB: string;

  beforeAll(async () => {
    const admin = serviceClient();
    const { data, error } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Latzug", weight_step_kg: 2.5 })
      .select("id")
      .single();
    if (error) throw error;
    modelId = data.id;

    const { data: modelBData, error: modelBError } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioB, name: "Latzug B", weight_step_kg: 2.5 })
      .select("id")
      .single();
    if (modelBError) throw modelBError;
    modelB = modelBData.id;
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

  it("cross-tenant: Staff aus Studio B kann keine Einstelldefinition an einem Studio-A-Geraetemodell anlegen", async () => {
    // staffBEmail wird an dieser Datei sonst nur gegen equipment_models
    // verwendet -- die vier esd-Schreibpolicies waren damit nur auf der
    // Rollen-Dimension (Staff vs. Mitglied) abgesichert, nicht auf der
    // Mandanten-Dimension.
    const client = await userClient(staffBEmail);
    const { error } = await client.from("equipment_setting_definitions").insert({
      equipment_model_id: modelId,
      key: "cross_tenant_verboten",
      label: "Cross-Tenant-Verboten",
      kind: "number",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("equipment_setting_definitions")
      .select("id")
      .eq("equipment_model_id", modelId)
      .eq("key", "cross_tenant_verboten");
    expect(found).toEqual([]);
  });

  it("positiv: Mitglied sieht die Einstelldefinition seines Studios", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client
      .from("equipment_setting_definitions")
      .select("id")
      .eq("equipment_model_id", modelId);
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht die Einstelldefinition nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("equipment_setting_definitions")
      .select("id")
      .eq("equipment_model_id", modelId);
    expect(data).toEqual([]);
  });

  describe("update/delete", () => {
    let updateDefId: string;
    let moveDefId: string;
    let deleteDefId: string;
    let deleteDenyDefId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data, error } = await admin
        .from("equipment_setting_definitions")
        .insert([
          { equipment_model_id: modelId, key: "update_ziel", label: "Update-Ziel", kind: "number" },
          { equipment_model_id: modelId, key: "move_ziel", label: "Move-Ziel", kind: "number" },
          { equipment_model_id: modelId, key: "delete_ziel", label: "Delete-Ziel", kind: "number" },
          {
            equipment_model_id: modelId,
            key: "delete_verboten_ziel",
            label: "Delete-Verboten-Ziel",
            kind: "number",
          },
        ])
        .select("id");
      if (error) throw error;
      updateDefId = data[0]!.id;
      moveDefId = data[1]!.id;
      deleteDefId = data[2]!.id;
      deleteDenyDefId = data[3]!.id;
    });

    it("positiv: Staff kann eine Einstelldefinition aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("equipment_setting_definitions")
        .update({ label: "Update-Ziel (bearbeitet)" })
        .eq("id", updateDefId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateDefId);
    });

    it("negativ (with check): Staff kann eine Einstelldefinition nicht auf ein fremdes Geraetemodell umhaengen", async () => {
      // Die using-Klausel allein liesse das durch (die Zeile gehoert derzeit
      // zu modelId in Studio A, staffA ist dort Staff) -- erst die
      // with-check-Klausel prueft den *neuen* equipment_model_id-Wert
      // (modelB in Studio B, wo staffA kein Staff ist) und muss hier
      // greifen. Anders als bei equipment_model_exercises gibt es hier
      // keinen zweiten Elternbezug, gegen den sich ein Same-Studio-Join
      // isolieren liesse -- staffA (nicht staffAB) ist hier der richtige
      // Akteur: die using-Klausel passiert er (Zeile ist in Studio A
      // sichtbar/bearbeitbar), die with-check-Klausel scheitert am neuen
      // Zielmodell, nicht an der Sichtbarkeit der Ausgangszeile.
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("equipment_setting_definitions")
        .update({ equipment_model_id: modelB })
        .eq("id", moveDefId)
        .select("id");
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("equipment_setting_definitions")
        .select("equipment_model_id")
        .eq("id", moveDefId)
        .single();
      expect(reloaded?.equipment_model_id).toBe(modelId);
    });

    it("negativ: Mitglied kann keine Einstelldefinition aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_setting_definitions")
        .update({ label: "Verboten-Update" })
        .eq("id", updateDefId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);
    });

    it("positiv: Staff kann eine Einstelldefinition loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("equipment_setting_definitions")
        .delete()
        .eq("id", deleteDefId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_setting_definitions")
        .select("id")
        .eq("id", deleteDefId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann keine Einstelldefinition loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_setting_definitions")
        .delete()
        .eq("id", deleteDenyDefId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_setting_definitions")
        .select("id")
        .eq("id", deleteDenyDefId);
      expect(remaining).toHaveLength(1);
    });
  });
});
