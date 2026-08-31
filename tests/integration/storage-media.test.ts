import { beforeAll, describe, expect, it } from "vitest";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Zwei private Buckets, nach Studio-Ordner getrennt. Der erste Pfadabschnitt
// ist die studio_id -- daran haengt die gesamte Mandantentrennung im Storage.
// Videos zeigen Menschen: das sind Personendaten des Trainers (Spec 6.8),
// deshalb privat und nur ueber kurzlebige signierte URLs.

const PHOTOS = "equipment-photos";
const VIDEOS = "instruction-videos";

let studioA: string;
let studioB: string;
let trainerA: string;
let memberA: string;
let memberB: string;

/** Kleinstes gueltiges JPEG -- SOI, APP0/JFIF, EOI. */
function jpegBytes(padding = 0): Blob {
  const head = [
    0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10, 0x4a, 0x46, 0x49, 0x46, 0x00, 0x01,
    0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00,
  ];
  const tail = [0xff, 0xd9];
  const bytes = new Uint8Array([...head, ...new Array(padding).fill(0), ...tail]);
  return new Blob([bytes], { type: "image/jpeg" });
}

/** Minimaler MP4-Rumpf: ftyp-Box mit Marke isom. */
function mp4Bytes(): Blob {
  const bytes = new Uint8Array([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x69, 0x73, 0x6f, 0x6d,
    0x00, 0x00, 0x02, 0x00, 0x69, 0x73, 0x6f, 0x6d, 0x69, 0x73, 0x6f, 0x32,
  ]);
  return new Blob([bytes], { type: "video/mp4" });
}

/** Eindeutiger Objektname je Testfall -- Uploads bleiben liegen. */
function objectName(studioId: string, suffix: string): string {
  return `${studioId}/${crypto.randomUUID()}.${suffix}`;
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "Medien-Studio A" }, { name: "Medien-Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("medien-trainer-a");
  memberA = uniqueEmail("medien-member-a");
  memberB = uniqueEmail("medien-member-b");

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: await createTestUser(trainerA), role: "trainer" },
      { studio_id: studioA, user_id: await createTestUser(memberA), role: "member" },
      { studio_id: studioB, user_id: await createTestUser(memberB), role: "member" },
    ]);
  if (membershipError) throw membershipError;
});

describe("Storage-Buckets", () => {
  it("beide Buckets sind privat -- Videos zeigen Menschen", async () => {
    const admin = serviceClient();
    const { data, error } = await admin.storage.listBuckets();
    expect(error).toBeNull();

    const photos = data?.find((bucket) => bucket.name === PHOTOS);
    const videos = data?.find((bucket) => bucket.name === VIDEOS);
    expect(photos?.public).toBe(false);
    expect(videos?.public).toBe(false);
  });
});

