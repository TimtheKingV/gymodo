import { describe, expect, it } from "vitest";
import { zaehleBesucheJeGeraet } from "./bootstrap.js";

describe("zaehleBesucheJeGeraet", () => {
  it("zaehlt zwei Saetze derselben Session als einen Besuch", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m1", session_id: "s1" },
    ]);

    expect(besuche.get("m1")).toBe(1);
  });

  it("zaehlt zwei Sessions als zwei Besuche", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m1", session_id: "s2" },
    ]);

    expect(besuche.get("m1")).toBe(2);
  });

  it("haelt Geraete auseinander", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m2", session_id: "s1" },
      { machine_id: "m2", session_id: "s2" },
    ]);

    expect(besuche.get("m1")).toBe(1);
    expect(besuche.get("m2")).toBe(2);
  });

  it("liefert fuer ein nie benutztes Geraet keinen Eintrag", () => {
    const besuche = zaehleBesucheJeGeraet([]);

    expect(besuche.get("m1")).toBeUndefined();
  });
});
