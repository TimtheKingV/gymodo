import { mkdtempSync, readFileSync } from "node:fs";
import { readdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { beforeEach, describe, expect, it } from "vitest";
import { eintragSchreiben, sitzungAnlegen, sitzungLesen } from "./ablage";
import type { Eintragsentwurf, Sitzungskopf } from "./format";

let wurzel: string;

const KOPF: Sitzungskopf = {
  id: "",
  startedAt: "2026-09-21T14:12:03+02:00",
  app: { bundleId: "gymodo.web.portal", version: "0.0.0", build: "dev", configuration: "Debug" },
  device: { model: "Chrome 143", os: "macOS", screen: { width: 1512, height: 858, scale: 2 } },
};

function entwurf(teile: Partial<Eintragsentwurf> = {}): Eintragsentwurf {
  return {
    id: "8F0C2A4E-6B1D-4C3A-9E7F-1A2B3C4D5E6F",
    createdAt: "2026-09-21T14:13:41+02:00",
    kind: "crop",
    cropRect: null,
    element: null,
    note: "Gewicht abgeschnitten",
    runtime: { online: true, pendingWrites: 0, signedIn: true, studioId: "s_1" },
    log: [],
    ...teile,
  };
}

const BILD = new Uint8Array([137, 80, 78, 71]);

beforeEach(() => {
  wurzel = path.join(mkdtempSync(path.join(tmpdir(), "testnotiz-")), "testnotizen");
});

describe("sitzungAnlegen", () => {
  it("legt den Ordner nach der Startzeit an, mit leerer Sitzung", async () => {
    const sitzung = await sitzungAnlegen(wurzel, KOPF);
    expect(sitzung.session.id).toBe("2026-09-21-1412");
    expect(sitzung.platform).toBe("web");
    expect(await readdir(path.join(wurzel, sitzung.session.id))).toEqual(
      expect.arrayContaining(["sitzung.json", "sitzung.md"]),
    );
  });

  it("zweite Sitzung in derselben Minute bekommt ein -2", async () => {
    await sitzungAnlegen(wurzel, KOPF);
    const zweite = await sitzungAnlegen(wurzel, KOPF);
    const dritte = await sitzungAnlegen(wurzel, KOPF);
    expect(zweite.session.id).toBe("2026-09-21-1412-2");
    expect(dritte.session.id).toBe("2026-09-21-1412-3");
  });
});

describe("eintragSchreiben", () => {
  it("vergibt Nummer und Dateinamen und schreibt beide Bilder", async () => {
    const { session } = await sitzungAnlegen(wurzel, KOPF);
    const erster = await eintragSchreiben(wurzel, session.id, entwurf(), null, BILD, BILD);
    const zweiter = await eintragSchreiben(wurzel, session.id, entwurf(), null, BILD, null);

    expect(erster.eintrag.index).toBe(1);
    expect(erster.eintrag.screenshot).toBe("01-voll.png");
    expect(erster.eintrag.crop).toBe("01-ausschnitt.png");
    expect(zweiter.eintrag.index).toBe(2);
    expect(zweiter.eintrag.crop).toBeNull();
    expect(zweiter.anzahl).toBe(2);

    const dateien = await readdir(path.join(wurzel, session.id));
    expect(dateien).toEqual(
      expect.arrayContaining(["01-voll.png", "01-ausschnitt.png", "02-voll.png"]),
    );
    expect(dateien).not.toContain("02-ausschnitt.png");
  });

  it("schreibt sitzung.json und sitzung.md nach jedem Eintrag neu", async () => {
    const { session } = await sitzungAnlegen(wurzel, KOPF);
    await eintragSchreiben(
      wurzel,
      session.id,
      entwurf(),
      {
        name: "portal/[studioId]/geraete",
        file: "apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx",
        stack: ["apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx"],
        context: { studioId: "s_1" },
      },
      BILD,
      null,
    );

    const gelesen = await sitzungLesen(wurzel, session.id);
    expect(gelesen?.entries).toHaveLength(1);
    expect(gelesen?.entries[0]?.screen?.file).toContain("geraete/page.tsx");
    // Sprachnotizen gibt es im Portal nicht, die Felder bleiben trotzdem da.
    expect(gelesen?.entries[0]?.audio).toBeNull();
    expect(gelesen?.entries[0]?.transcript).toBeNull();

    const md = readFileSync(path.join(wurzel, session.id, "sitzung.md"), "utf8");
    expect(md).toContain("## 1 · 14:13 · Ausschnitt · portal/[studioId]/geraete");
    expect(md).toContain("**Notiz:** Gewicht abgeschnitten");
  });

  it("zwei gleichzeitige Einträge bekommen verschiedene Nummern", async () => {
    const { session } = await sitzungAnlegen(wurzel, KOPF);
    const [a, b] = await Promise.all([
      eintragSchreiben(wurzel, session.id, entwurf(), null, BILD, null),
      eintragSchreiben(wurzel, session.id, entwurf(), null, BILD, null),
    ]);
    expect([a.eintrag.index, b.eintrag.index].sort()).toEqual([1, 2]);
    expect((await sitzungLesen(wurzel, session.id))?.entries).toHaveLength(2);
  });

  it("eine unbekannte Sitzung ist ein Fehler, keine neue Ablage", async () => {
    await expect(
      eintragSchreiben(wurzel, "2026-01-01-0000", entwurf(), null, BILD, null),
    ).rejects.toThrow();
  });
});

describe("sitzungLesen", () => {
  it("nimmt nur Ordnernamen des Formats", async () => {
    expect(await sitzungLesen(wurzel, "../../etc")).toBeNull();
    expect(await sitzungLesen(wurzel, "2026-09-21-1412")).toBeNull();
  });
});
