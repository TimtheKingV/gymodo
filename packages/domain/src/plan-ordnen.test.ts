import { describe, expect, it } from "vitest";
import type { PlanEinheit, PlanPosition } from "./trainingsplan-generator.js";
import { uebungMinuten } from "./trainingsplan-zeit.js";
import { minutenNachOrdnen } from "./trainingsplan.js";

function pos(key: string, teil: Partial<PlanPosition>): PlanPosition {
  return {
    key,
    baustein: "brust",
    rolle: "pflicht",
    exerciseId: `ex-${key}`,
    modelId: `m-${key}`,
    typ: "mehrgelenk",
    saetze: 3,
    wdhVon: 8,
    wdhBis: 12,
    reserveVon: 1,
    reserveBis: 3,
    pauseSek: 90,
    aufwaermsatz: false,
    dauerMin: null,
    hauptmuskeln: [],
    ...teil,
  } as PlanPosition;
}

const einheit: PlanEinheit = {
  key: "a",
  geschaetzteMinuten: 40,
  positionen: [
    pos("p0", { typ: "mehrgelenk", saetze: 3 }),
    pos("p1", { typ: "isolation", saetze: 3 }),
    pos("p2", { baustein: "cardio", rolle: "cardio", saetze: 1, dauerMin: 10 }),
  ],
};

describe("minutenNachOrdnen", () => {
  it("bleibt bei reiner Umordnung gleich", () => {
    expect(minutenNachOrdnen(einheit, ["p1", "p0", "p2"])).toBe(40);
  });

  it("zieht die Minuten einer entfernten Kraftuebung ab", () => {
    expect(minutenNachOrdnen(einheit, ["p0", "p2"])).toBe(40 - uebungMinuten("isolation", 3));
  });

  it("zieht bei Cardio die Dauer ab", () => {
    expect(minutenNachOrdnen(einheit, ["p0"])).toBe(40 - uebungMinuten("isolation", 3) - 10);
  });

  it("wird nie negativ", () => {
    expect(minutenNachOrdnen({ ...einheit, geschaetzteMinuten: 5 }, ["p0"])).toBe(0);
  });
});
