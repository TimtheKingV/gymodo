import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { beforeAll, describe, expect, it } from "vitest";
import { karteLesen } from "./routenkarte.mjs";
import { type Routenknoten, screenBauen, seiteFinden } from "./seitendatei";

let wurzel: string;
let karte: Routenknoten;

/**
 * Ein Baum wie der echte App-Router: Klammergruppe, dynamische Segmente,
 * eine Huelle je Ebene.
 */
beforeAll(() => {
  wurzel = path.join(mkdtempSync(path.join(tmpdir(), "testnotiz-")), "app");
  const anlegen = (unterpfad: string, dateien: string[]) => {
    const ordner = path.join(wurzel, unterpfad);
    mkdirSync(ordner, { recursive: true });
    for (const datei of dateien) writeFileSync(path.join(ordner, datei), "");
  };

  anlegen(".", ["layout.tsx", "page.tsx"]);
  anlegen("portal", ["page.tsx"]);
  anlegen("portal/[studioId]/(schreibtisch)", ["layout.tsx", "page.tsx"]);
  anlegen("portal/[studioId]/(schreibtisch)/geraete", ["page.tsx"]);
  anlegen("portal/[studioId]/(schreibtisch)/geraete/[modelId]", ["layout.tsx", "page.tsx"]);
  anlegen("portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen", ["page.tsx"]);
  anlegen("portal/[studioId]/einrichten", ["page.tsx"]);
  anlegen("t/[...rest]", ["page.tsx"]);

  karte = karteLesen(wurzel, "apps/web/app");
});

function finden(pfad: string) {
  return seiteFinden(karte, pfad);
}

describe("seiteFinden", () => {
  it("findet die Wurzel", () => {
    expect(finden("/")).toMatchObject({
      datei: "apps/web/app/page.tsx",
      name: "start",
      stapel: ["apps/web/app/layout.tsx", "apps/web/app/page.tsx"],
      parameter: {},
    });
  });

  it("loest dynamische Segmente auf und nennt sie als Kontext", () => {
    expect(finden("/portal/s_1/geraete/m_2/uebungen")).toMatchObject({
      datei: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/page.tsx",
      name: "portal/[studioId]/geraete/[modelId]/uebungen",
      parameter: { studioId: "s_1", modelId: "m_2" },
    });
  });

  it("Klammergruppen sind keine URL-Ebene, aber ihre Huelle zaehlt", () => {
    expect(finden("/portal/s_1")?.stapel).toEqual([
      "apps/web/app/layout.tsx",
      "apps/web/app/portal/[studioId]/(schreibtisch)/layout.tsx",
      "apps/web/app/portal/[studioId]/(schreibtisch)/page.tsx",
    ]);
  });

  it("woertliche Segmente schlagen dynamische", () => {
    expect(finden("/portal/s_1/einrichten")?.datei).toBe(
      "apps/web/app/portal/[studioId]/einrichten/page.tsx",
    );
    expect(finden("/portal")?.datei).toBe("apps/web/app/portal/page.tsx");
  });

  it("Sammelsegmente nehmen den Rest", () => {
    expect(finden("/t/abc/def")).toMatchObject({
      datei: "apps/web/app/t/[...rest]/page.tsx",
      parameter: { rest: "abc/def" },
    });
  });

  it("was es nicht gibt, gibt es nicht", () => {
    expect(finden("/gibtsnicht")).toBeNull();
    expect(finden("/portal/s_1/geraete/m_2/gibtsnicht")).toBeNull();
  });

  it("fuehrt kein .. aus dem App-Verzeichnis heraus", () => {
    expect(finden("/../../etc")).toBeNull();
  });

  it("ohne Karte gibt es keinen Treffer", () => {
    expect(seiteFinden(null, "/portal/s_1")).toBeNull();
  });
});

describe("screenBauen", () => {
  it("sammelt Segmente, Abfrage und eigenen Kontext", () => {
    expect(
      screenBauen(karte, {
        pfad: "/portal/s_1/geraete/m_2/uebungen",
        suche: "?filter=neu",
        kontext: { phase: "eingabe" },
      }),
    ).toEqual({
      name: "portal/[studioId]/geraete/[modelId]/uebungen",
      file: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/page.tsx",
      stack: [
        "apps/web/app/layout.tsx",
        "apps/web/app/portal/[studioId]/(schreibtisch)/layout.tsx",
        "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/layout.tsx",
        "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/uebungen/page.tsx",
      ],
      context: { studioId: "s_1", modelId: "m_2", filter: "neu", phase: "eingabe" },
    });
  });

  it("ohne Treffer bleibt der Screen leer", () => {
    expect(screenBauen(karte, { pfad: "/gibtsnicht" })).toBeNull();
    expect(screenBauen(null, { pfad: "/portal/s_1" })).toBeNull();
  });
});
