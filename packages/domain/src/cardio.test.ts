import { describe, expect, it } from "vitest";
import {
  CARDIO_WERTE,
  altEingabeUmwandeln,
  cardioAusZeile,
  cardioDesSatzes,
  cardioListeDesModells,
  cardioPruefen,
  cardioWerteSchema,
  cardioZuSpalten,
} from "./cardio.js";

describe("CARDIO_WERTE", () => {
  it("hat die feste Reihenfolge der Spec", () => {
    expect(CARDIO_WERTE).toEqual(["zeit", "strecke", "stufe", "stufenanzahl", "kmh", "steigung", "watt", "frequenz", "kcal"]);
  });
});

describe("cardioWerteSchema", () => {
  it("nimmt gueltige Werte, auch einzeln", () => {
    expect(cardioWerteSchema.parse({ zeit: 510, strecke: 2000 })).toEqual({ zeit: 510, strecke: 2000 });
    expect(cardioWerteSchema.parse({ kmh: 10.5, steigung: -2.5 })).toEqual({ kmh: 10.5, steigung: -2.5 });
  });

  it("kennt die Anzahl Stufen (Testnotiz 18.10., #5): ganz, 1 bis 10000, eigene Spalte", () => {
    expect(cardioWerteSchema.parse({ stufenanzahl: 120 })).toEqual({ stufenanzahl: 120 });
    expect(cardioWerteSchema.safeParse({ stufenanzahl: 0 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ stufenanzahl: 10_001 }).success).toBe(false);
    expect(cardioWerteSchema.safeParse({ stufenanzahl: 12.5 }).success).toBe(false);
    expect(cardioZuSpalten({ stufenanzahl: 120 }).stufenanzahl).toBe(120);
    expect(cardioZuSpalten({ stufe: 6 }).stufenanzahl).toBeNull();
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

  // Wie round() in Postgres (0055): halbe Werte weg von der Null.
  it("rundet eine negative halbe Steigung weg von der Null", () => {
    expect(
      altEingabeUmwandeln(
        { load: 8, secondaryLoad: -2.25, volume: null, loadUnit: "kmh", secondaryUnit: "pct", volumeKind: "reps" },
        ["kmh", "steigung"],
      ),
    ).toEqual({ kmh: 8, steigung: -2.3 });
  });
});

describe("altEingabeUmwandeln -- Regel wie Migration 0055 (Final-Review A/G)", () => {
  it("kappt jeden Wert in den Bereich seiner Spalte", () => {
    expect(
      altEingabeUmwandeln(
        { load: 150, secondaryLoad: null, volume: 99999, loadUnit: "level", secondaryUnit: null, volumeKind: "seconds" },
        ["zeit", "stufe"],
      ),
    ).toEqual({ zeit: 86_400, stufe: 100 });
  });

  it("rundet Zehntel auf eine Nachkommastelle", () => {
    expect(
      altEingabeUmwandeln(
        { load: 8.46, secondaryLoad: 2.34, volume: null, loadUnit: "kmh", secondaryUnit: "pct", volumeKind: "reps" },
        ["kmh", "steigung"],
      ),
    ).toEqual({ kmh: 8.5, steigung: 2.3 });
  });

  it("die Belastung geht vor der Nebenbelastung, wenn beide in dieselbe Spalte fallen", () => {
    expect(
      altEingabeUmwandeln(
        { load: 80, secondaryLoad: 90, volume: null, loadUnit: "rpm", secondaryUnit: "rpm", volumeKind: "reps" },
        ["frequenz"],
      ),
    ).toEqual({ frequenz: 80 });
  });
});

describe("cardioDesSatzes (Final-Review A)", () => {
  const leer = { dauer_s: null, strecke_m: null, stufe: null, stufenanzahl: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null };
  const rad = { liste: ["zeit", "watt"] as const, loadUnit: "watt" as const, secondaryUnit: null };

  it("nimmt die Spalten, wenn der Satz Cardio-Werte traegt", () => {
    expect(cardioDesSatzes({ ...leer, dauer_s: 600, load: null, secondary_load: null, volume: null }, { ...rad, liste: [...rad.liste] }, "seconds"))
      .toEqual({ zeit: 600 });
  });

  it("leitet die Werte eines alten Satzes am Cardio-Geraet ab", () => {
    expect(cardioDesSatzes({ ...leer, load: "150", secondary_load: null, volume: 1500 }, { ...rad, liste: [...rad.liste] }, "seconds"))
      .toEqual({ zeit: 1500, watt: 150 });
  });

  it("ohne Uebung nur die Belastung", () => {
    expect(cardioDesSatzes({ ...leer, load: 150, secondary_load: null, volume: 1500 }, { ...rad, liste: [...rad.liste] }, null))
      .toEqual({ watt: 150 });
  });

  it("null an einem Kraftgeraet, an einem unbekannten Geraet und wenn nichts bleibt", () => {
    const satz = { ...leer, load: 40, secondary_load: null, volume: 10 };
    expect(cardioDesSatzes(satz, { liste: [], loadUnit: "kg", secondaryUnit: null }, "reps")).toBeNull();
    expect(cardioDesSatzes(satz, undefined, "reps")).toBeNull();
    expect(cardioDesSatzes(satz, { liste: ["zeit"], loadUnit: "kg", secondaryUnit: null }, "reps")).toBeNull();
  });
});

describe("Zeilen-Mapping", () => {
  it("liest nur gesetzte Spalten und schreibt alle acht", () => {
    expect(cardioAusZeile({ dauer_s: 510, strecke_m: null, stufe: null, stufenanzahl: null, kmh: "10.5", steigung_pct: null, watt: null, kcal: null, frequenz: null }))
      .toEqual({ zeit: 510, kmh: 10.5 });
    expect(cardioAusZeile({ dauer_s: null, strecke_m: null, stufe: null, stufenanzahl: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null }))
      .toBeNull();
    expect(cardioZuSpalten({ zeit: 510 })).toEqual({
      dauer_s: 510, strecke_m: null, stufe: null, stufenanzahl: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null,
    });
  });
});
