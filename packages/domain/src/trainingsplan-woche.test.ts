import { describe, expect, it } from "vitest";
import { DomainError } from "./errors.js";
import { pruefeWoche, type Wochentag } from "./trainingsplan-woche.js";

describe("pruefeWoche", () => {
  const ok = { kursTage: [1] as Wochentag[], cardioTage: [7] as Wochentag[], kraftTage: [3, 5] as Wochentag[] };
  const wirft = (w: Parameters<typeof pruefeWoche>[0]) => {
    try {
      pruefeWoche(w);
    } catch (e) {
      expect(e).toBeInstanceOf(DomainError);
      expect((e as DomainError).code).toBe("validation_failed");
      return;
    }
    throw new Error("keine Ausnahme");
  };

  it("lehnt eine Woche ab, in der Kurse und Cardio alle sieben Tage belegen", () => {
    try {
      pruefeWoche({ kursTage: [1, 2, 3, 4], cardioTage: [5, 6, 7], kraftTage: [] });
    } catch (e) {
      expect((e as DomainError).code).toBe("validation_failed");
      expect((e as DomainError).detail).toEqual({ grund: "keine_freien_tage" });
      return;
    }
    throw new Error("keine Ausnahme");
  });

  it("akzeptiert eine stimmige Woche", () => {
    expect(() => pruefeWoche(ok)).not.toThrow();
  });
  it("wirft bei Ueberschneidungen", () => {
    wirft({ ...ok, cardioTage: [1] });
    wirft({ ...ok, kraftTage: [1] });
    wirft({ ...ok, kraftTage: [7] });
  });
  it("wirft bei Tag ausserhalb 1-7", () => {
    wirft({ ...ok, kursTage: [8 as Wochentag] });
    wirft({ ...ok, kraftTage: [0 as Wochentag] });
  });
  it("wirft bei doppeltem Tag", () => {
    wirft({ ...ok, kraftTage: [3, 3] });
  });
});
