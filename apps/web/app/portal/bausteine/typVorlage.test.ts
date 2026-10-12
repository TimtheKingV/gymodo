import { describe, expect, it } from "vitest";
import type { CatalogType } from "@fitretro/domain";
import { belastungStart, typVorlagen } from "./typVorlage";

const basis: CatalogType = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft", retired: false,
  loadUnit: "kg", loadStep: 1, loadMin: 0, loadMax: null,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
  photoPath: "gymtavo/catalog/photos/chest_press-abcd1234.png",
  products: [],
  exercises: [{ exerciseId: "u1", name: "Brustpresse neutral", description: "lang", volumeKind: "reps",
    targetMin: 8, targetMax: 12, sortOrder: 1, videoStoragePath: null, videoDurationS: null }],
};
const laufband: CatalogType = {
  ...basis, id: "t2", name: "Laufband", category: "cardio", loadUnit: "kmh", loadStep: 0.1,
  secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
  photoPath: null, exercises: [],
};

const typMitProdukt: CatalogType = {
  ...basis,
  photoPath: "gymtavo/t1.png",
  products: [{ id: "p1", key: "k", manufacturer: "gym80", series: null, name: "Brustpresse", modelCode: null, note: null, load: null, secondary: null, photoPath: "gymtavo/p1.png" }],
};

describe("typVorlagen", () => {
  // Testnotiz 12.10., #1: ein im Kabelzug aufgegangener Typ ist keine
  // Vorlage mehr fuer ein neues Modell.
  it("laesst abgeloeste Typen weg", () => {
    expect(typVorlagen([basis, { ...basis, id: "t9", retired: true }]).map((v) => v.id)).toEqual(["t1"]);
  });

  it("laesst Uebungen und Pfad weg und merkt nur, ob es ein Foto gibt", () => {
    const [vorlage] = typVorlagen([basis]);
    expect(vorlage).toEqual({
      id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
      loadUnit: "kg", loadStep: 1, loadMin: 0, loadMax: null,
      secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
      hatFoto: true, fotoUrl: null, produkte: [],
    });
  });

  it("haengt signierte Bild-URLs an Typ und Produkt, ohne Pfade herauszugeben", () => {
    const [vorlage] = typVorlagen([typMitProdukt], undefined, { "gymtavo/t1.png": "https://bild/t1", "gymtavo/p1.png": "https://bild/p1" });
    expect(vorlage).toMatchObject({ hatFoto: true, fotoUrl: "https://bild/t1" });
    expect(vorlage!.produkte).toEqual([
      { id: "p1", manufacturer: "gym80", series: null, name: "Brustpresse", modelCode: null, note: null, load: null, secondary: null, fotoUrl: "https://bild/p1" },
    ]);
    expect(JSON.stringify(vorlage)).not.toContain("gymtavo/");
  });

  it("filtert nach Kategorie, wenn eine vorgegeben ist", () => {
    expect(typVorlagen([basis, laufband], "cardio").map((t) => t.id)).toEqual(["t2"]);
    expect(typVorlagen([basis, laufband]).map((t) => t.id)).toEqual(["t1", "t2"]);
  });
});

describe("belastungStart", () => {
  it("bildet einen Krafttyp ohne Nebenbelastung ab", () => {
    expect(belastungStart(typVorlagen([basis])[0]!)).toEqual({
      category: "kraft", loadUnit: "kg", loadMin: 0, loadMax: null, loadStep: 1,
      secondaryUnit: null, secondaryMin: null, secondaryMax: null, secondaryStep: null,
    });
  });

  it("bildet einen Cardiotyp mit Nebenbelastung ab", () => {
    expect(belastungStart(typVorlagen([laufband])[0]!)).toEqual({
      category: "cardio", loadUnit: "kmh", loadMin: 0, loadMax: null, loadStep: 0.1,
      secondaryUnit: "pct", secondaryMin: 0, secondaryMax: 15, secondaryStep: 0.5,
    });
  });
});
