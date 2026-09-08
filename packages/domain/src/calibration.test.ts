import { describe, expect, it } from "vitest";
import { pruefeEinstellwerte, type EinstellDefinition } from "./calibration.js";

/** Beinpresse aus dem Testkatalog: Sitz 1-8 in Schritten von 1. */
const sitz: EinstellDefinition = {
  key: "sitz",
  label: "Sitzposition",
  kind: "number",
  min_value: 1,
  max_value: 8,
  step_value: 1,
  allowed_values: null,
};

const griff: EinstellDefinition = {
  key: "griff",
  label: "Griff",
  kind: "enum",
  min_value: null,
  max_value: null,
  step_value: null,
  allowed_values: ["eng", "breit"],
};

describe("pruefeEinstellwerte", () => {
  it("nimmt einen Wert innerhalb der Grenzen an", () => {
    expect(pruefeEinstellwerte([sitz], { sitz: 4 })).toBeNull();
  });

  it("weist einen Wert oberhalb des Maximums ab und nennt die Grenze", () => {
    const fehler = pruefeEinstellwerte([sitz], { sitz: 9 });

    expect(fehler).toContain("Sitzposition");
    expect(fehler).toContain("8");
  });

  it("weist einen Wert unterhalb des Minimums ab", () => {
    expect(pruefeEinstellwerte([sitz], { sitz: 0 })).not.toBeNull();
  });

  it("weist einen Wert neben der Schrittweite ab", () => {
    expect(pruefeEinstellwerte([sitz], { sitz: 4.5 })).not.toBeNull();
  });

  it("weist einen unbekannten Schluessel ab", () => {
    expect(pruefeEinstellwerte([sitz], { lehne: 2 })).not.toBeNull();
  });

  it("nimmt einen erlaubten Auswahlwert an", () => {
    expect(pruefeEinstellwerte([griff], { griff: "eng" })).toBeNull();
  });

  it("weist einen nicht erlaubten Auswahlwert ab", () => {
    expect(pruefeEinstellwerte([griff], { griff: "mittel" })).not.toBeNull();
  });

  it("weist eine Zahl fuer ein Auswahlfeld ab", () => {
    expect(pruefeEinstellwerte([griff], { griff: 3 })).not.toBeNull();
  });

  it("nimmt eine Teilmenge an -- nicht jeder Parameter muss gesetzt sein", () => {
    expect(pruefeEinstellwerte([sitz, griff], { sitz: 4 })).toBeNull();
  });

  it("weist einen leeren Satz ab -- eine Kalibrierung ohne Werte ist keine", () => {
    expect(pruefeEinstellwerte([sitz], {})).not.toBeNull();
  });
});
