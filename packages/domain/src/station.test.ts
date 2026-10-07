import { describe, expect, it } from "vitest";
import { stationsSchluessel } from "./station.js";

describe("stationsSchluessel", () => {
  it("nimmt das Geraet, wenn es eines gibt", () => {
    expect(stationsSchluessel({ machine_id: "m1", equipment_model_id: "t1" })).toBe("geraet:m1");
  });

  it("nimmt ohne Geraet den Geraetetyp", () => {
    expect(stationsSchluessel({ machine_id: null, equipment_model_id: "t1" })).toBe("typ:t1");
  });

  it("haelt zwei Typen ohne Geraet auseinander", () => {
    expect(stationsSchluessel({ machine_id: null, equipment_model_id: "t1" })).not.toBe(
      stationsSchluessel({ machine_id: null, equipment_model_id: "t2" }),
    );
  });

  it("verwechselt kein Geraet mit einem Typ derselben id", () => {
    expect(stationsSchluessel({ machine_id: "x", equipment_model_id: "y" })).not.toBe(
      stationsSchluessel({ machine_id: null, equipment_model_id: "x" }),
    );
  });
});
