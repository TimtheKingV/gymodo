import { describe, expect, it } from "vitest";
import {
  ANDERER_HERSTELLER,
  herstellerOptionen,
  nameNachVorschlag,
  produkteVon,
  produktName,
  vorlageStart,
  vorlageText,
} from "./herstellerWahl";
import type { ProduktVorlage, TypVorlage } from "./typVorlage";

function produkt(werte: Partial<ProduktVorlage> & Pick<ProduktVorlage, "id" | "manufacturer" | "name">): ProduktVorlage {
  return { series: null, modelCode: null, note: null, load: null, secondary: null, fotoUrl: null, ...werte };
}

const typ: TypVorlage = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
  loadUnit: "kg", loadStep: 1.25, loadMin: 0, loadMax: null,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null,
  hatFoto: true, fotoUrl: "https://bild/typ",
  produkte: [
    produkt({ id: "p1", manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345" }),
    produkt({ id: "p2", manufacturer: "gym80", series: "Sygnum", name: "Chest Press", load: { unit: "kg", step: 5, min: 5, max: 150 } }),
    produkt({ id: "p3", manufacturer: "Life Fitness", series: "Insignia", name: "Chest Press", modelCode: "SS-CP" }),
  ],
};

describe("herstellerOptionen", () => {
  it("nennt jeden Hersteller einmal mit Anzahl, dazu Anderer Hersteller", () => {
    expect(herstellerOptionen(typ)).toEqual([
      { wert: "gym80", anzeige: "gym80 (2)" },
      { wert: "Life Fitness", anzeige: "Life Fitness (1)" },
      { wert: ANDERER_HERSTELLER, anzeige: "Anderer Hersteller" },
    ]);
  });
});

describe("produkteVon", () => {
  it("liefert nur die Produkte des Herstellers", () => {
    expect(produkteVon(typ, "gym80").map((x) => x.id)).toEqual(["p1", "p2"]);
    expect(produkteVon(typ, ANDERER_HERSTELLER)).toEqual([]);
  });
});

describe("produktName und vorlageText", () => {
  it("setzt Serie, Name und Code ohne leere Teile zusammen", () => {
    expect(produktName(typ.produkte[0]!)).toBe("Pure Kraft Brustpresse 4345");
    expect(produktName(typ.produkte[1]!)).toBe("Sygnum Chest Press");
    expect(produktName(produkt({ id: "x", manufacturer: "Assault", name: "AirBike" }))).toBe("AirBike");
  });

  it("nennt die Vorlage mit Hersteller", () => {
    expect(vorlageText({ manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345" })).toBe(
      "Vorlage: gym80 Pure Kraft Brustpresse 4345",
    );
    expect(vorlageText({ manufacturer: "Assault", series: null, name: "AirBike", modelCode: null })).toBe("Vorlage: Assault AirBike");
  });
});

describe("vorlageStart", () => {
  it("nimmt die Belastung vom Produkt, wenn bekannt, sonst vom Typ", () => {
    expect(vorlageStart(typ, typ.produkte[1]!)).toMatchObject({ category: "kraft", loadUnit: "kg", loadStep: 5, loadMin: 5, loadMax: 150 });
    expect(vorlageStart(typ, typ.produkte[0]!)).toMatchObject({ loadStep: 1.25, loadMin: 0, loadMax: null });
    expect(vorlageStart(typ, null)).toMatchObject({ loadStep: 1.25 });
  });

  it("nimmt die Nebenbelastung vom Produkt nur zusammen mit dessen Belastung", () => {
    const cardio = produkt({
      id: "c", manufacturer: "Precor", name: "Laufband",
      load: { unit: "kmh", step: 0.1, min: 0.8, max: 25 }, secondary: { unit: "pct", step: 0.5, min: 0, max: 15 },
    });
    expect(vorlageStart({ ...typ, category: "cardio" }, cardio)).toMatchObject({
      loadUnit: "kmh", loadMin: 0.8, secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
    });
  });
});

describe("nameNachVorschlag", () => {
  it("uebernimmt den Vorschlag bei leerem oder unveraendert vorgeschlagenem Namen", () => {
    expect(nameNachVorschlag("", null, "Brustpresse")).toBe("Brustpresse");
    expect(nameNachVorschlag("Brustpresse", "Brustpresse", "Pure Kraft Brustpresse 4345")).toBe("Pure Kraft Brustpresse 4345");
  });

  it("laesst einen selbst getippten Namen stehen", () => {
    expect(nameNachVorschlag("Presse links", "Brustpresse", "Pure Kraft Brustpresse 4345")).toBe("Presse links");
    expect(nameNachVorschlag("Presse links", null, null)).toBe("Presse links");
  });
});
