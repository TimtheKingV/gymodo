import { describe, expect, it } from "vitest";
import {
  PROGRESSION_ALGO_VERSION,
  suggestNextLoad,
  toBlocks,
  type BlockInput,
  type ProgressionInput,
} from "./progression.js";

/**
 * Zwei Geraete, dieselbe Regel. Jeder Fall laeuft einmal mit der Beinpresse
 * aus dem Testkatalog (2,5-kg-Schritte, Korridor 8-12 Wiederholungen) und
 * einmal mit einem Ergometer (5-W-Schritte, Korridor 20-30 Minuten). Die
 * Erwartungen sind je Geraet dieselben Stufen -- das ist der Beleg, dass die
 * Regel keinen Zweig "wenn Cardio" hat (Cardio-Spec Abschnitt 5.2).
 */
type Geraet = {
  name: string;
  input: Omit<ProgressionInput, "history">;
  /** Ein "normaler" Wert, eine Stufe darueber, eine darunter, ein Wert neben dem Raster. */
  last: number;
  hoch: number;
  runter: number;
  daneben: number;
  /** Umfang: im Korridor, am oberen Ende, ueber dem oberen Ende, unter dem unteren. */
  mitte: number;
  oben: number;
  drueber: number;
  unten: number;
  knappUnten: number;
};

const geraete: Geraet[] = [
  {
    name: "Beinpresse (kg, Wiederholungen)",
    input: { targetMin: 8, targetMax: 12, loadStep: 2.5, loadMin: 5, loadMax: 150 },
    last: 80, hoch: 82.5, runter: 77.5, daneben: 81,
    mitte: 10, oben: 12, drueber: 13, unten: 6, knappUnten: 7,
  },
  {
    name: "Ergometer (Watt, Sekunden)",
    input: { targetMin: 1200, targetMax: 1800, loadStep: 5, loadMin: 25, loadMax: 400 },
    last: 120, hoch: 125, runter: 115, daneben: 122,
    mitte: 1500, oben: 1800, drueber: 1900, unten: 900, knappUnten: 1000,
  },
];

type TestSet = { volume: number; rir?: number | null; problemFlag?: boolean };

/** Baut einen Block mit durchgehend gleicher Belastung (und Nebenbelastung). */
function block(
  performedOn: string,
  load: number,
  sets: TestSet[],
  secondaryLoad: number | null = null,
): BlockInput {
  return {
    performedOn,
    sets: sets.map((set) => ({
      load,
      secondaryLoad,
      volume: set.volume,
      rir: set.rir ?? null,
      problemFlag: set.problemFlag ?? false,
    })),
  };
}

