import { describe, expect, it } from "vitest";
import { pruefeTrainingsLimits, pruefeTrainingsprofil } from "./trainingsprofil.js";

const gueltig = { minutes: 60, experience: "neu", focus: ["brust"] };

describe("pruefeTrainingsprofil", () => {
  it("nimmt ein gueltiges Profil", () => {
    expect(pruefeTrainingsprofil(gueltig)).toMatchObject(gueltig);
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

describe("pruefeTrainingsprofil: Wochenraster", () => {
  it("ein Profil ohne die neuen Felder liefert leere Listen", () => {
    expect(pruefeTrainingsprofil(gueltig)).toEqual({
      ...gueltig,
      kursTage: [],
      cardioTage: [],
      cardioArten: [],
      kraftTage: [],
    });
  });
  it("nimmt gueltige Wochentage und Cardio-Arten", () => {
    const p = pruefeTrainingsprofil({
      ...gueltig,
      kursTage: [1],
      cardioTage: [7],
      cardioArten: ["laufen", "radfahren"],
      kraftTage: [3, 5],
    });
    expect(p.kursTage).toEqual([1]);
    expect(p.cardioArten).toEqual(["laufen", "radfahren"]);
    expect(p.kraftTage).toEqual([3, 5]);
  });
  it("lehnt eine unbekannte Cardio-Art ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, cardioArten: ["joggen"] })).toThrow(
      expect.objectContaining({ code: "validation_failed" }),
    );
  });
  it("lehnt doppelte Cardio-Arten ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, cardioArten: ["laufen", "laufen"] })).toThrow(
      expect.objectContaining({ code: "validation_failed" }),
    );
  });
  it("lehnt einen Tag in zwei Arten ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, kursTage: [2], kraftTage: [2] })).toThrow(
      expect.objectContaining({ code: "validation_failed" }),
    );
  });
  it("lehnt Wochentag 8 ab", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, kursTage: [8] })).toThrow(
      expect.objectContaining({ code: "validation_failed" }),
    );
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
