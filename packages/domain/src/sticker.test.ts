import { readFileSync } from "node:fs";
import { Resvg } from "@resvg/resvg-js";
import jsQR from "jsqr";
import { describe, expect, test } from "vitest";
import { stickerPdf, stickerSvg } from "./sticker.js";

const vorlage = readFileSync(
  new URL("../../../assets/branding/sticker/GYMTAVO-NFC-QR-Tag-50x50mm-MUSTER.svg", import.meta.url),
  "utf8",
);
const token = "AbCdEfGhIjKlMnOpQrStUv";

// Rastert in Druckaufloesung (600 dpi auf 50 mm) und liest den QR wie eine
// Kamera zurueck; ein Logo, das zu viele Datenmodule verdeckt, faellt hier auf.
function zuruecklesen(svg: string): string | undefined {
  const bild = new Resvg(svg, { fitTo: { mode: "width", value: 1181 } }).render();
  return jsQR(new Uint8ClampedArray(bild.pixels), bild.width, bild.height)?.data;
}

describe("stickerSvg", () => {
  test.each(["https://gymtavo.de", "https://gymodo-web.vercel.app"])(
    "der QR traegt die echte URL (%s)",
    (basis) => {
      const url = `${basis}/t/${token}`;
      expect(zuruecklesen(stickerSvg(vorlage, url).svg)).toBe(url);
    },
  );

  test("vom Muster bleibt nichts", () => {
    const { svg } = stickerSvg(vorlage, `https://gymtavo.de/t/${token}`);
    expect(svg).not.toContain('viewBox="0 0 33 33"');
    expect(svg).not.toContain("MUSTER");
  });

  test("keinClipPath: das gruene Band ist ein eigener Pfad", () => {
    const { svg } = stickerSvg(vorlage, `https://gymtavo.de/t/${token}`);
    expect(svg).not.toContain("clip-path=");
    expect(svg).toContain('fill="#D4FF3F"/>');
  });

  test("zuKleineModule: eine lange URL bricht ab statt unlesbar zu drucken", () => {
    const url = `https://${"x".repeat(120)}.de/t/${token}`;
    expect(() => stickerSvg(vorlage, url)).toThrow(/0,4 mm/);
  });

  // Ab Version 7 liegt ein Ausrichtungsmuster genau in der Mitte, unter dem Logo.
  test("ab QR-Version 7 bricht der Sticker ab", () => {
    const url = `https://${"x".repeat(26)}.de/t/${token}`;
    expect(() => stickerSvg(vorlage, url)).toThrow(/Version 7/);
  });

  test("die laengste erlaubte URL ist noch lesbar", () => {
    const url = `https://${"x".repeat(22)}.de/t/${token}`;
    const { svg, version } = stickerSvg(vorlage, url);
    expect(version).toBe(6);
    expect(zuruecklesen(svg)).toBe(url);
  });

  test("geaendertes Logo im Muster: kein Sticker ohne Logo", () => {
    const anders = vorlage.replace('<rect x="13.5"', '<rect x="13.6"');
    expect(() => stickerSvg(anders, `https://gymtavo.de/t/${token}`)).toThrow(/Logo/);
  });

  test("fremdeVorlage: ohne Muster-Block kein Sticker", () => {
    expect(() => stickerSvg("<svg/>", "https://gymtavo.de/t/x")).toThrow(/Muster-QR/);
  });
});

describe("stickerPdf", () => {
  test("eine Seite je Sticker, 50 x 50 mm", async () => {
    const { svg } = stickerSvg(vorlage, `https://gymtavo.de/t/${token}`);
    const pdf = (await stickerPdf([svg, svg])).toString("latin1");
    const seiten = pdf.match(/\/MediaBox \[0 0 141\.7\d* 141\.7\d*\]/g) ?? [];
    expect(seiten).toHaveLength(2);
  });
});