describe.each(geraete)("suggestNextLoad -- $name", (g) => {
  const basis = g.input;

  it("gibt beim Erstkontakt keinen Vorschlag ab", () => {
    const suggestion = suggestNextLoad({ ...basis, history: [] });

    expect(suggestion.resultLoad).toBeNull();
    expect(suggestion.resultSecondaryLoad).toBeNull();
    expect(suggestion.reasonCode).toBe("kein_verlauf");
  });

  it("haelt die Belastung, solange der Umfang im Korridor liegt", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [block("2026-08-27", g.last, [{ volume: g.mitte }, { volume: g.mitte }])],
    });

    expect(suggestion.resultLoad).toBe(g.last);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("steigert um eine Stufe, wenn der Korridor mit Reserve ausgeschoepft ist", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [
        block("2026-08-27", g.last, [
          { volume: g.oben, rir: 2 },
          { volume: g.oben, rir: 1 },
        ]),
      ],
    });

    expect(suggestion.resultLoad).toBe(g.hoch);
    expect(suggestion.reasonCode).toBe("korridor_oben_erreicht");
  });

  it("steigert ohne erfasste Reserve erst nach zwei Einheiten am oberen Ende", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [
        block("2026-08-27", g.last, [{ volume: g.oben }, { volume: g.oben }]),
        block("2026-08-20", g.last, [{ volume: g.oben }, { volume: g.drueber }]),
      ],
    });

    expect(suggestion.resultLoad).toBe(g.hoch);
    expect(suggestion.reasonCode).toBe("korridor_oben_erreicht");
  });

  it("steigert nicht, wenn im juengsten Block ein Problem gemeldet wurde", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [
        block("2026-08-27", g.last, [
          { volume: g.oben, rir: 2 },
          { volume: g.oben, rir: 2, problemFlag: true },
        ]),
      ],
    });

    expect(suggestion.resultLoad).toBe(g.last);
    expect(suggestion.reasonCode).toBe("problem_gemeldet");
  });

  it("reduziert, wenn der erste Satz zweimal in Folge unter dem Korridor blieb", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [
        block("2026-08-27", g.last, [{ volume: g.unten }, { volume: g.unten }]),
        block("2026-08-20", g.last, [{ volume: g.knappUnten }, { volume: g.unten }]),
      ],
    });

    expect(suggestion.resultLoad).toBe(g.runter);
    expect(suggestion.reasonCode).toBe("korridor_unten_verfehlt");
  });

  it("kappt die Steigerung am Geraetemaximum", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      loadMax: g.last,
      history: [block("2026-08-27", g.last, [{ volume: g.oben, rir: 2 }])],
    });

    expect(suggestion.resultLoad).toBe(g.last);
    expect(suggestion.reasonCode).toBe("geraetegrenze_erreicht");
  });

  it("schlaegt nichts vor, wenn die Saetze eines Blocks verschiedene Belastungen tragen", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [
        {
          performedOn: "2026-08-27",
          sets: [
            { load: g.last, secondaryLoad: null, volume: g.oben, rir: 2, problemFlag: false },
            { load: g.runter, secondaryLoad: null, volume: g.oben, rir: 2, problemFlag: false },
          ],
        },
      ],
    });

    expect(suggestion.resultLoad).toBeNull();
    expect(suggestion.reasonCode).toBe("daten_uneindeutig");
  });

  it("rastet eine Belastung neben dem Raster auf eine einstellbare Stufe", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [block("2026-08-27", g.daneben, [{ volume: g.oben, rir: 2 }])],
    });

    expect(suggestion.resultLoad).toBe(g.hoch);
  });

  it("gibt Algorithmusversion und Eingaben zum Nachvollziehen mit aus", () => {
    const suggestion = suggestNextLoad({
      ...basis,
      history: [
        block("2026-08-27", g.last, [{ volume: g.mitte }]),
        block("2026-08-20", g.last, [{ volume: g.mitte }]),
      ],
    });

    expect(suggestion.algoVersion).toBe(PROGRESSION_ALGO_VERSION);
    expect(suggestion.inputs).toEqual({
      ...basis,
      currentLoad: g.last,
      currentSecondaryLoad: null,
      consideredBlocks: 2,
    });
  });

  describe("Grenzen der Steigerung", () => {
    it("steigert nicht, wenn die Reserve ausgeschoepft war", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [block("2026-08-27", g.last, [{ volume: g.oben, rir: 0 }])],
      });

      expect(suggestion.resultLoad).toBe(g.last);
      expect(suggestion.reasonCode).toBe("im_korridor");
    });

    it("steigert ohne Reserve nicht nach einer einzelnen Einheit", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [block("2026-08-27", g.last, [{ volume: g.oben }, { volume: g.oben }])],
      });

      expect(suggestion.resultLoad).toBe(g.last);
      expect(suggestion.reasonCode).toBe("im_korridor");
    });

    it("steigert nicht, wenn ein einzelner Satz unter dem oberen Ende blieb", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [
          block("2026-08-27", g.last, [
            { volume: g.oben, rir: 2 },
            { volume: g.mitte, rir: 2 },
          ]),
        ],
      });

      expect(suggestion.resultLoad).toBe(g.last);
      expect(suggestion.reasonCode).toBe("im_korridor");
    });

    it("steigert nicht, wenn die beiden Einheiten auf verschiedenen Belastungen lagen", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [
          block("2026-08-27", g.last, [{ volume: g.oben }]),
          block("2026-08-20", g.runter, [{ volume: g.oben }]),
        ],
      });

      expect(suggestion.resultLoad).toBe(g.last);
      expect(suggestion.reasonCode).toBe("im_korridor");
    });

    it("reduziert nicht nach einer einzelnen schwachen Einheit", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [
          block("2026-08-27", g.last, [{ volume: g.unten }]),
          block("2026-08-20", g.last, [{ volume: g.mitte }]),
        ],
      });

      expect(suggestion.resultLoad).toBe(g.last);
      expect(suggestion.reasonCode).toBe("im_korridor");
    });

    it("kappt die Reduzierung am Geraeteminimum", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [
          block("2026-08-27", basis.loadMin, [{ volume: g.unten }]),
          block("2026-08-20", basis.loadMin, [{ volume: g.unten }]),
        ],
      });

      expect(suggestion.resultLoad).toBe(basis.loadMin);
      expect(suggestion.reasonCode).toBe("geraetegrenze_erreicht");
    });

    it("schlaegt bei einem Block ohne Saetze nichts vor", () => {
      const suggestion = suggestNextLoad({
        ...basis,
        history: [{ performedOn: "2026-08-27", sets: [] }],
      });

      expect(suggestion.resultLoad).toBeNull();
      expect(suggestion.reasonCode).toBe("daten_uneindeutig");
    });

    it("liefert bei gleicher Eingabe zweimal dasselbe Ergebnis", () => {
      const input = {
        ...basis,
        history: [block("2026-08-27", g.last, [{ volume: g.oben, rir: 2 }])],
      };

      expect(suggestNextLoad(input)).toEqual(suggestNextLoad(input));
    });
  });
});

/**
 * Die Nebenbelastung (Cardio-Spec Abschnitt 3.1b): Laufband mit 0,5-km/h-
 * Schritten, Korridor 15-20 Minuten, Neigung als Nebenbelastung. Die Regel
 * steigert nur das Tempo -- und nur, wenn die Neigung gleich geblieben ist.
 */
