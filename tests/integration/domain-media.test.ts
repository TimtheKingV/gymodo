import { beforeAll, describe, expect, it } from "vitest";
import {
  DomainError,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  confirmInstructionVideo,
  prepareInstructionVideoUpload,
  uploadEquipmentPhoto,
} from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let trainerA: string;
let memberA: string;
let modelA: string;
let modelB: string;
let linkA: string;
let linkB: string;

function ascii(text: string): number[] {
  return [...text].map((character) => character.charCodeAt(0));
}

function jpegSegment(marker: number, payload: number[]): number[] {
  const length = payload.length + 2;
  return [0xff, marker, (length >> 8) & 0xff, length & 0xff, ...payload];
}

/** Ein JPEG mit Exif-Segment -- so kommt es aus dem Trainerhandy. */
function jpegMitExif(): Uint8Array {
  return new Uint8Array([
    0xff, 0xd8,
    ...jpegSegment(0xe0, [...ascii("JFIF"), 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]),
    ...jpegSegment(0xe1, [...ascii("Exif"), 0x00, 0x00, ...ascii("MM"), 0x2a, 0x47, 0x50, 0x53]),
    ...jpegSegment(0xda, [0x01, 0x01, 0x00, 0x00, 0x3f, 0x00]),
    0xab, 0xcd, 0xef,
    0xff, 0xd9,
  ]);
}

function uint32(value: number): number[] {
  return [(value >>> 24) & 0xff, (value >>> 16) & 0xff, (value >>> 8) & 0xff, value & 0xff];
}

function box(type: string, payload: number[]): number[] {
  return [...uint32(payload.length + 8), ...ascii(type), ...payload];
}

/** Gueltiges MP4 mit der gewuenschten Laufzeit in der mvhd-Box. */
function mp4MitDauer(sekunden: number): Uint8Array {
  const mvhd = box("mvhd", [
    0x00, 0x00, 0x00, 0x00,
    ...uint32(0), ...uint32(0),
    ...uint32(600), ...uint32(600 * sekunden),
    ...new Array(80).fill(0),
  ]);
  return new Uint8Array([
    ...box("ftyp", [...ascii("isom"), ...uint32(512), ...ascii("isomiso2")]),
    ...box("mdat", new Array(64).fill(0x11)),
    ...box("moov", mvhd),
  ]);
}

/** Laedt ein Objekt so hoch, wie es der Browser per TUS taete. */
async function uploadRaw(
  email: string,
  bucket: string,
  path: string,
  bytes: Uint8Array,
  contentType: string,
): Promise<void> {
  const client = await userClient(email);
  const { error } = await client.storage
    .from(bucket)
    .upload(path, new Blob([bytes], { type: contentType }), {
      contentType,
      upsert: true,
    });
  if (error) throw error;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Upload-Studio A" }, { name: "Upload-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("upload-trainer-a");
  memberA = uniqueEmail("upload-member-a");
  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" },
      { studio_id: studioA, user_id: await createTestUser(memberA), role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Upload-Modell A", weight_step_kg: 5 },
      { studio_id: studioB, name: "Upload-Modell B", weight_step_kg: 5 },
    ])
    .select("id");
  if (modelError) throw modelError;
  modelA = models[0]!.id;
  modelB = models[1]!.id;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert([
      { studio_id: studioA, name: "Upload-Uebung A", target_reps_min: 8, target_reps_max: 12 },
      { studio_id: studioB, name: "Upload-Uebung B", target_reps_min: 8, target_reps_max: 12 },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;

  const { data: links, error: linkError } = await admin
    .from("equipment_model_exercises")
    .insert([
      { equipment_model_id: modelA, exercise_id: exercises[0]!.id },
      { equipment_model_id: modelB, exercise_id: exercises[1]!.id },
    ])
    .select("id");
  if (linkError) throw linkError;
  linkA = links[0]!.id;
  linkB = links[1]!.id;
});

