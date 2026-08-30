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
let staffABEmail: string;
let modelA: string;
let exerciseB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Exercise Studio A" }, { name: "Exercise Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("ex-member-a");
  staffAEmail = uniqueEmail("ex-staff-a");
  memberBEmail = uniqueEmail("ex-member-b");
  staffBEmail = uniqueEmail("ex-staff-b");
  staffABEmail = uniqueEmail("ex-staff-ab");

  const memberAId = await createTestUser(memberAEmail);
  const staffAId = await createTestUser(staffAEmail);
  const memberBId = await createTestUser(memberBEmail);
  const staffBId = await createTestUser(staffBEmail);
  const staffABId = await createTestUser(staffABEmail);

  const { error: membershipError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: memberAId, role: "member" },
    { studio_id: studioA, user_id: staffAId, role: "trainer" },
    { studio_id: studioB, user_id: memberBId, role: "member" },
    { studio_id: studioB, user_id: staffBId, role: "trainer" },
    // Trainer einer Studiokette: Staff gleichzeitig in Studio A und B. Nur
    // mit diesem Nutzer laesst sich der Same-Studio-Join in
    // equipment_model_exercises isoliert testen -- fuer ihn sind Rolle
    // und Sichtbarkeit in beiden Studios bereits erfuellt, ein Insert
    // kann also nur noch am Join selbst scheitern.
    { studio_id: studioA, user_id: staffABId, role: "trainer" },
    { studio_id: studioB, user_id: staffABId, role: "trainer" },
  ]);
  if (membershipError) throw membershipError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Kabelzug", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;
  modelA = model.id;

  const { data: exercise, error: exerciseError } = await admin
    .from("exercises")
    .insert({
      studio_id: studioB,
      name: "Fremde Uebung",
      target_reps_min: 8,
      target_reps_max: 12,
    })
    .select("id")
    .single();
  if (exerciseError) throw exerciseError;
  exerciseB = exercise.id;
});

describe("RLS auf exercises", () => {
  it("positiv: Staff kann eine Uebung anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioA,
      name: "Breiter Griff",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).toBeNull();
  });

  it("negativ: Mitglied kann keine Uebung anlegen", async () => {
    const client = await userClient(memberAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioA,
      name: "Verboten",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: Staff aus Studio A kann keine Uebung in Studio B anlegen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("exercises").insert({
      studio_id: studioB,
      name: "Cross-Insert-Verboten",
      target_reps_min: 8,
      target_reps_max: 12,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: found } = await admin
      .from("exercises")
      .select("id")
      .eq("studio_id", studioB)
      .eq("name", "Cross-Insert-Verboten");
    expect(found).toEqual([]);
  });

  it("positiv: Mitglied sieht Uebungen seines Studios", async () => {
    const client = await userClient(memberAEmail);
    const { data, error } = await client
      .from("exercises")
      .select("id")
      .eq("studio_id", studioA);
    expect(error).toBeNull();
    expect(data!.length).toBeGreaterThan(0);
  });

  it("cross-tenant: Mitglied aus Studio B sieht Uebungen von Studio A nicht", async () => {
    const client = await userClient(memberBEmail);
    const { data } = await client
      .from("exercises")
      .select("id")
      .eq("studio_id", studioA);
    expect(data).toEqual([]);
  });

  describe("update/delete", () => {
    let updateExId: string;
    let memberUpdateDenyExId: string;
    let crossUpdateDenyExId: string;
    let deleteExId: string;
    let memberDeleteDenyExId: string;
    let crossDeleteDenyExId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data, error } = await admin
        .from("exercises")
        .insert([
          { studio_id: studioA, name: "Update-Ziel", target_reps_min: 8, target_reps_max: 12 },
          {
            studio_id: studioA,
            name: "Update-Mitglied-Verboten-Ziel",
            target_reps_min: 8,
            target_reps_max: 12,
          },
          {
            studio_id: studioA,
            name: "Update-Cross-Verboten-Ziel",
            target_reps_min: 8,
            target_reps_max: 12,
          },
          { studio_id: studioA, name: "Delete-Ziel", target_reps_min: 8, target_reps_max: 12 },
          {
            studio_id: studioA,
            name: "Delete-Mitglied-Verboten-Ziel",
            target_reps_min: 8,
            target_reps_max: 12,
          },
          {
            studio_id: studioA,
            name: "Delete-Cross-Verboten-Ziel",
            target_reps_min: 8,
            target_reps_max: 12,
          },
        ])
        .select("id");
      if (error) throw error;
      updateExId = data[0]!.id;
      memberUpdateDenyExId = data[1]!.id;
      crossUpdateDenyExId = data[2]!.id;
      deleteExId = data[3]!.id;
      memberDeleteDenyExId = data[4]!.id;
      crossDeleteDenyExId = data[5]!.id;
    });

    it("positiv: Staff kann eine Uebung aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("exercises")
        .update({ name: "Update-Ziel (bearbeitet)" })
        .eq("id", updateExId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateExId);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("exercises")
        .select("name")
        .eq("id", updateExId)
        .single();
      expect(reloaded?.name).toBe("Update-Ziel (bearbeitet)");
    });

    it("negativ: Mitglied kann keine Uebung aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("exercises")
        .update({ name: "Verboten-Update" })
        .eq("id", memberUpdateDenyExId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("exercises")
        .select("name")
        .eq("id", memberUpdateDenyExId)
        .single();
      expect(reloaded?.name).toBe("Update-Mitglied-Verboten-Ziel");
    });

    it("cross-tenant: Staff aus Studio B kann eine Uebung in Studio A nicht aktualisieren", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("exercises")
        .update({ name: "Verboten-Cross-Update" })
        .eq("id", crossUpdateDenyExId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("exercises")
        .select("name")
        .eq("id", crossUpdateDenyExId)
        .single();
      expect(reloaded?.name).toBe("Update-Cross-Verboten-Ziel");
    });

    it("positiv: Staff kann eine Uebung loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client.from("exercises").delete().eq("id", deleteExId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("exercises")
        .select("id")
        .eq("id", deleteExId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann keine Uebung loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("exercises")
        .delete()
        .eq("id", memberDeleteDenyExId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("exercises")
        .select("id")
        .eq("id", memberDeleteDenyExId);
      expect(remaining).toHaveLength(1);
    });

    it("cross-tenant: Staff aus Studio B kann eine Uebung in Studio A nicht loeschen", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("exercises")
        .delete()
        .eq("id", crossDeleteDenyExId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("exercises")
        .select("id")
        .eq("id", crossDeleteDenyExId);
      expect(remaining).toHaveLength(1);
    });
  });
});

