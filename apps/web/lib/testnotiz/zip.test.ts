import { describe, expect, it } from "vitest";
import { crc32, dosZeit, zipBauen } from "./zip";

const ZEIT = new Date(2026, 8, 21, 14, 12, 4); // 21.09.2026, 14:12:04

function text(inhalt: string): Uint8Array {
  return new TextEncoder().encode(inhalt);
}

/**
 * Liest die Zip so, wie ein entpackendes Werkzeug es tut: vom Abschlusssatz
 * ueber das zentrale Verzeichnis zu den lokalen Kopfsaetzen. Damit prueft der
 * Test die Versaetze wirklich und nicht nur die Bytes, die er selbst erwartet.
 */
function entpacken(zip: Uint8Array): { name: string; inhalt: string; crc: number }[] {
  const sicht = new DataView(zip.buffer, zip.byteOffset, zip.byteLength);
  const abschluss = zip.length - 22;
  expect(sicht.getUint32(abschluss, true)).toBe(0x06054b50);

  const anzahl = sicht.getUint16(abschluss + 10, true);
  let stelle = sicht.getUint32(abschluss + 16, true);
  const dekodierer = new TextDecoder();
  const dateien: { name: string; inhalt: string; crc: number }[] = [];

  for (let i = 0; i < anzahl; i += 1) {
    expect(sicht.getUint32(stelle, true)).toBe(0x02014b50);
    const crc = sicht.getUint32(stelle + 16, true);
    const groesse = sicht.getUint32(stelle + 24, true);
    const namenlaenge = sicht.getUint16(stelle + 28, true);
    const versatz = sicht.getUint32(stelle + 42, true);
    const name = dekodierer.decode(zip.subarray(stelle + 46, stelle + 46 + namenlaenge));

    expect(sicht.getUint32(versatz, true)).toBe(0x04034b50);
    const lokalName = sicht.getUint16(versatz + 26, true);
    const lokalZusatz = sicht.getUint16(versatz + 28, true);
    const start = versatz + 30 + lokalName + lokalZusatz;
    dateien.push({ name, crc, inhalt: dekodierer.decode(zip.subarray(start, start + groesse)) });

    stelle += 46 + namenlaenge;
  }
  return dateien;
}

describe("crc32", () => {
  it("trifft die bekannten Werte", () => {
    expect(crc32(text("123456789"))).toBe(0xcbf43926);
    expect(crc32(text(""))).toBe(0);
    expect(crc32(text("a"))).toBe(0xe8b7be43);
  });
});

describe("dosZeit", () => {
  it("packt Uhrzeit in Zweisekundenschritte und Jahre ab 1980", () => {
    const { zeit, datum } = dosZeit(ZEIT);
    expect(zeit >> 11).toBe(14);
    expect((zeit >> 5) & 0x3f).toBe(12);
    expect((zeit & 0x1f) * 2).toBe(4);
    expect((datum >> 9) + 1980).toBe(2026);
    expect((datum >> 5) & 0x0f).toBe(9);
    expect(datum & 0x1f).toBe(21);
  });

  it("klemmt, was vor 1980 liegt", () => {
    expect(dosZeit(new Date(1970, 0, 1))).toEqual({ zeit: 0, datum: (1 << 5) | 1 });
  });
});

describe("zipBauen", () => {
  it("legt jede Datei mit Name und Inhalt ab", () => {
    const zip = zipBauen(
      [
        { name: "2026-09-21-1412/sitzung.md", daten: text("# Testsitzung\n") },
        { name: "2026-09-21-1412/sitzung.json", daten: text('{"format":"gymodo.testnotiz/2"}') },
      ],
      ZEIT,
    );

    expect(entpacken(zip)).toEqual([
      { name: "2026-09-21-1412/sitzung.md", inhalt: "# Testsitzung\n", crc: crc32(text("# Testsitzung\n")) },
      {
        name: "2026-09-21-1412/sitzung.json",
        inhalt: '{"format":"gymodo.testnotiz/2"}',
        crc: crc32(text('{"format":"gymodo.testnotiz/2"}')),
      },
    ]);
  });

  it("haelt Rohbytes unveraendert -- store, nicht deflate", () => {
    const png = new Uint8Array([137, 80, 78, 71, 13, 10, 26, 10, 0, 255, 128]);
    const zip = zipBauen([{ name: "01-voll.png", daten: png }], ZEIT);
    const sicht = new DataView(zip.buffer);
    expect(sicht.getUint16(8, true)).toBe(0); // Verfahren 0 = store
    expect(sicht.getUint32(18, true)).toBe(png.length); // komprimiert
    expect(sicht.getUint32(22, true)).toBe(png.length); // unkomprimiert
    const start = 30 + sicht.getUint16(26, true);
    expect(Array.from(zip.subarray(start, start + png.length))).toEqual(Array.from(png));
  });

  it("meldet im Abschlusssatz die Zahl der Dateien", () => {
    const zip = zipBauen(
      [
        { name: "a.txt", daten: text("a") },
        { name: "b.txt", daten: text("b") },
        { name: "c.txt", daten: text("c") },
      ],
      ZEIT,
    );
    const sicht = new DataView(zip.buffer);
    expect(sicht.getUint16(zip.length - 12, true)).toBe(3);
  });

  it("kommt mit einer leeren Sitzung zurecht", () => {
    const zip = zipBauen([], ZEIT);
    expect(zip.length).toBe(22);
    expect(new DataView(zip.buffer).getUint32(0, true)).toBe(0x06054b50);
  });

  it("kodiert Namen als UTF-8 und setzt die Flagge dafuer", () => {
    const zip = zipBauen([{ name: "Größe/übung.txt", daten: text("x") }], ZEIT);
    expect(new DataView(zip.buffer).getUint16(6, true) & 0x0800).toBe(0x0800);
    expect(entpacken(zip)[0]?.name).toBe("Größe/übung.txt");
  });
});
