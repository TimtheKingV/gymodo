import { DomainError } from "./errors.js";

/**
 * Formatpruefung und Metadatenentfernung fuer Studiomedien.
 *
 * Warum das hier steht und nicht im Bucket: die Grenzen in
 * 0020_media_buckets.sql pruefen den Content-Type, den der Client *behauptet*,
 * und die Bytegroesse. Beides ist mit einer Zeile curl gefaelscht. Spec 6.8
 * verlangt eine Pruefung "anhand des Inhalts" -- das kann nur jemand, der die
 * Bytes ansieht. Die Bucket-Grenze bleibt trotzdem sinnvoll: sie faengt den
 * Grossteil frueh ab, bevor 50 MiB durch die Leitung gehen.
 */

export const PHOTO_BUCKET = "equipment-photos";
export const VIDEO_BUCKET = "instruction-videos";

/** 10 MiB -- muss zur Bucket-Grenze in 0020 passen. */
export const MAX_PHOTO_BYTES = 10 * 1024 * 1024;
/** 50 MiB -- 45 s 720p HEVC liegen bei rund 25 MiB, der Rest ist Reserve. */
export const MAX_VIDEO_BYTES = 50 * 1024 * 1024;
/** Spec 6.8. Auch der Check-Constraint auf instruction_assets.duration_s. */
export const MAX_VIDEO_SECONDS = 45;

/**
 * Lebensdauer einer signierten Medien-URL: 15 Minuten.
 *
 * Lang genug, dass ein Mitglied waehrend seiner Saetze am Geraet nicht neu
 * laden muss, kurz genug, dass eine weitergegebene URL kein dauerhafter
 * Zugang zu Studioinhalten wird (Spec 6.8, Blueprint 10.5).
 */
export const MEDIA_URL_TTL_SECONDS = 900;

export type MediaKind =
  | "image/jpeg"
  | "image/png"
  | "video/mp4"
  | "video/quicktime";

const PNG_SIGNATURE = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/**
 * MP4-Marken, die AVPlayer und Safari abspielen. Das iPhone schreibt beim
 * Aufnehmen "qt  " (QuickTime), beim Teilen haeufig "isom" oder "mp42".
 */
const MP4_BRANDS = new Set([
  "isom", "iso2", "iso4", "iso5", "iso6", "mp41", "mp42", "avc1", "mmp4",
  "M4V ", "dash", "hvc1", "hev1",
]);

function readAscii(bytes: Uint8Array, start: number, length: number): string {
  let text = "";
  for (let i = start; i < start + length; i += 1) {
    text += String.fromCharCode(bytes[i]!);
  }
  return text;
}

function startsWith(bytes: Uint8Array, prefix: number[]): boolean {
  if (bytes.length < prefix.length) return false;
  return prefix.every((byte, index) => bytes[index] === byte);
}

/**
 * Erkennt den Typ an den Bytes, nicht am behaupteten Content-Type.
 * Liefert null fuer alles, was nicht auf die Whitelist gehoert -- ein als
 * Bild deklariertes PDF faellt hier durch.
 */
export function sniffMediaType(bytes: Uint8Array): MediaKind | null {
  if (startsWith(bytes, PNG_SIGNATURE)) return "image/png";

  // SOI plus der Beginn des ersten Segments. Nur FFD8 zu pruefen wuerde
  // zwei zufaellige Bytes ausreichen lassen.
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return "image/jpeg";
  }

  // ISO-BMFF: Boxgroesse, dann "ftyp", dann die Hauptmarke.
  if (bytes.length >= 12 && readAscii(bytes, 4, 4) === "ftyp") {
    const brand = readAscii(bytes, 8, 4);
    if (brand === "qt  ") return "video/quicktime";
    if (MP4_BRANDS.has(brand)) return "video/mp4";
  }

  return null;
}

function uint32At(bytes: Uint8Array, offset: number): number {
  return (
    ((bytes[offset]! << 24) >>> 0) +
    (bytes[offset + 1]! << 16) +
    (bytes[offset + 2]! << 8) +
    bytes[offset + 3]!
  );
}

