import { describe, expect, it } from "vitest";
import { belastungAusFormular, umfangAusFormular } from "./formfelder";

function form(felder: Record<string, string>): FormData {
  const daten = new FormData();
  for (const [name, wert] of Object.entries(felder)) daten.set(name, wert);
  return daten;
}

describe("belastungAusFormular", () => {
  it("faellt ohne die neuen Felder auf ein Kraftgeraet zurueck", () => {
    const felder = belastungAusFormular(form({ loadStep: "2,5", loadMin: "0", loadMax: "" }));

    expect(felder).toEqual({
      category: "kraft",
      loadUnit: "kg",
      loadStep: 2.5,
      loadMin: 0,
      loadMax: null,
      secondaryUnit: null,
      secondaryStep: null,
      secondaryMin: null,
      secondaryMax: null,
    });
  });

  it("liest ein Laufband mit Neigung", () => {
    const felder = belastungAusFormular(
      form({
        category: "cardio",
        loadUnit: "kmh",
        loadStep: "0,5",
        loadMin: "0",
        loadMax: "20",
        secondaryUnit: "pct",
        secondaryStep: "0,5",
        secondaryMin: "0",
        secondaryMax: "15",
      }),
    );

    expect(felder).toMatchObject({
      category: "cardio",
      loadUnit: "kmh",
      loadStep: 0.5,
      loadMax: 20,
      secondaryUnit: "pct",
      secondaryStep: 0.5,
      secondaryMin: 0,
      secondaryMax: 15,
    });
  });

  it("verwirft die Rastung der Nebenbelastung, wenn sie auf keine steht", () => {
    const felder = belastungAusFormular(
      form({ loadStep: "5", secondaryUnit: "", secondaryStep: "0,5", secondaryMin: "0", secondaryMax: "15" }),
    );

    expect(felder.secondaryUnit).toBeNull();
    expect(felder.secondaryStep).toBeNull();
    expect(felder.secondaryMin).toBeNull();
    expect(felder.secondaryMax).toBeNull();
  });

  it("nimmt keine erfundene Einheit an", () => {
    const felder = belastungAusFormular(form({ loadUnit: "mph", category: "yoga", loadStep: "1" }));

    expect(felder.loadUnit).toBe("kg");
    expect(felder.category).toBe("kraft");
  });
});

describe("umfangAusFormular", () => {
  it("Wiederholungen bleiben Wiederholungen", () => {
    expect(umfangAusFormular(form({ targetMin: "8", targetMax: "12" }))).toEqual({
      volumeKind: "reps",
      targetMin: 8,
      targetMax: 12,
    });
  });

  it("Minuten werden zu Sekunden", () => {
    expect(
      umfangAusFormular(form({ volumeKind: "seconds", targetMin: "15", targetMax: "20" })),
    ).toEqual({ volumeKind: "seconds", targetMin: 900, targetMax: 1200 });
  });

  it("Meter bleiben Meter", () => {
    expect(
      umfangAusFormular(form({ volumeKind: "meters", targetMin: "2000", targetMax: "5000" })),
    ).toEqual({ volumeKind: "meters", targetMin: 2000, targetMax: 5000 });
  });

  it("laesst ein leeres Feld als NaN durch, damit die Domain die Meldung liefert", () => {
    expect(umfangAusFormular(form({ targetMax: "12" })).targetMin).toBeNaN();
  });
});
