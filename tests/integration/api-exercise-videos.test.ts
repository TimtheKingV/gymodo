import { beforeAll, describe, expect, it } from "vitest";
import { GET as exerciseVideosGET } from "@/app/api/v1/me/exercise-videos/route";
import { GET as machinePhotosGET } from "@/app/api/v1/me/machine-photos/route";
import {
  accessTokenFor,
  createTestUser,
  serviceClient,
  uniqueEmail,
} from "./helpers/clients.js";

// Testnotiz 11.10., #1, #2: die Liste zeigt Videos je Uebung und Fotos auch
// fuer Gymtavo-Typen. Andere Testdateien legen ebenfalls Typen an -- geprueft
// wird auf Enthaltensein, nie auf Gleichheit der Liste.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

/** Kleinstes gueltiges JPEG -- SOI, APP0/JFIF, EOI. */
function jpegBytes(): Blob {
  const bytes = new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
  ]);
  return new Blob([bytes], { type: "image/jpeg" });
}

/** Der Bucket prueft nur den MIME-Typ, nicht den Inhalt. */
function mp4Bytes(): Blob {
  return new Blob([new Uint8Array([0, 0, 0, 8, 0x66, 0x74, 0x79, 0x70])], { type: "video/mp4" });
}

let bearerA: string;
let bearerB: string;
let typ: string;
let studioModell: string;
let katalogUebung: string;
let eigeneVideoUebung: string;
let studioPfad: string;
let fremdeUebung: string;

function request(pfad: string, auth?: string): Request {
  return new Request(`http://localhost${pfad}`, {
    headers: auth ? { authorization: `Bearer ${auth}` } : {},
  });
}

async function hochladen(bucket: string, pfad: string, inhalt: Blob): Promise<void> {
  const { error } = await serviceClient().storage.from(bucket).upload(pfad, inhalt);
  if (error) throw error;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: `Videos A ${kennung}` }, { name: `Videos B ${kennung}` }])
    .select("id");
  if (studioError) throw studioError;
  const studioA = studios[0]!.id;
  const studioB = studios[1]!.id;

  const emailA = uniqueEmail("videos-a");
  const emailB = uniqueEmail("videos-b");
  const userA = await createTestUser(emailA);
  const userB = await createTestUser(emailB);
  const { error: rolleError } = await admin.from("studio_memberships").insert([
    { studio_id: studioA, user_id: userA, role: "member" },
    { studio_id: studioB, user_id: userB, role: "member" },
  ]);
  if (rolleError) throw rolleError;

  // Gymtavo-Typ mit Foto, ein Studio-Modell ohne eigenes Foto darauf.
  const typFoto = `${GYMTAVO}/${crypto.randomUUID()}.jpg`;
  await hochladen("equipment-photos", typFoto, jpegBytes());
  const { data: typRow, error: typError } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: `Videotyp ${kennung}`, load_step: 5, photo_path: typFoto })
    .select("id")
    .single();
  if (typError) throw typError;
  typ = typRow.id;

  const { data: modellRow, error: modellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: `Videomodell ${kennung}`, load_step: 5, catalog_model_id: typ })
    .select("id")
    .single();
  if (modellError) throw modellError;
  studioModell = modellRow.id;
  const { error: geraetError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: studioModell, label: "V1" });
  if (geraetError) throw geraetError;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: GYMTAVO, name: `Katalogvideo ${kennung}`, target_min: 8, target_max: 12 },
      { studio_id: GYMTAVO, name: `Ueberschrieben ${kennung}`, target_min: 8, target_max: 12 },
      { studio_id: studioB, name: `Fremd ${kennung}`, target_min: 8, target_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  katalogUebung = uebungen[0]!.id;
  eigeneVideoUebung = uebungen[1]!.id;
  fremdeUebung = uebungen[2]!.id;

  const { data: fremdModell, error: fremdModellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioB, name: `Fremdmodell ${kennung}`, load_step: 5 })
    .select("id")
    .single();
  if (fremdModellError) throw fremdModellError;

  const { data: links, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: typ, exercise_id: katalogUebung, sort_order: 1 },
      { equipment_model_id: typ, exercise_id: eigeneVideoUebung, sort_order: 2 },
      { equipment_model_id: studioModell, exercise_id: eigeneVideoUebung, sort_order: 1 },
      { equipment_model_id: fremdModell.id, exercise_id: fremdeUebung, sort_order: 1 },
    ])
    .select("id");
  if (linkError) throw linkError;

  const katalogPfad1 = `${GYMTAVO}/${crypto.randomUUID()}.mp4`;
  const katalogPfad2 = `${GYMTAVO}/${crypto.randomUUID()}.mp4`;
  studioPfad = `${studioA}/${crypto.randomUUID()}.mp4`;
  const fremdPfad = `${studioB}/${crypto.randomUUID()}.mp4`;
  for (const pfad of [katalogPfad1, katalogPfad2, studioPfad, fremdPfad]) {
    await hochladen("instruction-videos", pfad, mp4Bytes());
  }
  const { error: assetError } = await admin.from("instruction_assets").insert([
    { equipment_model_exercise_id: links[0]!.id, kind: "video", storage_path: katalogPfad1, duration_s: 5 },
    { equipment_model_exercise_id: links[1]!.id, kind: "video", storage_path: katalogPfad2, duration_s: 5 },
    { equipment_model_exercise_id: links[2]!.id, kind: "video", storage_path: studioPfad, duration_s: 5 },
    { equipment_model_exercise_id: links[3]!.id, kind: "video", storage_path: fremdPfad, duration_s: 5 },
  ]);
  if (assetError) throw assetError;

  bearerA = await accessTokenFor(emailA);
  bearerB = await accessTokenFor(emailB);
});

