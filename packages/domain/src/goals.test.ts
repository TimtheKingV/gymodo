import { describe, expect, it } from "vitest";
import { pruefeZiel } from "./goals.js";

describe("pruefeZiel", () => {
  it("nimmt ein gueltiges Wochenziel", () => {
    expect(pruefeZiel({ kind: "weekly_days", targetValue: 3 })).toEqual({
      kind: "weekly_days",
      targetValue: 3,
    });
  });

  it("nimmt ein gueltiges Zielgewicht", () => {
    expect(pruefeZiel({ kind: "target_weight", targetValue: 78 })).toEqual({
      kind: "target_weight",
      targetValue: 78,
    });
  });

  it("weist ein Wochenziel von 0 Tagen ab", () => {
    expect(() => pruefeZiel({ kind: "weekly_days", targetValue: 0 })).toThrow();
  });

  it("weist ein Wochenziel von 8 Tagen ab", () => {
    expect(() => pruefeZiel({ kind: "weekly_days", targetValue: 8 })).toThrow();
  });

  it("weist ein Wochenziel mit Nachkommastelle ab", () => {
    expect(() => pruefeZiel({ kind: "weekly_days", targetValue: 2.5 })).toThrow();
  });

  it("weist ein Zielgewicht unter 20 kg ab", () => {
    expect(() => pruefeZiel({ kind: "target_weight", targetValue: 19.5 })).toThrow();
  });

  it("weist ein Zielgewicht ueber 400 kg ab", () => {
    expect(() => pruefeZiel({ kind: "target_weight", targetValue: 400.5 })).toThrow();
  });

  it("weist ein Zielgewicht mit zwei Nachkommastellen ab", () => {
    expect(() => pruefeZiel({ kind: "target_weight", targetValue: 78.25 })).toThrow();
  });

  it("weist eine unbekannte Zielsorte ab", () => {
    expect(() => pruefeZiel({ kind: "unbekannt", targetValue: 3 })).toThrow();
  });
});
