import { describe, expect, it } from "vitest";
import { herkunftPruefen, repEventsSchema } from "./herkunft.js";
import { recordSetInputSchema } from "./workout.js";

function events(n: number) {
  return {
    algo: "langhantel/1",
    befestigungsart: "langhantel" as const,
    unsicher: null,
    wiederholungen: Array.from({ length: n }, (_, i) => ({
      beginn: i * 2, umkehr: i * 2 + 1, ende: i * 2 + 1.9, ausschlag: 110, sicherheit: 0.9,
    })),
  };
}

const basis = {
  sessionId: "11111111-1111-4111-8111-111111111111",
  setId: "22222222-2222-4222-8222-222222222222",
  machineId: "33333333-3333-4333-8333-333333333333",
  exerciseId: "44444444-4444-4444-8444-444444444444",
  setIndex: 1,
  load: 20,
  volume: 10,
};

describe("repEventsSchema", () => {
  it("nimmt das Format aus der App an", () => {
    expect(repEventsSchema.safeParse(events(3)).success).toBe(true);
  });

  it("weist eine Wiederholung ab, deren Umkehr vor dem Beginn liegt", () => {
    const kaputt = events(1);
    kaputt.wiederholungen[0]!.umkehr = -1;
    expect(repEventsSchema.safeParse(kaputt).success).toBe(false);
  });

  it("weist Wiederholungen in falscher Reihenfolge ab", () => {
    const kaputt = events(2);
    kaputt.wiederholungen.reverse();
    expect(repEventsSchema.safeParse(kaputt).success).toBe(false);
  });

  it("weist eine unbekannte Befestigungsart und eine Sicherheit ueber 1 ab", () => {
    expect(repEventsSchema.safeParse({ ...events(1), befestigungsart: "nacken" }).success).toBe(false);
    const zuSicher = events(1);
    zuSicher.wiederholungen[0]!.sicherheit = 1.2;
    expect(repEventsSchema.safeParse(zuSicher).success).toBe(false);
  });

  it("verlangt den Schluessel unsicher, auch als null", () => {
    const { unsicher: _weg, ...ohne } = events(1);
    expect(repEventsSchema.safeParse(ohne).success).toBe(false);
  });
});

describe("herkunftPruefen", () => {
  it.each([
    ["eingegeben ohne alles", { volume: 10, volumeSource: "eingegeben" as const }, null],
    ["gemessen passend", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 10, repEvents: events(10) }, null],
    ["korrigiert passend", { volume: 12, volumeSource: "korrigiert" as const, volumeCounted: 10, repEvents: events(10) }, null],
  ])("laesst durch: %s", (_n, eingabe, erwartet) => {
    expect(herkunftPruefen(eingabe)).toBe(erwartet);
  });

  it.each([
    ["eingegeben mit Zaehlerstand", { volume: 10, volumeSource: "eingegeben" as const, volumeCounted: 10 }],
    ["eingegeben mit Ereignissen", { volume: 10, volumeSource: "eingegeben" as const, repEvents: events(10) }],
    ["gemessen ohne Ereignisse", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 10 }],
    ["gemessen mit anderem Stand", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 9, repEvents: events(9) }],
    ["korrigiert ohne Abweichung", { volume: 10, volumeSource: "korrigiert" as const, volumeCounted: 10, repEvents: events(10) }],
    ["Anzahl Ereignisse passt nicht", { volume: 10, volumeSource: "gemessen" as const, volumeCounted: 10, repEvents: events(9) }],
  ])("weist ab: %s", (_n, eingabe) => {
    expect(herkunftPruefen(eingabe)).toEqual(expect.any(String));
  });
});

describe("recordSetInputSchema -- Herkunft", () => {
  it("setzt ohne Angabe eingegeben (alte App-Versionen)", () => {
    const ergebnis = recordSetInputSchema.safeParse(basis);
    expect(ergebnis.success && ergebnis.data.volumeSource).toBe("eingegeben");
  });

  it("nimmt einen gemessenen Satz an", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis, volumeSource: "gemessen", volumeCounted: 10, repEvents: events(10),
    });
    expect(ergebnis.success).toBe(true);
  });

  it("weist einen inkonsistenten Satz schon im Schema ab", () => {
    const ergebnis = recordSetInputSchema.safeParse({ ...basis, volumeSource: "gemessen" });
    expect(ergebnis.success).toBe(false);
  });
});
