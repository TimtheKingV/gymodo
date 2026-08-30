import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let staffAEmail: string;
let staffBEmail: string;
let memberAEmail: string;
let memberBEmail: string;
let staffABEmail: string;
let modelA: string;
let modelB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Machines Studio A" }, { name: "Machines Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  staffAEmail = uniqueEmail("machines-staff-a");
  staffBEmail = uniqueEmail("machines-staff-b");
  memberAEmail = uniqueEmail("machines-member-a");
  memberBEmail = uniqueEmail("machines-member-b");
  staffABEmail = uniqueEmail("machines-staff-ab");
  const staffAId = await createTestUser(staffAEmail);
  const staffBId = await createTestUser(staffBEmail);
  const memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(memberBEmail);
  const staffABId = await createTestUser(staffABEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: staffBId, role: "trainer" },
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
    // Trainer einer Studiokette: Staff gleichzeitig in Studio A UND Studio B
    // (zwei studio_memberships-Zeilen fuer dieselbe user_id -- unique
    // (studio_id, user_id) erlaubt das). Nur mit diesem Nutzer laesst sich
    // die Studio-Konsistenzpruefung in der machines-Policy isoliert testen:
    // fuer ihn sind beide Modelle sichtbar und er ist in beiden Studios
    // Staff, ein Insert kann also nur noch an
    // "em.studio_id = machines.studio_id" scheitern.
    { studio_id: studioA, user_id: staffABId, role: "trainer" },
    { studio_id: studioB, user_id: staffABId, role: "trainer" },
  ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Rudergeraet", weight_step_kg: 5 },
      { studio_id: studioB, name: "Fremdgeraet", weight_step_kg: 5 },
    ])
    .select("id");
  if (modelError) throw modelError;
  modelA = models[0]!.id;
  modelB = models[1]!.id;
});

