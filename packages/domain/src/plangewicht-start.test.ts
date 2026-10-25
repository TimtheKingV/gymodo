import { describe, expect, it } from "vitest";
import { AGE_BANDS, SEX } from "./profil.js";
import type { WorkoutSetInput } from "./progression.js";
import {
  STARTSCHAETZUNG_VERSION,
  WIEDEREINSTIEG_VERSION,
  schaetzeStartgewicht,
  startgewichtAusHistorie,
  uebertragungsFaktor,
  wiedereinstieg,
} from "./plangewicht-start.js";

const geraet = { loadStep: 2.5, loadMin: 5, loadMax: 100 };
const satz = (load: number, volume = 10): WorkoutSetInput => ({
  load,
  secondaryLoad: null,
  volume,
  rir: null,
  problemFlag: false,
});

describe("startgewichtAusHistorie (G12)", () => {
  it("nimmt bei einheitlichem Block 3x10 bei 40 kg die 40 kg", () => {
    expect(
      startgewichtAusHistorie([satz(40), satz(40), satz(40)], geraet),
    ).toBe(40);
  });
  it("nimmt bei gemischten Lasten die Last des letzten Arbeitssatzes", () => {
    expect(
      startgewichtAusHistorie([satz(45), satz(42.5), satz(40)], geraet),
    ).toBe(40);
  });
  it("rastet auf die Geraetestufe und haelt die Grenzen", () => {
    expect(startgewichtAusHistorie([satz(41)], geraet)).toBe(40);
    expect(startgewichtAusHistorie([satz(150)], geraet)).toBe(100);
    expect(startgewichtAusHistorie([satz(1)], geraet)).toBe(5);
  });
  it("liefert null ohne Saetze", () => {
    expect(startgewichtAusHistorie([], geraet)).toBeNull();
  });
});

describe("schaetzeStartgewicht", () => {
  const leer = {
    geschlecht: null,
    altersgruppe: null,
    koerpergewichtKg: null,
    geraet,
  };
  it("hat versionierte Konstanten", () => {
    expect(STARTSCHAETZUNG_VERSION).toBe("1.0.0");
    expect(WIEDEREINSTIEG_VERSION).toBe("1.0.0");
  });
  it("ohne Profilangaben und mit Erfahrung regelmaessig = loadStart", () => {
    expect(
      schaetzeStartgewicht({
        ...leer,
        loadStart: 30,
        erfahrung: "regelmaessig",
      }),
    ).toBe(30);
  });
  it("ohne loadStart startet sie bei loadMin", () => {
    expect(
      schaetzeStartgewicht({
        ...leer,
        loadStart: null,
        erfahrung: "regelmaessig",
      }),
    ).toBe(5);
  });
  it("ist konservativ: weniger Erfahrung gibt nie mehr Last", () => {
    const w = (erfahrung: "neu" | "unregelmaessig" | "regelmaessig") =>
      schaetzeStartgewicht({ ...leer, loadStart: 40, erfahrung });
    expect(w("neu")).toBeLessThan(w("unregelmaessig"));
    expect(w("unregelmaessig")).toBeLessThan(w("regelmaessig"));
  });
  it("Profilangaben senken nur, nie ueber loadStart", () => {
    const basis = { loadStart: 40, erfahrung: "regelmaessig" as const, geraet };
    const w = schaetzeStartgewicht({
      ...basis,
      geschlecht: "female",
      altersgruppe: "45_54",
      koerpergewichtKg: 55,
    });
    expect(w).toBeLessThan(40);
    const stark = schaetzeStartgewicht({
      ...basis,
      geschlecht: "male",
      altersgruppe: "25_34",
      koerpergewichtKg: 120,
    });
    expect(stark).toBeLessThanOrEqual(40);
  });
  it("liegt immer auf einer Stufe innerhalb loadMin..loadMax", () => {
    for (const erfahrung of [
      "neu",
      "unregelmaessig",
      "regelmaessig",
    ] as const) {
      for (const loadStart of [null, 1, 7, 33.3, 500]) {
        const w = schaetzeStartgewicht({
          loadStart,
          erfahrung,
          geschlecht: "female",
          altersgruppe: "65_plus",
          koerpergewichtKg: 50,
          geraet,
        });
        expect(w).toBeGreaterThanOrEqual(5);
        expect(w).toBeLessThanOrEqual(100);
        expect(((w - 5) / 2.5) % 1).toBeCloseTo(0, 9);
      }
    }
  });
  it("Altersbaender: je aelter, nie mehr Last (alle echten Baender)", () => {
    const w = (altersgruppe: (typeof AGE_BANDS)[number]) =>
      schaetzeStartgewicht({
        ...leer,
        loadStart: 80,
        erfahrung: "regelmaessig",
        altersgruppe,
      });
    const werte = AGE_BANDS.filter((b) => b !== "under_18").map(w);
    for (let i = 1; i < werte.length; i++)
      expect(werte[i]!).toBeLessThanOrEqual(werte[i - 1]!);
    expect(w("65_plus")).toBeLessThan(w("25_34"));
    expect(w("under_18")).toBeLessThan(80);
  });
  it("jedes echte Geschlecht und Alter liefert eine gueltige Stufe", () => {
    for (const geschlecht of SEX)
      for (const altersgruppe of AGE_BANDS) {
        const x = schaetzeStartgewicht({
          ...leer,
          loadStart: 40,
          erfahrung: "neu",
          geschlecht,
          altersgruppe,
        });
        expect(x).toBeLessThanOrEqual(40);
        expect(x).toBeGreaterThanOrEqual(5);
      }
    expect(
      schaetzeStartgewicht({
        ...leer,
        loadStart: 40,
        erfahrung: "regelmaessig",
        geschlecht: "female",
      }),
    ).toBeLessThan(40);
    expect(
      schaetzeStartgewicht({
        ...leer,
        loadStart: 40,
        erfahrung: "regelmaessig",
        geschlecht: "male",
      }),
    ).toBe(40);
    expect(
      schaetzeStartgewicht({
        ...leer,
        loadStart: 40,
        erfahrung: "regelmaessig",
        geschlecht: "diverse",
      }),
    ).toBe(40);
  });
  it("loadStart genau auf einer Stufe mit Faktor < 1 rutscht nicht durch Gleitkomma eine Stufe zu tief", () => {
    // 50 * 0,9 (Band 45_54) = 45 exakt auf Stufe
    const g = { loadStep: 5, loadMin: 0, loadMax: 100 };
    expect(
      schaetzeStartgewicht({
        ...leer,
        geraet: g,
        loadStart: 50,
        erfahrung: "regelmaessig",
        altersgruppe: "45_54",
      }),
    ).toBe(45);
  });
  it("rundet ab, nicht auf", () => {
    // 10 kg * 0,7 = 7 -> Stufe 5 (nicht 7,5)
    expect(
      schaetzeStartgewicht({ ...leer, loadStart: 10, erfahrung: "neu" }),
    ).toBe(7.5 - 2.5);
  });
});