describe("uploadEquipmentPhoto", () => {
  it("positiv: legt das Foto im Studio-Ordner ab und traegt den Pfad am Modell ein", async () => {
    const client = await userClient(trainerA);

    const { storagePath } = await uploadEquipmentPhoto(client, {
      equipmentModelId: modelA,
      bytes: jpegMitExif(),
    });

    expect(storagePath.startsWith(`${studioA}/`)).toBe(true);

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_models")
      .select("photo_path")
      .eq("id", modelA)
      .single();
    expect(data?.photo_path).toBe(storagePath);
  });

  it("entfernt die Aufnahmedaten -- ein Geraetefoto traegt sonst GPS mit", async () => {
    const client = await userClient(trainerA);

    const { storagePath } = await uploadEquipmentPhoto(client, {
      equipmentModelId: modelA,
      bytes: jpegMitExif(),
    });

    const { data, error } = await client.storage.from(PHOTO_BUCKET).download(storagePath);
    expect(error).toBeNull();
    const gespeichert = new Uint8Array(await data!.arrayBuffer());

    // Weder der APP1-Marker noch die Exif-Kennung duerfen uebrig sein.
    const hatApp1 = gespeichert.some(
      (byte, index) => byte === 0xff && gespeichert[index + 1] === 0xe1,
    );
    expect(hatApp1).toBe(false);
    expect(Buffer.from(gespeichert).includes("Exif")).toBe(false);
    // Die Bilddaten selbst sind noch da.
    expect(Buffer.from(gespeichert).includes(Buffer.from([0xab, 0xcd, 0xef]))).toBe(true);
  });

  it("negativ: ein als JPEG deklariertes PDF wird abgewiesen", async () => {
    const client = await userClient(trainerA);
    const pdf = new Uint8Array([...ascii("%PDF-1.7"), 0x0a, 0x25, 0x00]);

    await expect(
      uploadEquipmentPhoto(client, { equipmentModelId: modelA, bytes: pdf }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: eine Datei ueber der Groessengrenze wird abgewiesen", async () => {
    const client = await userClient(trainerA);
    const zuGross = new Uint8Array(11 * 1024 * 1024);
    zuGross.set(jpegMitExif(), 0);

    await expect(
      uploadEquipmentPhoto(client, { equipmentModelId: modelA, bytes: zuGross }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein einfaches Mitglied laedt kein Foto hoch", async () => {
    const client = await userClient(memberA);

    await expect(
      uploadEquipmentPhoto(client, { equipmentModelId: modelA, bytes: jpegMitExif() }),
    ).rejects.toThrow();
  });

  it("cross-tenant: ein Modell aus Studio B ist fuer den Trainer aus A nicht auffindbar", async () => {
    const client = await userClient(trainerA);

    await expect(
      uploadEquipmentPhoto(client, { equipmentModelId: modelB, bytes: jpegMitExif() }),
    ).rejects.toThrow(DomainError);

    const admin = serviceClient();
    const { data } = await admin
      .from("equipment_models")
      .select("photo_path")
      .eq("id", modelB)
      .single();
    expect(data?.photo_path).toBeNull();
  });

  it("raeumt das vorige Foto weg -- sonst bleibt es unerreichbar im Bucket liegen", async () => {
    const client = await userClient(trainerA);

    const erstes = await uploadEquipmentPhoto(client, {
      equipmentModelId: modelA,
      bytes: jpegMitExif(),
    });
    const zweites = await uploadEquipmentPhoto(client, {
      equipmentModelId: modelA,
      bytes: jpegMitExif(),
    });
    expect(zweites.storagePath).not.toBe(erstes.storagePath);

    const { data } = await client.storage.from(PHOTO_BUCKET).download(erstes.storagePath);
    expect(data).toBeNull();
  });
});

describe("prepareInstructionVideoUpload", () => {
  it("positiv: liefert einen Pfad im Ordner des eigenen Studios", async () => {
    const client = await userClient(trainerA);

    const { bucket, storagePath } = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: linkA,
      sizeBytes: 1024,
    });

    expect(bucket).toBe(VIDEO_BUCKET);
    expect(storagePath.startsWith(`${studioA}/`)).toBe(true);
  });

  it("negativ: eine angekuendigte Groesse ueber der Grenze wird gar nicht erst begonnen", async () => {
    const client = await userClient(trainerA);

    await expect(
      prepareInstructionVideoUpload(client, {
        equipmentModelExerciseId: linkA,
        sizeBytes: 60 * 1024 * 1024,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("cross-tenant: eine Verknuepfung aus Studio B ist nicht auffindbar", async () => {
    const client = await userClient(trainerA);

    await expect(
      prepareInstructionVideoUpload(client, {
        equipmentModelExerciseId: linkB,
        sizeBytes: 1024,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("negativ: ein einfaches Mitglied bekommt keinen Pfad", async () => {
    const client = await userClient(memberA);

    await expect(
      prepareInstructionVideoUpload(client, {
        equipmentModelExerciseId: linkA,
        sizeBytes: 1024,
      }),
    ).rejects.toThrow(DomainError);
  });
});

describe("confirmInstructionVideo", () => {
  it("positiv: traegt das Video mit der aus der Datei gelesenen Dauer ein", async () => {
    const client = await userClient(trainerA);
    const { storagePath } = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: linkA,
      sizeBytes: 1024,
    });
    await uploadRaw(trainerA, VIDEO_BUCKET, storagePath, mp4MitDauer(30), "video/mp4");

    const ergebnis = await confirmInstructionVideo(client, {
      equipmentModelExerciseId: linkA,
      storagePath,
    });

    expect(ergebnis.durationS).toBe(30);

    const admin = serviceClient();
    const { data } = await admin
      .from("instruction_assets")
      .select("id, duration_s, storage_path")
      .eq("id", ergebnis.instructionAssetId)
      .single();
    expect(data?.duration_s).toBe(30);
    expect(data?.storage_path).toBe(storagePath);
  });

  it("negativ: ein zu langes Video wird abgewiesen und das Objekt entfernt", async () => {
    const client = await userClient(trainerA);
    const { storagePath } = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: linkA,
      sizeBytes: 1024,
    });
    await uploadRaw(trainerA, VIDEO_BUCKET, storagePath, mp4MitDauer(50), "video/mp4");

    await expect(
      confirmInstructionVideo(client, {
        equipmentModelExerciseId: linkA,
        storagePath,
      }),
    ).rejects.toThrow(DomainError);

    // Kein Waisenobjekt: was nicht eingetragen wird, bleibt auch nicht liegen.
    const { data } = await client.storage.from(VIDEO_BUCKET).download(storagePath);
    expect(data).toBeNull();

    const admin = serviceClient();
    const { data: zeilen } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("storage_path", storagePath);
    expect(zeilen).toEqual([]);
  });

  it("negativ: ein als Video hochgeladenes Bild wird abgewiesen und entfernt", async () => {
    const client = await userClient(trainerA);
    const { storagePath } = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: linkA,
      sizeBytes: 1024,
    });
    // Der Bucket glaubt dem Content-Type -- der Inhalt ist trotzdem ein JPEG.
    await uploadRaw(trainerA, VIDEO_BUCKET, storagePath, jpegMitExif(), "video/mp4");

    await expect(
      confirmInstructionVideo(client, {
        equipmentModelExerciseId: linkA,
        storagePath,
      }),
    ).rejects.toThrow(DomainError);

    const { data } = await client.storage.from(VIDEO_BUCKET).download(storagePath);
    expect(data).toBeNull();
  });

  it("ein zweiter Anlauf auf denselben Pfad legt keine zweite Zeile an", async () => {
    const client = await userClient(trainerA);
    const { storagePath } = await prepareInstructionVideoUpload(client, {
      equipmentModelExerciseId: linkA,
      sizeBytes: 1024,
    });
    await uploadRaw(trainerA, VIDEO_BUCKET, storagePath, mp4MitDauer(20), "video/mp4");

    const erst = await confirmInstructionVideo(client, {
      equipmentModelExerciseId: linkA,
      storagePath,
    });
    const nochmal = await confirmInstructionVideo(client, {
      equipmentModelExerciseId: linkA,
      storagePath,
    });
    expect(nochmal.instructionAssetId).toBe(erst.instructionAssetId);

    const admin = serviceClient();
    const { data } = await admin
      .from("instruction_assets")
      .select("id")
      .eq("equipment_model_exercise_id", linkA)
      .eq("storage_path", storagePath);
    expect(data).toHaveLength(1);
  });

  it("negativ: ein Pfad ohne hochgeladenes Objekt fuehrt zu keiner Zeile", async () => {
    const client = await userClient(trainerA);

    await expect(
      confirmInstructionVideo(client, {
        equipmentModelExerciseId: linkA,
        storagePath: `${studioA}/gibt-es-nicht.mp4`,
      }),
    ).rejects.toThrow(DomainError);
  });

  it("cross-tenant: ein Pfad ausserhalb des eigenen Studios wird abgewiesen", async () => {
    const client = await userClient(trainerA);

    await expect(
      confirmInstructionVideo(client, {
        equipmentModelExerciseId: linkA,
        storagePath: `${studioB}/fremdes-video.mp4`,
      }),
    ).rejects.toThrow(DomainError);
  });
});
