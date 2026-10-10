import { describe, expect, it } from "vitest";
import { pruefeKatalog } from "./katalog-datei.js";
import { beispielKatalog } from "./katalog-testdaten.js";

function fehlerVon(aendern: (roh: ReturnType<typeof beispielKatalog>["roh"]) => void): string[] {
  const { roh } = beispielKatalog();
  aendern(roh);
  const pruefung = pruefeKatalog(roh);
  if (pruefung.ok) throw new Error("Pruefung haette scheitern muessen");
  return pruefung.fehler;
}

describe("pruefeKatalog", () => {
  it("laesst den Beispielkatalog durch", () => {
    const pruefung = pruefeKatalog(beispielKatalog().roh);
    expect(pruefung.ok).toBe(true);
    if (pruefung.ok) expect(pruefung.wert.equipment.map((g) => g.key)).toEqual(["brustpresse", "trizepsmaschine", "laufband"]);
  });

  it("nennt den Ort mit Index und Schluessel", () => {
    expect(fehlerVon((roh) => delete (roh.equipment[2] as Record<string, unknown>).load_step)).toEqual([
      'equipment[2] "laufband" load_step: fehlt',
    ]);
  });

  it("sammelt alle Fehler auf einmal", () => {
    const fehler = fehlerVon((roh) => {
      roh.equipment[0]!.load_unit = "lbs";
      (roh.exercises[0] as Record<string, unknown>).grp = "x";
    });
    expect(fehler).toEqual([
      'equipment[0] "brustpresse" load_unit: ist "lbs", erlaubt: kg, watt, level, kmh, pct, rpm',
      'exercises[0] "brustpresse_neutral": unbekanntes Feld "grp"',
    ]);
  });

  it("verlangt die Nebenbelastung vollstaendig", () => {
    expect(fehlerVon((roh) => delete (roh.equipment[2]!.secondary as Record<string, unknown>).max)).toEqual([
      'equipment[2] "laufband" secondary.max: fehlt',
    ]);
  });

  it("prueft Schluessel, Format und Wurzel", () => {
    expect(fehlerVon((roh) => (roh.equipment[0]!.key = "Brust-Presse"))).toContain(
      'equipment[0] "Brust-Presse" key: darf nur a-z, 0-9 und _ enthalten',
    );
    expect(fehlerVon((roh) => (roh.format = 2))).toEqual(["format: muss 1 sein"]);
    const liste = pruefeKatalog([]);
    expect(liste.ok ? [] : liste.fehler).toEqual(["Datei: muss Objekt sein, ist Liste"]);
  });

  it("prueft Einstellungen", () => {
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[1]!.allowed_values = ["eng"]))).toEqual([
      'equipment[0] "brustpresse" settings[1] "griff" allowed_values: braucht mindestens zwei Werte',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[1]!.allowed_values = ["eng", "eng"]))).toEqual([
      'equipment[0] "brustpresse" settings[1] "griff": allowed_values enthaelt "eng" mehrfach',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[0]!.allowed_values = ["a", "b"]))).toEqual([
      'equipment[0] "brustpresse" settings[0] "sitzhoehe": unbekanntes Feld "allowed_values"',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[0]!.kind = "slider"))).toEqual([
      'equipment[0] "brustpresse" settings[0] "sitzhoehe" kind: muss number oder enum sein',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.settings[0]!.min = 11))).toEqual([
      'equipment[0] "brustpresse" settings[0] "sitzhoehe": max ist kleiner als min',
    ]);
  });

  it("prueft Belastungsgrenzen", () => {
    expect(fehlerVon((roh) => (roh.equipment[0]!.load_max = -1))).toEqual([
      'equipment[0] "brustpresse" load_max: darf nicht negativ sein',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.load_min = 130))).toEqual([
      'equipment[0] "brustpresse": load_max ist kleiner als load_min',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[0]!.load_step = 0))).toEqual([
      'equipment[0] "brustpresse" load_step: muss groesser als 0 sein',
    ]);
  });

  it("prueft Schluessel und Verweise ueber Listen hinweg", () => {
    expect(fehlerVon((roh) => (roh.equipment[1]!.key = "brustpresse"))).toEqual([
      'equipment: Schluessel "brustpresse" kommt mehrfach vor',
    ]);
    expect(fehlerVon((roh) => roh.equipment[2]!.exercises.push("rudern"))).toEqual([
      'equipment[2] "laufband" exercises: Uebung "rudern" gibt es in exercises nicht',
    ]);
    expect(fehlerVon((roh) => (roh.equipment[2]!.exercises = []))).toEqual([
      'exercises[2] "gehen": haengt an keinem Geraetetyp',
    ]);
  });

  it("prueft den Zielkorridor gegen die Umfangsart", () => {
    expect(fehlerVon((roh) => (roh.exercises[0]!.target_min = 13))).toEqual([
      'exercises[0] "brustpresse_neutral": target_max ist kleiner als target_min',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[0]!.target_max = 1001))).toEqual([
      'exercises[0] "brustpresse_neutral": target_max ist groesser als 1000 (Obergrenze fuer reps)',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[0]!.target_min = 8.5))).toEqual([
      'exercises[0] "brustpresse_neutral" target_min: muss eine ganze Zahl sein',
    ]);
  });

  it("prueft Video, Muskeln und Quellen", () => {
    expect(fehlerVon((roh) => (roh.exercises[0]!.video = { file: "a.mp4", duration_s: 46 }))).toEqual([
      'exercises[0] "brustpresse_neutral" video.duration_s: darf hoechstens 45 sein',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[0]!.video = { file: "../a.mp4", duration_s: 6 }))).toEqual([
      'exercises[0] "brustpresse_neutral" video.file: muss relativ zur Datei sein und darf nicht mit .. hinausfuehren',
    ]);
    expect(fehlerVon((roh) => (roh.exercises[1]!.muscles = [{ muscle: "trizeps", role: "secondary" }]))).toEqual([
      'exercises[1] "trizeps_druecken": braucht mindestens einen Muskel mit role "primary"',
    ]);
    expect(fehlerVon((roh) => roh.exercises[1]!.muscles.push({ muscle: "bizeps", role: "secondary" }))).toEqual([
      'exercises[1] "trizeps_druecken" muscles: Muskel "bizeps" gibt es in muscles nicht',
    ]);
    expect(fehlerVon((roh) => roh.exercises[1]!.sources.push("quelle_b"))).toEqual([
      'exercises[1] "trizeps_druecken" sources: Quelle "quelle_b" gibt es in sources nicht',
    ]);
    expect(fehlerVon((roh) => (roh.sources[0]!.url = "http://example.org"))).toEqual([
      'sources[0] "quelle_a" url: muss eine https-Adresse sein',
    ]);
  });
});
