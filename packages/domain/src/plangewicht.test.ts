import { describe, expect, it } from "vitest";
import {
  berechnePlanGewicht,
  type PlanGewichtEingabe,
} from "./plangewicht.js";
import type { WorkoutSetInput } from "./progression.js";

const satz = (load: number, volume: number, rir: number | null = null, problemFlag = false): WorkoutSetInput => ({
  load,
  secondaryLoad: null,
  volume,
  rir,
  problemFlag,
});

const drei = (load: number, volume: number, letzterRir: number | null): WorkoutSetInput[] => [
  satz(load, volume),
  satz(load, volume),
  satz(load, volume, letzterRir),
];

const basis = (over: Partial<PlanGewichtEingabe> = {}): PlanGewichtEingabe => ({
  position: { wdhVon: 8, wdhBis: 12, reserveVon: 1 },
  geraet: { loadStep: 2.5, loadMin: 5, loadMax: 100 },
  block: drei(40, 12, 2),
  vorher: null,
  aktuellesZiel: { load: 40, secondaryLoad: null },
  ...over,
});

describe("berechnePlanGewicht", () => {
  it("steigert, wenn alle Saetze oben sind und der letzte RIR hat", () => {
    expect(berechnePlanGewicht(basis())).toMatchObject({ load: 42.5, grund: "korridor_oben_erreicht" });
  });

  it("bleibt bei RIR 0", () => {
    expect(berechnePlanGewicht(basis({ block: drei(40, 12, 0) }))).toMatchObject({
      load: 40,
      grund: "im_korridor",
    });
  });

  it("ohne RIR zaehlen zwei Einheiten oben", () => {
    const e = basis({ block: drei(40, 12, null), vorher: drei(40, 12, null) });
    expect(berechnePlanGewicht(e).load).toBe(42.5);
    expect(berechnePlanGewicht({ ...e, vorher: null }).load).toBe(40);
  });

  it("senkt erst bei zweimal verfehltem Korridor", () => {
    const unten = [satz(40, 6), satz(40, 8), satz(40, 8)];
    const e = basis({ block: unten, vorher: unten });
    expect(berechnePlanGewicht(e)).toMatchObject({ load: 37.5, grund: "korridor_unten_verfehlt" });
    expect(berechnePlanGewicht({ ...e, vorher: null }).load).toBe(40);
  });

  it("Problemflag schlaegt jede Steigerung", () => {
    const block = [satz(40, 12), satz(40, 12, null, true), satz(40, 12, 2)];
    expect(berechnePlanGewicht(basis({ block }))).toMatchObject({ load: 40, grund: "problem_gemeldet" });
  });

  it("meldet die Geraetegrenze", () => {
    const e = basis({ block: drei(100, 12, 2), aktuellesZiel: { load: 100, secondaryLoad: null } });
    expect(berechnePlanGewicht(e)).toMatchObject({ load: 100, grund: "geraetegrenze_erreicht" });
  });

  it("rastet den Istwert auf die naechste Stufe", () => {
    const e = basis({ block: drei(41, 10, 2) });
    expect(berechnePlanGewicht(e).load).toBe(40);
    expect(berechnePlanGewicht({ ...e, block: drei(41.3, 10, 2) }).load).toBe(42.5);
  });

  it("ohne Block kein Verlauf und keine Aenderung", () => {
    expect(berechnePlanGewicht(basis({ block: [] }))).toMatchObject({ load: 40, grund: "kein_verlauf" });
    expect(berechnePlanGewicht(basis({ block: [], aktuellesZiel: null }))).toMatchObject({
      load: null,
      grund: "kein_verlauf",
    });
  });

  it("uneinheitliche Last ist uneindeutig, Ziel bleibt", () => {
    const block = [satz(40, 12), satz(42.5, 12), satz(40, 12, 2)];
    expect(berechnePlanGewicht(basis({ block }))).toMatchObject({ load: 40, grund: "daten_uneindeutig" });
  });

  it("rechnet vom Ist, nicht vom Ziel", () => {
    expect(berechnePlanGewicht(basis({ block: drei(45, 12, 2) })).load).toBe(47.5);
  });

  it("steigert die Nebenlast nie", () => {
    const block = drei(40, 12, 2).map((s) => ({ ...s, secondaryLoad: 6 }));
    expect(berechnePlanGewicht(basis({ block })).secondaryLoad).toBe(6);
  });
});
