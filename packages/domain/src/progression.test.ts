import { describe, expect, it } from "vitest";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
} from "./progression.js";

/** Beinpresse aus dem Testkatalog: 2,5-kg-Schritte, Korridor 8-12. */
const beinpresse = {
  targetRepsMin: 8,
  targetRepsMax: 12,
  weightStepKg: 2.5,
  minWeightKg: 5,
  maxWeightKg: 150,
};

type TestSet = { reps: number; rir?: number | null; problemFlag?: boolean };

/** Baut einen Block mit durchgehend gleichem Gewicht. */
function block(performedOn: string, weightKg: number, sets: TestSet[]) {
  return {
    performedOn,
    sets: sets.map((set) => ({
      weightKg,
      reps: set.reps,
      rir: set.rir ?? null,
      problemFlag: set.problemFlag ?? false,
    })),
  };
}

describe("suggestNextWeight", () => {
  it("gibt beim Erstkontakt keinen Vorschlag ab", () => {
    const suggestion = suggestNextWeight({ ...beinpresse, history: [] });

    expect(suggestion.resultWeightKg).toBeNull();
    expect(suggestion.reasonCode).toBe("kein_verlauf");
  });

  it("haelt das Gewicht, solange die Wiederholungen im Korridor liegen", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [block("2026-08-27", 80, [{ reps: 10 }, { reps: 9 }])],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("steigert um einen Geraeteschritt, wenn der Korridor mit Reserve ausgeschoepft ist", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [
          { reps: 12, rir: 2 },
          { reps: 12, rir: 1 },
        ]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(82.5);
    expect(suggestion.reasonCode).toBe("korridor_oben_erreicht");
  });

  it("steigert ohne erfasste Reserve erst nach zwei Einheiten am oberen Ende", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [{ reps: 12 }, { reps: 12 }]),
        block("2026-08-20", 80, [{ reps: 12 }, { reps: 13 }]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(82.5);
    expect(suggestion.reasonCode).toBe("korridor_oben_erreicht");
  });

  it("steigert nicht, wenn im juengsten Block ein Problem gemeldet wurde", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [
          { reps: 12, rir: 2 },
          { reps: 12, rir: 2, problemFlag: true },
        ]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("problem_gemeldet");
  });

  it("reduziert, wenn der erste Satz zweimal in Folge unter dem Korridor blieb", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [{ reps: 6 }, { reps: 5 }]),
        block("2026-08-20", 80, [{ reps: 7 }, { reps: 6 }]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(77.5);
    expect(suggestion.reasonCode).toBe("korridor_unten_verfehlt");
  });

  it("kappt die Steigerung am Geraetemaximum", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      maxWeightKg: 80,
      history: [block("2026-08-27", 80, [{ reps: 12, rir: 2 }])],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("geraetegrenze_erreicht");
  });

  it("schlaegt nichts vor, wenn die Saetze eines Blocks verschiedene Gewichte tragen", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        {
          performedOn: "2026-08-27",
          sets: [
            { weightKg: 80, reps: 12, rir: 2, problemFlag: false },
            { weightKg: 77.5, reps: 12, rir: 2, problemFlag: false },
          ],
        },
      ],
    });

    expect(suggestion.resultWeightKg).toBeNull();
    expect(suggestion.reasonCode).toBe("daten_uneindeutig");
  });

  it("rastet ein Gewicht neben dem Raster auf eine einstellbare Stufe", () => {
    // 81,0 kg laesst sich an einem Geraet mit 2,5-kg-Platten nicht einstellen.
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [block("2026-08-27", 81, [{ reps: 12, rir: 2 }])],
    });

    expect(suggestion.resultWeightKg).toBe(82.5);
  });

  it("gibt Algorithmusversion und Eingaben zum Nachvollziehen mit aus", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [{ reps: 10 }]),
        block("2026-08-20", 80, [{ reps: 10 }]),
      ],
    });

    expect(suggestion.algoVersion).toBe(PROGRESSION_ALGO_VERSION);
    expect(suggestion.inputs).toEqual({
      targetRepsMin: 8,
      targetRepsMax: 12,
      weightStepKg: 2.5,
      minWeightKg: 5,
      maxWeightKg: 150,
      currentWeightKg: 80,
      consideredBlocks: 2,
    });
  });
});

/**
 * Randfaelle. Sie halten die Konservativitaet fest: jeder einzelne beschreibt
 * eine Situation, in der die Regel gerade NICHT steigern darf.
 */
describe("suggestNextWeight -- Grenzen der Steigerung", () => {
  it("steigert nicht, wenn die Reserve ausgeschoepft war", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [block("2026-08-27", 80, [{ reps: 12, rir: 0 }])],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("steigert ohne Reserve nicht nach einer einzelnen Einheit", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [block("2026-08-27", 80, [{ reps: 12 }, { reps: 12 }])],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("steigert nicht, wenn ein einzelner Satz unter dem oberen Ende blieb", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [
          { reps: 12, rir: 2 },
          { reps: 11, rir: 2 },
        ]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("steigert nicht, wenn die beiden Einheiten auf verschiedenen Gewichten lagen", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [{ reps: 12 }]),
        block("2026-08-20", 75, [{ reps: 12 }]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("reduziert nicht nach einer einzelnen schwachen Einheit", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 80, [{ reps: 6 }]),
        block("2026-08-20", 80, [{ reps: 10 }]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(80);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("kappt die Reduzierung am Geraeteminimum", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [
        block("2026-08-27", 5, [{ reps: 4 }]),
        block("2026-08-20", 5, [{ reps: 5 }]),
      ],
    });

    expect(suggestion.resultWeightKg).toBe(5);
    expect(suggestion.reasonCode).toBe("geraetegrenze_erreicht");
  });

  it("schlaegt bei einem Block ohne Saetze nichts vor", () => {
    const suggestion = suggestNextWeight({
      ...beinpresse,
      history: [{ performedOn: "2026-08-27", sets: [] }],
    });

    expect(suggestion.resultWeightKg).toBeNull();
    expect(suggestion.reasonCode).toBe("daten_uneindeutig");
  });

  it("liefert bei gleicher Eingabe zweimal dasselbe Ergebnis", () => {
    const input = {
      ...beinpresse,
      history: [block("2026-08-27", 80, [{ reps: 12, rir: 2 }])],
    };

    expect(suggestNextWeight(input)).toEqual(suggestNextWeight(input));
  });
});
