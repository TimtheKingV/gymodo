import { beforeAll, describe, expect, it } from "vitest";
import { GET as machinePhotosGET } from "@/app/api/v1/me/machine-photos/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";

/** Kleinstes gueltiges JPEG -- SOI, APP0/JFIF, EOI. */
function jpegBytes(): Blob {
  const bytes = new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
  ]);
  return new Blob([bytes], { type: "image/jpeg" });
}

let bearerA: string;
let bearerB: string;
let rudermaschineId: string;
let beinpresseId: string;
let latzugId: string;
let crosstrainerId: string;
let stepperId: string;

function request(url: string, auth?: string): Request {
  return new Request(url, {
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Fotos-Studio A" }, { name: "Fotos-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  const studioA = studios[0]!.id;
  const studioB = studios[1]!.id;

  const emailA = uniqueEmail("fotos-member-a");
  const emailB = uniqueEmail("fotos-member-b");
  const userA = await createTestUser(emailA);
  const userB = await createTestUser(emailB);

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: userA, role: "member" },
      { studio_id: studioB, user_id: userB, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  // Rudermaschine: mit Foto, zwei Geraete.
  const rudermaschinePfad = `${studioA}/${crypto.randomUUID()}.jpg`;
  const { error: uploadError } = await admin.storage
    .from("equipment-photos")
    .upload(rudermaschinePfad, jpegBytes());
  if (uploadError) throw uploadError;

  const { data: rudermaschine, error: rudermaschineError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Rudermaschine",
      weight_step_kg: 2.5,
      photo_path: rudermaschinePfad,
    })
    .select("id")
    .single();
  if (rudermaschineError) throw rudermaschineError;
  rudermaschineId = rudermaschine.id;

  const { error: rudermaschineMachinesError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: rudermaschineId, label: "R1" },
      { studio_id: studioA, equipment_model_id: rudermaschineId, label: "R2" },
    ]);
  if (rudermaschineMachinesError) throw rudermaschineMachinesError;

  // Beinpresse: ohne Foto, ein Geraet.
  const { data: beinpresse, error: beinpresseError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: "Beinpresse", weight_step_kg: 5 })
    .select("id")
    .single();
  if (beinpresseError) throw beinpresseError;
  beinpresseId = beinpresse.id;

  const { error: beinpresseMachineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: beinpresseId, label: "B1" });
  if (beinpresseMachineError) throw beinpresseMachineError;

  // Stepper: gesperrt (status inactive), mit Foto, eigenes Geraet.
  // Die Liste zeigt gesperrte Geraete gedimmt statt sie auszublenden
  // ("gesperrte eingeschlossen") -- das Foto muss deshalb auch fuer ein
  // rein gesperrtes Modell ankommen.
  const stepperPfad = `${studioA}/${crypto.randomUUID()}.jpg`;
  const { error: stepperUploadError } = await admin.storage
    .from("equipment-photos")
    .upload(stepperPfad, jpegBytes());
  if (stepperUploadError) throw stepperUploadError;

  const { data: stepper, error: stepperError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Stepper",
      weight_step_kg: 1,
      photo_path: stepperPfad,
    })
    .select("id")
    .single();
  if (stepperError) throw stepperError;
  stepperId = stepper.id;

  const { error: stepperMachineError } = await admin.from("machines").insert({
    studio_id: studioA,
    equipment_model_id: stepperId,
    label: "S1",
    status: "inactive",
  });
  if (stepperMachineError) throw stepperMachineError;

  // Latzug: photo_path zeigt auf ein nicht hochgeladenes Objekt.
  const { data: latzug, error: latzugError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioA,
      name: "Latzug",
      weight_step_kg: 5,
      photo_path: `${studioA}/${crypto.randomUUID()}.jpg`,
    })
    .select("id")
    .single();
  if (latzugError) throw latzugError;
  latzugId = latzug.id;

  const { error: latzugMachineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: latzug.id, label: "L1" });
  if (latzugMachineError) throw latzugMachineError;

  // Crosstrainer in Studio B, mit Foto.
  const crosstrainerPfad = `${studioB}/${crypto.randomUUID()}.jpg`;
  const { error: crosstrainerUploadError } = await admin.storage
    .from("equipment-photos")
    .upload(crosstrainerPfad, jpegBytes());
  if (crosstrainerUploadError) throw crosstrainerUploadError;

  const { data: crosstrainer, error: crosstrainerError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioB,
      name: "Crosstrainer",
      weight_step_kg: 1,
      photo_path: crosstrainerPfad,
    })
    .select("id")
    .single();
  if (crosstrainerError) throw crosstrainerError;
  crosstrainerId = crosstrainer.id;

  const { error: crosstrainerMachineError } = await admin
    .from("machines")
    .insert({ studio_id: studioB, equipment_model_id: crosstrainerId, label: "C1" });
  if (crosstrainerMachineError) throw crosstrainerMachineError;

  bearerA = await accessTokenFor(emailA);
  bearerB = await accessTokenFor(emailB);
});

