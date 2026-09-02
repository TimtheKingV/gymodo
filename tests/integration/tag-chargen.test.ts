import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { chargeFuerTest, tagAnlegen } from "../helpers/tags.js";

let studioA: string;
let studioB: string;
let trainerA: string;
let lieferungA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Chargen Studio A" }, { name: "Chargen Studio B" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("chargen-trainer-a");
  const nutzer = await createTestUser(trainerA);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: nutzer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const charge = await chargeFuerTest(admin, "machine");
  const { data: lieferung, error: lieferFehler } = await admin
    .from("tag_shipments")
    .insert([
      { batch_id: charge.id, studio_id: studioA, quantity: 100 },
      { batch_id: charge.id, studio_id: studioB, quantity: 50 },
    ])
    .select("id, studio_id");
  if (lieferFehler) throw lieferFehler;
  lieferungA = lieferung.find((zeile) => zeile.studio_id === studioA)!.id;
});

describe("Chargen und Lieferungen", () => {
  it("haelt tag_batches vor jedem angemeldeten Konto verschlossen", async () => {
    const client = await userClient(trainerA);
    const { data, error } = await client.from("tag_batches").select("id");
    expect(error).toBeNull();
    expect(data).toEqual([]);
  });

  it("zeigt einem Trainer die Lieferungen seines Studios", async () => {
    const client = await userClient(trainerA);
    const { data, error } = await client
      .from("tag_shipments")
      .select("id, quantity");
    expect(error).toBeNull();
    expect(data?.map((zeile) => zeile.id)).toEqual([lieferungA]);
    expect(data?.[0]?.quantity).toBe(100);
  });

  it("laesst einen Trainer keine Lieferung anlegen", async () => {
    const client = await userClient(trainerA);
    const charge = await chargeFuerTest(serviceClient(), "machine");
    const { error } = await client
      .from("tag_shipments")
      .insert({ batch_id: charge.id, studio_id: studioA, quantity: 1 });
    expect(error).not.toBeNull();
  });
});

describe("Die Halde", () => {
  it("speichert eine Zeile ohne Studio", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId: null });
    const { data } = await admin
      .from("machine_tags")
      .select("studio_id, status")
      .eq("id", id)
      .single<{ studio_id: string | null; status: string }>();
    expect(data?.studio_id).toBeNull();
    expect(data?.status).toBe("unassigned");
  });

  it("verbirgt eine studiolose Zeile vor jedem angemeldeten Konto", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId: null });
    const client = await userClient(trainerA);
    const { data } = await client.from("machine_tags").select("id").eq("id", id);
    expect(data).toEqual([]);
  });

  it("lehnt eine studiolose Zeile mit Geraet ab", async () => {
    const admin = serviceClient();
    const charge = await chargeFuerTest(admin, "machine");

    const { data: modell, error: modellFehler } = await admin
      .from("equipment_models")
      .insert({ studio_id: studioA, name: "Halde-Geraet", weight_step_kg: 5 })
      .select("id")
      .single();
    if (modellFehler) throw modellFehler;

    const { data: geraet, error: geraetFehler } = await admin
      .from("machines")
      .insert({ studio_id: studioA, equipment_model_id: modell.id, label: "H1" })
      .select("id")
      .single();
    if (geraetFehler) throw geraetFehler;

    const { error } = await admin.from("machine_tags").insert({
      studio_id: null,
      machine_id: geraet.id,
      kind: "machine",
      status: "unassigned",
      token: "AAAAAAAAAAAAAAAAAAAAAA",
      batch_id: charge.id,
      batch_index: 9001,
    });
    expect(error?.message).toContain("machine_tags_halde");
  });

  it("lehnt eine studiolose Zeile mit status active ab", async () => {
    const admin = serviceClient();
    const charge = await chargeFuerTest(admin, "studio");
    const { error } = await admin.from("machine_tags").insert({
      studio_id: null,
      kind: "studio",
      status: "active",
      token: "BBBBBBBBBBBBBBBBBBBBBB",
      batch_id: charge.id,
      batch_index: 9002,
    });
    expect(error?.message).toContain("machine_tags_halde");
  });

  it("erlaubt eine studiolose Zeile als revoked", async () => {
    const admin = serviceClient();
    const { id } = await tagAnlegen(admin, { studioId: null, status: "revoked" });
    expect(id).toBeTruthy();
  });
});
