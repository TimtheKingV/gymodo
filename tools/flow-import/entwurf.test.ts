import { describe, expect, it } from "vitest";
import { pruefeFlowEntwurf } from "./entwurf";

function gueltig() {
  return {
    key: "mobility-10-min",
    titel: "Mobility 10 Min",
    beschreibung: null,
    level: "einsteiger",
    quelle: { url: "https://www.youtube.com/watch?v=abc", kanal: "Kanal" },
    schritte: [
      { name: "Katze", beschreibung: null, workS: 40, restS: 5, istWarmup: true },
      { name: "Kuh", beschreibung: "ruhig", workS: 40, restS: 0, istWarmup: false },
    ],
  };
}

describe("pruefeFlowEntwurf", () => {
  it("akzeptiert einen gueltigen Entwurf", () => {
    const e = pruefeFlowEntwurf(gueltig());
    expect(e.schritte).toHaveLength(2);
    expect(e.key).toBe("mobility-10-min");
  });

  it("wirft ohne Schritte", () => {
    expect(() => pruefeFlowEntwurf({ ...gueltig(), schritte: [] })).toThrow(/Schritt/);
  });

  it("wirft bei workS <= 0", () => {
    const e = gueltig();
    e.schritte[0]!.workS = 0;
    expect(() => pruefeFlowEntwurf(e)).toThrow(/workS/);
  });

  it("wirft bei restS < 0", () => {
    const e = gueltig();
    e.schritte[0]!.restS = -1;
    expect(() => pruefeFlowEntwurf(e)).toThrow(/restS/);
  });

  it("wirft bei nicht ganzzahligen Zeiten", () => {
    const e = gueltig();
    e.schritte[0]!.workS = 40.5;
    expect(() => pruefeFlowEntwurf(e)).toThrow(/ganzzahlig/);
  });

  it("wirft bei leerem Namen", () => {
    const e = gueltig();
    e.schritte[0]!.name = "  ";
    expect(() => pruefeFlowEntwurf(e)).toThrow(/Name/);
  });

  it("wirft bei ungueltigem key", () => {
    expect(() => pruefeFlowEntwurf({ ...gueltig(), key: "Mobility 10" })).toThrow(/key/);
  });

  it("wirft wenn der letzte Schritt Pause hat", () => {
    const e = gueltig();
    e.schritte[1]!.restS = 5;
    expect(() => pruefeFlowEntwurf(e)).toThrow(/letzte/);
  });
});