describe("RLS auf equipment_model_exercises", () => {
  it("negativ (Sichtbarkeit): Staff nur in Studio A sieht exerciseB nicht und kann nicht verknuepfen", async () => {
    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: exerciseB,
    });
    expect(error).not.toBeNull();
  });

  it("negativ (Same-Studio-Join isoliert): Trainer in beiden Studios kann modelA nicht mit exerciseB verknuepfen", async () => {
    // staffABEmail ist Trainer in Studio A UND Studio B: exerciseB ist fuer
    // ihn ueber exercises_select sichtbar, und is_studio_staff greift fuer
    // ihn in beiden Studios. Der Insert kann also nur noch am
    // Same-Studio-Join (e.studio_id = em.studio_id) in der Policy
    // scheitern -- das ist die eigentliche Klausel, um die es in diesem
    // Task geht.
    const client = await userClient(staffABEmail);

    const visibility = await client.from("exercises").select("id").eq("id", exerciseB);
    expect(visibility.data).toHaveLength(1);

    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: exerciseB,
    });
    expect(error).not.toBeNull();

    const admin = serviceClient();
    const { data: created } = await admin
      .from("equipment_model_exercises")
      .select("id")
      .eq("equipment_model_id", modelA)
      .eq("exercise_id", exerciseB);
    expect(created).toEqual([]);
  });

  it("negativ (Rolle): Mitglied kann zwei Studio-A-Zeilen nicht verknuepfen", async () => {
    const admin = serviceClient();
    const { data: ownExercise, error: exerciseError } = await admin
      .from("exercises")
      .insert({
        studio_id: studioA,
        name: "Mitglied-Verknuepfungsversuch",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (exerciseError) throw exerciseError;

    const client = await userClient(memberAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: ownExercise.id,
    });
    expect(error).not.toBeNull();

    const { data: created } = await admin
      .from("equipment_model_exercises")
      .select("id")
      .eq("equipment_model_id", modelA)
      .eq("exercise_id", ownExercise.id);
    expect(created).toEqual([]);
  });

  it("positiv: Staff kann Geraet und Uebung im selben Studio verknuepfen", async () => {
    const admin = serviceClient();
    const { data: ownExercise, error: exerciseError } = await admin
      .from("exercises")
      .insert({
        studio_id: studioA,
        name: "Eigene Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id")
      .single();
    if (exerciseError) throw exerciseError;

    const client = await userClient(staffAEmail);
    const { error } = await client.from("equipment_model_exercises").insert({
      equipment_model_id: modelA,
      exercise_id: ownExercise.id,
    });
    expect(error).toBeNull();
  });

  describe("select/update/delete", () => {
    let selectLinkId: string;
    let updateLinkId: string;
    let memberUpdateDenyLinkId: string;
    let crossUpdateDenyLinkId: string;
    let deleteLinkId: string;
    let memberDeleteDenyLinkId: string;
    let crossDeleteDenyLinkId: string;

    beforeAll(async () => {
      const admin = serviceClient();
      const { data: exs, error: exErr } = await admin
        .from("exercises")
        .insert([
          { studio_id: studioA, name: "Link-Select", target_reps_min: 8, target_reps_max: 12 },
          { studio_id: studioA, name: "Link-Update", target_reps_min: 8, target_reps_max: 12 },
          {
            studio_id: studioA,
            name: "Link-Update-Mitglied-Verboten",
            target_reps_min: 8,
            target_reps_max: 12,
          },
          {
            studio_id: studioA,
            name: "Link-Update-Cross-Verboten",
            target_reps_min: 8,
            target_reps_max: 12,
          },
          { studio_id: studioA, name: "Link-Delete", target_reps_min: 8, target_reps_max: 12 },
          {
            studio_id: studioA,
            name: "Link-Delete-Mitglied-Verboten",
            target_reps_min: 8,
            target_reps_max: 12,
          },
          {
            studio_id: studioA,
            name: "Link-Delete-Cross-Verboten",
            target_reps_min: 8,
            target_reps_max: 12,
          },
        ])
        .select("id");
      if (exErr) throw exErr;
      const exSelect = exs[0]!.id;
      const exUpdate = exs[1]!.id;
      const exMemberUpdateDeny = exs[2]!.id;
      const exCrossUpdateDeny = exs[3]!.id;
      const exDelete = exs[4]!.id;
      const exMemberDeleteDeny = exs[5]!.id;
      const exCrossDeleteDeny = exs[6]!.id;

      const { data: links, error: linkErr } = await admin
        .from("equipment_model_exercises")
        .insert([
          { equipment_model_id: modelA, exercise_id: exSelect },
          { equipment_model_id: modelA, exercise_id: exUpdate },
          { equipment_model_id: modelA, exercise_id: exMemberUpdateDeny },
          { equipment_model_id: modelA, exercise_id: exCrossUpdateDeny },
          { equipment_model_id: modelA, exercise_id: exDelete },
          { equipment_model_id: modelA, exercise_id: exMemberDeleteDeny },
          { equipment_model_id: modelA, exercise_id: exCrossDeleteDeny },
        ])
        .select("id");
      if (linkErr) throw linkErr;
      selectLinkId = links[0]!.id;
      updateLinkId = links[1]!.id;
      memberUpdateDenyLinkId = links[2]!.id;
      crossUpdateDenyLinkId = links[3]!.id;
      deleteLinkId = links[4]!.id;
      memberDeleteDenyLinkId = links[5]!.id;
      crossDeleteDenyLinkId = links[6]!.id;
    });

    it("positiv: Mitglied aus Studio A sieht die Verknuepfung", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", selectLinkId);
      expect(error).toBeNull();
      expect(data).toHaveLength(1);
    });

    it("cross-tenant: Mitglied aus Studio B sieht die Verknuepfung nicht", async () => {
      const client = await userClient(memberBEmail);
      const { data } = await client
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", selectLinkId);
      expect(data).toEqual([]);
    });

    it("positiv: Staff kann eine Verknuepfung aktualisieren", async () => {
      const client = await userClient(staffAEmail);
      const { data, error } = await client
        .from("equipment_model_exercises")
        .update({ sort_order: 5 })
        .eq("id", updateLinkId)
        .select("id")
        .single();
      expect(error).toBeNull();
      expect(data?.id).toBe(updateLinkId);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("equipment_model_exercises")
        .select("sort_order")
        .eq("id", updateLinkId)
        .single();
      expect(reloaded?.sort_order).toBe(5);
    });

    it("negativ: Mitglied kann keine Verknuepfung aktualisieren", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_model_exercises")
        .update({ sort_order: 9 })
        .eq("id", memberUpdateDenyLinkId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("equipment_model_exercises")
        .select("sort_order")
        .eq("id", memberUpdateDenyLinkId)
        .single();
      expect(reloaded?.sort_order).toBe(0);
    });

    it("cross-tenant: Staff aus Studio B kann eine Verknuepfung in Studio A nicht aktualisieren", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("equipment_model_exercises")
        .update({ sort_order: 9 })
        .eq("id", crossUpdateDenyLinkId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: reloaded } = await admin
        .from("equipment_model_exercises")
        .select("sort_order")
        .eq("id", crossUpdateDenyLinkId)
        .single();
      expect(reloaded?.sort_order).toBe(0);
    });

    it("positiv: Staff kann eine Verknuepfung loeschen", async () => {
      const client = await userClient(staffAEmail);
      const { error } = await client
        .from("equipment_model_exercises")
        .delete()
        .eq("id", deleteLinkId);
      expect(error).toBeNull();

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", deleteLinkId);
      expect(remaining).toEqual([]);
    });

    it("negativ: Mitglied kann keine Verknuepfung loeschen", async () => {
      const client = await userClient(memberAEmail);
      const { data, error } = await client
        .from("equipment_model_exercises")
        .delete()
        .eq("id", memberDeleteDenyLinkId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", memberDeleteDenyLinkId);
      expect(remaining).toHaveLength(1);
    });

    it("cross-tenant: Staff aus Studio B kann eine Verknuepfung in Studio A nicht loeschen", async () => {
      const client = await userClient(staffBEmail);
      const { data, error } = await client
        .from("equipment_model_exercises")
        .delete()
        .eq("id", crossDeleteDenyLinkId)
        .select("id");
      expect(error).toBeNull();
      expect(data).toEqual([]);

      const admin = serviceClient();
      const { data: remaining } = await admin
        .from("equipment_model_exercises")
        .select("id")
        .eq("id", crossDeleteDenyLinkId);
      expect(remaining).toHaveLength(1);
    });
  });
});
