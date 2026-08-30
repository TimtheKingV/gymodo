import { beforeAll, describe, expect, it } from "vitest";
import { createClient } from "@supabase/supabase-js";
import { createTagToken, hashTagToken } from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";

function anonClient() {
  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    throw new Error("SUPABASE_URL/SUPABASE_ANON_KEY fehlen");
  }
  return createClient(url, anonKey, { auth: { persistSession: false } });
}

let activeToken: string;
let revokedToken: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Resolve-Fallback Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Resolve-Fallback Geraet", weight_step_kg: 5 })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: machine, error: machineError } = await admin
    .from("machines")
    .insert({
      studio_id: studio.id,
      equipment_model_id: model.id,
      label: "Resolve-Fallback Geraet 1",
    })
    .select("id")
    .single();
  if (machineError) throw machineError;

  activeToken = createTagToken();
  revokedToken = createTagToken();
  const { error: tagError } = await admin.from("machine_tags").insert([
    {
      studio_id: studio.id,
      machine_id: machine.id,
      token_hash: hashTagToken(activeToken),
      status: "active",
    },
    { studio_id: studio.id, token_hash: hashTagToken(revokedToken), status: "revoked" },
  ]);
  if (tagError) throw tagError;
});

describe("resolve_tag_fallback", () => {
  it("liefert eine Zeile fuer einen aktiven Tag", async () => {
    const client = anonClient();
    const { data, error } = await client.rpc("resolve_tag_fallback", {
      p_token_hash: hashTagToken(activeToken),
    });
    expect(error).toBeNull();
    expect(data).toHaveLength(1);
  });

  it("liefert keine Zeile fuer einen gesperrten Tag", async () => {
    const client = anonClient();
    const { data, error } = await client.rpc("resolve_tag_fallback", {
      p_token_hash: hashTagToken(revokedToken),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("liefert keine Zeile fuer einen unbekannten Token-Hash", async () => {
    const client = anonClient();
    const { data, error } = await client.rpc("resolve_tag_fallback", {
      p_token_hash: hashTagToken(createTagToken()),
    });
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("anonymer Client kann machine_tags nicht direkt lesen", async () => {
    const client = anonClient();
    const { data, error } = await client.from("machine_tags").select("id");
    // RLS verweigert: entweder ein Fehler oder eine leere Liste, niemals Daten.
    if (!error) {
      expect(data).toEqual([]);
    }
  });
});
