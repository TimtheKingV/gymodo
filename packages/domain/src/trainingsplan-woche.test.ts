import { describe, expect, it } from "vitest";
import { DomainError } from "./errors.js";
import { kraftAnzahl, pruefeWoche, verteileKraft, type Wochentag } from "./trainingsplan-woche.js";

describe("kraftAnzahl", () => {
  it("zieht Kurs- und Cardio-Tage von den Trainingstagen ab", () => {
    expect(kraftAnzahl(3, [1], [7])).toEqual({ anzahl: 1, angehoben: false });
    expect(kraftAnzahl(4, [1], [7])).toEqual({ anzahl: 2, angehoben: false });
  });

  it("hebt auf mindestens einen Krafttag an und meldet das", () => {
    expect(kraftAnzahl(2, [1], [7])).toEqual({ anzahl: 1, angehoben: true });
  });

  it("zaehlt doppelte Tage nur einmal", () => {
    expect(kraftAnzahl(3, [1, 1], [])).toEqual({ anzahl: 2, angehoben: false });
  });
});

describe("verteileKraft", () => {
  it("verteilt gleichmaessig statt greedy", () => {
    expect(verteileKraft([1, 7], 2)).toEqual([3, 5]);
  });
  it("nimmt bei einem Tag die Mitte der groessten Luecke, bei Gleichstand den fruehen", () => {
    expect(verteileKraft([1, 7], 1)).toEqual([4]);
  });
  it("startet ohne Belegung bei Montag", () => {
    expect(verteileKraft([], 3)).toEqual([1, 3, 5]);
  });
  it("liefert nichts, wenn alle Tage belegt sind", () => {
    expect(verteileKraft([1, 2, 3, 4, 5, 6, 7], 1)).toEqual([]);
  });
  it("liefert alle freien Tage, wenn mehr verlangt sind als frei", () => {
    expect(verteileKraft([1, 2, 3, 4, 5], 4)).toEqual([6, 7]);
  });
});

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