describe("uebertragungsFaktor", () => {
  it("12 gemacht + Reserve 3 gegen Mitte 10 + Zielreserve 2: 15 gegen 12 = +9 %", () => {
    expect(
      uebertragungsFaktor({
        gemacht: 12,
        reserve: 3,
        wdhMitte: 10,
        zielreserve: 2,
      }),
    ).toBeCloseTo(1.09, 9);
  });
  it("genau im Ziel = 1", () => {
    expect(
      uebertragungsFaktor({
        gemacht: 8,
        reserve: 2,
        wdhMitte: 8,
        zielreserve: 2,
      }),
    ).toBe(1);
  });
  it("negative Richtung: Last war zu schwer", () => {
    expect(
      uebertragungsFaktor({
        gemacht: 6,
        reserve: 0,
        wdhMitte: 10,
        zielreserve: 2,
      }),
    ).toBeCloseTo(0.82, 9);
  });
  it("deckelt auf +20 %", () => {
    expect(
      uebertragungsFaktor({
        gemacht: 20,
        reserve: 5,
        wdhMitte: 8,
        zielreserve: 2,
      }),
    ).toBeCloseTo(1.2, 9);
  });
  it("deckelt auf -20 %", () => {
    expect(
      uebertragungsFaktor({
        gemacht: 2,
        reserve: 0,
        wdhMitte: 15,
        zielreserve: 3,
      }),
    ).toBeCloseTo(0.8, 9);
  });
});

describe("wiedereinstieg (F18)", () => {
  it("bis 7 Tage: Ziel unveraendert", () => {
    expect(wiedereinstieg(7, 40, geraet)).toEqual({
      load: 40,
      saetzeMinus: 0,
      grund: null,
    });
    expect(wiedereinstieg(0, 40, geraet)).toEqual({
      load: 40,
      saetzeMinus: 0,
      grund: null,
    });
  });
  it("8 bis 14 Tage: Ziel gehalten", () => {
    expect(wiedereinstieg(8, 40, geraet)).toEqual({
      load: 40,
      saetzeMinus: 0,
      grund: null,
    });
    expect(wiedereinstieg(10, 40, geraet)).toEqual({
      load: 40,
      saetzeMinus: 0,
      grund: null,
    });
    expect(wiedereinstieg(14, 40, geraet)).toEqual({
      load: 40,
      saetzeMinus: 0,
      grund: null,
    });
  });
  it("15 bis 28 Tage: -7,5 % abgerundet auf Stufe und 1 Satz weniger", () => {
    // 40 * 0,925 = 37 -> 35
    expect(wiedereinstieg(15, 40, geraet)).toEqual({
      load: 35,
      saetzeMinus: 1,
      grund: "wiedereinstieg",
    });
    expect(wiedereinstieg(20, 40, geraet)).toEqual({
      load: 35,
      saetzeMinus: 1,
      grund: "wiedereinstieg",
    });
    expect(wiedereinstieg(28, 40, geraet).load).toBe(35);
  });
  it("29 bis 42 Tage: -12,5 %", () => {
    // 40 * 0,875 = 35 -> 35 (exakte Stufe darf nicht durch Gleitkomma fallen)
    expect(wiedereinstieg(35, 40, geraet)).toEqual({
      load: 35,
      saetzeMinus: 1,
      grund: "wiedereinstieg",
    });
    // 60 * 0,875 = 52,5
    expect(wiedereinstieg(29, 60, geraet).load).toBe(52.5);
    expect(wiedereinstieg(42, 60, geraet).load).toBe(52.5);
  });
  it("ueber 42 Tage: keine Last, Startschaetzung gilt", () => {
    expect(wiedereinstieg(43, 40, geraet)).toEqual({
      load: null,
      saetzeMinus: 0,
      grund: "startschaetzung",
    });
    expect(wiedereinstieg(50, 40, geraet).load).toBeNull();
  });
  it("haelt loadMin ein", () => {
    expect(wiedereinstieg(20, 5, geraet).load).toBe(5);
    expect(wiedereinstieg(35, 6, geraet).load).toBe(5);
  });
  it("haelt loadMax ein", () => {
    expect(wiedereinstieg(20, 200, geraet).load).toBe(100);
  });
});