describe("RLS auf machines", () => {
  it("positiv: Staff kann eine Geraeteinstanz anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelA,
      label: "Rudergeraet 1",
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Geraeteinstanz anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelA,
      label: "Verboten",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("machines")
      .select("id")
      .eq("label", "Verboten");
    expect(found).toEqual([]);
  });

  it("negativ (Sichtbarkeit): Staff nur in Studio A sieht modelB nicht und kann nicht anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelB,
      label: "Fremdes Modell",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("machines")
      .select("id")
      .eq("label", "Fremdes Modell");
    expect(found).toEqual([]);
  });

  it("negativ (Same-Studio-Konsistenz isoliert): Trainer in beiden Studios kann studioA nicht mit modelB kombinieren", async () => {
    // staffABEmail ist Trainer in Studio A UND Studio B: modelB ist fuer ihn
    // ueber equipment_models_select sichtbar, und is_studio_staff greift fuer
    // ihn in beiden Studios. Der Insert kann also nur noch an der
    // Studio-Konsistenzpruefung (em.studio_id = machines.studio_id) in der
    // Policy scheitern -- das ist die eigentliche Klausel, um die es hier
    // geht.
    const client = await userClient(staffABEmail);

    const visibility = await client
      .from("equipment_models")
      .select("id")
      .eq("id", modelB);
    expect(visibility.data).toHaveLength(1);

    const { error } = await client.from("machines").insert({
      studio_id: studioA,
      equipment_model_id: modelB,
      label: "Inkonsistente Kombination",
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("machines")
      .select("id")
      .eq("label", "Inkonsistente Kombination");
    expect(found).toEqual([]);
  });

  it("positiv: Staff aus Studio B kann eine eigene, konsistente Geraeteinstanz anlegen", async () => {
    // Belegt, dass die insert-Policy ueberhaupt jemandem im fremden Studio
    // Zugriff gewaehrt -- erst dadurch sind die obigen Ablehnungen fuer
    // staffAB/staffA aussagekraeftig und nicht bloss Zufall.
    const client = await userClient(staffBEmail);
    const { error } = await client.from("machines").insert({
      studio_id: studioB,
      equipment_model_id: modelB,
      label: "Fremdgeraet 1",
    });
    expect(error).toBeNull();
  });

  it("positiv: Mitglied sieht Geraeteinstanzen seines Studios", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client
      .from("machines")
      .select("id")
      .eq("studio_id", studioA);
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht Studio-A-Geraete nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("machines")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });

  describe("update/delete", () => {
    let updateMachineId: string;
    let memberUpdateDenyMachineId: string;
    let crossUpdateDenyMachineId: string;
    let reassignStudioDenyMachineId: string;
    let reassignModelDenyMachineId: string;
    let reassignModelDenyStaffABMachineId: string;
    let deleteMachineId: string;
    let memberDeleteDenyMachineId: string;
    let crossDeleteDenyMachineId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data, error } = await admin
        .from("machines")
        .insert([
          { studio_id: studioA, equipment_model_id: modelA, label: "Update-Ziel" },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Update-Mitglied-Verboten-Ziel",
          },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Update-Cross-Verboten-Ziel",
          },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Reassign-Studio-Verboten-Ziel",
          },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Reassign-Modell-Verboten-Ziel",
          },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Reassign-Modell-StaffAB-Verboten-Ziel",
          },
          { studio_id: studioA, equipment_model_id: modelA, label: "Delete-Ziel" },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Delete-Mitglied-Verboten-Ziel",
          },
          {
            studio_id: studioA,
            equipment_model_id: modelA,
            label: "Delete-Cross-Verboten-Ziel",
          },
        ])
        .select("id");
      if (error) throw error;
      updateMachineId = data[0]!.id;
      memberUpdateDenyMachineId = data[1]!.id;
      crossUpdateDenyMachineId = data[2]!.id;
      reassignStudioDenyMachineId = data[3]!.id;
      reassignModelDenyMachineId = data[4]!.id;
      reassignModelDenyStaffABMachineId = data[5]!.id;
      deleteMachineId = data[6]!.id;
      memberDeleteDenyMachineId = data[7]!.id;
      crossDeleteDenyMachineId = data[8]!.id;
    });

    it("positiv: Staff kann eine Geraeteinstanz aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("machines")
        .update({ label: "Update-Ziel (bearbeitet)" })
        .eq("id", updateMachineId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateMachineId);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("machines")
        .select("label")
        .eq("id", updateMachineId)
        .single();
      expect(reloaded?.label).toBe("Update-Ziel (bearbeitet)");
    });

    it("negativ: Mitglied kann keine Geraeteinstanz aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("machines")
        .update({ label: "Verboten-Update" })
        .eq("id", memberUpdateDenyMachineId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("machines")
        .select("label")
        .eq("id", memberUpdateDenyMachineId)
        .single();
      expect(reloaded?.label).toBe("Update-Mitglied-Verboten-Ziel");
    });

    it("cross-tenant: Staff aus Studio B kann eine Geraeteinstanz in Studio A nicht aktualisieren", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("machines")
        .update({ label: "Verboten-Cross-Update" })
        .eq("id", crossUpdateDenyMachineId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("machines")
        .select("label")
        .eq("id", crossUpdateDenyMachineId)
        .single();
      expect(reloaded?.label).toBe("Update-Cross-Verboten-Ziel");
    });

    it("with check: Staff aus Studio A kann eine eigene Geraeteinstanz nicht auf Studio B umhaengen", async () => {
      // Die using-Klausel allein liesse das durch (Aufrufer ist Staff in
      // Studio A, und die Zeile gehoert derzeit zu Studio A) -- nur die
      // with-check-Klausel prueft den *neuen* Zielwert (studio_id = studioB,
      // wo staffA kein Staff ist) und muss hier greifen.
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("machines")
        .update({ studio_id: studioB })
        .eq("id", reassignStudioDenyMachineId)
        .select("id");
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("machines")
        .select("studio_id")
        .eq("id", reassignStudioDenyMachineId)
        .single();
      expect(reloaded?.studio_id).toBe(studioA);
    });

    it("with check: Staff aus Studio A kann eine eigene Geraeteinstanz nicht auf ein fremdes Modell umhaengen", async () => {
      // Analog, aber ueber die Studio-Konsistenzpruefung: studio_id bleibt
      // studioA (using greift), aber equipment_model_id wird auf modelB
      // (Studio B) geaendert -- der EXISTS-Join in with check muss das
      // ablehnen.
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("machines")
        .update({ equipment_model_id: modelB })
        .eq("id", reassignModelDenyMachineId)
        .select("id");
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("machines")
        .select("equipment_model_id")
        .eq("id", reassignModelDenyMachineId)
        .single();
      expect(reloaded?.equipment_model_id).toBe(modelA);
    });

    it("with check (Same-Studio-Konsistenz isoliert): Trainer in beiden Studios kann eine Studio-A-Zeile nicht auf modelB umhaengen", async () => {
      // Der obige staffA-Test allein ist nicht schluessig: fuer staffA ist
      // modelB schon durch equipment_models_select unsichtbar, das Update
      // koennte also auch an dieser Sichtbarkeit statt an der
      // Studio-Konsistenzpruefung scheitern. staffAB ist Trainer in Studio A
      // UND B: modelB ist fuer ihn sichtbar und er ist in beiden Studios
      // Staff, die using-Klausel passiert er ebenfalls (Zeile gehoert zu
      // Studio A). Der Update-Versuch kann also nur noch an
      // "em.studio_id = machines.studio_id" in with check scheitern.
      const client = await userClient(staffABEmail);

      const visibility = await client
        .from("equipment_models")
        .select("id")
        .eq("id", modelB);
      expect(visibility.data).toHaveLength(1);

      const { error } = await client
        .from("machines")
        .update({ equipment_model_id: modelB })
        .eq("id", reassignModelDenyStaffABMachineId)
        .select("id");
      expect(error).not.toBeNull();

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("machines")
        .select("equipment_model_id")
        .eq("id", reassignModelDenyStaffABMachineId)
        .single();
      expect(reloaded?.equipment_model_id).toBe(modelA);
    });

    it("positiv: Staff kann eine Geraeteinstanz loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("machines").delete().eq("id", deleteMachineId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("machines")
        .select("id")
        .eq("id", deleteMachineId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann keine Geraeteinstanz loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("machines")
        .delete()
        .eq("id", memberDeleteDenyMachineId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("machines")
        .select("id")
        .eq("id", memberDeleteDenyMachineId);
      expect(remaining).toHaveLength(1);
    });

    it("cross-tenant: Staff aus Studio B kann eine Geraeteinstanz in Studio A nicht loeschen", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("machines")
        .delete()
        .eq("id", crossDeleteDenyMachineId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("machines")
        .select("id")
        .eq("id", crossDeleteDenyMachineId);
      expect(remaining).toHaveLength(1);
    });
  });
});