/**
 * Sucht die mvhd-Box und rechnet Dauer/Zeitbasis in Sekunden um.
 *
 * Warum ueberhaupt selbst parsen: Spec 6.8 verlangt die 45-Sekunden-Grenze
 * serverseitig. Eine vom Browser mitgeschickte Dauer ist keine serverseitige
 * Pruefung -- sie ist eine Behauptung des Clients, so wie der Content-Type.
 * mvhd ist in jeder gueltigen MP4- und QuickTime-Datei vorgeschrieben.
 *
 * moov steht beim iPhone hinter den Mediendaten, deshalb wird ueber die
 * Boxkette gelaufen und nicht nur der Dateianfang angesehen.
 */
export function readVideoDurationSeconds(bytes: Uint8Array): number | null {
  const mvhd = findBox(bytes, 0, bytes.length, ["moov", "mvhd"]);
  if (mvhd === null) return null;

  const { start, end } = mvhd;
  const version = bytes[start];
  if (version === undefined) return null;

  // Version 0: 32-Bit-Zeitstempel, Version 1: 64-Bit. Danach folgen in
  // beiden Faellen Zeitbasis und Dauer.
  const timescaleOffset = version === 1 ? start + 4 + 16 : start + 4 + 8;
  const durationOffset = timescaleOffset + 4;
  const durationWidth = version === 1 ? 8 : 4;
  if (durationOffset + durationWidth > end) return null;

  const timescale = uint32At(bytes, timescaleOffset);
  if (timescale <= 0) return null;

  // Die oberen 32 Bit einer 64-Bit-Dauer sind bei 45 Sekunden immer null;
  // sie werden uebersprungen statt in einen unsicheren Number zu wandern.
  const duration =
    version === 1
      ? uint32At(bytes, durationOffset + 4)
      : uint32At(bytes, durationOffset);

  // Aufrunden: 45,4 Sekunden sind laenger als erlaubt, nicht genau erlaubt.
  return Math.ceil(duration / timescale);
}

/** Laeuft den Boxpfad ab und liefert die Nutzlastgrenzen der letzten Box. */
function findBox(
  bytes: Uint8Array,
  from: number,
  to: number,
  path: string[],
): { start: number; end: number } | null {
  const [gesucht, ...rest] = path;
  let index = from;

  while (index + 8 <= to) {
    let size = uint32At(bytes, index);
    let headerSize = 8;
    if (size === 1) {
      // 64-Bit-Groesse. Die oberen 32 Bit sind bei unseren Grenzen null.
      if (index + 16 > to) return null;
      size = uint32At(bytes, index + 12);
      headerSize = 16;
    } else if (size === 0) {
      size = to - index;
    }
    if (size < headerSize || index + size > to) return null;

    const type = readAscii(bytes, index + 4, 4);
    if (type === gesucht) {
      const start = index + headerSize;
      const end = index + size;
      if (rest.length === 0) return { start, end };
      return findBox(bytes, start, end, rest);
    }
    index += size;
  }

  return null;
}

/** JPEG-Segmente, die Aufnahmedaten tragen: APP1-APP15 (Exif, XMP) und COM. */
function isMetadataMarker(marker: number): boolean {
  return (marker >= 0xe1 && marker <= 0xef) || marker === 0xfe;
}

/**
 * Stuecke aneinanderhaengen, ohne sie je einzeln anzufassen.
 *
 * Der naheliegende Weg -- out.push(...bytes.slice(a, b)) -- reicht jedes
 * Byte als eigenes Argument weiter und sprengt ab etwa einem halben
 * Megabyte den Aufrufstapel. Das traf jedes Foto aus einer Kamera und blieb
 * unbemerkt, solange die Tests mit ein paar Dutzend Bytes liefen.
 */
function verbinde(stuecke: Uint8Array[]): Uint8Array<ArrayBuffer> {
  const laenge = stuecke.reduce((summe, stueck) => summe + stueck.byteLength, 0);
  const ergebnis = new Uint8Array(laenge);
  let versatz = 0;
  for (const stueck of stuecke) {
    ergebnis.set(stueck, versatz);
    versatz += stueck.byteLength;
  }
  return ergebnis;
}

