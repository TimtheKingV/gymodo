import { describe, expect, it } from "vitest";
import { gruppeDesModells, letzteSaetze, startDesModells, uebungAusZeile, zaehleBesucheJeGeraet } from "./bootstrap.js";

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

describe("letzteSaetze", () => {
  const satz = (o: {
    machine_id: string | null;
    equipment_model_id?: string;
    exercise_id: string;
    session_id: string;
    performed_at: string;
    load?: number | null;
    volume?: number | null;
    dauer_s?: number | null;
    strecke_m?: number | null;
  }) => ({
    equipment_model_id: "em1",
    load: 10 as number | null,
    secondary_load: null,
    volume: 10 as number | null,
    rir: null,
    dauer_s: null,
    strecke_m: null,
    stufe: null,
    stufenanzahl: null,
    kmh: null,
    steigung_pct: null,
    watt: null,
    kcal: null,
    frequenz: null,
    ...o,
  });

  it("liefert Cardio-Werte am letzten Satz und null bei Kraft", () => {
    const { lastSets } = letzteSaetze([
      satz({ machine_id: "m1", exercise_id: "c1", session_id: "s1", performed_at: "2026-10-14T10:00:00Z", load: null, volume: null, dauer_s: 510, strecke_m: 2000 }),
      satz({ machine_id: "m2", exercise_id: "u1", session_id: "s1", performed_at: "2026-10-14T09:00:00Z" }),
    ]);
    expect(lastSets[0]).toMatchObject({ load: null, volume: null, cardio: { zeit: 510, strecke: 2000 } });
    expect(lastSets[1]).toMatchObject({ load: 10, cardio: null });
  });

  // Testnotiz 14.10., 18:25: die Uebungsliste am Geraet sortiert nach
  // Haeufigkeit -- gezaehlt in Einheiten, nicht in Saetzen.
  it("zaehlt je Geraet und Uebung die Einheiten, nicht die Saetze", () => {
    const { lastSets } = letzteSaetze([
      satz({ machine_id: "m1", exercise_id: "u1", session_id: "s2", performed_at: "2026-10-14T10:02:00Z", load: 30 }),
      satz({ machine_id: "m1", exercise_id: "u1", session_id: "s2", performed_at: "2026-10-14T10:01:00Z" }),
      satz({ machine_id: "m1", exercise_id: "u1", session_id: "s1", performed_at: "2026-10-10T10:00:00Z" }),
      satz({ machine_id: "m1", exercise_id: "u2", session_id: "s1", performed_at: "2026-10-10T09:00:00Z" }),
    ]);

    expect(lastSets).toEqual([
      expect.objectContaining({ machineId: "m1", exerciseId: "u1", load: 30, sessionCount: 2 }),
      expect.objectContaining({ machineId: "m1", exerciseId: "u2", sessionCount: 1 }),
    ]);
  });

  it("zaehlt am Typ getrennt vom Geraet", () => {
    const { lastSets, lastTypeSets } = letzteSaetze([
      satz({ machine_id: null, equipment_model_id: "t1", exercise_id: "u1", session_id: "s1", performed_at: "2026-10-14T10:00:00Z" }),
      satz({ machine_id: "m1", equipment_model_id: "t1", exercise_id: "u1", session_id: "s2", performed_at: "2026-10-13T10:00:00Z" }),
    ]);

    expect(lastTypeSets).toEqual([
      expect.objectContaining({ equipmentModelId: "t1", exerciseId: "u1", sessionCount: 1 }),
    ]);
    expect(lastSets).toEqual([
      expect.objectContaining({ machineId: "m1", exerciseId: "u1", sessionCount: 1 }),
    ]);
  });
});

describe("uebungAusZeile", () => {
  it("reicht die Beschreibung fuer die Einweisung offline durch", () => {
    expect(
      uebungAusZeile({ id: "e1", name: "Face Pull", description: "Ellbogen hoch.", volume_kind: "reps", target_min: 12, target_max: 15 }),
    ).toEqual({ id: "e1", name: "Face Pull", description: "Ellbogen hoch.", volumeKind: "reps", targetMin: 12, targetMax: 15, muscles: [] });
  });

  it("reicht die Muskeln unveraendert durch", () => {
    const muscles = [
      { key: "rear-delt", name: "Hintere Schulter", role: "primary" as const },
      { key: "trapezius", name: "Trapezmuskel", role: "secondary" as const },
    ];
    expect(
      uebungAusZeile({ id: "e1", name: "Face Pull", description: null, volume_kind: "reps", target_min: 12, target_max: 15, muscles }).muscles,
    ).toEqual(muscles);
  });

  it("liefert [] statt null, wenn die Spalte fehlt oder null ist", () => {
    const basis = { id: "e2", name: "X", description: null, volume_kind: "reps" as const, target_min: 8, target_max: 12 };
    expect(uebungAusZeile(basis).muscles).toEqual([]);
    expect(uebungAusZeile({ ...basis, muscles: null }).muscles).toEqual([]);
  });

  it("liefert null ohne gepflegte Beschreibung", () => {
    expect(
      uebungAusZeile({ id: "e2", name: "X", description: null, volume_kind: "reps", target_min: 8, target_max: 12 }).description,
    ).toBeNull();
  });
});