describe("GET /api/v1/me/machine-photos", () => {
  it("ohne Anmeldung 401", async () => {
    const response = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos"),
    );
    expect(response.status).toBe(401);
  });

  it("liefert je Modell mit Foto genau eine ladbare URL", async () => {
    const response = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerA),
    );
    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      photos: Array<{ equipmentModelId: string; url: string }>;
    };
    const eintraege = payload.photos.filter(
      (foto) => foto.equipmentModelId === rudermaschineId,
    );
    expect(eintraege).toHaveLength(1);

    const geladen = await fetch(eintraege[0]!.url);
    expect(geladen.status).toBe(200);
  });

  it("ein gesperrtes Geraet liefert das Foto seines Modells trotzdem", async () => {
    const response = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerA),
    );
    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      photos: Array<{ equipmentModelId: string; url: string }>;
    };
    const eintraege = payload.photos.filter(
      (foto) => foto.equipmentModelId === stepperId,
    );
    expect(eintraege).toHaveLength(1);

    const geladen = await fetch(eintraege[0]!.url);
    expect(geladen.status).toBe(200);
  });

  it("ein Modell ohne Foto fehlt, statt mit null zu kommen", async () => {
    const response = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerA),
    );
    const payload = (await response.json()) as {
      photos: Array<{ equipmentModelId: string; url: string }>;
    };
    expect(
      payload.photos.some((foto) => foto.equipmentModelId === beinpresseId),
    ).toBe(false);
  });

  it("ein verwaister Pfad fehlt, statt die Antwort zu kippen", async () => {
    const response = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerA),
    );
    expect(response.status).toBe(200);
    const payload = (await response.json()) as {
      photos: Array<{ equipmentModelId: string; url: string }>;
    };
    expect(
      payload.photos.some((foto) => foto.equipmentModelId === latzugId),
    ).toBe(false);
  });

  it("cross-tenant: das Foto aus Studio B erscheint bei A nicht", async () => {
    const responseA = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerA),
    );
    const payloadA = (await responseA.json()) as {
      photos: Array<{ equipmentModelId: string; url: string }>;
    };
    expect(
      payloadA.photos.some((foto) => foto.equipmentModelId === crosstrainerId),
    ).toBe(false);

    const responseB = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerB),
    );
    const payloadB = (await responseB.json()) as {
      photos: Array<{ equipmentModelId: string; url: string }>;
    };
    expect(
      payloadB.photos.some((foto) => foto.equipmentModelId === crosstrainerId),
    ).toBe(true);
  });

  it("antwortet private, no-store", async () => {
    const response = await machinePhotosGET(
      request("http://localhost/api/v1/me/machine-photos", bearerA),
    );
    expect(response.headers.get("cache-control")).toContain("private");
    expect(response.headers.get("cache-control")).toContain("no-store");
  });
});
