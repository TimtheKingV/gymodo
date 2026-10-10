import { createHash } from "node:crypto";
import { GYMTAVO_STUDIO_ID, type KatalogDatei, type Pruefung } from "./katalog-datei.js";
import {
  MAX_PHOTO_BYTES,
  MAX_VIDEO_BYTES,
  PHOTO_BUCKET,
  VIDEO_BUCKET,
  readVideoDurationSeconds,
  sniffMediaType,
} from "./media.js";

/**
 * Fotos und Videos der Katalogdatei: lesen, am Inhalt pruefen, Storage-Pfad
 * bestimmen.
 *
 * Der Pfad enthaelt einen Hash des Inhalts. Eine geaenderte Datei bekommt so
 * einen neuen Pfad, statt eine alte zu ueberschreiben -- der Import loescht
 * und ueberschreibt nie, und eine App mit zwischengespeicherter URL bekommt
 * nie still den neuen Inhalt unter dem alten Namen.
 */

export type Medium = {
  datei: string;
  bucket: typeof PHOTO_BUCKET | typeof VIDEO_BUCKET;
  storagePath: string;
  contentType: "image/png" | "image/jpeg" | "video/mp4";
  bytes: Uint8Array;
};

export type Medien = { fotos: Map<string, Medium>; videos: Map<string, Medium> };

// "-" trennt Schluessel und Hash und kommt in Schluesseln nicht vor
// (^[a-z0-9_]+$). Damit ist kein Praefix der Anfang eines anderen: "bank-"
// trifft nie "bank_schraeg-...". Daran erkennt der Import seine eigenen
// Objekte und laesst im Portal hochgeladene in Ruhe.
export function fotoPraefix(key: string): string {
  return `${GYMTAVO_STUDIO_ID}/catalog/photos/${key}-`;
}

export function videoPraefix(key: string): string {
  return `${GYMTAVO_STUDIO_ID}/catalog/videos/${key}-`;
}

function kurzHash(bytes: Uint8Array): string {
  return createHash("sha256").update(bytes).digest("hex").slice(0, 8);
}

export function pruefeMedien(
  k: KatalogDatei,
  lies: (datei: string) => Uint8Array | null,
): Pruefung<Medien> {
  const fehler: string[] = [];
  const fotos = new Map<string, Medium>();
  const videos = new Map<string, Medium>();

  k.equipment.forEach((g, i) => {
    if (g.photo === null) return;
    const wo = `equipment[${i}] "${g.key}" photo "${g.photo}"`;
    const bytes = lies(g.photo);
    if (bytes === null) return void fehler.push(`${wo}: Datei fehlt`);
    const typ = sniffMediaType(bytes);
    if (typ !== "image/png" && typ !== "image/jpeg") return void fehler.push(`${wo}: ist kein PNG oder JPEG`);
    if (bytes.length > MAX_PHOTO_BYTES) return void fehler.push(`${wo}: ist groesser als 10 MiB`);
    const endung = typ === "image/png" ? "png" : "jpg";
    fotos.set(g.key, {
      datei: g.photo,
      bucket: PHOTO_BUCKET,
      storagePath: `${fotoPraefix(g.key)}${kurzHash(bytes)}.${endung}`,
      contentType: typ,
      bytes,
    });
  });

  k.exercises.forEach((u, i) => {
    if (u.video === null) return;
    const wo = `exercises[${i}] "${u.key}" video "${u.video.file}"`;
    const bytes = lies(u.video.file);
    if (bytes === null) return void fehler.push(`${wo}: Datei fehlt`);
    if (sniffMediaType(bytes) !== "video/mp4") return void fehler.push(`${wo}: ist kein MP4`);
    if (bytes.length > MAX_VIDEO_BYTES) return void fehler.push(`${wo}: ist groesser als 50 MiB`);
    // Die App zeigt die Laenge aus duration_s. Wo die Datei sie selbst
    // verraet, darf die Angabe nicht abweichen.
    const dauer = readVideoDurationSeconds(bytes);
    if (dauer !== null && dauer !== u.video.duration_s) {
      return void fehler.push(`${wo}: dauert ${dauer} s, angegeben sind ${u.video.duration_s} s`);
    }
    videos.set(u.key, {
      datei: u.video.file,
      bucket: VIDEO_BUCKET,
      storagePath: `${videoPraefix(u.key)}${kurzHash(bytes)}.mp4`,
      contentType: "video/mp4",
      bytes,
    });
  });

  return fehler.length > 0 ? { ok: false, fehler } : { ok: true, wert: { fotos, videos } };
}
