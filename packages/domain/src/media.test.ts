import { describe, expect, it } from "vitest";
import {
  MAX_PHOTO_BYTES,
  MAX_VIDEO_BYTES,
  MAX_VIDEO_SECONDS,
  readVideoDurationSeconds,
  sniffMediaType,
  stripImageMetadata,
} from "./media.js";

/** JPEG-Segment: Marker, Laenge (inkl. der zwei Laengenbytes), Nutzlast. */
function segment(marker: number, payload: number[]): number[] {
  const length = payload.length + 2;
  return [0xff, marker, (length >> 8) & 0xff, length & 0xff, ...payload];
}

function ascii(text: string): number[] {
  return [...text].map((character) => character.charCodeAt(0));
}

const SOI = [0xff, 0xd8];
const EOI = [0xff, 0xd9];
const JFIF = segment(0xe0, [...ascii("JFIF"), 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00]);
const DQT = segment(0xdb, [0x00, ...new Array(64).fill(0x10)]);
const EXIF = segment(0xe1, [...ascii("Exif"), 0x00, 0x00, ...ascii("MM"), 0x2a, 0xff, 0xfe]);
const XMP = segment(0xe1, [...ascii("http://ns.adobe.com/xap/1.0/"), 0x00, 0x3c, 0x78]);
const COMMENT = segment(0xfe, ascii("aufgenommen mit iPhone"));
/** Ab SOS bis EOI liegen die eigentlichen Bilddaten -- sie sind unantastbar. */
const SOS = segment(0xda, [0x01, 0x01, 0x00, 0x00, 0x3f, 0x00]);
const BILDDATEN = [0xab, 0xcd, 0xef, 0x12, 0x34];

function jpeg(...parts: number[][]): Uint8Array {
  return new Uint8Array(parts.flat());
}

const PNG_SIGNATUR = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];

/** PNG-Chunk: Laenge, Typ, Daten, CRC. Der CRC wird hier nicht geprueft. */
function chunk(type: string, data: number[] = []): number[] {
  const length = data.length;
  return [
    (length >>> 24) & 0xff,
    (length >>> 16) & 0xff,
    (length >>> 8) & 0xff,
    length & 0xff,
    ...ascii(type),
    ...data,
    0xde, 0xad, 0xbe, 0xef,
  ];
}

function png(...chunks: number[][]): Uint8Array {
  return new Uint8Array([...PNG_SIGNATUR, ...chunks.flat()]);
}

describe("sniffMediaType", () => {
  it("erkennt ein JPEG am SOI-Marker", () => {
    expect(sniffMediaType(jpeg(SOI, JFIF, SOS, BILDDATEN, EOI))).toBe("image/jpeg");
  });

  it("erkennt ein PNG an der Signatur", () => {
    expect(sniffMediaType(png(chunk("IHDR", new Array(13).fill(0))))).toBe("image/png");
  });

  it("erkennt ein MP4 an der ftyp-Box", () => {
    const bytes = new Uint8Array([
      0x00, 0x00, 0x00, 0x18, ...ascii("ftyp"), ...ascii("isom"),
      0x00, 0x00, 0x02, 0x00, ...ascii("isomiso2"),
    ]);
    expect(sniffMediaType(bytes)).toBe("video/mp4");
  });

  it("erkennt eine QuickTime-Aufnahme -- so nimmt das iPhone auf", () => {
    const bytes = new Uint8Array([
      0x00, 0x00, 0x00, 0x14, ...ascii("ftyp"), ...ascii("qt  "),
      0x00, 0x00, 0x00, 0x00, ...ascii("qt  "),
    ]);
    expect(sniffMediaType(bytes)).toBe("video/quicktime");
  });

  it("erkennt ein als JPEG deklariertes PDF nicht als Bild", () => {
    // Der Kern der serverseitigen Pruefung: die Bucket-Grenze glaubt dem
    // Content-Type des Clients, diese Funktion nur den Bytes.
    const bytes = new Uint8Array([...ascii("%PDF-1.7"), 0x0a, 0x25]);
    expect(sniffMediaType(bytes)).toBeNull();
  });

  it("liefert null bei einem zu kurzen Puffer", () => {
    expect(sniffMediaType(new Uint8Array([0xff]))).toBeNull();
    expect(sniffMediaType(new Uint8Array())).toBeNull();
  });

  it("liefert null bei einer ftyp-Box mit unbekannter Marke", () => {
    const bytes = new Uint8Array([
      0x00, 0x00, 0x00, 0x14, ...ascii("ftyp"), ...ascii("crx "),
      0x00, 0x00, 0x00, 0x00, ...ascii("crx "),
    ]);
    expect(sniffMediaType(bytes)).toBeNull();
  });
});

