import { describe, expect, it } from "vitest";
import { gruppeDesModells, startDesModells, zaehleBesucheJeGeraet } from "./bootstrap.js";

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

// Testnotiz 12.10., #3: unter welcher Kachel ein Geraet in der App steht.
describe("gruppeDesModells", () => {
  it("nimmt die eigene Gruppe vor der des Gymtavo-Typs", () => {
    expect(gruppeDesModells({ eigene: "freihantel", katalog: "kabelzug", category: "kraft" })).toBe("freihantel");
  });

  it("erbt die Gruppe des zugeordneten Gymtavo-Typs", () => {
    expect(gruppeDesModells({ eigene: null, katalog: "kabelzug", category: "kraft" })).toBe("kabelzug");
  });

  it("faellt ohne Zuordnung auf die Kategorie zurueck", () => {
    expect(gruppeDesModells({ eigene: null, katalog: null, category: "cardio" })).toBe("cardio");
    expect(gruppeDesModells({ eigene: null, katalog: null, category: "kraft" })).toBe("geraete");
  });
});

// Testnotiz 12.10. abends, #3: wo das Rad ohne Historie steht.
describe("startDesModells", () => {
  it("nimmt den eigenen Startwert vor dem des Gymtavo-Typs", () => {
    expect(startDesModells({ eigener: 30, katalog: { start: 20, einheit: "kg" }, einheit: "kg" })).toBe(30);
  });

  it("erbt den Startwert des Gymtavo-Typs bei gleicher Einheit", () => {
    expect(startDesModells({ eigener: null, katalog: { start: 20, einheit: "kg" }, einheit: "kg" })).toBe(20);
  });

  it("erbt nicht ueber verschiedene Einheiten und ohne Zuordnung", () => {
    expect(startDesModells({ eigener: null, katalog: { start: 20, einheit: "kg" }, einheit: "level" })).toBeNull();
    expect(startDesModells({ eigener: null, katalog: null, einheit: "kg" })).toBeNull();
  });
});