describe("Ruhestandspfad statt Loeschen (0008-Kommentarkorrektur)", () => {
  // on delete restrict verhindert nur den automatischen Loeschpfad, nicht
  // den Verlust der Tag-Historie insgesamt (siehe korrigierter Kommentar in
  // 0008_machine_tags_fk.sql). Der vorgesehene Weg, ein Geraet ausser Betrieb
  // zu nehmen, ist machines.status = 'inactive' -- dieser Test belegt, dass
  // Staff das darf und ein daran haengender aktiver Tag dabei unangetastet
  // bleibt (weder geloescht noch revoziert).
  it("positiv: Staff kann eine Geraeteinstanz auf inactive setzen, ein aktiver Tag bleibt unveraendert bestehen", async () => {
    const admin = serviceClient();
    const { data: machine, error: machineError } = await admin
      .from("machines")
      .insert({
        studio_id: studioA,
        equipment_model_id: modelA,
        label: "Ruhestand-Ziel",
      })
      .select("id")
      .single();
    if (machineError) throw machineError;

    const token = createTagToken();
    const { data: tag, error: tagError } = await admin
      .from("machine_tags")
      .insert({
        studio_id: studioA,
        machine_id: machine!.id,
        token_hash: hashTagToken(token),
        status: "active",
      })
      .select("id")
      .single();
    if (tagError) throw tagError;

    const client = await userClient(staffAEmail);
    const { data, error } = await client
      .from("machines")
      .update({ status: "inactive" })
      .eq("id", machine!.id)
      .select("status")
      .single();
    expect(error).toBeNull();
    expect(data?.status).toBe("inactive");

    const { data: reloadedTag } = await admin
      .from("machine_tags")
      .select("machine_id, status")
      .eq("id", tag!.id)
      .single();
    expect(reloadedTag?.machine_id).toBe(machine!.id);
    expect(reloadedTag?.status).toBe("active");
  });
});