describe("Storage-Policies auf equipment-photos", () => {
  it("positiv: der Trainer laedt ein Foto in den Ordner seines Studios", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioA, "jpg");

    const { error } = await client.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(error).toBeNull();
  });

  it("negativ: ein einfaches Mitglied laedt kein Foto hoch", async () => {
    const client = await userClient(memberA);
    const name = objectName(studioA, "jpg");

    const { error } = await client.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: der Trainer aus A laedt nicht in den Ordner von Studio B", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioB, "jpg");

    const { error } = await client.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(error).not.toBeNull();
  });

  it("negativ: ein Objekt ausserhalb jedes Studio-Ordners ist nicht ablegbar", async () => {
    const client = await userClient(trainerA);

    const { error } = await client.storage
      .from(PHOTOS)
      .upload(`lose-datei-${crypto.randomUUID()}.jpg`, jpegBytes(), {
        contentType: "image/jpeg",
      });
    expect(error).not.toBeNull();
  });

  it("positiv: ein Mitglied desselben Studios bekommt eine signierte URL", async () => {
    const trainer = await userClient(trainerA);
    const name = objectName(studioA, "jpg");
    const { error: uploadError } = await trainer.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(uploadError).toBeNull();

    const client = await userClient(memberA);
    const { data, error } = await client.storage
      .from(PHOTOS)
      .createSignedUrl(name, 60);
    expect(error).toBeNull();
    expect(data?.signedUrl).toContain(name);
  });

  it("cross-tenant: ein Mitglied aus Studio B bekommt keine signierte URL", async () => {
    const trainer = await userClient(trainerA);
    const name = objectName(studioA, "jpg");
    const { error: uploadError } = await trainer.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(uploadError).toBeNull();

    const client = await userClient(memberB);
    const { data, error } = await client.storage
      .from(PHOTOS)
      .createSignedUrl(name, 60);
    expect(error).not.toBeNull();
    expect(data).toBeNull();
  });

  it("negativ: ohne Anmeldung kein Zugriff", async () => {
    const trainer = await userClient(trainerA);
    const name = objectName(studioA, "jpg");
    const { error: uploadError } = await trainer.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(uploadError).toBeNull();

    const client = anonClient();
    const { error } = await client.storage.from(PHOTOS).createSignedUrl(name, 60);
    expect(error).not.toBeNull();
  });

  it("negativ: der oeffentliche Pfad liefert die Datei nicht aus", async () => {
    const trainer = await userClient(trainerA);
    const name = objectName(studioA, "jpg");
    const { error: uploadError } = await trainer.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(), { contentType: "image/jpeg" });
    expect(uploadError).toBeNull();

    const { data } = trainer.storage.from(PHOTOS).getPublicUrl(name);
    const response = await fetch(data.publicUrl);
    expect(response.ok).toBe(false);
  });

  it("negativ: ein nicht erlaubter Inhaltstyp wird abgewiesen", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioA, "pdf");

    const { error } = await client.storage
      .from(PHOTOS)
      .upload(
        name,
        new Blob([new Uint8Array([0x25, 0x50, 0x44, 0x46])], {
          type: "application/pdf",
        }),
        { contentType: "application/pdf" },
      );
    expect(error).not.toBeNull();
  });

  it("negativ: eine Datei ueber der Groessengrenze wird abgewiesen", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioA, "jpg");

    // 11 MiB -- der Foto-Bucket ist auf 10 MiB begrenzt.
    const { error } = await client.storage
      .from(PHOTOS)
      .upload(name, jpegBytes(11 * 1024 * 1024), { contentType: "image/jpeg" });
    expect(error).not.toBeNull();
  });
});

describe("Storage-Policies auf instruction-videos", () => {
  it("positiv: der Trainer laedt ein Video in den Ordner seines Studios", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioA, "mp4");

    const { error } = await client.storage
      .from(VIDEOS)
      .upload(name, mp4Bytes(), { contentType: "video/mp4" });
    expect(error).toBeNull();
  });

  it("negativ: ein einfaches Mitglied laedt kein Video hoch", async () => {
    const client = await userClient(memberA);
    const name = objectName(studioA, "mp4");

    const { error } = await client.storage
      .from(VIDEOS)
      .upload(name, mp4Bytes(), { contentType: "video/mp4" });
    expect(error).not.toBeNull();
  });

  it("cross-tenant: der Trainer aus A laedt nicht in den Ordner von Studio B", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioB, "mp4");

    const { error } = await client.storage
      .from(VIDEOS)
      .upload(name, mp4Bytes(), { contentType: "video/mp4" });
    expect(error).not.toBeNull();
  });

  it("positiv: ein Mitglied desselben Studios bekommt eine signierte URL", async () => {
    const trainer = await userClient(trainerA);
    const name = objectName(studioA, "mp4");
    const { error: uploadError } = await trainer.storage
      .from(VIDEOS)
      .upload(name, mp4Bytes(), { contentType: "video/mp4" });
    expect(uploadError).toBeNull();

    const client = await userClient(memberA);
    const { error } = await client.storage.from(VIDEOS).createSignedUrl(name, 60);
    expect(error).toBeNull();
  });

  it("cross-tenant: ein Mitglied aus Studio B bekommt keine signierte URL", async () => {
    const trainer = await userClient(trainerA);
    const name = objectName(studioA, "mp4");
    const { error: uploadError } = await trainer.storage
      .from(VIDEOS)
      .upload(name, mp4Bytes(), { contentType: "video/mp4" });
    expect(uploadError).toBeNull();

    const client = await userClient(memberB);
    const { error } = await client.storage.from(VIDEOS).createSignedUrl(name, 60);
    expect(error).not.toBeNull();
  });

  it("negativ: ein nicht erlaubter Inhaltstyp wird abgewiesen", async () => {
    const client = await userClient(trainerA);
    const name = objectName(studioA, "gif");

    const { error } = await client.storage
      .from(VIDEOS)
      .upload(name, new Blob([new Uint8Array(8)], { type: "image/gif" }), {
        contentType: "image/gif",
      });
    expect(error).not.toBeNull();
  });
});
