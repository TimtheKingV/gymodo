import { describe, expect, it } from "vitest";
import {
  OHNE_MIT_START,
  feedLage,
  feedZeitplan,
  ohneMitZustand,
  pillenFlug,
  type OhneMitEreignis,
} from "./ohnemit.logik";

const ablauf = (...e: OhneMitEreignis[]) => e.reduce(ohneMitZustand, OHNE_MIT_START);

describe("ohneMitZustand", () => {
  it("folgt der Sonde in beide Richtungen", () => {
    expect(ablauf({ art: "sonde", schneidet: true }).mit).toBe(true);
    expect(ablauf({ art: "sonde", schneidet: true }, { art: "sonde", schneidet: false }).mit).toBe(false);
  });

  it("ein Tipp schaltet um und haelt gegen die Sonde", () => {
    const z = ablauf({ art: "sonde", schneidet: true }, { art: "tipp" }, { art: "sonde", schneidet: true });
    expect(z).toEqual({ mit: false, manuell: true });
  });

  it("verlaesst die Karte den Viewport, gilt wieder die Sonde, und die meldet draussen Ohne", () => {
    const z = ablauf({ art: "tipp" }, { art: "karteWeg" });
    expect(z).toEqual({ mit: false, manuell: false });
    expect(ohneMitZustand(z, { art: "sonde", schneidet: true }).mit).toBe(true);
  });
});

describe("pillenFlug", () => {
  it("fliegt weg von der Mitte", () => {
    const links = pillenFlug(20, 50, 0);
    expect(links.sx).toBeLessThan(0);
    expect(pillenFlug(80, 50, 0).sx).toBeGreaterThan(0);
    expect(pillenFlug(50, 10, 0).sy).toBeLessThan(0);
  });

  it("dreht abwechselnd zwischen 24 und 32 Grad und staffelt 15 ms", () => {
    const winkel = Array.from({ length: 10 }, (_, i) => pillenFlug(30, 30, i).r);
    for (const [i, r] of winkel.entries()) {
      expect(Math.abs(r)).toBeGreaterThanOrEqual(24);
      expect(Math.abs(r)).toBeLessThanOrEqual(32);
      expect(Math.sign(r)).toBe(i % 2 === 0 ? 1 : -1);
    }
    expect(pillenFlug(30, 30, 9).verzoegerung).toBe(135);
  });

  it("liefert in der Mitte keine NaN", () => {
    const m = pillenFlug(50, 50, 3);
    expect(Number.isFinite(m.sx) && Number.isFinite(m.sy)).toBe(true);
  });
});

describe("feedZeitplan", () => {
  it("ein Durchgang: 120 ms Anlauf, 1100 halten, 480 gleiten", () => {
    expect(feedZeitplan(4)).toEqual([1220, 2800, 4380]);
    expect(feedZeitplan(1)).toEqual([]);
  });
});

describe("feedLage", () => {
  it("aktueller Eintrag in Originalgroesse, Nachbarn klein und blass, Fernere unsichtbar", () => {
    expect(feedLage(0)).toEqual({ versatz: 0, skala: 1, deckkraft: 1 });
    expect(feedLage(1)).toEqual({ versatz: 1, skala: 0.55, deckkraft: 0.28 });
    expect(feedLage(-2).deckkraft).toBe(0);
    expect(feedLage(-2).versatz).toBe(-1.6);
  });
});