type Videos = { videos: Array<{ exerciseId: string; url: string; pfad: string }> };
type Fotos = { photos: Array<{ equipmentModelId: string; url: string }> };

describe("GET /api/v1/me/exercise-videos", () => {
  it("ohne Anmeldung 401", async () => {
    const response = await exerciseVideosGET(request("/api/v1/me/exercise-videos"));
    expect(response.status).toBe(401);
  });

  it("liefert das Katalogvideo als ladbare URL", async () => {
    const response = await exerciseVideosGET(request("/api/v1/me/exercise-videos", bearerA));
    expect(response.status).toBe(200);
    const { videos } = (await response.json()) as Videos;
    const eintrag = videos.find((video) => video.exerciseId === katalogUebung);
    expect(eintrag).toBeDefined();

    const geladen = await fetch(eintrag!.url);
    expect(geladen.status).toBe(200);
  });

  it("das eigene Video des Studios schlaegt das des Katalogs", async () => {
    const response = await exerciseVideosGET(request("/api/v1/me/exercise-videos", bearerA));
    const { videos } = (await response.json()) as Videos;
    const eintraege = videos.filter((video) => video.exerciseId === eigeneVideoUebung);
    expect(eintraege).toHaveLength(1);
    expect(eintraege[0]!.pfad).toBe(studioPfad);
  });

  it("cross-tenant: das Video aus Studio B erscheint bei A nicht", async () => {
    const responseA = await exerciseVideosGET(request("/api/v1/me/exercise-videos", bearerA));
    const a = (await responseA.json()) as Videos;
    expect(a.videos.some((video) => video.exerciseId === fremdeUebung)).toBe(false);

    const responseB = await exerciseVideosGET(request("/api/v1/me/exercise-videos", bearerB));
    const b = (await responseB.json()) as Videos;
    expect(b.videos.some((video) => video.exerciseId === fremdeUebung)).toBe(true);
  });

  it("antwortet private, no-store", async () => {
    const response = await exerciseVideosGET(request("/api/v1/me/exercise-videos", bearerA));
    expect(response.headers.get("cache-control")).toContain("no-store");
  });
});

describe("GET /api/v1/me/machine-photos mit Gymtavo-Typen", () => {
  it("liefert dem Typ sein Foto und dem Modell ohne eigenes das des Typs", async () => {
    const response = await machinePhotosGET(request("/api/v1/me/machine-photos", bearerA));
    const { photos } = (await response.json()) as Fotos;

    expect(photos.some((foto) => foto.equipmentModelId === typ)).toBe(true);
    expect(photos.some((foto) => foto.equipmentModelId === studioModell)).toBe(true);
  });
});