describe("suggestNextLoad -- Nebenbelastung", () => {
  const laufband = { targetMin: 900, targetMax: 1200, loadStep: 0.5, loadMin: 0, loadMax: 20 };

  it("gibt die Nebenbelastung im Vorschlag und in den Eingaben mit", () => {
    const suggestion = suggestNextLoad({
      ...laufband,
      history: [
        block("2026-08-27", 8.5, [{ volume: 1200 }], 6),
        block("2026-08-20", 8.5, [{ volume: 1200 }], 6),
      ],
    });

    expect(suggestion.resultLoad).toBe(9);
    expect(suggestion.resultSecondaryLoad).toBe(6);
    expect(suggestion.reasonCode).toBe("korridor_oben_erreicht");
    expect(suggestion.inputs.currentLoad).toBe(8.5);
    expect(suggestion.inputs.currentSecondaryLoad).toBe(6);
  });

  it("zaehlt den Vorblock nicht, wenn die Neigung dort anders war", () => {
    const suggestion = suggestNextLoad({
      ...laufband,
      history: [
        block("2026-08-27", 8.5, [{ volume: 1200 }], 6),
        block("2026-08-20", 8.5, [{ volume: 1200 }], 2),
      ],
    });

    expect(suggestion.resultLoad).toBe(8.5);
    expect(suggestion.resultSecondaryLoad).toBe(6);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("reduziert nicht, wenn die Neigung im Vorblock anders war", () => {
    const suggestion = suggestNextLoad({
      ...laufband,
      history: [
        block("2026-08-27", 8.5, [{ volume: 600 }], 6),
        block("2026-08-20", 8.5, [{ volume: 600 }], 2),
      ],
    });

    expect(suggestion.resultLoad).toBe(8.5);
    expect(suggestion.reasonCode).toBe("im_korridor");
  });

  it("schlaegt nichts vor, wenn die Neigung innerhalb des Blocks wechselt", () => {
    const suggestion = suggestNextLoad({
      ...laufband,
      history: [
        {
          performedOn: "2026-08-27",
          sets: [
            { load: 8.5, secondaryLoad: 2, volume: 1200, rir: null, problemFlag: false },
            { load: 8.5, secondaryLoad: 6, volume: 1200, rir: null, problemFlag: false },
          ],
        },
      ],
    });

    expect(suggestion.resultLoad).toBeNull();
    expect(suggestion.resultSecondaryLoad).toBeNull();
    expect(suggestion.reasonCode).toBe("daten_uneindeutig");
  });

  it("steigert mit Reserve auch dann, wenn die Neigung letzte Woche anders war", () => {
    // Der Reserve-Pfad schaut nur auf den neuesten Block.
    const suggestion = suggestNextLoad({
      ...laufband,
      history: [
        block("2026-08-27", 8.5, [{ volume: 1200, rir: 2 }], 6),
        block("2026-08-20", 8.5, [{ volume: 1200, rir: 2 }], 2),
      ],
    });

    expect(suggestion.resultLoad).toBe(9);
    expect(suggestion.resultSecondaryLoad).toBe(6);
  });

  it("verhaelt sich ohne Nebenbelastung wie mit gleichbleibender", () => {
    const ohne = suggestNextLoad({
      ...laufband,
      history: [
        block("2026-08-27", 8.5, [{ volume: 1200 }]),
        block("2026-08-20", 8.5, [{ volume: 1200 }]),
      ],
    });
    const mit = suggestNextLoad({
      ...laufband,
      history: [
        block("2026-08-27", 8.5, [{ volume: 1200 }], 6),
        block("2026-08-20", 8.5, [{ volume: 1200 }], 6),
      ],
    });

    expect(mit.resultLoad).toBe(ohne.resultLoad);
    expect(mit.reasonCode).toBe(ohne.reasonCode);
  });

  it("festes Ziel (min = max): zweimal erreicht, eine Stufe hoch", () => {
    // Rudergeraet, 2 km, Level-Schritte.
    const suggestion = suggestNextLoad({
      targetMin: 2000, targetMax: 2000, loadStep: 1, loadMin: 1, loadMax: 10,
      history: [
        block("2026-08-27", 5, [{ volume: 2000 }]),
        block("2026-08-20", 5, [{ volume: 2000 }]),
      ],
    });

    expect(suggestion.resultLoad).toBe(6);
    expect(suggestion.reasonCode).toBe("korridor_oben_erreicht");
  });
});

describe("toBlocks", () => {
  it("liest secondary_load mit und laesst null null", () => {
    const blocks = toBlocks([
      { performed_at: "2026-08-27T10:00:00Z", load: "8.50", secondary_load: "6.00", volume: 1200, rir: null, problem_flag: false },
      { performed_at: "2026-08-20T10:00:00Z", load: 80, secondary_load: null, volume: 10, rir: "1.0", problem_flag: false },
    ]);

    expect(blocks[0]?.sets[0]).toEqual({ load: 8.5, secondaryLoad: 6, volume: 1200, rir: null, problemFlag: false });
    expect(blocks[1]?.sets[0]).toEqual({ load: 80, secondaryLoad: null, volume: 10, rir: 1, problemFlag: false });
  });
});
