import { describe, expect, it } from "vitest";
import { aenderungZumLetzten, bloeckeUm, folgeEinheiten, hatZielgewicht } from "./plangewichte.js";
import type { SatzZeile } from "./progression.js";
import type { PlanPosition } from "./trainingsplan-generator.js";

describe("folgeEinheiten (G3, G21)", () => {
  it("nimmt die naechsten drei nach der abgeschlossenen, zyklisch", () => {
    expect(folgeEinheiten(["A", "B", "C", "D", "E"], "A")).toEqual(["B", "C", "D"]);
    expect(folgeEinheiten(["A", "B", "C", "D", "E"], "D")).toEqual(["E", "A", "B"]);
  });
  it("bei weniger Einheiten alle, auch die abgeschlossene selbst", () => {
    expect(folgeEinheiten(["A", "B"], "A")).toEqual(["B", "A"]);
    expect(folgeEinheiten(["A"], "A")).toEqual(["A"]);
    expect(folgeEinheiten(["A", "B", "C"], "B")).toEqual(["C", "A", "B"]);
  });
  it("unbekannte Einheit beginnt vorn", () => {
    expect(folgeEinheiten(["A", "B", "C", "D"], "X")).toEqual(["A", "B", "C"]);
    expect(folgeEinheiten([], "A")).toEqual([]);
  });
});

describe("aenderungZumLetzten (G17)", () => {
  it("Ziel minus letztes Gewicht, gerundet", () => {
    expect(aenderungZumLetzten(42.5, 40)).toBe(2.5);
    expect(aenderungZumLetzten(37.5, 40)).toBe(-2.5);
    expect(aenderungZumLetzten(0.3, 0.1)).toBe(0.2);
  });
  it("null ohne Vorgaenger oder bei Gleichheit", () => {
    expect(aenderungZumLetzten(40, null)).toBeNull();
    expect(aenderungZumLetzten(40, 40)).toBeNull();
  });
});

const zeile = (session: string, minute: number, load: number): SatzZeile => ({
  session_id: session,
  performed_at: new Date(Date.UTC(2026, 9, 1, 10, minute)).toISOString(),
  load,
  secondary_load: null,
  volume: 10,
  rir: null,
  problem_flag: false,
});

describe("bloeckeUm", () => {
  // Absteigend wie aus der Datenbank.
  const historie = [zeile("s3", 50, 50), zeile("s2", 31, 45), zeile("s2", 30, 45), zeile("s1", 10, 40)];

  it("Block der Session, Vorgaenger und ob ein neuerer existiert", () => {
    const um = bloeckeUm(historie, "s2")!;
    expect(um.block.sets.map((s) => s.load)).toEqual([45, 45]);
    expect(um.vorher?.sets.map((s) => s.load)).toEqual([40]);
    expect(um.neuerVorhanden).toBe(true);
    expect(bloeckeUm(historie, "s3")!.neuerVorhanden).toBe(false);
    expect(bloeckeUm(historie, "s1")!.vorher).toBeNull();
  });
  it("null, wenn die Session dort keinen Satz hat", () => {
    expect(bloeckeUm(historie, "s9")).toBeNull();
  });
});

describe("hatZielgewicht", () => {
  const p = (x: Partial<PlanPosition>) => ({ rolle: "pflicht", baustein: "druecken", wdhVon: 8, wdhBis: 12, ...x }) as PlanPosition;
  it("Kraft ja, Cardio nein", () => {
    expect(hatZielgewicht(p({}))).toBe(true);
    expect(hatZielgewicht(p({ rolle: "cardio", baustein: "cardio", wdhVon: null, wdhBis: null }))).toBe(false);
    expect(hatZielgewicht(p({ wdhVon: null }))).toBe(false);
  });
});
