import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import {
  ablaufNachSatz,
  ablaufTauschen,
  einheitZaehlt,
  naechsteEinheitKey,
  type AblaufPosition,
  type AblaufSatz,
  type PositionStatus,
} from "./trainingsplan-ablauf.js";

// Gemeinsame Testfaelle: dieselbe Datei liest spaeter der Swift-Test (Spec F17).
type Fixture = {
  statusFaelle: {
    name: string;
    positionen: AblaufPosition[];
    ungeplanteGesehen: string[];
    saetze: AblaufSatz[];
    tausche: { positionKey: string; exerciseId: string; hauptmuskeln: string[] }[];
    erwartet: { key: string; status: PositionStatus; ersatzExerciseId: string | null }[];
  }[];
  folgeFaelle: { name: string; einheitKeys: string[]; zuletzt: string | null; erwartet: string }[];
  zaehlFaelle: { name: string; stati: PositionStatus[]; erwartet: boolean }[];
};

const fixture = JSON.parse(
  readFileSync(new URL("../fixtures/plan-ablauf.json", import.meta.url), "utf8"),
) as Fixture;

describe("Ablaufstatus", () => {
  for (const fall of fixture.statusFaelle) {
    it(fall.name, () => {
      let z = { positionen: fall.positionen, ungeplanteGesehen: fall.ungeplanteGesehen };
      for (const t of fall.tausche) {
        z = ablaufTauschen(z, t.positionKey, { exerciseId: t.exerciseId, hauptmuskeln: t.hauptmuskeln });
      }
      for (const satz of fall.saetze) z = ablaufNachSatz(z, satz);
      expect(
        z.positionen.map((p) => ({ key: p.key, status: p.status, ersatzExerciseId: p.ersatzExerciseId })),
      ).toEqual(fall.erwartet);
    });
  }
});

describe("Einheitenfolge", () => {
  for (const fall of fixture.folgeFaelle) {
    it(fall.name, () => {
      expect(naechsteEinheitKey(fall.einheitKeys, fall.zuletzt)).toBe(fall.erwartet);
    });
  }
});

describe("Zaehlung", () => {
  for (const fall of fixture.zaehlFaelle) {
    it(fall.name, () => {
      const positionen = fall.stati.map((status, i) => ({
        key: `p${i}`,
        exerciseId: `e${i}`,
        hauptmuskeln: [],
        cardio: false,
        status,
        ersatzExerciseId: null,
      }));
      expect(einheitZaehlt({ positionen, ungeplanteGesehen: [] })).toBe(fall.erwartet);
    });
  }
});

describe("Reinheit", () => {
  it("aendert den Eingabezustand nicht", () => {
    const z = {
      positionen: [
        { key: "a", exerciseId: "x", hauptmuskeln: ["brust"], cardio: false, status: "offen" as const, ersatzExerciseId: null },
      ],
      ungeplanteGesehen: [],
    };
    const kopie = structuredClone(z);
    ablaufNachSatz(z, { exerciseId: "y", hauptmuskeln: ["brust"], cardio: false });
    ablaufTauschen(z, "a", { exerciseId: "w", hauptmuskeln: ["brust"] });
    expect(z).toEqual(kopie);
  });

  it("tauscht weder Cardio noch erledigte Positionen", () => {
    const mk = (cardio: boolean, status: PositionStatus): AblaufPosition => ({
      key: "a", exerciseId: "x", hauptmuskeln: [], cardio, status, ersatzExerciseId: null,
    });
    for (const p of [mk(true, "offen"), mk(false, "erledigt"), mk(false, "optional")]) {
      const z = { positionen: [p], ungeplanteGesehen: [] };
      expect(ablaufTauschen(z, "a", { exerciseId: "w", hauptmuskeln: [] })).toEqual(z);
    }
  });
});
