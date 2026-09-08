import { describe, expect, it } from "vitest";
import { blockPaare, zuVorschlag } from "./abschluss.js";

describe("blockPaare", () => {
  it("fasst Saetze zu Paaren aus Geraet und Uebung zusammen", () => {
    const paare = blockPaare([
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m2", exercise_id: "e2" },
    ]);

    expect(paare).toEqual([
      { machineId: "m1", exerciseId: "e1" },
      { machineId: "m2", exerciseId: "e2" },
    ]);
  });

  it("haelt dasselbe Geraet mit zwei Uebungen auseinander", () => {
    const paare = blockPaare([
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m1", exercise_id: "e2" },
    ]);

    expect(paare).toHaveLength(2);
  });

  it("behaelt die Reihenfolge des ersten Auftretens", () => {
    const paare = blockPaare([
      { machine_id: "m2", exercise_id: "e2" },
      { machine_id: "m1", exercise_id: "e1" },
      { machine_id: "m2", exercise_id: "e2" },
    ]);

    expect(paare[0]).toEqual({ machineId: "m2", exerciseId: "e2" });
  });

  it("liefert fuer eine Session ohne Saetze nichts", () => {
    expect(blockPaare([])).toEqual([]);
  });
});

describe("zuVorschlag", () => {
  const basis = {
    machineId: "m1",
    exerciseId: "e1",
    suggestion: {
      algoVersion: "v1",
      resultWeightKg: 82.5,
      reasonCode: "korridor_oben_erreicht" as const,
      inputs: {
        targetRepsMin: 8,
        targetRepsMax: 12,
        weightStepKg: 2.5,
        minWeightKg: 5,
        maxWeightKg: 150,
        currentWeightKg: 80,
        consideredBlocks: 1,
      },
    },
  };

  it("rechnet das Delta aus Vorschlag und bisherigem Gewicht", () => {
    expect(zuVorschlag(basis).deltaKg).toBe(2.5);
  });

  it("laesst das Delta offen, wenn es keinen Vorschlag gibt", () => {
    const ohne = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultWeightKg: null,
        reasonCode: "problem_gemeldet" as const,
      },
    };

    expect(zuVorschlag(ohne).deltaKg).toBeNull();
    expect(zuVorschlag(ohne).resultWeightKg).toBeNull();
    expect(zuVorschlag(ohne).reasonCode).toBe("problem_gemeldet");
  });

  it("laesst das Delta offen, wenn es kein bisheriges Gewicht gibt", () => {
    const ersterKontakt = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        inputs: { ...basis.suggestion.inputs, currentWeightKg: null },
      },
    };

    expect(zuVorschlag(ersterKontakt).deltaKg).toBeNull();
  });

  it("gibt ein negatives Delta unveraendert weiter", () => {
    const runter = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultWeightKg: 77.5,
        reasonCode: "korridor_unten_verfehlt" as const,
      },
    };

    expect(zuVorschlag(runter).deltaKg).toBe(-2.5);
  });
});
