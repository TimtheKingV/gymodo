import { describe, expect, it } from "vitest";
import { GYMTAVO_STUDIO_ID, pruefeKatalog, type KatalogDatei } from "./katalog-datei.js";
import { pruefeMedien } from "./katalog-medien.js";
import { beispielKatalog, jpegBytes, mp4Bytes } from "./katalog-testdaten.js";

function katalog(roh: unknown): KatalogDatei {
  const pruefung = pruefeKatalog(roh);
  if (!pruefung.ok) throw new Error(pruefung.fehler.join("\n"));
  return pruefung.wert;
}

describe("pruefeMedien", () => {
  it("bildet Storage-Pfade aus Schluessel und Hash", () => {
    const { roh, dateien } = beispielKatalog();
    const pruefung = pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null);
    if (!pruefung.ok) throw new Error(pruefung.fehler.join("\n"));

    const foto = pruefung.wert.fotos.get("brustpresse");
    expect(foto?.bucket).toBe("equipment-photos");
    expect(foto?.contentType).toBe("image/png");
    expect(foto?.storagePath).toMatch(new RegExp(`^${GYMTAVO_STUDIO_ID}/catalog/photos/brustpresse-[0-9a-f]{8}\\.png$`));
    expect([...pruefung.wert.videos.keys()]).toEqual(["brustpresse_neutral", "trizeps_druecken"]);
    expect(pruefung.wert.videos.get("trizeps_druecken")?.storagePath).toMatch(
      new RegExp(`^${GYMTAVO_STUDIO_ID}/catalog/videos/trizeps_druecken-[0-9a-f]{8}\\.mp4$`),
    );
  });

  it("aendert den Pfad genau dann, wenn sich die Datei aendert", () => {
    const { roh, dateien } = beispielKatalog();
    const k = katalog(roh);
    const pfad = () => {
      const p = pruefeMedien(k, (d) => dateien.get(d) ?? null);
      if (!p.ok) throw new Error(p.fehler.join("\n"));
      return p.wert.videos.get("trizeps_druecken")?.storagePath;
    };
    const erster = pfad();
    expect(pfad()).toBe(erster);
    dateien.set("media/videos/trizeps.mp4", mp4Bytes(5, 99));
    expect(pfad()).not.toBe(erster);
  });

  it("nimmt JPEG als .jpg", () => {
    const { roh, dateien } = beispielKatalog();
    dateien.set("media/photos/brustpresse.png", jpegBytes(1));
    const p = pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null);
    expect(p.ok && p.wert.fotos.get("brustpresse")?.storagePath.endsWith(".jpg")).toBe(true);
  });

  it("meldet fehlende, falsche und zu lange Dateien gesammelt", () => {
    const { roh, dateien } = beispielKatalog();
    dateien.delete("media/photos/brustpresse.png");
    dateien.set("media/videos/brustpresse_neutral.mp4", jpegBytes());
    dateien.set("media/videos/trizeps.mp4", mp4Bytes(7));
    const p = pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null);
    expect(p.ok ? [] : p.fehler).toEqual([
      'equipment[0] "brustpresse" photo "media/photos/brustpresse.png": Datei fehlt',
      'exercises[0] "brustpresse_neutral" video "media/videos/brustpresse_neutral.mp4": ist kein MP4',
      'exercises[1] "trizeps_druecken" video "media/videos/trizeps.mp4": dauert 7 s, angegeben sind 5 s',
    ]);
  });

  it("nimmt ein MP4 hin, dessen Dauer sich nicht lesen laesst", () => {
    const { roh, dateien } = beispielKatalog();
    dateien.set("media/videos/trizeps.mp4", mp4Bytes(null));
    expect(pruefeMedien(katalog(roh), (d) => dateien.get(d) ?? null).ok).toBe(true);
  });
});
