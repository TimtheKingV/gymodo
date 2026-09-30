import { describe, expect, it } from "vitest";
import {
  FORMAT_KENNUNG,
  PLATTFORM,
  type Eintrag,
  type Sitzung,
  sitzungJson,
} from "./format";
import { abschnitt, elementZeile, kopf, rendern } from "./markdown";

function sitzung(entries: Eintrag[]): Sitzung {
  return {
    format: FORMAT_KENNUNG,
    platform: PLATTFORM,
    session: {
      id: "2026-09-21-1412",
      startedAt: "2026-09-21T14:12:03+02:00",
      app: { bundleId: "gymodo.web.portal", version: "0.0.0", build: "dev", configuration: "Debug" },
      device: {
        model: "Chrome 143",
        os: "macOS",
        screen: { width: 1512, height: 858, scale: 2 },
      },
    },
    entries,
  };
}

function eintrag(teile: Partial<Eintrag> = {}): Eintrag {
  return {
    id: "8F0C2A4E-6B1D-4C3A-9E7F-1A2B3C4D5E6F",
    index: 1,
    createdAt: "2026-09-21T14:13:41+02:00",
    kind: "crop",
    screen: {
      name: "portal/[studioId]/geraete",
      file: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx",
      stack: ["apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx"],
      context: { studioId: "s_1" },
    },
    screenshot: "01-voll.png",
    crop: "01-ausschnitt.png",
    cropRect: {
      points: { x: 20, y: 412, width: 335, height: 96 },
      pixels: { x: 40, y: 824, width: 670, height: 192 },
    },
    element: null,
    note: "Das Gewicht wird abgeschnitten wenn 100,5",
    audio: null,
    transcript: null,
    runtime: { online: true, pendingWrites: 0, signedIn: true, studioId: "s_1" },
    log: [],
    ...teile,
  };
}

describe("kopf", () => {
  it("nennt Zeit, Bau und Browser", () => {
    expect(kopf(sitzung([]))).toBe(
      "# Testsitzung 2026-09-21 14:12 — gymodo Portal 0.0.0 (dev), Chrome 143, macOS",
    );
  });
});

describe("abschnitt", () => {
  it("Ueberschrift traegt Nummer, Uhrzeit, Art und Screen", () => {
    expect(abschnitt(eintrag()).split("\n")[0]).toBe(
      "## 1 · 14:13 · Ausschnitt · portal/[studioId]/geraete",
    );
  });

  it("Screen-Zeile traegt Pfad und sortierten Kontext", () => {
    const text = abschnitt(
      eintrag({
        screen: {
          name: "portal/[studioId]/geraete/[modelId]",
          file: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/page.tsx",
          stack: [],
          context: { studioId: "s_1", modelId: "m_2" },
        },
      }),
    );
    expect(text).toContain(
      "**Screen:** `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/page.tsx` (modelId m_2, studioId s_1)",
    );
  });

  it("ohne Screen sagt der Abschnitt das ausdruecklich", () => {
    const text = abschnitt(eintrag({ screen: null }));
    expect(text).toContain("**Screen:** unbekannt — kein Screen hat sich gemeldet");
    expect(text.split("\n")[0]).toBe("## 1 · 14:13 · Ausschnitt · unbekannter Screen");
  });

  it("Ebenen erst ab zwei, mit Ordnernamen statt page.tsx", () => {
    const eine = abschnitt(eintrag());
    expect(eine).not.toContain("**Ebenen:**");

    const zwei = abschnitt(
      eintrag({
        screen: {
          name: "portal/[studioId]/geraete",
          file: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx",
          stack: [
            "apps/web/app/layout.tsx",
            "apps/web/app/portal/[studioId]/(schreibtisch)/layout.tsx",
            "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx",
          ],
          context: {},
        },
      }),
    );
    expect(zwei).toContain("**Ebenen:** app/layout → [studioId]/layout → geraete");
  });

  it("Ausschnitt steht vor dem Vollbild", () => {
    expect(abschnitt(eintrag())).toContain("![Ausschnitt](01-ausschnitt.png)\n![Vollbild](01-voll.png)");
  });

  it("ohne Ausschnitt nur das Vollbild", () => {
    const text = abschnitt(eintrag({ crop: null }));
    expect(text).toContain("![Vollbild](01-voll.png)");
    expect(text).not.toContain("![Ausschnitt]");
  });

  it("Protokoll steht in einem Details-Block", () => {
    const text = abschnitt(
      eintrag({
        log: [
          {
            at: "2026-09-21T14:13:02+02:00",
            level: "error",
            category: "console",
            message: "Kurs konnte nicht geladen werden",
          },
        ],
      }),
    );
    expect(text).toContain("<details><summary>Protokoll (letzte 5 min, 1 Zeile)</summary>");
    expect(text).toContain("14:13:02 error console — Kurs konnte nicht geladen werden");
  });

  it("Notiz nur mit Text", () => {
    expect(abschnitt(eintrag({ note: null }))).not.toContain("**Notiz:**");
  });
});

describe("elementZeile", () => {
  it("Kennung, Label, Typ und Fundstelle", () => {
    expect(
      elementZeile({
        source: "dom",
        identifier: "geraete.anlegen",
        label: "Gerät anlegen",
        type: "PrimaryButton",
        frame: { x: 0, y: 0, width: 10, height: 10 },
        file: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx",
        line: 42,
      }),
    ).toBe(
      "`geraete.anlegen` — „Gerät anlegen“, PrimaryButton, `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx:42`",
    );
  });

  it("was fehlt, entfaellt", () => {
    expect(
      elementZeile({
        source: "dom",
        identifier: null,
        label: null,
        type: "button",
        frame: { x: 0, y: 0, width: 10, height: 10 },
        file: null,
        line: null,
      }),
    ).toBe("button");
  });
});

describe("rendern", () => {
  it("Kopf, dann je Eintrag ein Abschnitt, Ende mit Zeilenumbruch", () => {
    const text = rendern(sitzung([eintrag(), eintrag({ index: 2, kind: "note", crop: null })]));
    expect(text.startsWith("# Testsitzung")).toBe(true);
    expect(text.match(/^## /gm)?.length).toBe(2);
    expect(text.endsWith("\n")).toBe(true);
  });
});

describe("sitzungJson", () => {
  it("sortiert Schluessel und laesst null stehen", () => {
    const text = sitzungJson(sitzung([eintrag({ element: null, note: null })]));
    expect(text).toContain('"element": null');
    expect(text).toContain('"note": null');
    expect(text.indexOf('"entries"')).toBeLessThan(text.indexOf('"format"'));
  });
});