function stripJpegMetadata(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const out: Uint8Array[] = [new Uint8Array([0xff, 0xd8])];
  let index = 2;

  while (index < bytes.length) {
    // Vor einem Marker duerfen beliebig viele Fuellbytes 0xFF stehen.
    if (bytes[index] !== 0xff) {
      throw new DomainError("validation_failed", "Das Bild ist beschaedigt.");
    }
    while (bytes[index] === 0xff && index + 1 < bytes.length) index += 1;
    const marker = bytes[index];
    if (marker === undefined) {
      throw new DomainError("validation_failed", "Das Bild ist beschaedigt.");
    }
    index += 1;

    // Ab SOS folgen die entropiecodierten Bilddaten. Sie werden nicht
    // zerlegt, sondern unveraendert uebernommen -- alles andere hiesse, das
    // Bild neu zu codieren, und genau das soll nicht passieren.
    if (marker === 0xda) {
      out.push(new Uint8Array([0xff, marker]), bytes.slice(index));
      return verbinde(out);
    }
    if (marker === 0xd9) {
      out.push(new Uint8Array([0xff, marker]));
      return verbinde(out);
    }
    // Markierungen ohne Laengenfeld.
    if (marker === 0x01 || (marker >= 0xd0 && marker <= 0xd7)) {
      out.push(new Uint8Array([0xff, marker]));
      continue;
    }

    const high = bytes[index];
    const low = bytes[index + 1];
    if (high === undefined || low === undefined) {
      throw new DomainError("validation_failed", "Das Bild ist beschaedigt.");
    }
    const length = (high << 8) | low;
    const end = index + length;
    if (length < 2 || end > bytes.length) {
      throw new DomainError("validation_failed", "Das Bild ist beschaedigt.");
    }

    if (!isMetadataMarker(marker)) {
      out.push(new Uint8Array([0xff, marker]), bytes.slice(index, end));
    }
    index = end;
  }

  return verbinde(out);
}

/** PNG-Chunks, die Aufnahmedaten tragen. */
const PNG_METADATA_CHUNKS = new Set(["eXIf", "tEXt", "zTXt", "iTXt", "tIME"]);

function stripPngMetadata(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const out: Uint8Array[] = [new Uint8Array(PNG_SIGNATURE)];
  let index = PNG_SIGNATURE.length;

  while (index + 8 <= bytes.length) {
    const length =
      (bytes[index]! << 24) |
      (bytes[index + 1]! << 16) |
      (bytes[index + 2]! << 8) |
      bytes[index + 3]!;
    const type = readAscii(bytes, index + 4, 4);
    const end = index + 12 + length;
    if (length < 0 || end > bytes.length) {
      throw new DomainError("validation_failed", "Das Bild ist beschaedigt.");
    }

    // Chunks werden byteweise uebernommen, deshalb bleibt ihre Pruefsumme
    // gueltig -- es wird nichts neu berechnet, nur weggelassen.
    if (!PNG_METADATA_CHUNKS.has(type)) {
      out.push(bytes.slice(index, end));
    }
    index = end;
    if (type === "IEND") break;
  }

  return verbinde(out);
}

/**
 * Entfernt Aufnahmedaten aus einem Bild, ohne es neu zu codieren.
 *
 * Ein Geraetefoto aus dem Trainerhandy traegt sonst GPS-Koordinaten,
 * Geraetenamen und Aufnahmezeit mit -- die Adresse des Studios und der
 * Tagesablauf des Trainers, in einer Datei, die jedes Mitglied abrufen darf.
 */
export function stripImageMetadata(bytes: Uint8Array): Uint8Array<ArrayBuffer> {
  const kind = sniffMediaType(bytes);
  if (kind === "image/jpeg") return stripJpegMetadata(bytes);
  if (kind === "image/png") return stripPngMetadata(bytes);
  throw new DomainError(
    "validation_failed",
    "Nur JPEG und PNG sind als Geraetefoto moeglich.",
  );
}
