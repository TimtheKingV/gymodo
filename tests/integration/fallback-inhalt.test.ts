import { beforeAll, describe, expect, it } from "vitest";
import {
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  createTagToken,
  hashTagToken,
} from "@fitretro/domain";
import { anonClient, serviceClient } from "./helpers/clients.js";
import { tagsAnlegen } from "../helpers/tags.js";

/**
 * Spec 6.4: der Fallback ist keine Sackgasse, sondern sofort nuetzlich --
 * "So stellst du dieses Geraet ein", Video laeuft, darunter erst der
 * Installationshinweis. Und er funktioniert auf Android.
 *
 * Weiterhin ohne persoenliche Daten, und mit identischer Antwort fuer
 * unbekannt, ungueltig und gesperrt: sonst liessen sich gueltige Tokens
 * durch Ausprobieren unterscheiden.
 */

let studioId: string;
let aktiverToken: string;
let gesperrterToken: string;
let stillgelegtToken: string;
let unbenutzterToken: string;
let fotoPfad: string;
let videoPfad: string;
let unveroeffentlichtesFoto: string;

function ascii(text: string): number[] {
  return [...text].map((zeichen) => zeichen.charCodeAt(0));
}

function jpegBytes() {
  return new Uint8Array([
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, ...ascii("JFIF"), 0x00, 0x01, 0x01,
    0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xff, 0xd9,
  ]);
}

function mp4Bytes() {
  return new Uint8Array([
    0x00, 0x00, 0x00, 0x18, ...ascii("ftyp"), ...ascii("isom"), 0x00, 0x00,
    0x02, 0x00, ...ascii("isomiso2"),
  ]);
}

type FallbackZeile = {
  machine_tag_id: string;
  machine_label: string;
  model_name: string;
  photo_path: string | null;
  exercises: Array<{ name: string; video_path: string | null }>;
};

async function loese(token: string): Promise<FallbackZeile[]> {
  const client = anonClient();
  const { data, error } = await client.rpc("resolve_tag_fallback", {
    p_token_hash: hashTagToken(token),
  });
  if (error) throw error;
  return (data ?? []) as FallbackZeile[];
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: "Fallback-Inhalt Studio" })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioId = studio.id;

  fotoPfad = `${studioId}/models/${crypto.randomUUID()}.jpg`;
  videoPfad = `${studioId}/exercises/${crypto.randomUUID()}.mp4`;
  unveroeffentlichtesFoto = `${studioId}/models/${crypto.randomUUID()}.jpg`;

  const { data: model, error: modelError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: studioId,
      name: "Latzug",
      manufacturer: "Technogym",
      weight_step_kg: 2.5,
      photo_path: fotoPfad,
    })
    .select("id")
    .single();
  if (modelError) throw modelError;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: studioId, name: "Latzug breit", target_reps_min: 8, target_reps_max: 12 },
      { studio_id: studioId, name: "Latzug eng", target_reps_min: 8, target_reps_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;

  const { data: links, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: model.id, exercise_id: uebungen[0]!.id, sort_order: 1 },
      { equipment_model_id: model.id, exercise_id: uebungen[1]!.id, sort_order: 2 },
    ])
    .select("id");
  if (linkError) throw linkError;

  // Nur die erste Uebung hat ein Video -- die zweite muss trotzdem erscheinen.
  const { error: assetError } = await admin.from("instruction_assets").insert({
    equipment_model_exercise_id: links[0]!.id,
    kind: "video",
    storage_path: videoPfad,
    duration_s: 25,
  });
  if (assetError) throw assetError;

  const { data: geraete, error: geraetError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioId, equipment_model_id: model.id, label: "12" },
      { studio_id: studioId, equipment_model_id: model.id, label: "13" },
      { studio_id: studioId, equipment_model_id: model.id, label: "14" },
    ])
    .select("id, label");
  if (geraetError) throw geraetError;

  const aktiv = geraete.find((g) => g.label === "12")!.id;
  const gesperrt = geraete.find((g) => g.label === "13")!.id;
  const stillgelegt = geraete.find((g) => g.label === "14")!.id;

  aktiverToken = createTagToken();
  gesperrterToken = createTagToken();
  stillgelegtToken = createTagToken();
  unbenutzterToken = createTagToken();

  await tagsAnlegen(admin, [
    { studioId, machineId: aktiv, token: aktiverToken, status: "active" },
    { studioId, machineId: gesperrt, token: gesperrterToken, status: "revoked" },
    { studioId, machineId: stillgelegt, token: stillgelegtToken, status: "active" },
  ]);

  const { error: statusError } = await admin
    .from("machines")
    .update({ status: "inactive" })
    .eq("id", stillgelegt);
  if (statusError) throw statusError;

  for (const [bucket, pfad, bytes, typ] of [
    [PHOTO_BUCKET, fotoPfad, jpegBytes(), "image/jpeg"],
    [PHOTO_BUCKET, unveroeffentlichtesFoto, jpegBytes(), "image/jpeg"],
    [VIDEO_BUCKET, videoPfad, mp4Bytes(), "video/mp4"],
  ] as const) {
    const { error } = await admin.storage
      .from(bucket)
      .upload(pfad, new Blob([bytes], { type: typ }), {
        contentType: typ,
        upsert: true,
      });
    if (error) throw error;
  }
});

