import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let staffAEmail: string;
let memberAEmail: string;
let memberBEmail: string;
let staffBEmail: string;
let linkId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Assets Studio A" }, { name: "Assets Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  staffAEmail = uniqueEmail("assets-staff-a");
  memberAEmail = uniqueEmail("assets-member-a");
  memberBEmail = uniqueEmail("assets-member-b");
  staffBEmail = uniqueEmail("assets-staff-b");
  const staffAId = await createTestUser(staffAEmail);
  const memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(memberBEmail);
  const staffBId = await createTestUser(staffBEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
    { studio_id: studioB, user_id: staffBId, role: "trainer" },
  ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinstrecker", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioA,
      name: "Beinstrecken",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;

  const { data: link, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert({ equipment_model_id: model.id, exercise_id: exercise.id })
    .select("id")
    .single();
  if (linkError) throw linkError;
  linkId = link.id;
});

describe("RLS auf instruction_assets", () => {
  it("positiv: Staff kann ein Einweisungsvideo anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/beinstrecken.mp4",
      duration_s: 30,
    });
    expect(error).toBeNull();
  });

  it("negativ: Video ueber 45 Sekunden wird abgelehnt", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/zu-lang.mp4",
      duration_s: 60,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", "instructions/zu-lang.mp4");
    expect(found).toEqual([]);
  });

  it("negativ: Mitglied kann kein Einweisungsvideo anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/verboten.mp4",
      duration_s: 20,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", "instructions/verboten.mp4");
    expect(found).toEqual([]);
  });

  it("cross-tenant: Staff aus Studio B kann in Studio A kein Video anlegen", async () => {
    const client = await userClient(staffBEmail);
    const { error } = await client.from("instruction_assets").insert({
      equipment_model_exercise_id: linkId,
      kind: "video",
      storage_path: "instructions/cross-verboten.mp4",
      duration_s: 20,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", "instructions/cross-verboten.mp4");
    expect(found).toEqual([]);
  });

  it("positiv: Mitglied aus Studio A sieht das Video", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkId);
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht das Video nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkId);
    expect(data).toEqual([]);
  });

  describe("update/delete", () => {
    let updateAssetId: string;
    let memberUpdateDenyAssetId: string;
    let crossUpdateDenyAssetId: string;
    let deleteAssetId: string;
    let memberDeleteDenyAssetId: string;
    let crossDeleteDenyAssetId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data, error } = await admin
        .from("instruction_assets")
        .insert([
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/update-ziel.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/update-mitglied-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/update-cross-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/delete-ziel.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/delete-mitglied-verboten.mp4",
            duration_s: 15,
          },
          {
            equipment_model_exercise_id: linkId,
            kind: "video",
            storage_path: "instructions/delete-cross-verboten.mp4",
            duration_s: 15,
          },
        ])
        .select("id");
      if (error) throw error;
      updateAssetId = data[0]!.id;
      memberUpdateDenyAssetId = data[1]!.id;
      crossUpdateDenyAssetId = data[2]!.id;
      deleteAssetId = data[3]!.id;
      memberDeleteDenyAssetId = data[4]!.id;
      crossDeleteDenyAssetId = data[5]!.id;
    });

    it("positiv: Staff kann ein Einweisungsvideo aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .update({ duration_s: 22 })
        .eq("id", updateAssetId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateAssetId);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("duration_s")
        .eq("id", updateAssetId)
        .single();
      expect(reloaded?.duration_s).toBe(22);
    });

    it("negativ: Mitglied kann kein Einweisungsvideo aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .update({ duration_s: 22 })
        .eq("id", memberUpdateDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("duration_s")
        .eq("id", memberUpdateDenyAssetId)
        .single();
      expect(reloaded?.duration_s).toBe(15);
    });

    it("cross-tenant: Staff aus Studio B kann ein Video in Studio A nicht aktualisieren", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .update({ duration_s: 22 })
        .eq("id", crossUpdateDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("instruction_assets")
        .select("duration_s")
        .eq("id", crossUpdateDenyAssetId)
        .single();
      expect(reloaded?.duration_s).toBe(15);
    });

    it("positiv: Staff kann ein Einweisungsvideo loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", deleteAssetId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("id", deleteAssetId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann kein Einweisungsvideo loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", memberDeleteDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("id", memberDeleteDenyAssetId);
      expect(remaining).toHaveLength(1);
    });

    it("cross-tenant: Staff aus Studio B kann ein Video in Studio A nicht loeschen", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("instruction_assets")
        .delete()
        .eq("id", crossDeleteDenyAssetId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("instruction_assets")
        .select("id")
        .eq("id", crossDeleteDenyAssetId);
      expect(remaining).toHaveLength(1);
    });
  });
});
