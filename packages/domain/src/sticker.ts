/// <reference path="./svg-to-pdfkit.d.ts" />
import PDFDocument from "pdfkit";
import QRCode from "qrcode";
import SVGtoPDF from "svg-to-pdfkit";

/**
 * Macht aus der Sticker-Vorlage des Designpakets (assets/branding/sticker)
 * einen Sticker fuer genau eine Tag-URL. Die Vorlage traegt einen Muster-QR;
 * nur dieser Block wird ersetzt, damit Layout und Schrift beim Designer bleiben.
 */

export const STICKER_MM = 50;
const PT_JE_MM = 72 / 25.4;

// Lage des Muster-QR in der Vorlage (viewBox 0..1000 = 50 mm).
const MUSTER =
  /<svg x="70" y="250" width="490" height="490" viewBox="0 0 33 33">([\s\S]*?)<\/svg>/;
const QR_X = 70;
const QR_Y = 250;
const QR_BREITE = 490;
// Muster: Version 2 (25 Module) plus 4 Module Ruhezone je Seite.
const MUSTER_RASTER = 33;
const RUHEZONE = 4;
// Logo-Feld im Muster-Raster; es waechst mit dem Raster, damit es gleich gross bleibt.
const LOGO_VON = 13.5;
const LOGO_BIS = 19.5;
// Ab Version 7 liegt ein Ausrichtungsmuster in der Mitte; das Logo wuerde es
// verdecken. Die Basis-URL darf darum hoechstens Version 6 ergeben.
const MAX_VERSION = 6;
// Unter 0,4 mm Kantenlaenge lesen Handykameras aus Armlaenge unzuverlaessig.
const MIN_MODUL_MM = 0.4;

// svg-to-pdfkit wertet clip-path nicht aus; das Band fehlte in der PDF.
const BAND_MIT_CLIP =
  /<g clip-path="url\(#tag-outline\)"><rect x="0" y="790" width="1000" height="210" fill="#D4FF3F"\/><\/g>/;
const BAND_ALS_PFAD =
  '<path d="M0 790H1000V920A80 80 0 0 1 920 1000H80A80 80 0 0 1 0 920Z" fill="#D4FF3F"/>';

const DUNKEL = "#0A0B0D";
const HELL = "#F2F4F7";

export function stickerSvg(
  vorlage: string,
  url: string,
): { svg: string; version: number; modulMm: number } {
  const muster = vorlage.match(MUSTER);
  if (!muster) throw new Error("Vorlage ohne Muster-QR-Block: Sticker-Vorlage pruefen.");
  if (!BAND_MIT_CLIP.test(vorlage)) {
    throw new Error("Vorlage ohne gruenes Band: Sticker-Vorlage pruefen.");
  }
  const innen = muster[1]!;
  const logoStart = innen.indexOf(`<rect x="${LOGO_VON}"`);
  // Sonst bliebe ein leeres Feld in der Mitte, und der Code laese sich trotzdem.
  if (logoStart < 0) throw new Error("Logo im Muster-QR nicht gefunden: Sticker-Vorlage pruefen.");
  const logo = innen.slice(logoStart);

  const qr = QRCode.create(url, { errorCorrectionLevel: "H" });
  const n = qr.modules.size;
  const raster = n + 2 * RUHEZONE;
  const modulMm = (QR_BREITE / raster) * (STICKER_MM / 1000);
  if (modulMm < MIN_MODUL_MM) {
    throw new Error(
      `QR-Modul ${modulMm.toFixed(2)} mm, mindestens 0,4 mm noetig: kuerzere Basis-URL waehlen.`,
    );
  }

  if (qr.version > MAX_VERSION) {
    throw new Error(
      `QR-Version ${qr.version}: ab Version 7 verdeckt das Logo ein Ausrichtungsmuster, kuerzere Basis-URL waehlen.`,
    );
  }

  const faktor = raster / MUSTER_RASTER;
  const logoVon = LOGO_VON * faktor;
  const logoBis = LOGO_BIS * faktor;
  const imFinder = (r: number, c: number) =>
    (r < 7 && c < 7) || (r < 7 && c >= n - 7) || (r >= n - 7 && c < 7);

  const teile = [`<rect width="${raster}" height="${raster}" rx="${2 * faktor}" fill="${HELL}"/>`];
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      if (!qr.modules.get(r, c) || imFinder(r, c)) continue;
      const x = c + RUHEZONE;
      const y = r + RUHEZONE;
      if (x + 1 > logoVon && x < logoBis && y + 1 > logoVon && y < logoBis) continue;
      // Wie im Muster: Takt- und Ausrichtungsmuster fast eckig, Daten rund.
      const rx = qr.modules.isReserved(r, c) ? 0.08 : 0.27;
      teile.push(`<rect x="${x}" y="${y}" width="1" height="1" rx="${rx}" fill="${DUNKEL}"/>`);
    }
  }
  for (const [x, y] of [
    [RUHEZONE, RUHEZONE],
    [RUHEZONE + n - 7, RUHEZONE],
    [RUHEZONE, RUHEZONE + n - 7],
  ] as const) {
    teile.push(
      `<rect x="${x}" y="${y}" width="7" height="7" rx="1.2" fill="${DUNKEL}"/>` +
        `<rect x="${x + 1}" y="${y + 1}" width="5" height="5" rx=".65" fill="${HELL}"/>` +
        `<rect x="${x + 2}" y="${y + 2}" width="3" height="3" rx=".55" fill="${DUNKEL}"/>`,
    );
  }
  teile.push(`<g transform="scale(${faktor})">${logo}</g>`);

  // Gruppe statt verschachteltem <svg>: robuster in PDF-Renderern.
  const gruppe = `<g transform="translate(${QR_X} ${QR_Y}) scale(${QR_BREITE / raster})">${teile.join("")}</g>`;
  const svg = vorlage
    .replace(MUSTER, gruppe)
    .replace(BAND_MIT_CLIP, BAND_ALS_PFAD)
    .replace(/<title>[^<]*<\/title>/, "<title>GYMTAVO NFC/QR-Tag 50 x 50 mm</title>");
  return { svg, version: qr.version, modulMm };
}

export async function stickerPdf(svgs: string[]): Promise<Buffer> {
  const kante = STICKER_MM * PT_JE_MM;
  const doc = new PDFDocument({ size: [kante, kante], margin: 0, autoFirstPage: false });
  const teile: Buffer[] = [];
  doc.on("data", (teil: Buffer) => teile.push(teil));
  const fertig = new Promise<void>((resolve) => doc.on("end", () => resolve()));
  for (const svg of svgs) {
    doc.addPage();
    SVGtoPDF(doc, svg, 0, 0, { width: kante, height: kante });
  }
  doc.end();
  await fertig;
  return Buffer.concat(teile);
}
