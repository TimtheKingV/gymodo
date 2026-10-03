import { describe, expect, it } from "vitest";
import {
  SONSTIGES,
  belastungMinimum,
  einheitenFuer,
  maxGewichtWerte,
  minMaxWerte,
  nameRadWerte,
  nameVorschlaege,
  vorgabeFuer,
} from "./einstellungVorschlaege";

/** Testnotiz 23.09. (zweite Sitzung), #2. */
describe("nameRadWerte", () => {
  it("fuehrt die Vorschlaege und am Ende Sonstiges", () => {
    const werte = nameRadWerte();
    expect(werte.slice(0, -1)).toEqual(nameVorschlaege());
    expect(werte.at(-1)).toEqual({ anzeige: "Sonstiges …", wert: SONSTIGES });
  });
});

describe("vorgabeFuer", () => {
  it("stellt fuer Winkel Grad und Schritt 5 ein", () => {
    expect(vorgabeFuer("Winkel")).toEqual({ min: "0", max: "90", schritt: "5", einheit: "°" });
  });

  it("stellt fuer Gewicht kg ein", () => {
    expect(vorgabeFuer("Gewicht").einheit).toBe("kg");
  });

  it("hat fuer jeden Vorschlag eine Vorgabe, deren Werte im Rad stehen", () => {
    for (const { wert } of nameVorschlaege()) {
      const vorgabe = vorgabeFuer(wert);
      const takt = minMaxWerte(vorgabe.schritt).map((zeile) => zeile.wert);
      expect(takt, wert).toContain(vorgabe.min);
      expect(takt, wert).toContain(vorgabe.max);
    }
  });

  it("faellt fuer Sonstiges und Unbekanntes auf den neutralen Bereich zurueck", () => {
    const neutral = { min: "0", max: "10", schritt: "1", einheit: "" };
    expect(vorgabeFuer(SONSTIGES)).toEqual(neutral);
    expect(vorgabeFuer("Fussstuetze")).toEqual(neutral);
  });
});

/** Testnotiz 23.09. (zweite Sitzung), #3. */
describe("minMaxWerte", () => {
  it("zaehlt ohne Schritt wie bisher 0 bis 200", () => {
    const werte = minMaxWerte();
    expect(werte).toHaveLength(201);
    expect(werte[1]).toEqual({ anzeige: "1", wert: "1" });
  });

  it("zaehlt im Takt des Schritts", () => {
    expect(minMaxWerte("5").slice(0, 4).map((zeile) => zeile.wert)).toEqual(["0", "5", "10", "15"]);
    expect(minMaxWerte("5").at(-1)!.wert).toBe("200");
  });

  it("schreibt Kommazahlen deutsch", () => {
    expect(minMaxWerte("2,5").slice(0, 3).map((zeile) => zeile.wert)).toEqual(["0", "2,5", "5"]);
    expect(minMaxWerte("0,5")[1]!.anzeige).toBe("0,5");
  });

  it("gilt auch fuer das Maximum am Geraet, mit ∞ am Ende", () => {
    const werte = maxGewichtWerte("5");
    expect(werte[1]!.wert).toBe("5");
    expect(werte.at(-1)).toEqual({ anzeige: "∞", wert: "" });
  });
});

/** Testnotiz 03.10., #1: Kraft und Cardio bieten verschiedene Einheiten. */
describe("einheitenFuer", () => {
  it("Kraft misst in kg", () => {
    expect(einheitenFuer("kraft")).toEqual(["kg"]);
  });

  it("Cardio bietet alles ausser kg", () => {
    expect(einheitenFuer("cardio")).toEqual(["watt", "level", "kmh", "pct", "rpm"]);
  });
});

/** Testnotiz 03.10., #2: kein Minimum mehr im Rad. */
describe("belastungMinimum", () => {
  it("ist ohne Bestand der Schritt -- der kleinste Wert ueber null", () => {
    expect(belastungMinimum("2,5")).toBe("2,5");
    expect(belastungMinimum("0,5")).toBe("0,5");
  });

  it("behaelt ein Bestandsminimum ueber null im Takt", () => {
    expect(belastungMinimum("2,5", "5")).toBe("5");
    expect(belastungMinimum("5", "25")).toBe("25");
  });

  it("verwirft null und Werte ausserhalb des Takts", () => {
    expect(belastungMinimum("2,5", "0")).toBe("2,5");
    expect(belastungMinimum("5", "7,5")).toBe("5");
  });
});
