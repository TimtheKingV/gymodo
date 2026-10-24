import { describe, expect, it } from "vitest";
import { pruefeTrainingsLimits, pruefeTrainingsprofil } from "./trainingsprofil.js";

const gueltig = { minutes: 60, experience: "neu", focus: ["brust"] };

describe("pruefeTrainingsprofil", () => {
  it("nimmt ein gueltiges Profil", () => {
    expect(pruefeTrainingsprofil(gueltig)).toEqual(gueltig);
  });
  it("lehnt Minuten 50 ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, minutes: 50 })).toThrow();
  });
  it("lehnt drei Fokusbereiche ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, focus: ["brust", "po", "arme"] })).toThrow();
  });
  it("lehnt doppelten Fokus ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, focus: ["po", "po"] })).toThrow();
  });
  it("akzeptiert leeren Fokus", () => {
    expect(pruefeTrainingsprofil({ ...gueltig, focus: [] }).focus).toEqual([]);
  });
});

describe("pruefeTrainingsLimits", () => {
  it("lehnt Beschwerden ohne einwilligung ab", () => {
    expect(() => pruefeTrainingsLimits({ areas: { knie: "meiden" } })).toThrow();
    expect(() => pruefeTrainingsLimits({ einwilligung: false, areas: {} })).toThrow();
  });
  it("lehnt unbekannten Bereich und unbekannte Stufe ab", () => {
    expect(() => pruefeTrainingsLimits({ einwilligung: true, areas: { fuss: "meiden" } })).toThrow();
    expect(() => pruefeTrainingsLimits({ einwilligung: true, areas: { knie: "egal" } })).toThrow();
  });
  it("leere areas mit einwilligung sind erlaubt", () => {
    expect(pruefeTrainingsLimits({ einwilligung: true, areas: {} })).toEqual({ areas: {} });
  });
  it("nimmt bekannte Bereiche", () => {
    expect(
      pruefeTrainingsLimits({ einwilligung: true, areas: { knie: "meiden", schulter: "vorsichtig" } }).areas,
    ).toEqual({ knie: "meiden", schulter: "vorsichtig" });
  });
});
