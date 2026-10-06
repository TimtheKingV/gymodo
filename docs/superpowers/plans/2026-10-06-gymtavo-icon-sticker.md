# GYMTAVO App-Icon und Sticker-Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das App-Icon „G.“ aus dem GYMTAVO-Gesamtpaket steckt in der iOS-App und im Web, und `pnpm tags charge:sticker` erzeugt aus einer Charge pro Tag einen druckfertigen 50-mm-Sticker mit dem echten Geraete-Link im QR.

**Architecture:** Die Paketdateien kommen unveraendert nach `assets/branding/`. iOS bekommt ein `AppIcon.appiconset` (eine 1024er-Datei, Xcode erzeugt die Groessen). Web nutzt die Next-Dateikonvention `app/icon.svg` und `app/apple-icon.png`. Der Sticker-Renderer ist eine reine Funktion in `@fitretro/domain/sticker`: Vorlage (SVG-Text) + URL -> SVG-Text; sie ersetzt den Muster-QR-Block der Vorlage durch einen echten QR (Fehlerkorrektur H, Logo in der Mitte, Modulstil der Vorlage). Das Betreiberwerkzeug `scripts/tags.ts` liest die Charge, ruft den Renderer und schreibt je Tag ein SVG und fuer die Charge eine mehrseitige PDF.

**Tech Stack:** `qrcode` (QR-Matrix inkl. Funktionsmodule), `pdfkit` + `svg-to-pdfkit` (Vektor-PDF), Tests mit `@resvg/resvg-js` + `jsqr` (rastern und zuruecklesen), Swift Testing, Playwright.

**Spec:** `~/Downloads/GYMTAVO-Gesamtpaket/*/README.md` (Designpaket vom 06.10.), `docs/branding/qr-nfc-design-status.md`, `docs/superpowers/specs/2026-09-01-tag-lieferung-design.md` §4 (Chargen).

## Global Constraints

- Paketdateien unveraendert uebernehmen; Aenderungen am Design passieren im Renderer, nicht in der Vorlage.
- QR-Inhalt ist exakt die URL aus `charge:csv`: `<basis ohne Schluss-/>/t/<token>`; NFC-Chip und QR tragen dieselbe URL.
- Keine Domain festschreiben: Basis kommt aus `--basis` oder `TAG_URL_BASE`, sonst Abbruch (wie `charge:csv`).
- Tokens erscheinen nie auf stdout (Regel aus `scripts/tags.ts`).
- Farben: Grund #0A0B0D, Hell #F2F4F7, Akzent #D4FF3F. Sticker 50 x 50 mm, Eckenradius 4 mm.
- Commits deutsch mit ae/oe/ue, ein Commit pro Aufgabe, Kommentare ASCII mit Begruendung.

## Review Focus

1. **Lange Basis-URL:** Eine laengere Domain hebt die QR-Version, die Module werden kleiner. Erwartet: Abbruch mit klarer Meldung, wenn ein Modul unter 0,4 mm faellt, statt still unlesbare Sticker. -> Aufgabe 3, Test `zuKleineModule`.
2. **Logo verdeckt Daten:** Mit Logo muss der Code trotzdem lesbar bleiben, bei jeder Version. -> Aufgabe 3, Test liest den gerasterten Sticker fuer kurze und lange URL zurueck.
3. **PDF-Renderer ohne clipPath:** `svg-to-pdfkit` ignoriert das `clip-path` des gruenen Bandes (im Spike: Band fehlte, Text schwarz auf schwarz). Erwartet: Band als eigener Pfad mit runden Ecken. -> Aufgabe 3, Test `keinClipPath`.
4. **Vorlage geaendert:** Findet der Renderer den Muster-Block nicht, darf er nicht die Vorlage unveraendert (mit Muster-QR) ausgeben. -> Aufgabe 3, Test `fremdeVorlage`.
5. **Verschrottete Charge:** `charge:sticker` auf eine verschrottete Charge waere Druck von toten Tokens. Erwartet: Abbruch. -> Aufgabe 4.

---

### Aufgabe 1: App-Icon in iOS

**Files:**
- Create: `assets/branding/app-icon/` (alle Dateien aus `02-App-Icons/`, inkl. `Lizenzen/`)
- Create: `apps/ios-member/FitnessMember/Assets.xcassets/AppIcon.appiconset/Contents.json`, `.../AppIcon.appiconset/AppIcon-1024.png` (= `GYMTAVO-App-Icon-1024.png`, deckend, ohne Alpha)
- Modify: `apps/ios-member/project.yml` (`ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`, Kommentar weg)
- Test: `apps/ios-member/FitnessMemberTests/MarkenAssetTests.swift`

- [ ] **Schritt 1: Roter Test** in `MarkenAssetTests`:

