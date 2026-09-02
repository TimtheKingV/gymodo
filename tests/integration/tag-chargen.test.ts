import { beforeAll, describe, expect, it } from "vitest";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { chargeFuerTest, tagAnlegen } from "../helpers/tags.js";
import {
  bestand,
  chargeAnlegen,
  chargeVerschrotten,
  chargeZeilen,
  lieferungAnlegen,
  studioAufloesen,
} from "@fitretro/domain/chargen";

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

describe("chargen.ts", () => {
  it("legt eine Charge samt studioloser Zeilen an", async () => {
    const admin = serviceClient();
    const code = `anlegen-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "machine", menge: 12 });
    expect(charge.quantity).toBe(12);

    const { data } = await admin
      .from("machine_tags")
      .select("batch_index, studio_id, status, kind")
      .eq("batch_id", charge.id)
      .order("batch_index", { ascending: true });
    expect(data).toHaveLength(12);
    expect(data?.[0]?.batch_index).toBe(1);
    expect(data?.[11]?.batch_index).toBe(12);
    expect(data?.every((zeile) => zeile.studio_id === null)).toBe(true);
    expect(data?.every((zeile) => zeile.status === "unassigned")).toBe(true);
  });

  it("lehnt eine zweite Charge mit demselben Code ab", async () => {
    const admin = serviceClient();
    const code = `doppelt-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 1 });
    await expect(
      chargeAnlegen(admin, { code, kind: "machine", menge: 1 }),
    ).rejects.toMatchObject({ code: "conflict" });
  });

  it("liefert alle Zeilen einer Charge ueber die PostgREST-Grenze hinaus", async () => {
    const admin = serviceClient();
    const code = `blaettern-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 1200 });

    const { zeilen } = await chargeZeilen(admin, code);
    expect(zeilen).toHaveLength(1200);
    expect(zeilen[0]?.nummer).toBe(1);
    expect(zeilen[1199]?.nummer).toBe(1200);
    expect(new Set(zeilen.map((zeile) => zeile.token)).size).toBe(1200);
    expect(zeilen[0]?.token).toMatch(/^[A-Za-z0-9_-]{22}$/);
  });

  it("schreibt fuer Geraetetags nur eine Lieferzeile und fasst keinen Token an", async () => {
    const admin = serviceClient();
    const code = `liefern-machine-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "machine", menge: 10 });

    const lieferung = await lieferungAnlegen(admin, {
      chargeCode: code,
      studioId: studioA,
      menge: 4,
    });
    expect(lieferung.menge).toBe(4);

    const { data } = await admin
      .from("machine_tags")
      .select("studio_id")
      .eq("batch_id", charge.id);
    expect(data?.every((zeile) => zeile.studio_id === null)).toBe(true);
  });

  it("aktiviert bei Aushangschildern genau die genannten Nummern", async () => {
    const admin = serviceClient();
    const code = `liefern-studio-${crypto.randomUUID()}`;
    const charge = await chargeAnlegen(admin, { code, kind: "studio", menge: 10 });

    const lieferung = await lieferungAnlegen(admin, {
      chargeCode: code,
      studioId: studioA,
      nummern: [3, 4, 5],
    });
    expect(lieferung.menge).toBe(3);

    const { data } = await admin
      .from("machine_tags")
      .select("batch_index, studio_id, status")
      .eq("batch_id", charge.id)
      .order("batch_index", { ascending: true });

    const aktiv = data?.filter((zeile) => zeile.status === "active") ?? [];
    expect(aktiv.map((zeile) => zeile.batch_index)).toEqual([3, 4, 5]);
    expect(aktiv.every((zeile) => zeile.studio_id === studioA)).toBe(true);
  });

  it("lehnt Menge bei Schildern und Nummern bei Geraetetags ab", async () => {
    const admin = serviceClient();
    const schilder = `falsch-studio-${crypto.randomUUID()}`;
    const geraete = `falsch-machine-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code: schilder, kind: "studio", menge: 5 });
    await chargeAnlegen(admin, { code: geraete, kind: "machine", menge: 5 });

    await expect(
      lieferungAnlegen(admin, { chargeCode: schilder, studioId: studioA, menge: 2 }),
    ).rejects.toMatchObject({ code: "validation_failed" });

    await expect(
      lieferungAnlegen(admin, { chargeCode: geraete, studioId: studioA, nummern: [1] }),
    ).rejects.toMatchObject({ code: "validation_failed" });
  });

  it("laesst nicht mehr ausliefern als die Charge gross ist", async () => {
    const admin = serviceClient();
    const code = `zuviel-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 10 });
    await lieferungAnlegen(admin, { chargeCode: code, studioId: studioA, menge: 8 });
    await expect(
      lieferungAnlegen(admin, { chargeCode: code, studioId: studioB, menge: 3 }),
    ).rejects.toMatchObject({ code: "conflict" });
  });

  it("liefert aus einer verschrotteten Charge nichts mehr", async () => {
    const admin = serviceClient();
    const code = `schrott-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 5 });
    await chargeVerschrotten(admin, code);
    await expect(
      lieferungAnlegen(admin, { chargeCode: code, studioId: studioA, menge: 1 }),
    ).rejects.toMatchObject({ code: "conflict" });
  });

  it("rechnet den Bestand aus Lieferung minus gebundenen Tags", async () => {
    const admin = serviceClient();

    const { data: studio, error: studioFehler } = await admin
      .from("studios")
      .insert({ name: `Bestand ${crypto.randomUUID()}` })
      .select("id")
      .single();
    if (studioFehler) throw studioFehler;

    const code = `bestand-${crypto.randomUUID()}`;
    await chargeAnlegen(admin, { code, kind: "machine", menge: 100 });
    await lieferungAnlegen(admin, { chargeCode: code, studioId: studio.id, menge: 100 });

    const vorher = await bestand(admin, studio.id);
    expect(vorher).toEqual({ geliefert: 100, verbraucht: 0, vorraetig: 100 });

    await tagAnlegen(admin, { studioId: studio.id, kind: "machine", status: "unassigned" });
    const nachher = await bestand(admin, studio.id);
    expect(nachher.verbraucht).toBe(1);
    expect(nachher.vorraetig).toBe(99);
  });

  it("loest ein Studio ueber seinen Namen auf", async () => {
    const admin = serviceClient();
    const name = `Aufloesbar ${crypto.randomUUID()}`;
    const { data: studio, error } = await admin
      .from("studios")
      .insert({ name })
      .select("id")
      .single();
    if (error) throw error;

    expect(await studioAufloesen(admin, name)).toBe(studio.id);
    expect(await studioAufloesen(admin, studio.id)).toBe(studio.id);
    await expect(studioAufloesen(admin, "Gibt es nicht")).rejects.toMatchObject({
      code: "not_found",
    });
  });
});
