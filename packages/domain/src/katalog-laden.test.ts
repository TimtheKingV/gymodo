import { mkdirSync, mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { ladeKatalog } from "./katalog-laden.js";
import { beispielKatalog } from "./katalog-testdaten.js";

function ordnerMitKatalog(): string {
  const ordner = mkdtempSync(join(tmpdir(), "katalog-"));
  const { roh, dateien } = beispielKatalog();
  writeFileSync(join(ordner, "gymtavo.json"), JSON.stringify(roh));
  for (const [pfad, bytes] of dateien) {
    mkdirSync(join(ordner, pfad, ".."), { recursive: true });
    writeFileSync(join(ordner, pfad), bytes);
  }
  return ordner;
}

describe("ladeKatalog", () => {
  it("liest Medien relativ zur Datei, nicht zum Arbeitsverzeichnis", () => {
    const ergebnis = ladeKatalog(join(ordnerMitKatalog(), "gymtavo.json"));
    if (!ergebnis.ok) throw new Error(ergebnis.fehler.join("\n"));
    expect(ergebnis.wert.medien.videos.size).toBe(2);
  });

  it("meldet kaputtes JSON", () => {
    const ordner = mkdtempSync(join(tmpdir(), "katalog-"));
    writeFileSync(join(ordner, "gymtavo.json"), "{ format: 1");
    const ergebnis = ladeKatalog(join(ordner, "gymtavo.json"));
    expect(ergebnis.ok ? "" : ergebnis.fehler[0]).toContain("kein gueltiges JSON");
  });

  it("meldet eine fehlende Datei", () => {
    const ergebnis = ladeKatalog(join(tmpdir(), "gibt-es-nicht.json"));
    expect(ergebnis.ok ? "" : ergebnis.fehler[0]).toContain("Datei nicht lesbar");
  });
});
