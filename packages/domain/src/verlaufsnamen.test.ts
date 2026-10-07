import { describe, expect, it } from "vitest";
import { fuelleVerlaufsnamen, type Verlaufsname } from "./verlaufsnamen.js";

const NAME: Verlaufsname = {
  exercise_id: "u1",
  exercise_name: "Latziehen breit",
  volume_kind: "reps",
  equipment_model_id: "t1",
  model_name: "Latzug",
  load_unit: "kg",
  secondary_unit: null,
  machine_id: "m1",
  machine_label: "L3",
  studio_id: "s1",
  studio_name: "Altes Studio",
};

describe("fuelleVerlaufsnamen", () => {
  it("laesst lesbare Einbettungen unangetastet", () => {
    const zeile = {
      machine_id: "m1",
      equipment_model_id: "t1",
      exercise_id: "u1",
      machines: { label: "Neu", equipment_models: { load_unit: "watt" as const, secondary_unit: null } },
      exercises: { name: "Aktuell", volume_kind: "seconds" as const },
    };

    const [ergebnis] = fuelleVerlaufsnamen([zeile], [NAME]);

    expect(ergebnis).toEqual(zeile);
  });

  it("fuellt Geraet und Uebung aus dem Namensverzeichnis, wenn RLS sie verschweigt", () => {
    const [ergebnis] = fuelleVerlaufsnamen(
      [{ machine_id: "m1", equipment_model_id: "t1", exercise_id: "u1", machines: null, exercises: null }],
      [NAME],
    );

    expect(ergebnis).toEqual({
      machine_id: "m1",
      equipment_model_id: "t1",
      exercise_id: "u1",
      machines: { label: "L3", equipment_models: { load_unit: "kg", secondary_unit: null } },
      exercises: { name: "Latziehen breit", volume_kind: "reps" },
    });
  });

  it("beschriftet einen Satz ohne Geraet mit dem Namen des Geraetetyps", () => {
    const ohneGeraet: Verlaufsname = { ...NAME, machine_id: null, machine_label: null, model_name: "Kurzhantel" };

    const [ergebnis] = fuelleVerlaufsnamen(
      [{ machine_id: null, equipment_model_id: "t1", exercise_id: "u1", machines: null, exercises: null }],
      [ohneGeraet],
    );

    expect(ergebnis?.machines).toEqual({
      label: "Kurzhantel",
      equipment_models: { load_unit: "kg", secondary_unit: null },
    });
  });

  it("wirft eine Zeile weg, zu der es keinen Namen gibt", () => {
    const ergebnis = fuelleVerlaufsnamen(
      [{ machine_id: "fremd", equipment_model_id: "x", exercise_id: "y", machines: null, exercises: null }],
      [NAME],
    );

    expect(ergebnis).toEqual([]);
  });
});
