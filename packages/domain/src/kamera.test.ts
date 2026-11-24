import { describe, expect, it } from "vitest";
import { kameraAusZeile, kameraFehler, kameraSpalten, tempoDateiSchema } from "./kamera.js";

describe("Kameraprofil und Tempo", () => {
  it("ohne_kamera braucht kein Signal und bekommt keine Seite", () => {
    expect(kameraFehler({ profil: "ohne_kamera", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined, "reps", { nurFreigeschaltet: true })).toEqual([]);
    expect(kameraSpalten({ profil: "ohne_kamera", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined)).toMatchObject({ kamera_signal: null, kamera_seite: null, tempo_beginnt_mit: "heben", tempo_senken_s: null });
  });
  it("Kameraprofil ohne Signal ist ein Fehler", () => {
    expect(kameraFehler({ profil: "oberkoerper", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined, "reps", { nurFreigeschaltet: false })).toHaveLength(1);
  });
  it("ohne_kamera mit Signal ist ein Fehler", () => {
    expect(kameraFehler({ profil: "ohne_kamera", signal: "knie", seite: "beide", beginnt_mit: "heben" }, undefined, "reps", { nurFreigeschaltet: false })).toHaveLength(1);
  });
  it("nicht freigeschaltetes Profil wird nur mit nurFreigeschaltet abgelehnt", () => {
    const k = { profil: "oberkoerper", signal: "ellbogen", seite: "beide", beginnt_mit: "heben" } as const;
    expect(kameraFehler(k, undefined, "reps", { nurFreigeschaltet: false })).toEqual([]);
    expect(kameraFehler(k, undefined, "reps", { nurFreigeschaltet: true })[0]).toMatch(/freigeschaltet/);
  });
  it("Tempo ohne Kamera und Kamera bei Sekunden-Uebungen sind Fehler", () => {
    expect(kameraFehler(undefined, { senken_s: 3, halten_s: 1, heben_s: 2 }, "reps", { nurFreigeschaltet: false })).toHaveLength(1);
    expect(kameraFehler({ profil: "ohne_kamera", signal: null, seite: "beide", beginnt_mit: "heben" }, undefined, "seconds", { nurFreigeschaltet: false })).toHaveLength(1);
  });
  it("Tempo ausserhalb des Rasters scheitert am Schema", () => {
    expect(tempoDateiSchema.safeParse({ senken_s: 2.3, halten_s: 0, heben_s: 2 }).success).toBe(false);
    expect(tempoDateiSchema.safeParse({ senken_s: 3, halten_s: 3.5, heben_s: 2 }).success).toBe(false);
    expect(tempoDateiSchema.safeParse({ senken_s: 0.5, halten_s: 0, heben_s: 2 }).success).toBe(false);
    expect(tempoDateiSchema.safeParse({ senken_s: 3, halten_s: 0, heben_s: 2 }).success).toBe(true);
  });
  it("kameraSpalten schreibt Tempo und Kamera mit Signal", () => {
    expect(kameraSpalten({ profil: "oberkoerper", signal: "ellbogen", seite: "links", beginnt_mit: "senken" }, { senken_s: 3, halten_s: 1, heben_s: 2 })).toEqual({
      kamera_profil: "oberkoerper", kamera_signal: "ellbogen", kamera_seite: "links",
      tempo_senken_s: 3, tempo_halten_s: 1, tempo_heben_s: 2, tempo_beginnt_mit: "senken",
    });
  });
  it("kameraAusZeile liest Zahlen auch aus Strings und gibt null ohne Profil", () => {
    expect(kameraAusZeile({ kamera_profil: null, kamera_signal: null, kamera_seite: null, tempo_senken_s: null, tempo_halten_s: null, tempo_heben_s: null, tempo_beginnt_mit: null })).toEqual({ kamera: null, tempo: null });
    expect(kameraAusZeile({ kamera_profil: "ohne_kamera", kamera_signal: null, kamera_seite: null, tempo_senken_s: "2.5", tempo_halten_s: "0.0", tempo_heben_s: "1.5", tempo_beginnt_mit: "heben" }).tempo).toEqual({ senkenS: 2.5, haltenS: 0, hebenS: 1.5 });
  });
});