```swift
    // Ohne AppIcon zeigt der Home-Bildschirm das leere Standardsymbol, und
    // App Store Connect lehnt den Upload ab.
    @Test func appIconIstEingetragen() {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primaer = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        #expect(primaer?["CFBundleIconName"] as? String == "AppIcon")
    }
```

- [ ] **Schritt 2: Rot bestaetigen** (vorher `df -h /System/Volumes/Data` > 3 GB): `cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/MarkenAssetTests` -> FAIL.
- [ ] **Schritt 3: Katalog und Einstellung.** `Contents.json`:

```json
{
  "images" : [
    { "filename" : "AppIcon-1024.png", "idiom" : "universal", "platform" : "ios", "size" : "1024x1024" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
```

`project.yml`: Kommentar und `""` ersetzen durch `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`. Danach `xcodegen generate` (seit b217dc6 sauberer Diff).
- [ ] **Schritt 4: Gruen + volle iOS-Suite**, Sichtpruefung Home-Bildschirm im Simulator (Screenshot per `xcrun simctl io booted screenshot`).
- [ ] **Schritt 5: Commit** `feat(ios): App-Icon G. aus dem Gesamtpaket`.

### Aufgabe 2: Icon im Web

**Files:**
- Create: `apps/web/app/icon.svg` (= `GYMTAVO-App-Icon-Abgerundet.svg`, transparente Ecken wirken im Tab sauberer), `apps/web/app/apple-icon.png` (= `GYMTAVO-App-Icon-180.png`, iOS rundet selbst)
- Test: `e2e/wurzel.spec.ts`

- [ ] **Schritt 1: Roter Test** am Ende von `e2e/wurzel.spec.ts`:

```ts
test("Browsertab und Home-Bildschirm zeigen das G.-Icon", async ({ page, request }) => {
  await page.goto("/");
  for (const rel of ["icon", "apple-touch-icon"]) {
    const href = await page.locator(`link[rel="${rel}"]`).first().getAttribute("href");
    expect(href, rel).toBeTruthy();
    const antwort = await request.get(href!);
    expect(antwort.status(), rel).toBe(200);
  }
});
```

- [ ] **Schritt 2: Rot bestaetigen:** `pnpm test:e2e e2e/wurzel.spec.ts -g "G.-Icon"` -> FAIL (kein Link).
- [ ] **Schritt 3: Dateien ablegen** (Next erzeugt die `<link>`-Tags selbst).
- [ ] **Schritt 4: Gruen**, gleicher Befehl.
- [ ] **Schritt 5: Commit** `feat(web): G.-Icon als Favicon und Apple-Touch-Icon`.

### Aufgabe 3: Sticker-Renderer

**Files:**
- Create: `assets/branding/sticker/` (alle Dateien aus `03-NFC-QR-Tags/` inkl. `Lizenzen/`); Vorlage ist `GYMTAVO-NFC-QR-Tag-50x50mm-MUSTER.svg`
- Create: `packages/domain/src/sticker.ts`, `packages/domain/src/sticker.test.ts`
- Modify: `packages/domain/package.json` (Export `./sticker`, deps `qrcode`, `pdfkit`, `svg-to-pdfkit`; devDeps `@types/qrcode`, `@types/pdfkit`, `@resvg/resvg-js`, `jsqr`), `packages/domain/src/svg-to-pdfkit.d.ts`

**Interfaces:**
- Produces: `stickerSvg(vorlage: string, url: string): { svg: string; version: number; modulMm: number }`, `stickerPdf(svgs: string[]): Promise<Buffer>`, `STICKER_MM = 50`.

- [ ] **Schritt 1: Rote Tests** `sticker.test.ts`:

```ts
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
```

- [ ] **Schritt 2: Rot bestaetigen:** `pnpm --filter @fitretro/domain test sticker` -> FAIL (Modul fehlt).
- [ ] **Schritt 3: Umsetzung** `sticker.ts` (im Spike vom 06.10. so geprueft):

```ts
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
  if (!BAND_MIT_CLIP.test(vorlage)) throw new Error("Vorlage ohne gruenes Band: Sticker-Vorlage pruefen.");
  const innen = muster[1]!;
  const logo = innen.slice(innen.indexOf(`<rect x="${LOGO_VON}"`));

  const qr = QRCode.create(url, { errorCorrectionLevel: "H" });
  const n = qr.modules.size;
  const raster = n + 2 * RUHEZONE;
  const modulMm = (QR_BREITE / raster) * (STICKER_MM / 1000);
  if (modulMm < MIN_MODUL_MM) {
    throw new Error(
      `QR-Modul ${modulMm.toFixed(2)} mm, mindestens 0,4 mm noetig: kuerzere Basis-URL waehlen.`,
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
```

`svg-to-pdfkit.d.ts`:

```ts
declare module "svg-to-pdfkit" {
  const SVGtoPDF: (
    doc: PDFKit.PDFDocument,
    svg: string,
    x: number,
    y: number,
    optionen?: { width?: number; height?: number },
  ) => void;
  export default SVGtoPDF;
}
```

