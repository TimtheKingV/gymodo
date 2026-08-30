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
let emailA: string;
let tokenA: string;
let tokenB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Tag-Studio A" }, { name: "Tag-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  emailA = uniqueEmail("tag-a");
  const userA = await createTestUser(emailA);
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: userA, role: "member" });
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Tag-Testgeraet A", weight_step_kg: 5 },
      { studio_id: studioB, name: "Tag-Testgeraet B", weight_step_kg: 5 },
    ])
    .select("id");
  if (modelError) throw modelError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "Geraet A" },
      { studio_id: studioB, equipment_model_id: models[1]!.id, label: "Geraet B" },
    ])
    .select("id");
  if (machineError) throw machineError;

  tokenA = createTagToken();
  tokenB = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioA,
      machine_id: machines[0]!.id,
      token_hash: hashTagToken(tokenA),
      status: "active",
    },
    {
      studio_id: studioB,
      machine_id: machines[1]!.id,
      token_hash: hashTagToken(tokenB),
      status: "active",
    },
  ]);
  if (tagError) throw tagError;
});

describe("machine_tags", () => {
  it("speichert nur den Hash, nie den Token", async () => {
    const admin = serviceClient();
    const { data } = await admin
      .from("machine_tags")
      .select("token_hash")
      .eq("studio_id", studioA);
    expect(data?.[0]?.token_hash).toBe(hashTagToken(tokenA));
    expect(JSON.stringify(data)).not.toContain(tokenA);
  });

  it("erzwingt Eindeutigkeit des Hashes", async () => {
    const admin = serviceClient();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(tokenA),
      status: "active",
    });
    expect(error).not.toBeNull();
  });

  it("positiv: Nutzer A sieht die Tags seines Studios", async () => {
    const client = await userClient(emailA);
    const { data, error } = await client.from("machine_tags").select("id");
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
  });

  it("cross-tenant: Nutzer A sieht die Tags von Studio B nicht", async () => {
    const client = await userClient(emailA);
    const { data } = await client
      .from("machine_tags")
      .select("id")
      .eq("studio_id", studioB);
    expect(data).toEqual([]);
  });

  it("negativ: Nutzer A kann keinen Tag anlegen", async () => {
    const client = await userClient(emailA);
    const { error } = await client.from("machine_tags").insert({
      studio_id: studioA,
      token_hash: hashTagToken(createTagToken()),
      status: "active",
    });
    expect(error).not.toBeNull();
  });
});

describe("machine_tags: active-Constraint und Fremdschluessel", () => {
  let studioC: string;
  let machineC: string;

  beforeAll(async () => {
    const admin = serviceClient();

    const { data: studio, error: studioError } = await admin
      .from("studios")
      .insert({ name: "Tag-Studio C" })
      .select("id")
      .single();
    if (studioError) throw studioError;
    studioC = studio.id;

    const { data: model, error: modelError } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioC, name: "Tag-Testgeraet C", weight_step_kg: 5 })
      .select("id")
      .single();
    if (modelError) throw modelError;

    const { data: machine, error: machineError } = await admin
      .from("machines")
      .insert({ studio_id: studioC, equipment_model_id: model.id, label: "Geraet C" })
      .select("id")
      .single();
    if (machineError) throw machineError;
    machineC = machine.id;
  });

  it("negativ: ein aktiver Tag ohne machine_id verletzt die Check-Constraint", async () => {
    const admin = serviceClient();
    const token = createTagToken();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioC,
      token_hash: hashTagToken(token),
      status: "active",
    });
    expect(error).not.toBeNull();

    const { data: found } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(found).toEqual([]);
  });

  it("positiv: ein unassigned Tag ohne machine_id ist erlaubt", async () => {
    const admin = serviceClient();
    const token = createTagToken();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioC,
      token_hash: hashTagToken(token),
      status: "unassigned",
    });
    expect(error).toBeNull();

    const { data: found } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(found).toHaveLength(1);
  });

  it("positiv: ein revoked Tag ohne machine_id ist erlaubt", async () => {
    const admin = serviceClient();
    const token = createTagToken();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioC,
      token_hash: hashTagToken(token),
      status: "revoked",
    });
    expect(error).toBeNull();

    const { data: found } = await admin
      .from("machine_tags")
      .select("id")
      .eq("token_hash", hashTagToken(token));
    expect(found).toHaveLength(1);
  });

  it("positiv: ein aktiver Tag mit machine_id ist erlaubt", async () => {
    const admin = serviceClient();
    const token = createTagToken();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: studioC,
      machine_id: machineC,
      token_hash: hashTagToken(token),
      status: "active",
    });
    expect(error).toBeNull();

    const { data: found } = await admin
      .from("machine_tags")
      .select("id, machine_id")
      .eq("token_hash", hashTagToken(token));
    expect(found).toHaveLength(1);
    expect(found?.[0]?.machine_id).toBe(machineC);
  });

  it("negativ: eine Geraeteinstanz mit verknuepftem Tag kann nicht geloescht werden (on delete restrict)", async () => {
    const admin = serviceClient();

    const { data: model, error: modelError } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioC, name: "Tag-Testgeraet D", weight_step_kg: 5 })
      .select("id")
      .single();
    if (modelError) throw modelError;

    const { data: machine, error: machineError } = await admin
      .from("machines")
      .insert({ studio_id: studioC, equipment_model_id: model.id, label: "Geraet D" })
      .select("id")
      .single();
    if (machineError) throw machineError;

    const token = createTagToken();
    const { error: tagError } = await admin.from("machine_tags").insert({
      studio_id: studioC,
      machine_id: machine.id,
      token_hash: hashTagToken(token),
      status: "active",
    });
    if (tagError) throw tagError;

    const { error: deleteError } = await admin
      .from("machines")
      .delete()
      .eq("id", machine.id);
    expect(deleteError).not.toBeNull();

    const { data: stillThere } = await admin
      .from("machines")
      .select("id")
      .eq("id", machine.id);
    expect(stillThere).toHaveLength(1);
  });
});
