import { describe, expect, it } from "vitest";
import { berechneWochenziel } from "./wochenziel.js";
import type { TrainingProfile } from "./trainingsprofil.js";

const profil = (p: Partial<TrainingProfile> = {}): TrainingProfile => ({
  minutes: 60, experience: "regelmaessig", focus: [], kursTage: [], cardioTage: [], cardioArten: [], kraftTage: [],
  kraftProWoche: null, cardioProWoche: 0, cardioMinuten: 30, ...p,
});

describe("berechneWochenziel", () => {
  it("nimmt die Zaehler aus dem Profil", () => {
    expect(berechneWochenziel(profil({ kraftProWoche: 3, cardioProWoche: 1, cardioMinuten: 45 }), 5, 4))
      .toEqual({ kraft: 3, cardio: 1, cardioMinuten: 45 });
  });
  it("faellt fuer Kraft auf Plantage, dann weeklyDays, dann 2 zurueck", () => {
    expect(berechneWochenziel(profil(), 2, 4).kraft).toBe(4);
    expect(berechneWochenziel(profil(), 5, null).kraft).toBe(5);
    expect(berechneWochenziel(profil(), null, null).kraft).toBe(2);
  });
  it("Profil null: Cardio 0 und 30 Minuten", () => {
    expect(berechneWochenziel(null, null, null)).toEqual({ kraft: 2, cardio: 0, cardioMinuten: 30 });
    expect(berechneWochenziel(null, 3, null).kraft).toBe(3);
  });
  it("Kraft bleibt zwischen 1 und 7", () => {
    expect(berechneWochenziel(profil(), null, 9).kraft).toBe(7);
    expect(berechneWochenziel(profil(), 0, null).kraft).toBe(1);
  });
});
