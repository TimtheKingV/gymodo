import { beforeAll, describe, expect, it } from "vitest";
import { createClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import { serviceClient, createTestUser, userClient, uniqueEmail } from "./helpers/clients.js";

function anonClient() {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY fehlen");
  return createClient(url, anonKey, { auth: { persistSession: false } });
}

let studioId: string;
let modelId: string;
let machineId: string;
let geraetToken: string;
let aushangToken: string;
let gesperrtToken: string;
let fremdEmail: string;
let trainerEmail: string;
let trainerId: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Beitritts-Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Beitritts-Geraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;
  modelId = model.id;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: model.id, label: "07" })
    .select("id")
    .single();
  if (machineError) throw machineError;
  machineId = machine.id;

  geraetToken = createTagToken();
  aushangToken = createTagToken();
  gesperrtToken = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studioId,
      machine_id: machineId,
      kind: "machine",
      token_hash: hashTagToken(geraetToken),
      status: "active",
    },
    {
      studio_id: studioId,
      kind: "studio",
      token_hash: hashTagToken(aushangToken),
      status: "active",
    },
    { studio_id: studioId, kind: "machine", token_hash: hashTagToken(gesperrtToken), status: "revoked" },
  ]);
  if (tagError) throw tagError;

  fremdEmail = uniqueEmail("beitritt-fremd");
  await createTestUser(fremdEmail);

  trainerEmail = uniqueEmail("beitritt-trainer");
  trainerId = await createTestUser(trainerEmail);
  const { error: mitgliedError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioId, user_id: trainerId, role: "trainer" });
  if (mitgliedError) throw mitgliedError;
});

describe("join_studio_by_tag", () => {
  it("macht ein fremdes Konto durch einen Geraetetag zum Mitglied", async () => {
    const client = await userClient(fremdEmail);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
    expect(data[0].studio_id).toBe(studioId);
    expect(data[0].machine_id).toBe(machineId);
    expect(data[0].joined).toBe(true);
  });

  it("gewaehrt Zugriff auf die Geraete des Studios und entzieht ihn beim Austritt", async () => {
    const email = uniqueEmail("beitritt-rls-effekt");
    const userId = await createTestUser(email);
    const client = await userClient(email);

    const { data: vorher } = await client.from("machines").select("id");
    expect(vorher).toEqual([]);

    const { error: joinError } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(joinError).toBeNull();

    const { data: nachher } = await client.from("machines").select("id");
    expect(nachher).toHaveLength(1);
    expect(nachher?.[0]?.id).toBe(machineId);

    const { error: leaveError } = await client
      .from("studio_memberships")
      .delete()
      .eq("user_id", userId);
    expect(leaveError).toBeNull();

    const { data: nachAustritt } = await client.from("machines").select("id");
    expect(nachAustritt).toEqual([]);
  });

  it("ist beim zweiten Scan wirkungslos und meldet joined = false", async () => {
    const client = await userClient(fremdEmail);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).toBeNull();
    expect(data[0].joined).toBe(false);

    const admin = serviceClient();
    const { data: zeilen } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("studio_id", studioId);
    // Trainer plus genau ein beigetretenes Mitglied -- kein Duplikat.
    expect(zeilen).toHaveLength(2);
  });

  it("liefert beim Aushang ein Studio ohne Geraet", async () => {
    const email = uniqueEmail("beitritt-aushang");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(aushangToken),
    });
    expect(error).toBeNull();
    expect(data[0].studio_id).toBe(studioId);
    expect(data[0].machine_id).toBeNull();
    expect(data[0].joined).toBe(true);
  });

  it("stuft einen Trainer nicht auf member zurueck", async () => {
    const client = await userClient(trainerEmail);
    const { error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).toBeNull();

    const admin = serviceClient();
    const { data } = await admin
      .from("studio_memberships")
      .select("role")
      .eq("studio_id", studioId)
      .eq("user_id", trainerId)
      .single();
    expect(data?.role).toBe("trainer");
  });

  it("liefert nichts fuer einen gesperrten Token und traegt niemanden ein", async () => {
    const email = uniqueEmail("beitritt-gesperrt");
    const userId = await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(gesperrtToken),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);

    const admin = serviceClient();
    const { data: zeilen } = await admin
      .from("studio_memberships")
      .select("id")
      .eq("user_id", userId);
    expect(zeilen).toEqual([]);
  });

  it("liefert nichts fuer einen unbekannten Token", async () => {
    const email = uniqueEmail("beitritt-unbekannt");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(createTagToken()),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("ist fuer anon nicht aufrufbar", async () => {
    // Regressionstest fuer 0009: ohne den Entzug der Default-Grants waere
    // die Funktion fuer anon faktisch aufrufbar -- und damit ein Orakel.
    const { error } = await anonClient().rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(geraetToken),
    });
    expect(error).not.toBeNull();
  });

  it("erlaubt den Beitritt auch ueber ein stillgelegtes Geraet -- die Mitgliedschaft haengt nicht am Geraetestatus", async () => {
    const admin = serviceClient();
    const { data: stillgelegt, error: machineError } = await admin
      .from("machines")
      .insert({
        studio_id: studioId,
        equipment_model_id: modelId,
        label: "stillgelegt-08",
        status: "inactive",
      })
      .select("id")
      .single();
    if (machineError) throw machineError;

    const inaktivToken = createTagToken();
    const { error: tagError } = await admin.from("machine_tags").insert({
      studio_id: studioId,
      machine_id: stillgelegt.id,
      kind: "machine",
      token_hash: hashTagToken(inaktivToken),
      status: "active",
    });
    if (tagError) throw tagError;

    const email = uniqueEmail("beitritt-stillgelegt");
    await createTestUser(email);
    const client = await userClient(email);
    const { data, error } = await client.rpc("join_studio_by_tag", {
      p_token_hash: hashTagToken(inaktivToken),
    });
    expect(error).toBeNull();
    expect(data[0].studio_id).toBe(studioId);
    expect(data[0].joined).toBe(true);
  });
});