describe("resolve_tag_fallback liefert Einweisungsinhalte", () => {
  it("nennt Geraet, Modell, Foto und die Uebungen in ihrer Reihenfolge", async () => {
    const zeilen = await loese(aktiverToken);

    expect(zeilen).toHaveLength(1);
    const zeile = zeilen[0]!;
    expect(zeile.machine_label).toBe("12");
    expect(zeile.model_name).toBe("Latzug");
    expect(zeile.photo_path).toBe(fotoPfad);
    expect(zeile.exercises.map((u) => u.name)).toEqual([
      "Latzug breit",
      "Latzug eng",
    ]);
    expect(zeile.exercises[0]!.video_path).toBe(videoPfad);
  });

  it("eine Uebung ohne Video erscheint trotzdem", async () => {
    const zeilen = await loese(aktiverToken);
    expect(zeilen[0]!.exercises[1]!.video_path).toBeNull();
  });

  it("enthaelt keine persoenlichen Daten", async () => {
    const zeilen = await loese(aktiverToken);
    const roh = JSON.stringify(zeilen);

    for (const verboten of ["user_id", "weight_kg", "reps", "email", "studio_id"]) {
      expect(roh).not.toContain(verboten);
    }
  });

  it("ein gesperrter Tag liefert weiterhin nichts", async () => {
    expect(await loese(gesperrterToken)).toEqual([]);
  });

  it("ein unbekannter Token liefert dieselbe leere Antwort", async () => {
    expect(await loese(unbenutzterToken)).toEqual([]);
  });

  it("ein stillgelegtes Geraet liefert nichts -- eine Einweisung dafuer waere falsch", async () => {
    expect(await loese(stillgelegtToken)).toEqual([]);
  });
});

describe("Medien im Fallback", () => {
  it("anonym lesbar, solange ein aktiver Tag darauf zeigt", async () => {
    const client = anonClient();

    const foto = await client.storage.from(PHOTO_BUCKET).createSignedUrl(fotoPfad, 60);
    expect(foto.error).toBeNull();
    const abruf = await fetch(foto.data!.signedUrl);
    expect(abruf.ok).toBe(true);

    const video = await client.storage.from(VIDEO_BUCKET).createSignedUrl(videoPfad, 60);
    expect(video.error).toBeNull();
  });

  it("ein Objekt ohne aktiven Tag bleibt anonym verschlossen", async () => {
    const client = anonClient();

    const { data, error } = await client.storage
      .from(PHOTO_BUCKET)
      .createSignedUrl(unveroeffentlichtesFoto, 60);
    expect(error).not.toBeNull();
    expect(data).toBeNull();
  });

  it("anonym laesst sich nichts hochladen", async () => {
    const client = anonClient();

    const { error } = await client.storage
      .from(PHOTO_BUCKET)
      .upload(
        `${studioId}/models/${crypto.randomUUID()}.jpg`,
        new Blob([jpegBytes()], { type: "image/jpeg" }),
        { contentType: "image/jpeg" },
      );
    expect(error).not.toBeNull();
  });

  it("anonym laesst sich nichts loeschen", async () => {
    // Ohne Delete-Policy trifft das Loeschen null Zeilen und meldet keinen
    // Fehler -- was zaehlt, ist also nicht die Antwort, sondern dass die
    // Datei danach noch da ist.
    const client = anonClient();
    await client.storage.from(PHOTO_BUCKET).remove([fotoPfad]);

    const admin = serviceClient();
    const { data } = await admin.storage
      .from(PHOTO_BUCKET)
      .list(`${studioId}/models`);
    expect(data?.some((eintrag) => fotoPfad.endsWith(eintrag.name))).toBe(true);
  });
});
