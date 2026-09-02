import { beforeAll, describe, expect, it } from "vitest";
import { createTagToken } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";
import { chargeFuerTest, tagAnlegen } from "../helpers/tags.js";

type Befund = {
  verdict: string;
  batch_code: string | null;
  batch_index: number | null;
  machine_id: string | null;
  machine_label: string | null;
};

let studioA: string;
let studioB: string;
let trainerA: string;
let geraetA: string;
let geraetB: string;

async function befund(email: string, token: string, studioId: string): Promise<Befund> {
  const client = await userClient(email);
  const { data, error } = await client.rpc("inspect_tag", {
    p_token: token,
    p_studio_id: studioId,
  });
  if (error) throw error;
  return (data as Befund[])[0]!;
}

async function binden(email: string, token: string, machineId: string) {
  const client = await userClient(email);
  const { data, error } = await client.rpc("bind_tag_to_machine", {
    p_token: token,
    p_machine_id: machineId,
  });
  if (error) throw error;
  return (data as Array<{ verdict: string; tag_id: string | null }>)[0]!;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Binden Studio A" }, { name: "Binden Studio B" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("binden-trainer-a");
  const nutzer = await createTestUser(trainerA);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: nutzer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const { data: modelle, error: modellFehler } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Binden-Modell A", weight_step_kg: 5 },
      { studio_id: studioB, name: "Binden-Modell B", weight_step_kg: 5 },
    ])
    .select("id");
  if (modellFehler) throw modellFehler;

  const { data: geraete, error: geraetFehler } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: modelle[0]!.id, label: "Beinpresse 7" },
      { studio_id: studioB, equipment_model_id: modelle[1]!.id, label: "Fremdgeraet" },
    ])
    .select("id");
  if (geraetFehler) throw geraetFehler;
  geraetA = geraete[0]!.id;
  geraetB = geraete[1]!.id;
});

describe("inspect_tag", () => {
  it("nennt einen studiolosen Geraetetag frei, mit Charge und Nummer", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    const ergebnis = await befund(trainerA, token, studioA);
    expect(ergebnis.verdict).toBe("frei");
    expect(ergebnis.batch_code).toBeTruthy();
    expect(ergebnis.batch_index).toBeGreaterThan(0);
  });

  it("nennt einen gebundenen Tag vergeben, mit dem Geraet", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      machineId: geraetA,
      status: "active",
    });
    const ergebnis = await befund(trainerA, token, studioA);
    expect(ergebnis.verdict).toBe("vergeben");
    expect(ergebnis.machine_label).toBe("Beinpresse 7");
  });

  it("nennt einen gesperrten Tag gesperrt", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      status: "revoked",
    });
    expect((await befund(trainerA, token, studioA)).verdict).toBe("gesperrt");
  });

  it("nennt einen Tag aus verschrotteter Charge gesperrt", async () => {
    const admin = serviceClient();
    const { data: charge, error: chargeFehler } = await admin
      .from("tag_batches")
      .insert({
        code: `verschrottet-${crypto.randomUUID()}`,
        kind: "machine",
        quantity: 1,
        scrapped_at: new Date().toISOString(),
      })
      .select("id")
      .single();
    if (chargeFehler) throw chargeFehler;

    const token = createTagToken();
    const { error } = await admin.from("machine_tags").insert({
      studio_id: null,
      kind: "machine",
      status: "unassigned",
      token,
      batch_id: charge.id,
      batch_index: 1,
    });
    if (error) throw error;

    expect((await befund(trainerA, token, studioA)).verdict).toBe("gesperrt");
  });

  it("nennt ein aktives Aushangschild des eigenen Studios beim Namen", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      kind: "studio",
      status: "active",
    });
    expect((await befund(trainerA, token, studioA)).verdict).toBe("aushangschild");
  });

  it("verraet nichts ueber ein fremdes Studio", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioB,
      machineId: geraetB,
      status: "active",
    });
    const ergebnis = await befund(trainerA, token, studioA);
    expect(ergebnis.verdict).toBe("unbekannt");
    expect(ergebnis.machine_label).toBeNull();
  });

  it("verraet nichts ueber ein noch nicht geliefertes Schild", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: null,
      kind: "studio",
    });
    expect((await befund(trainerA, token, studioA)).verdict).toBe("unbekannt");
  });

  it("antwortet unbekannt auf einen Token, den es nicht gibt", async () => {
    expect((await befund(trainerA, createTagToken(), studioA)).verdict).toBe("unbekannt");
  });

  it("antwortet unbekannt, wenn der Fragende nicht zum Studio gehoert", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    expect((await befund(trainerA, token, studioB)).verdict).toBe("unbekannt");
  });
});

describe("bind_tag_to_machine", () => {
  it("bindet einen studiolosen Tag und vergibt dabei das Studio", async () => {
    const admin = serviceClient();
    const { token, id } = await tagAnlegen(admin, { studioId: null });

    const ergebnis = await binden(trainerA, token, geraetA);
    expect(ergebnis.verdict).toBe("gebunden");
    expect(ergebnis.tag_id).toBe(id);

    const { data } = await admin
      .from("machine_tags")
      .select("studio_id, machine_id, status")
      .eq("id", id)
      .single<{ studio_id: string; machine_id: string; status: string }>();
    expect(data?.studio_id).toBe(studioA);
    expect(data?.machine_id).toBe(geraetA);
    expect(data?.status).toBe("active");
  });

  it("bindet keinen Tag an ein fremdes Geraet", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    expect((await binden(trainerA, token, geraetB)).verdict).toBe("unbekannt");
  });

  it("bindet einen bereits gebundenen Tag nicht noch einmal", async () => {
    const { token } = await tagAnlegen(serviceClient(), { studioId: null });
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("gebunden");
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("vergeben");
  });

  it("bindet kein Aushangschild", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: studioA,
      kind: "studio",
      status: "active",
    });
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("aushangschild");
  });

  it("bindet keinen gesperrten Tag", async () => {
    const { token } = await tagAnlegen(serviceClient(), {
      studioId: null,
      status: "revoked",
    });
    expect((await binden(trainerA, token, geraetA)).verdict).toBe("gesperrt");
  });
});
