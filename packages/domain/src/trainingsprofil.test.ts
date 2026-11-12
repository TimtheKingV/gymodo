import { describe, expect, it } from "vitest";
import {
  fuehreProfilZusammen,
  pruefeTeilprofil,
  pruefeTrainingsLimits,
  pruefeTrainingsprofil,
  type TrainingProfile,
} from "./trainingsprofil.js";

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
      kraftProWoche: null,
      cardioProWoche: 0,
      cardioMinuten: 30,
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

describe("pruefeTrainingsprofil: Wochenzaehler", () => {
  it("nimmt Zaehler und liefert die Werte", () => {
    const p = pruefeTrainingsprofil({ ...gueltig, kraftProWoche: 2, cardioProWoche: 1, cardioMinuten: 30 });
    expect(p).toMatchObject({ kraftProWoche: 2, cardioProWoche: 1, cardioMinuten: 30 });
  });
  it.each([
    { kraftProWoche: 0 },
    { kraftProWoche: 8 },
    { kraftProWoche: 1.5 },
    { cardioProWoche: -1 },
    { cardioProWoche: 8 },
    { cardioMinuten: 9 },
    { cardioMinuten: 181 },
  ])("lehnt %o ab", (felder) => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, ...felder })).toThrow(
      expect.objectContaining({ code: "validation_failed" }),
    );
  });
  it("Tagesfelder ohne Zaehler laufen weiter durch pruefeWoche", () => {
    expect(() => pruefeTrainingsprofil({ ...gueltig, kursTage: [2], kraftTage: [2] })).toThrow(
      expect.objectContaining({ code: "validation_failed" }),
    );
  });
});

describe("fuehreProfilZusammen", () => {
  const gespeichert: TrainingProfile = {
    ...(gueltig as Pick<TrainingProfile, "minutes" | "experience" | "focus">),
    kursTage: [],
    cardioTage: [],
    cardioArten: [],
    kraftTage: [],
    kraftProWoche: 3,
    cardioProWoche: 2,
    cardioMinuten: 30,
  };
  it("alte App: Krafttage ohne Zaehler setzen kraftProWoche auf die Anzahl", () => {
    const { profil, spalten } = fuehreProfilZusammen(pruefeTeilprofil({ ...gueltig, kraftTage: [1, 4] }), gespeichert);
    expect(profil.kraftProWoche).toBe(2);
    expect(spalten).toMatchObject({ kraft_tage: [1, 4], kraft_pro_woche: 2 });
  });
  it("alte App: leere Krafttage lassen kraftProWoche unveraendert", () => {
    const { profil, spalten } = fuehreProfilZusammen(pruefeTeilprofil({ ...gueltig, kraftTage: [] }), gespeichert);
    expect(profil.kraftProWoche).toBe(3);
    expect(spalten).not.toHaveProperty("kraft_pro_woche");
  });
  it("alte App: Cardiotage ohne Zaehler setzen cardioProWoche auf die Anzahl, auch 0", () => {
    const eins = fuehreProfilZusammen(pruefeTeilprofil({ ...gueltig, cardioTage: [6] }), gespeichert);
    expect(eins.profil.cardioProWoche).toBe(1);
    expect(eins.spalten).toMatchObject({ cardio_pro_woche: 1 });
    const null_ = fuehreProfilZusammen(pruefeTeilprofil({ ...gueltig, cardioTage: [] }), gespeichert);
    expect(null_.profil.cardioProWoche).toBe(0);
    expect(null_.spalten).toMatchObject({ cardio_pro_woche: 0 });
  });
  it("gesendete Zaehler gehen vor den Tagesfeldern", () => {
    const { profil } = fuehreProfilZusammen(
      pruefeTeilprofil({ ...gueltig, kraftTage: [1, 4], kraftProWoche: 5, cardioTage: [6], cardioProWoche: 0 }),
      gespeichert,
    );
    expect(profil).toMatchObject({ kraftProWoche: 5, cardioProWoche: 0 });
  });
  it("nur Zaehler: gespeicherte Alt-Tage, die pruefeWoche nicht bestuenden, stoeren nicht", () => {
    const kaputt: TrainingProfile = { ...gespeichert, kursTage: [2], kraftTage: [2] };
    const { profil, spalten } = fuehreProfilZusammen(pruefeTeilprofil({ ...gueltig, kraftProWoche: 2 }), kaputt);
    expect(profil.kraftProWoche).toBe(2);
    expect(spalten).not.toHaveProperty("kraft_tage");
  });
  it("mit Tagesfeldern prueft pruefeWoche gegen die gespeicherten Tage", () => {
    const mitKurs: TrainingProfile = { ...gespeichert, kursTage: [1] };
    expect(() => fuehreProfilZusammen(pruefeTeilprofil({ ...gueltig, kraftTage: [1] }), mitKurs)).toThrow(
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
