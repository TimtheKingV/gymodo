import { describe, expect, it } from "vitest";
import {
  ABSCHLUSS_ZEITFENSTER_MS,
  ausGespeichertenZeilen,
  blockPaare,
  zuVorschlag,
  type Blockeinheiten,
  type GespeicherteVorschlagZeile,
} from "./abschluss.js";

const kg: Blockeinheiten = { loadUnit: "kg", secondaryUnit: null };
const laufband: Blockeinheiten = { loadUnit: "kmh", secondaryUnit: "pct" };

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
      resultLoad: 82.5,
      resultSecondaryLoad: null,
      reasonCode: "korridor_oben_erreicht" as const,
      inputs: {
        targetMin: 8,
        targetMax: 12,
        loadStep: 2.5,
        loadMin: 5,
        loadMax: 150,
        currentLoad: 80,
        currentSecondaryLoad: null,
        consideredBlocks: 1,
      },
    },
    einheiten: kg,
  };

  it("rechnet das Delta aus Vorschlag und bisherigem Gewicht", () => {
    expect(zuVorschlag(basis).deltaLoad).toBe(2.5);
  });

  it("laesst das Delta offen, wenn es keinen Vorschlag gibt", () => {
    const ohne = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultLoad: null,
        reasonCode: "problem_gemeldet" as const,
      },
    };

    expect(zuVorschlag(ohne).deltaLoad).toBeNull();
    expect(zuVorschlag(ohne).resultLoad).toBeNull();
    expect(zuVorschlag(ohne).reasonCode).toBe("problem_gemeldet");
  });

  it("laesst das Delta offen, wenn es kein bisheriges Gewicht gibt", () => {
    const ersterKontakt = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        inputs: { ...basis.suggestion.inputs, currentLoad: null },
      },
    };

    expect(zuVorschlag(ersterKontakt).deltaLoad).toBeNull();
  });

  it("traegt Einheiten und Nebenbelastung des Geraets", () => {
    const cardio = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultLoad: 9,
        resultSecondaryLoad: 6,
        inputs: { ...basis.suggestion.inputs, currentLoad: 8.5, currentSecondaryLoad: 6 },
      },
      einheiten: laufband,
    };

    const vorschlag = zuVorschlag(cardio);
    expect(vorschlag.loadUnit).toBe("kmh");
    expect(vorschlag.secondaryUnit).toBe("pct");
    expect(vorschlag.secondaryLoad).toBe(6);
    expect(vorschlag.deltaLoad).toBe(0.5);
  });

  it("gibt ein negatives Delta unveraendert weiter", () => {
    const runter = {
      ...basis,
      suggestion: {
        ...basis.suggestion,
        resultLoad: 77.5,
        reasonCode: "korridor_unten_verfehlt" as const,
      },
    };

    expect(zuVorschlag(runter).deltaLoad).toBe(-2.5);
  });
});

