import { describe, expect, it } from "vitest";
import { FOKUS_BEREICHE, PFLICHT_BAUSTEINE } from "./trainingsplan-typen.js";
import type { Struktur } from "./trainingsplan-regeln.js";
import { FOKUS_MUSKELN, strukturFuerTage, zielAusTrainingGoal, zielprofil } from "./trainingsplan-regeln.js";

type Einheit = Struktur["einheiten"][number];
const keys = (tage: number) => strukturFuerTage(tage).einheiten.map((e) => e.key);

describe("zielAusTrainingGoal", () => {
  it("bildet Ziele ab", () => {
    expect(zielAusTrainingGoal("get_stronger")).toBe("muskelaufbau");
    expect(zielAusTrainingGoal("build_muscle")).toBe("muskelaufbau");
    expect(zielAusTrainingGoal("stay_fit")).toBe("fitness");
    expect(zielAusTrainingGoal("lose_weight")).toBe("abnehmen");
    expect(zielAusTrainingGoal(null)).toBeNull();
    expect(zielAusTrainingGoal("xyz")).toBeNull();
  });
});

describe("zielprofil", () => {
  it("Erfahrung neu mit Anfaengerende nutzt das Profil von unregelmaessig", () => {
    expect(zielprofil("muskelaufbau", "neu", true)).toEqual(zielprofil("muskelaufbau", "unregelmaessig"));
  });

  it("Muskelaufbau regelmaessig", () => {
    expect(zielprofil("muskelaufbau", "regelmaessig")).toEqual({
      saetze: 3,
      wdh: { mehrgelenk: [8, 12], isolation: [10, 15] },
      reserve: [1, 3],
    });
  });
  it("Anfaenger: 2 Saetze, Reserve 3-4", () => {
    const p = zielprofil("fitness", "neu");
    expect(p.saetze).toBe(2);
    expect(p.reserve).toEqual([3, 4]);
    expect(p.wdh.mehrgelenk).toEqual([10, 15]);
  });
  it("Fitness plant immer 2 Saetze", () => {
    for (const e of ["regelmaessig", "unregelmaessig"] as const) {
      const p = zielprofil("fitness", e);
      expect(p.saetze).toBe(2);
      expect(p.reserve).toEqual([2, 3]);
    }
  });
  it("Abnehmen unregelmaessig", () => {
    const p = zielprofil("abnehmen", "unregelmaessig");
    expect(p.saetze).toBe(3);
    expect(p.reserve).toEqual([2, 3]);
  });
});

describe("strukturFuerTage", () => {
  it("waehlt Struktur nach Tagen", () => {
    expect(keys(0)).toEqual(["A"]);
    expect(keys(1)).toEqual(["A"]);
    expect(strukturFuerTage(1).key).toBe("gk_eine");
    expect(keys(2)).toEqual(["A", "B"]);
    expect(keys(3)).toEqual(["A", "B"]);
    expect(keys(4)).toEqual(["OK_A", "UK_A", "OK_B", "UK_B"]);
    expect(strukturFuerTage(4).key).toBe("ober_unter");
    expect(keys(5)).toEqual(["A", "B", "C"]);
    expect(keys(6)).toEqual(["A", "B", "C"]);
    expect(keys(7)).toEqual(keys(6));
  });
  it("Ganzkoerper-Einheiten haben alle Pflichtbausteine", () => {
    for (const t of [1, 3, 5]) {
      for (const e of strukturFuerTage(t).einheiten) {
        expect(e.bausteine.pflicht).toEqual(PFLICHT_BAUSTEINE);
        expect(e.bausteine.ergaenzung).toEqual(["schulter", "rumpf", "arme", "beine_ergaenzung"]);
      }
    }
  });
  it("Ober-/Unterkoerper-Bausteine", () => {
    const [ok, uk] = strukturFuerTage(4).einheiten as [Einheit, Einheit];
    expect(ok.bausteine).toEqual({ pflicht: ["druecken", "ziehen"], ergaenzung: ["schulter", "arme"] });
    expect(uk.bausteine).toEqual({ pflicht: ["beine_knie", "beine_huefte"], ergaenzung: ["beine_ergaenzung", "rumpf"] });
  });
});

describe("FOKUS_MUSKELN", () => {
  it("jeder Fokusbereich hat Muskeln", () => {
    for (const b of FOKUS_BEREICHE) expect(FOKUS_MUSKELN[b].length).toBeGreaterThan(0);
  });
});
