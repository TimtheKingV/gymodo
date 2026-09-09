import { describe, expect, it } from "vitest";
import {
  ABSCHLUSS_ZEITFENSTER_MS,
  ausGespeichertenZeilen,
  blockPaare,
  zuVorschlag,
  type GespeicherteVorschlagZeile,
} from "./abschluss.js";

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

describe("ausGespeichertenZeilen", () => {
  const abschlussZeit = "2026-09-08T18:00:00.000Z";
  const paare = [
    { machineId: "m1", exerciseId: "e1" },
    { machineId: "m1", exerciseId: "e2" },
  ];

  function zeile(
    ueber: Partial<GespeicherteVorschlagZeile> = {},
  ): GespeicherteVorschlagZeile {
    return {
      machine_id: "m1",
      exercise_id: "e1",
      created_at: "2026-09-08T18:00:01.000Z",
      algo_version: "v1",
      result_weight_kg: 82.5,
      reason_code: "korridor_oben_erreicht",
      inputs: { currentWeightKg: 80 },
      ...ueber,
    };
  }

  it("rechnet das Delta aus der festgehaltenen Eingabe zurueck", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile()],
      abschlussZeit,
    );

    expect(vorschlaege).toEqual([
      {
        machineId: "m1",
        exerciseId: "e1",
        resultWeightKg: 82.5,
        deltaKg: 2.5,
        reasonCode: "korridor_oben_erreicht",
        algoVersion: "v1",
      },
    ]);
  });

  it("nimmt die aelteste Zeile ab dem Abschluss, nicht eine spaetere vom Geraetescan", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [
        // Innerhalb des Fensters, aber spaeter -- ein Geraetescan.
        zeile({ created_at: "2026-09-08T18:04:00.000Z", result_weight_kg: 85 }),
        zeile({ created_at: "2026-09-08T18:00:01.000Z", result_weight_kg: 82.5 }),
      ],
      abschlussZeit,
    );

    expect(vorschlaege[0]!.resultWeightKg).toBe(82.5);
  });

  it("nimmt eine Zeile knapp VOR dem Abschluss -- der Uhrendifferenz-Fall", () => {
    // completed_at kommt aus der Node-Uhr, created_at aus der Datenbank.
    // Laeuft die Node-Uhr eine Sekunde vor, liegt die Zeile des Abschlusses
    // rechnerisch davor -- sie gehoert trotzdem dazu.
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ created_at: "2026-09-08T17:59:59.000Z", result_weight_kg: 82.5 })],
      abschlussZeit,
    );

    expect(vorschlaege[0]!.resultWeightKg).toBe(82.5);
  });

  it("ordnet KEINE Zeile aus einer anderen Einheit zu", () => {
    // Der Punkt der Zeitschranke: eine Zeile vom Vortag gehoert zu einer
    // anderen Einheit. Ein fehlender Vorschlag ist eine Luecke, ein
    // fremder eine Falschaussage.
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [
        zeile({ created_at: "2026-09-07T10:00:00.000Z", result_weight_kg: 75 }),
        zeile({ created_at: "2026-09-08T20:00:00.000Z", result_weight_kg: 90 }),
      ],
      abschlussZeit,
    );

    expect(vorschlaege).toEqual([]);
  });

  it("zieht die Grenze bei ABSCHLUSS_ZEITFENSTER_MS", () => {
    const gerade = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ created_at: "2026-09-08T18:04:59.000Z", result_weight_kg: 82.5 })],
      abschlussZeit,
    );
    const knappDarueber = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ created_at: "2026-09-08T18:05:01.000Z", result_weight_kg: 82.5 })],
      abschlussZeit,
    );

    expect(ABSCHLUSS_ZEITFENSTER_MS).toBe(5 * 60 * 1000);
    expect(gerade).toHaveLength(1);
    expect(knappDarueber).toEqual([]);
  });

  it("laesst einen Block weg, zu dem nichts festgehalten wurde", () => {
    expect(ausGespeichertenZeilen(paare, [zeile()], abschlussZeit)).toHaveLength(
      1,
    );
  });

  it("haelt zwei Uebungen an derselben Maschine auseinander", () => {
    const vorschlaege = ausGespeichertenZeilen(
      paare,
      [
        zeile({ exercise_id: "e2", result_weight_kg: 40 }),
        zeile({ exercise_id: "e1", result_weight_kg: 82.5 }),
      ],
      abschlussZeit,
    );

    expect(vorschlaege.map((v) => v.resultWeightKg)).toEqual([82.5, 40]);
  });

  it("liefert kein Delta ohne bisheriges Gewicht", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ result_weight_kg: null, inputs: { currentWeightKg: null } })],
      abschlussZeit,
    );

    expect(vorschlaege[0]!.deltaKg).toBeNull();
    expect(vorschlaege[0]!.resultWeightKg).toBeNull();
  });

  it("nimmt numerische Werte auch als Text entgegen", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ result_weight_kg: "82.50", inputs: { currentWeightKg: "80.00" } })],
      abschlussZeit,
    );

    expect(vorschlaege[0]!.deltaKg).toBe(2.5);
  });
});
