import { describe, expect, it } from "vitest";
import { uebungenZusammenfuehren } from "./machine-context.js";
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

describe("muskelnAusSpalte", () => {
  it("macht null und fehlende Werte zu []", () => {
    expect(muskelnAusSpalte(null)).toEqual([]);
    expect(muskelnAusSpalte(undefined)).toEqual([]);
  });
});
