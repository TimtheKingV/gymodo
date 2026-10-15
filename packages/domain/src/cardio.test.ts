import { describe, expect, it } from "vitest";
import {
  CARDIO_WERTE,
  altEingabeUmwandeln,
  cardioAusZeile,
  cardioListeDesModells,
  cardioPruefen,
  cardioWerteSchema,
  cardioZuSpalten,
} from "./cardio.js";

describe("CARDIO_WERTE", () => {
  it("hat die feste Reihenfolge der Spec", () => {
    expect(CARDIO_WERTE).toEqual(["zeit", "strecke", "stufe", "kmh", "steigung", "watt", "frequenz", "kcal"]);
  });
});

describe("cardioWerteSchema", () => {
  it("nimmt gueltige Werte, auch einzeln", () => {
    expect(cardioWerteSchema.parse({ zeit: 510, strecke: 2000 })).toEqual({ zeit: 510, strecke: 2000 });
    expect(cardioWerteSchema.parse({ kmh: 10.5, steigung: -2.5 })).toEqual({ kmh: 10.5, steigung: -2.5 });
  });

  it("weist Werte ausserhalb der Grenzen und gebrochene Ganzzahlen ab", () => {
    expect(cardioWerteSchema.safeParse({ zeit: 0 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ kmh: 50.1 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ steigung: -10.5 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ watt: 142.5 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ puls: 120 }).success).toBe(false);
  });
});

describe("cardioPruefen", () => {
  const ruderer = ["zeit", "strecke", "watt", "frequenz", "kcal"] as const;

  it("laesst Werte aus der Liste des Geraets durch", () => {
    expect(cardioPruefen({ zeit: 510, strecke: 2000 }, [...ruderer])).toBeNull();
  });

  it("lehnt einen Wert ab, den das Geraet nicht hat", () => {
    expect(cardioPruefen({ stufe: 5 }, [...ruderer])).toBe("Dieser Wert gehört nicht zu diesem Gerät.");
  });

  it("verlangt mindestens einen Wert", () => {
    expect(cardioPruefen({}, [...ruderer])).toBe("Mindestens ein Wert fehlt.");
  });
});

describe("cardioListeDesModells", () => {
  it("nimmt die eigene Liste, sonst die des Katalog-Typs", () => {
    expect(cardioListeDesModells({ eigene: ["zeit"], katalog: ["zeit", "kmh"] })).toEqual(["zeit"]);
    expect(cardioListeDesModells({ eigene: [], katalog: ["zeit", "kmh"] })).toEqual(["zeit", "kmh"]);
    expect(cardioListeDesModells({ eigene: [], katalog: null })).toEqual([]);
  });

  it("ordnet nach der festen Reihenfolge", () => {
    expect(cardioListeDesModells({ eigene: ["kcal", "zeit", "strecke"], katalog: null })).toEqual(["zeit", "strecke", "kcal"]);
  });
});

describe("altEingabeUmwandeln", () => {
  const rad = ["zeit", "strecke", "stufe", "watt", "frequenz", "kcal"] as const;

  it("macht aus Sekunden Zeit und aus der Stufe stufe", () => {
    expect(
      altEingabeUmwandeln(
        { load: 5, secondaryLoad: null, volume: 1200, loadUnit: "level", secondaryUnit: null, volumeKind: "seconds" },
        [...rad],
      ),
    ).toEqual({ zeit: 1200, stufe: 5 });
  });

  it("macht aus Metern Strecke und verwirft, was das Geraet nicht hat", () => {
    expect(
      altEingabeUmwandeln(
        { load: 8.5, secondaryLoad: 2, volume: 3000, loadUnit: "kmh", secondaryUnit: "pct", volumeKind: "meters" },
        ["zeit", "strecke", "kmh"],
      ),
    ).toEqual({ strecke: 3000, kmh: 8.5 });
  });

  it("laesst kg und Wiederholungen weg", () => {
    expect(
      altEingabeUmwandeln(
        { load: 80, secondaryLoad: null, volume: 10, loadUnit: "kg", secondaryUnit: null, volumeKind: "reps" },
        [...rad],
      ),
    ).toEqual({});
  });
});

describe("Zeilen-Mapping", () => {
  it("liest nur gesetzte Spalten und schreibt alle acht", () => {
    expect(cardioAusZeile({ dauer_s: 510, strecke_m: null, stufe: null, kmh: "10.5", steigung_pct: null, watt: null, kcal: null, frequenz: null }))
      .toEqual({ zeit: 510, kmh: 10.5 });
    expect(cardioAusZeile({ dauer_s: null, strecke_m: null, stufe: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null }))
      .toBeNull();
    expect(cardioZuSpalten({ zeit: 510 })).toEqual({
      dauer_s: 510, strecke_m: null, stufe: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null,
    });
  });
});
