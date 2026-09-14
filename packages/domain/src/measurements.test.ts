import { describe, expect, it } from "vitest";
import { pruefeMesswert, zielErreicht } from "./measurements.js";

describe("pruefeMesswert", () => {
  it("nimmt Datum und Gewicht mit einer Nachkommastelle", () => {
    expect(pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 82.5 })).toEqual({
      measuredOn: "2026-09-14", weightKg: 82.5,
    });
  });

  it("rundet nicht still -- zwei Nachkommastellen sind ein Fehler", () => {
    expect(() => pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 82.55 })).toThrow(/Nachkommastelle/);
  });

  it("haelt das Gewicht in 20 bis 400 kg", () => {
    expect(() => pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 19.5 })).toThrow(/20/);
    expect(() => pruefeMesswert({ measuredOn: "2026-09-14", weightKg: 400.5 })).toThrow(/400/);
  });

  it("weist ein Datum in der Zukunft ab -- mit einem Tag Luft fuer die Zeitzone", () => {
    const heute = new Date("2026-09-14T12:00:00Z");
    expect(() => pruefeMesswert({ measuredOn: "2026-09-16", weightKg: 80 }, heute)).toThrow(/Zukunft/);
    expect(pruefeMesswert({ measuredOn: "2026-09-15", weightKg: 80 }, heute).measuredOn).toBe("2026-09-15");
  });

  it("weist ein Datum ausserhalb von YYYY-MM-DD ab", () => {
    expect(() => pruefeMesswert({ measuredOn: "14.09.2026", weightKg: 80 })).toThrow();
  });
});

describe("zielErreicht", () => {
  // Die Richtung ergibt sich aus dem ersten Messwert, nicht aus einem
  // eigenen Feld: lag der Start ueber dem Ziel, ist "<= Ziel" erreicht.
  it("abnehmen: erreicht, sobald der Wert das Ziel unterschreitet oder trifft", () => {
    expect(zielErreicht(82.5, 78, 78)).toBe(true);
    expect(zielErreicht(82.5, 78, 77.5)).toBe(true);
    expect(zielErreicht(82.5, 78, 78.5)).toBe(false);
  });

  it("zunehmen: erreicht, sobald der Wert das Ziel ueberschreitet oder trifft", () => {
    expect(zielErreicht(60, 65, 65)).toBe(true);
    expect(zielErreicht(60, 65, 64.5)).toBe(false);
  });

  it("Start gleich Ziel: Gleichstand zaehlt", () => {
    expect(zielErreicht(78, 78, 78)).toBe(true);
  });

  it("ohne Start nie erreicht", () => {
    expect(zielErreicht(null, 78, 78)).toBe(false);
  });
});
