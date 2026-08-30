import { describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

const BOGUS_UPDATED_AT = "2099-01-01T00:00:00.000Z";

describe("updated_at wird serverseitig fortgeschrieben (Migration 0011)", () => {
  it("studios: updated_at wird erneuert, ein mitgeschickter Wert wird ueberschrieben", async () => {
    const admin = serviceClient();
    const { data: created, error: createError } = await admin
      .from("studios")
      .insert({ name: "Updated-At Studio" })
      .select("id, updated_at")
      .single();
    if (createError) throw createError;

    const { data: updated, error: updateError } = await admin
      .from("studios")
      .update({ name: "Updated-At Studio (bearbeitet)", updated_at: BOGUS_UPDATED_AT })
      .eq("id", created!.id)
      .select("updated_at")
      .single();
    expect(updateError).toBeNull();
    expect(updated?.updated_at).not.toBe(BOGUS_UPDATED_AT);
    expect(new Date(updated!.updated_at).getTime()).toBeGreaterThan(
      new Date(created!.updated_at).getTime(),
    );
  });

  it("equipment_models: updated_at wird erneuert, ein mitgeschickter Wert wird ueberschrieben", async () => {
    const admin = serviceClient();
    const { data: studio, error: studioError } = await admin
      .from("studios")
      .insert({ name: "Updated-At Studio (equipment_models)" })
      .select("id")
      .single();
    if (studioError) throw studioError;

    const { data: created, error: createError } = await admin
      .from("equipment_models")
      .insert({ studio_id: studio!.id, name: "Updated-At Geraet", weight_step_kg: 5 })
      .select("id, updated_at")
      .single();
    if (createError) throw createError;

    const { data: updated, error: updateError } = await admin
      .from("equipment_models")
      .update({ name: "Updated-At Geraet (bearbeitet)", updated_at: BOGUS_UPDATED_AT })
      .eq("id", created!.id)
      .select("updated_at")
      .single();
    expect(updateError).toBeNull();
    expect(updated?.updated_at).not.toBe(BOGUS_UPDATED_AT);
    expect(new Date(updated!.updated_at).getTime()).toBeGreaterThan(
      new Date(created!.updated_at).getTime(),
    );
  });

  it("exercises: updated_at wird erneuert, ein mitgeschickter Wert wird ueberschrieben", async () => {
    const admin = serviceClient();
    const { data: studio, error: studioError } = await admin
      .from("studios")
      .insert({ name: "Updated-At Studio (exercises)" })
      .select("id")
      .single();
    if (studioError) throw studioError;

    const { data: created, error: createError } = await admin
      .from("exercises")
      .insert({
        studio_id: studio!.id,
        name: "Updated-At Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      })
      .select("id, updated_at")
      .single();
    if (createError) throw createError;

    const { data: updated, error: updateError } = await admin
      .from("exercises")
      .update({ name: "Updated-At Uebung (bearbeitet)", updated_at: BOGUS_UPDATED_AT })
      .eq("id", created!.id)
      .select("updated_at")
      .single();
    expect(updateError).toBeNull();
    expect(updated?.updated_at).not.toBe(BOGUS_UPDATED_AT);
    expect(new Date(updated!.updated_at).getTime()).toBeGreaterThan(
      new Date(created!.updated_at).getTime(),
    );
  });

  it("machines: updated_at wird erneuert, ein mitgeschickter Wert wird ueberschrieben", async () => {
    const admin = serviceClient();
    const { data: studio, error: studioError } = await admin
      .from("studios")
      .insert({ name: "Updated-At Studio (machines)" })
      .select("id")
      .single();
    if (studioError) throw studioError;

    const { data: model, error: modelError } = await admin
      .from("equipment_models")
      .insert({ studio_id: studio!.id, name: "Updated-At Geraetemodell", weight_step_kg: 5 })
      .select("id")
      .single();
    if (modelError) throw modelError;

    const { data: created, error: createError } = await admin
      .from("machines")
      .insert({
        studio_id: studio!.id,
        equipment_model_id: model!.id,
        label: "Updated-At Geraeteinstanz",
      })
      .select("id, updated_at")
      .single();
    if (createError) throw createError;

    const { data: updated, error: updateError } = await admin
      .from("machines")
      .update({ label: "Updated-At Geraeteinstanz (bearbeitet)", updated_at: BOGUS_UPDATED_AT })
      .eq("id", created!.id)
      .select("updated_at")
      .single();
    expect(updateError).toBeNull();
    expect(updated?.updated_at).not.toBe(BOGUS_UPDATED_AT);
    expect(new Date(updated!.updated_at).getTime()).toBeGreaterThan(
      new Date(created!.updated_at).getTime(),
    );
  });

  it("profiles: ueber einen authentifizierten Client wird ein mitgeschickter updated_at-Wert ueberschrieben", async () => {
    // Anders als die obigen Tests laeuft dieser ueber den normalen
    // RLS-Schreibpfad (profiles_update_own), nicht ueber den Service-Client
    // -- er belegt, dass der Trigger auch dort greift, wo ein Client den
    // Wert tatsaechlich mitschicken koennte.
    const admin = serviceClient();
    const email = uniqueEmail("updated-at-profile");
    const userId = await createTestUser(email);
    const { data: created, error: createError } = await admin
      .from("profiles")
      .insert({ id: userId, display_name: "Updated-At Nutzer" })
      .select("updated_at")
      .single();
    if (createError) throw createError;

    const client = await userClient(email);
    const { data: updated, error: updateError } = await client
      .from("profiles")
      .update({ display_name: "Updated-At Nutzer (bearbeitet)", updated_at: BOGUS_UPDATED_AT })
      .eq("id", userId)
      .select("updated_at")
      .single();
    expect(updateError).toBeNull();
    expect(updated?.updated_at).not.toBe(BOGUS_UPDATED_AT);
    expect(new Date(updated!.updated_at).getTime()).toBeGreaterThan(
      new Date(created!.updated_at).getTime(),
    );
  });
});