describe("ausGespeichertenZeilen", () => {
  const abschlussZeit = "2026-09-08T18:00:00.000Z";
  const paare = [
    { machineId: "m1", exerciseId: "e1" },
    { machineId: "m1", exerciseId: "e2" },
  ];
  const einheiten = new Map<string, Blockeinheiten>([["m1", kg]]);

  function zeile(
    ueber: Partial<GespeicherteVorschlagZeile> = {},
  ): GespeicherteVorschlagZeile {
    return {
      machine_id: "m1",
      exercise_id: "e1",
      created_at: "2026-09-08T18:00:01.000Z",
      algo_version: "v1",
      result_load: 82.5,
      reason_code: "korridor_oben_erreicht",
      inputs: { currentLoad: 80 },
      ...ueber,
    };
  }

  it("rechnet das Delta aus der festgehaltenen Eingabe zurueck", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile()],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege).toEqual([
      {
        machineId: "m1",
        exerciseId: "e1",
        resultLoad: 82.5,
        deltaLoad: 2.5,
        secondaryLoad: null,
        loadUnit: "kg",
        secondaryUnit: null,
        reasonCode: "korridor_oben_erreicht",
        algoVersion: "v1",
      },
    ]);
  });

  it("liest die Nebenbelastung aus der festgehaltenen Eingabe zurueck", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ result_load: 9, inputs: { currentLoad: 8.5, currentSecondaryLoad: "6.00" } })],
      abschlussZeit,
      new Map([["m1", laufband]]),
    );

    expect(vorschlaege[0]).toMatchObject({
      resultLoad: 9,
      deltaLoad: 0.5,
      secondaryLoad: 6,
      loadUnit: "kmh",
      secondaryUnit: "pct",
    });
  });

  it("laesst einen Block weg, dessen Geraet keine Einheit hat -- kg wird nie geraten", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile()],
      abschlussZeit,
      new Map(),
    );

    expect(vorschlaege).toEqual([]);
  });

  it("laesst das Delta einer Zeile aus Version 1.0.0 offen, zeigt den Vorschlag aber", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ inputs: { currentWeightKg: 80 } as unknown as GespeicherteVorschlagZeile["inputs"] })],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege[0]!.resultLoad).toBe(82.5);
    expect(vorschlaege[0]!.deltaLoad).toBeNull();
  });

  it("nimmt die aelteste Zeile ab dem Abschluss, nicht eine spaetere vom Geraetescan", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [
        // Innerhalb des Fensters, aber spaeter -- ein Geraetescan.
        zeile({ created_at: "2026-09-08T18:04:00.000Z", result_load: 85 }),
        zeile({ created_at: "2026-09-08T18:00:01.000Z", result_load: 82.5 }),
      ],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege[0]!.resultLoad).toBe(82.5);
  });

  it("nimmt eine Zeile knapp VOR dem Abschluss -- der Uhrendifferenz-Fall", () => {
    // completed_at kommt aus der Node-Uhr, created_at aus der Datenbank.
    // Laeuft die Node-Uhr eine Sekunde vor, liegt die Zeile des Abschlusses
    // rechnerisch davor -- sie gehoert trotzdem dazu.
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ created_at: "2026-09-08T17:59:59.000Z", result_load: 82.5 })],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege[0]!.resultLoad).toBe(82.5);
  });

  it("ordnet KEINE Zeile aus einer anderen Einheit zu", () => {
    // Der Punkt der Zeitschranke: eine Zeile vom Vortag gehoert zu einer
    // anderen Einheit. Ein fehlender Vorschlag ist eine Luecke, ein
    // fremder eine Falschaussage.
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [
        zeile({ created_at: "2026-09-07T10:00:00.000Z", result_load: 75 }),
        zeile({ created_at: "2026-09-08T20:00:00.000Z", result_load: 90 }),
      ],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege).toEqual([]);
  });

  it("zieht die Grenze bei ABSCHLUSS_ZEITFENSTER_MS", () => {
    const gerade = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ created_at: "2026-09-08T18:04:59.000Z", result_load: 82.5 })],
      abschlussZeit,
      einheiten,
    );
    const knappDarueber = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ created_at: "2026-09-08T18:05:01.000Z", result_load: 82.5 })],
      abschlussZeit,
      einheiten,
    );

    expect(ABSCHLUSS_ZEITFENSTER_MS).toBe(5 * 60 * 1000);
    expect(gerade).toHaveLength(1);
    expect(knappDarueber).toEqual([]);
  });

  it("laesst einen Block weg, zu dem nichts festgehalten wurde", () => {
    expect(ausGespeichertenZeilen(paare, [zeile()], abschlussZeit, einheiten)).toHaveLength(
      1,
    );
  });

  it("haelt zwei Uebungen an derselben Maschine auseinander", () => {
    const vorschlaege = ausGespeichertenZeilen(
      paare,
      [
        zeile({ exercise_id: "e2", result_load: 40 }),
        zeile({ exercise_id: "e1", result_load: 82.5 }),
      ],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege.map((v) => v.resultLoad)).toEqual([82.5, 40]);
  });

  it("liefert kein Delta ohne bisherige Belastung", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ result_load: null, inputs: { currentLoad: null } })],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege[0]!.deltaLoad).toBeNull();
    expect(vorschlaege[0]!.resultLoad).toBeNull();
  });

  it("nimmt numerische Werte auch als Text entgegen", () => {
    const vorschlaege = ausGespeichertenZeilen(
      [paare[0]!],
      [zeile({ result_load: "82.50", inputs: { currentLoad: "80.00" } })],
      abschlussZeit,
      einheiten,
    );

    expect(vorschlaege[0]!.deltaLoad).toBe(2.5);
  });
});