describe("stripImageMetadata bei JPEG", () => {
  it("entfernt das Exif-Segment", () => {
    const eingabe = jpeg(SOI, JFIF, EXIF, DQT, SOS, BILDDATEN, EOI);
    const ausgabe = stripImageMetadata(eingabe);

    expect(ausgabe.length).toBeLessThan(eingabe.length);
    expect([...ausgabe]).toEqual([...jpeg(SOI, JFIF, DQT, SOS, BILDDATEN, EOI)]);
  });

  it("entfernt auch XMP und einen Kommentar", () => {
    const eingabe = jpeg(SOI, JFIF, XMP, COMMENT, DQT, SOS, BILDDATEN, EOI);
    const ausgabe = stripImageMetadata(eingabe);

    expect([...ausgabe]).toEqual([...jpeg(SOI, JFIF, DQT, SOS, BILDDATEN, EOI)]);
  });

  it("laesst die Bilddaten ab SOS unveraendert", () => {
    const eingabe = jpeg(SOI, EXIF, DQT, SOS, BILDDATEN, EOI);
    const ausgabe = stripImageMetadata(eingabe);

    const sosIndex = [...ausgabe].findIndex(
      (byte, index) => byte === 0xff && ausgabe[index + 1] === 0xda,
    );
    expect([...ausgabe.slice(sosIndex)]).toEqual([...SOS, ...BILDDATEN, ...EOI]);
  });

  it("laesst ein JPEG ohne Metadaten unveraendert", () => {
    const eingabe = jpeg(SOI, JFIF, DQT, SOS, BILDDATEN, EOI);
    expect([...stripImageMetadata(eingabe)]).toEqual([...eingabe]);
  });

  it("behaelt das JFIF-Segment -- es traegt keine Aufnahmedaten", () => {
    const ausgabe = stripImageMetadata(jpeg(SOI, JFIF, EXIF, SOS, BILDDATEN, EOI));
    expect(sniffMediaType(ausgabe)).toBe("image/jpeg");
    expect([...ausgabe]).toContain(0xe0);
  });

  /**
   * Die Groesse eines echten Handyfotos, nicht die eines Testrumpfs.
   *
   * Bis hierher lief jeder Test dieser Datei mit ein paar Dutzend Bytes --
   * und deshalb blieb unbemerkt, dass die Bilddaten per Spread in ein
   * number[] geschoben wurden. Ab etwa einem halben Megabyte sprengt das
   * den Aufrufstapel, und zwar bei JEDEM Foto aus einer Kamera.
   */
  it("vertraegt ein Foto in Handygroesse", () => {
    const nutzlast = new Array(3 * 1024 * 1024).fill(0x7a);
    const eingabe = jpeg(SOI, JFIF, EXIF, SOS, nutzlast, EOI);

    const ausgabe = stripImageMetadata(eingabe);

    expect(sniffMediaType(ausgabe)).toBe("image/jpeg");
    // Das Exif-Segment ist weg, die Bilddaten sind vollstaendig da.
    expect(ausgabe.byteLength).toBe(eingabe.byteLength - EXIF.length);
    expect(ausgabe.at(-2)).toBe(0xff);
    expect(ausgabe.at(-1)).toBe(0xd9);
  });
});

describe("stripImageMetadata bei PNG", () => {
  it("entfernt den eXIf-Chunk", () => {
    const ihdr = chunk("IHDR", new Array(13).fill(0));
    const idat = chunk("IDAT", [0x78, 0x9c, 0x01]);
    const iend = chunk("IEND");
    const eingabe = png(ihdr, chunk("eXIf", [0x4d, 0x4d, 0x00, 0x2a]), idat, iend);

    expect([...stripImageMetadata(eingabe)]).toEqual([...png(ihdr, idat, iend)]);
  });

  it("entfernt Textchunks und den Zeitstempel", () => {
    const ihdr = chunk("IHDR", new Array(13).fill(0));
    const idat = chunk("IDAT", [0x78, 0x9c, 0x01]);
    const iend = chunk("IEND");
    const eingabe = png(
      ihdr,
      chunk("tEXt", ascii("Author\0Trainer")),
      chunk("iTXt", ascii("XML")),
      chunk("tIME", [0x07, 0xe6, 0x08, 0x1f, 0x0c, 0x00, 0x00]),
      idat,
      iend,
    );

    expect([...stripImageMetadata(eingabe)]).toEqual([...png(ihdr, idat, iend)]);
  });

  it("laesst ein PNG ohne Metadaten unveraendert", () => {
    const eingabe = png(
      chunk("IHDR", new Array(13).fill(0)),
      chunk("IDAT", [0x78, 0x9c, 0x01]),
      chunk("IEND"),
    );
    expect([...stripImageMetadata(eingabe)]).toEqual([...eingabe]);
  });

  /** Dieselbe Groessenfalle wie beim JPEG: ein IDAT ist megabytegross. */
  it("vertraegt ein PNG in Handygroesse", () => {
    const ihdr = chunk("IHDR", new Array(13).fill(0));
    const idat = chunk("IDAT", new Array(3 * 1024 * 1024).fill(0x7a));
    const iend = chunk("IEND");
    const eingabe = png(ihdr, chunk("tEXt", ascii("Kamera")), idat, iend);

    const ausgabe = stripImageMetadata(eingabe);

    expect(sniffMediaType(ausgabe)).toBe("image/png");
    expect(ausgabe.byteLength).toBe(png(ihdr, idat, iend).byteLength);
  });
});