- [ ] **Schritt 4: Gruen** + `pnpm typecheck`; Sichtpruefung: ein erzeugtes SVG und die PDF (`qlmanage -t`) neben `Design-Uebersicht.png` legen.
- [ ] **Schritt 5: Commit** `feat(tags): Sticker-Renderer mit echtem QR aus der Designvorlage`.

### Aufgabe 4: Befehl `charge:sticker` und Doku

**Files:**
- Modify: `scripts/tags.ts` (neuer Fall, URL-Bau mit `charge:csv` teilen)
- Modify: `docs/branding/qr-nfc-design-status.md`, `assets/branding/README.md`

- [ ] **Schritt 1: Hilfetext und Fall.** Hilfe ergaenzen:

```
  charge:sticker      --code <text> [--basis <url>] [--ordner <pfad>]
```

`--ordner` in `parseArgs` aufnehmen. Basis-Pruefung aus `charge:csv` in `function basisUrl(values): string` ziehen und den URL-Bau in `function tagUrl(basis: string, token: string): string` (beide Faelle nutzen sie). Neuer Fall:

```ts
    case "charge:sticker": {
      const code = pflicht(values, "code");
      const basis = basisUrl(values);
      const { charge, zeilen } = await chargeZeilen(admin, code);
      // Verschrottete Tokens loest die Seite nicht mehr auf; Druck waere Muell.
      if (charge.scrappedAt) {
        throw new DomainError("validation_failed", `Charge ${charge.code} ist verschrottet.`);
      }
      const vorlage = readFileSync(STICKER_VORLAGE, "utf8");
      const ordner = values.ordner ?? `sticker-${charge.code}`;
      mkdirSync(ordner, { recursive: true });
      const svgs: string[] = [];
      let kleinstesModul = Infinity;
      for (const zeile of zeilen) {
        const { svg, modulMm } = stickerSvg(vorlage, tagUrl(basis, zeile.token));
        writeFileSync(join(ordner, `${charge.code}-${String(zeile.nummer).padStart(4, "0")}.svg`), svg, "utf8");
        svgs.push(svg);
        kleinstesModul = Math.min(kleinstesModul, modulMm);
      }
      writeFileSync(join(ordner, `${charge.code}.pdf`), await stickerPdf(svgs));
      console.log(
        `${svgs.length} Sticker nach ${ordner} geschrieben (QR-Modul ${kleinstesModul.toFixed(2)} mm). Vor dem Druck einen Probedruck mit Kamera und App pruefen.`,
      );
      return;
    }
```

`STICKER_VORLAGE = fileURLToPath(new URL("../assets/branding/sticker/GYMTAVO-NFC-QR-Tag-50x50mm-MUSTER.svg", import.meta.url))`. Pruefen, ob `chargeZeilen` das Feld `scrappedAt` am `charge` liefert (Typ `Charge`).
- [ ] **Schritt 2: Probelauf lokal:** `pnpm tags charge:anlegen --code PROBE-STICKER --sorte machine --menge 3` und `pnpm tags charge:sticker --code PROBE-STICKER --basis https://gymtavo.de --ordner <scratchpad>/sticker` -> 3 SVG + 1 PDF; eine Datei sichten; danach `pnpm tags charge:verschrotten --code PROBE-STICKER` und erneuter `charge:sticker` -> Abbruch.
- [ ] **Schritt 3: Doku.** `qr-nfc-design-status.md`: Stand 06.10., finale Vorlage liegt in `assets/branding/sticker/`, Generator-Aufruf, offene Punkte: Domain festlegen, Probedruck 50 mm mit iPhone-Kamera und App-Scanner, Beschnitt/Farbprofil nach Herstellervorgabe, NFC-Chips mit derselben URL aus `charge:csv` beschreiben. `assets/branding/README.md`: Abschnitte App-Icon und Sticker, „App-Icon bewusst nicht umgestellt“ streichen.
- [ ] **Schritt 4: Commit** `feat(tags): charge:sticker erzeugt druckfertige Sticker je Charge`.

### Aufgabe 5: Gesamtpruefung und PR-Entwurf

- [ ] `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `pnpm test:e2e e2e/wurzel.spec.ts`, volle iOS-Suite. Rote Laeufe gegen die Umgebungsfallen pruefen (Memory „Lokale Testumgebung: Fallen“).
- [ ] Bericht an Tim mit Screenshots (Home-Bildschirm, Favicon, Sticker); Push und PR erst nach Freigabe.

## Offen (nicht in diesem Plan)

- Endgueltige Domain fuer gedruckte Tags und Associated Domains; Bundle-ID `de.gymtaro.*`.
- Dunkle/getoente iOS-18-Iconvarianten (Paket liefert nur die Standardvariante).
