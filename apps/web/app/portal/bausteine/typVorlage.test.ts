import { describe, expect, it } from "vitest";
import type { CatalogType } from "@fitretro/domain";
import { belastungStart, nameNachTypwahl, typVorlagen, type TypVorlage } from "./typVorlage";

const basis: CatalogType = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
  loadUnit: "kg", loadStep: 1, loadMin: 0, loadMax: null,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
  photoPath: "gymtavo/catalog/photos/chest_press-abcd1234.png",
  exercises: [{ exerciseId: "u1", name: "Brustpresse neutral", description: "lang", volumeKind: "reps",
    targetMin: 8, targetMax: 12, sortOrder: 1, videoStoragePath: null, videoDurationS: null }],
};
const laufband: CatalogType = {
  ...basis, id: "t2", name: "Laufband", category: "cardio", loadUnit: "kmh", loadStep: 0.1,
  secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
  photoPath: null, exercises: [],
};

describe("typVorlagen", () => {
  it("laesst Uebungen und Pfad weg und merkt nur, ob es ein Foto gibt", () => {
    const [vorlage] = typVorlagen([basis]);
    expect(vorlage).toEqual({
      id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
      loadUnit: "kg", loadStep: 1, loadMin: 0, loadMax: null,
      secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
      hatFoto: true,
    });
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

describe("nameNachTypwahl", () => {
  const [brust, band] = typVorlagen([basis, laufband]) as [TypVorlage, TypVorlage];

  it("ein leerer Name bekommt den Typnamen", () => {
    expect(nameNachTypwahl("", null, brust)).toBe("Brustpresse");
    expect(nameNachTypwahl("   ", null, brust)).toBe("Brustpresse");
  });

  it("ein vom vorigen Typ gesetzter Name folgt dem neuen Typ", () => {
    expect(nameNachTypwahl("Brustpresse", brust, band)).toBe("Laufband");
  });

  it("ein selbst getippter Name bleibt", () => {
    expect(nameNachTypwahl("Brustpresse links", brust, band)).toBe("Brustpresse links");
    expect(nameNachTypwahl("Kabelturm", null, brust)).toBe("Kabelturm");
  });

  it("ohne neuen Typ bleibt der Name", () => {
    expect(nameNachTypwahl("Brustpresse", brust, null)).toBe("Brustpresse");
  });
});