/** ISO-BMFF-Box: Groesse (inkl. Kopf), Typ, Nutzlast. */
function box(type: string, payload: number[]): number[] {
  const size = payload.length + 8;
  return [
    (size >>> 24) & 0xff,
    (size >>> 16) & 0xff,
    (size >>> 8) & 0xff,
    size & 0xff,
    ...ascii(type),
    ...payload,
  ];
}

function uint32(value: number): number[] {
  return [
    (value >>> 24) & 0xff,
    (value >>> 16) & 0xff,
    (value >>> 8) & 0xff,
    value & 0xff,
  ];
}

/** mvhd Version 0: Zeitbasis und Dauer stehen als 32-Bit-Werte. */
function mvhdV0(timescale: number, duration: number): number[] {
  return box("mvhd", [
    0x00, 0x00, 0x00, 0x00,
    ...uint32(0), ...uint32(0),
    ...uint32(timescale), ...uint32(duration),
    ...new Array(80).fill(0),
  ]);
}

/** mvhd Version 1: Zeitstempel und Dauer sind 64 Bit breit. */
function mvhdV1(timescale: number, duration: number): number[] {
  return box("mvhd", [
    0x01, 0x00, 0x00, 0x00,
    ...new Array(8).fill(0), ...new Array(8).fill(0),
    ...uint32(timescale),
    ...uint32(0), ...uint32(duration),
    ...new Array(80).fill(0),
  ]);
}

const FTYP = box("ftyp", [...ascii("isom"), ...uint32(512), ...ascii("isomiso2")]);

describe("readVideoDurationSeconds", () => {
  it("liest die Dauer aus der mvhd-Box", () => {
    const bytes = new Uint8Array([...FTYP, ...box("moov", mvhdV0(600, 600 * 30))]);
    expect(readVideoDurationSeconds(bytes)).toBe(30);
  });

  it("liest auch eine mvhd-Box in Version 1", () => {
    const bytes = new Uint8Array([...FTYP, ...box("moov", mvhdV1(1000, 1000 * 42))]);
    expect(readVideoDurationSeconds(bytes)).toBe(42);
  });

  it("findet moov auch hinter den Mediendaten -- so schreibt das iPhone", () => {
    const bytes = new Uint8Array([
      ...FTYP,
      ...box("mdat", new Array(256).fill(0x11)),
      ...box("moov", mvhdV0(600, 600 * 12)),
    ]);
    expect(readVideoDurationSeconds(bytes)).toBe(12);
  });

  it("rundet auf ganze Sekunden auf -- 45,4 s sind mehr als 45 s", () => {
    const bytes = new Uint8Array([...FTYP, ...box("moov", mvhdV0(1000, 45_400))]);
    expect(readVideoDurationSeconds(bytes)).toBe(46);
  });

  it("liefert null, wenn keine mvhd-Box da ist", () => {
    const bytes = new Uint8Array([...FTYP, ...box("mdat", new Array(32).fill(0))]);
    expect(readVideoDurationSeconds(bytes)).toBeNull();
  });

  it("liefert null bei einer Zeitbasis von null -- sonst waere die Dauer unendlich", () => {
    const bytes = new Uint8Array([...FTYP, ...box("moov", mvhdV0(0, 1000))]);
    expect(readVideoDurationSeconds(bytes)).toBeNull();
  });

  it("liefert null statt in eine abgeschnittene Datei zu laufen", () => {
    const vollstaendig = new Uint8Array([
      ...FTYP,
      ...box("moov", mvhdV0(600, 600 * 30)),
    ]);
    expect(readVideoDurationSeconds(vollstaendig.slice(0, 20))).toBeNull();
  });
});

describe("Formatgrenzen", () => {
  it("stehen an einer Stelle und passen zu den Buckets aus 0020", () => {
    expect(MAX_PHOTO_BYTES).toBe(10 * 1024 * 1024);
    expect(MAX_VIDEO_BYTES).toBe(50 * 1024 * 1024);
    expect(MAX_VIDEO_SECONDS).toBe(45);
  });
});
