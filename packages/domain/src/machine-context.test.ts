import { describe, expect, it } from "vitest";
import { kontextUebung, uebungenZusammenfuehren } from "./machine-context.js";
import { muskelnAusSpalte } from "./muskeln.js";

const zeile = (id: string, muscles?: unknown) => ({
  equipment_model_id: "m1",
  exercises: { id, name: id, description: null, volume_kind: "reps" as const, target_min: 8, target_max: 12, muscles: muscles as never },
  instruction_assets: [],
});

describe("uebungenZusammenfuehren", () => {
  it("behaelt die Muskeln der Uebung", () => {
    const muscles = [{ key: "lats", name: "Latissimus", role: "primary" }];
    const [eintrag] = uebungenZusammenfuehren([zeile("e1", muscles)], []);
    expect(eintrag?.uebung.muscles).toEqual(muscles);
  });
});

describe("kontextUebung", () => {
  const basis = { id: "e1", name: "Kniebeuge", description: null, volume_kind: "reps" as const, target_min: 8, target_max: 12 };

  it("ohne die sieben Spalten sind kamera und tempo null", () => {
    expect(kontextUebung(basis, null)).toMatchObject({ kamera: null, tempo: null });
  });

  it("liest Kameraprofil und Tempo aus den Spalten", () => {
    expect(
      kontextUebung({ ...basis, kamera_profil: "ganzkoerper_stehend", kamera_signal: "knie", kamera_seite: "beide",
        tempo_senken_s: "3.0", tempo_halten_s: "1.0", tempo_heben_s: "2.0", tempo_beginnt_mit: "senken" }, null),
    ).toMatchObject({
      kamera: { profil: "ganzkoerper_stehend", signal: "knie", seite: "beide", beginntMit: "senken" },
      tempo: { senkenS: 3, haltenS: 1, hebenS: 2 },
    });
  });
});

describe("muskelnAusSpalte", () => {
  it("macht null und fehlende Werte zu []", () => {
    expect(muskelnAusSpalte(null)).toEqual([]);
    expect(muskelnAusSpalte(undefined)).toEqual([]);
  });
});
