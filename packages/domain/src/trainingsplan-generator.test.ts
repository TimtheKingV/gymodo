import { describe, expect, expectTypeOf, it } from "vitest";
import { PlanNichtMoeglichError } from "./errors.js";
import type { GeneratorEingabe, Kandidat, PlanEinheit } from "./trainingsplan-generator.js";
import { generierePlan } from "./trainingsplan-generator.js";
import type { Baustein, Bereich, PlanTyp } from "./trainingsplan-typen.js";
import { PLAN_REGEL_VERSION } from "./trainingsplan-regeln.js";

// Kleiner Testkatalog: je Baustein 2 Kandidaten, Typen wie in der Spec (beine_huefte hier
// Isolation, damit die Zeitrechnung des 60-min-Falls exakt 62,75 ergibt), ein Cardiogeraet.
function k(
  exerciseId: string,
  baustein: Baustein,
  typ: PlanTyp,
  hauptmuskeln: string[],
  bereiche: Bereich[] = [],
): Kandidat {
  return { exerciseId, machineId: `m_${exerciseId}`, baustein, typ, bereiche, hauptmuskeln };
}

const KATALOG: Kandidat[] = [
  k("belt_squat", "beine_knie", "mehrgelenk", ["quads"]),
  k("leg_press", "beine_knie", "mehrgelenk", ["quads"], ["knie"]),
  k("leg_curl", "beine_huefte", "isolation", ["hamstrings"], ["knie"]),
  k("hip_thrust", "beine_huefte", "isolation", ["glutes"], ["huefte"]),
  k("chest_press", "druecken", "mehrgelenk", ["pectorals"], ["schulter"]),
  k("incline_press", "druecken", "mehrgelenk", ["pectorals"], ["schulter"]),
  k("row", "ziehen", "mehrgelenk", ["upper_back"]),
  k("lat_pulldown", "ziehen", "mehrgelenk", ["lats"]),
  k("lateral_raise", "schulter", "isolation", ["deltoid_lateral"]),
  k("cable_lateral", "schulter", "isolation", ["deltoid_lateral"]),
  k("ab_crunch", "rumpf", "isolation", ["abs"]),
  k("back_extension", "rumpf", "isolation", ["lower_back"], ["unterer_ruecken"]),
  k("curl", "arme", "isolation", ["biceps"], ["ellenbogen_handgelenk"]),
  k("triceps_ext", "arme", "isolation", ["triceps"], ["ellenbogen_handgelenk"]),
  k("leg_extension", "beine_ergaenzung", "isolation", ["quads"], ["knie"]),
  k("calf_raise", "beine_ergaenzung", "isolation", ["calves"]),
  k("bike", "cardio", "isolation", []),
];

function eingabe(teil: Partial<GeneratorEingabe> = {}): GeneratorEingabe {
  return {
    ziel: "muskelaufbau",
    tage: 3,
    minuten: 60,
    fokus: [],
    erfahrung: "regelmaessig",
    beschwerden: {},
    kandidaten: KATALOG,
    ...teil,
  };
}

const ohne = (...ids: string[]) => KATALOG.filter((c) => !ids.includes(c.exerciseId));
const rollen = (e: PlanEinheit) => e.positionen.map((p) => p.rolle);
const kraft = (e: PlanEinheit) => e.positionen.filter((p) => p.rolle !== "cardio");
const bereicheVon = (id: string) => KATALOG.find((c) => c.exerciseId === id)!.bereiche;

describe("generierePlan: Zeit und Ziele", () => {
  it("60 min Muskelaufbau regelmaessig, 3 Tage: 7 Positionen je Einheit (4 Pflicht, 3 Ergaenzungen), geschaetzteMinuten 62.75", () => {
    const plan = generierePlan(eingabe());
    expect(plan.regelVersion).toBe(PLAN_REGEL_VERSION);
    expect(plan.struktur).toBe("gk_ab");
    expect(plan.einheiten.map((e) => e.key)).toEqual(["A", "B"]);
    for (const e of plan.einheiten) {
      expect(rollen(e)).toEqual(["pflicht", "pflicht", "pflicht", "pflicht", "ergaenzung", "ergaenzung", "ergaenzung"]);
      expect(e.positionen.map((p) => p.baustein)).toEqual([
        "beine_knie", "beine_huefte", "druecken", "ziehen", "schulter", "rumpf", "arme",
      ]);
      expect(e.positionen.map((p) => p.key)).toEqual(["0", "1", "2", "3", "4", "5", "6"]);
      expect(e.positionen.every((p) => p.saetze === 3)).toBe(true);
      // 5 + 3 x 10,25 + 4 x 6,75; Obergrenze 60 x 1,05 = 63
      expect(e.geschaetzteMinuten).toBeCloseTo(62.75, 10);
      expect(e.geschaetzteMinuten).toBeLessThanOrEqual(63);
    }
    const knie = plan.einheiten[0]!.positionen[0]!;
    expect(knie).toMatchObject({
      typ: "mehrgelenk", wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 3,
      pauseSek: 150, aufwaermsatz: true, dauerMin: null,
    });
    const huefte = plan.einheiten[0]!.positionen[1]!;
    expect(huefte).toMatchObject({ typ: "isolation", wdhVon: 10, wdhBis: 15, pauseSek: 90, aufwaermsatz: false });
    expect(plan.gruende).toContain("struktur_ganzkoerper_ab");
    expect(plan.gruende).toContain("zeit_uebungen");
    expect(plan.gruende).toContain("zeit_ergaenzung_entfallen");
    expect(plan.gruende).not.toContain("zeit_saetze_reduziert");
  });

  it("30 min Muskelaufbau: 5 Positionen mit 2 Saetzen, kein allgemeines Aufwaermen, Minuten <= 31.5", () => {
    const plan = generierePlan(eingabe({ minuten: 30 }));
    for (const e of plan.einheiten) {
      expect(e.positionen).toHaveLength(5);
      expect(e.positionen.every((p) => p.saetze === 2)).toBe(true);
      // 3 x 7 + 2 x 4,5 ohne Aufwaermen
      expect(e.geschaetzteMinuten).toBeCloseTo(30, 10);
      expect(e.geschaetzteMinuten).toBeLessThanOrEqual(31.5);
    }
    expect(plan.gruende).toContain("zeit_aufwaermen_entfallen");
    expect(plan.gruende).toContain("zeit_saetze_reduziert");
  });

  it("45 min Fitness: 2 Saetze, Reserve [2,3]", () => {
    const plan = generierePlan(eingabe({ ziel: "fitness", minuten: 45 }));
    for (const p of plan.einheiten.flatMap((e) => e.positionen)) {
      expect(p.saetze).toBe(2);
      expect([p.reserveVon, p.reserveBis]).toEqual([2, 3]);
      expect([p.wdhVon, p.wdhBis]).toEqual([10, 15]);
    }
    expect(plan.gruende).not.toContain("zeit_saetze_reduziert");
  });

  it("Abnehmen 60 min: letzte Position ist Cardio mit dauerMin 20, Minuten <= 63", () => {
    const plan = generierePlan(eingabe({ ziel: "abnehmen" }));
    for (const e of plan.einheiten) {
      const letzte = e.positionen.at(-1)!;
      expect(letzte).toMatchObject({
        rolle: "cardio", baustein: "cardio", exerciseId: "bike", machineId: "m_bike",
        saetze: 1, wdhVon: null, wdhBis: null, pauseSek: 0, aufwaermsatz: false, dauerMin: 20, hauptmuskeln: [],
        reserveVon: 2, reserveBis: 3,
      });
      expect(e.positionen.filter((p) => p.rolle === "cardio")).toHaveLength(1);
      expect(e.geschaetzteMinuten).toBeLessThanOrEqual(63);
    }
    expect(plan.gruende).toContain("abnehmen_cardio_zone");
    expect(plan.gruende).toContain("abnehmen_alltag");
    expect(plan.gruende).not.toContain("abnehmen_cardio_gekuerzt");
  });

  it("Abnehmen 45 min: dauerMin 10, Code abnehmen_cardio_gekuerzt", () => {
    const plan = generierePlan(eingabe({ ziel: "abnehmen", minuten: 45 }));
    for (const e of plan.einheiten) {
      expect(e.positionen.at(-1)).toMatchObject({ rolle: "cardio", dauerMin: 10 });
      expect(e.geschaetzteMinuten).toBeLessThanOrEqual(45 * 1.05);
    }
    expect(plan.gruende).toContain("abnehmen_cardio_gekuerzt");
  });

  it("Abnehmen 30 min: kein Cardio", () => {
    const plan = generierePlan(eingabe({ ziel: "abnehmen", minuten: 30 }));
    for (const e of plan.einheiten) expect(rollen(e)).not.toContain("cardio");
    expect(plan.gruende).toContain("abnehmen_alltag");
    expect(plan.gruende).not.toContain("abnehmen_cardio_zone");
  });

  it("Abnehmen ohne Cardio-Kandidat: kein Cardio, Code abnehmen_kein_cardio_geraet, mehr Kraftuebungen als mit Cardio", () => {
    const mit = generierePlan(eingabe({ ziel: "abnehmen" }));
    const ohneCardio = generierePlan(eingabe({ ziel: "abnehmen", kandidaten: ohne("bike") }));
    for (const e of ohneCardio.einheiten) expect(rollen(e)).not.toContain("cardio");
    expect(ohneCardio.gruende).toContain("abnehmen_kein_cardio_geraet");
    expect(ohneCardio.gruende).not.toContain("abnehmen_cardio_zone");
    expect(kraft(ohneCardio.einheiten[0]!).length).toBeGreaterThan(kraft(mit.einheiten[0]!).length);
  });

  it("Erfahrung neu: alle Positionen 2 Saetze, Reserve [3,4], Code anfaenger_reserve", () => {
    const plan = generierePlan(eingabe({ erfahrung: "neu" }));
    for (const p of plan.einheiten.flatMap((e) => e.positionen)) {
      expect(p.saetze).toBe(2);
      expect([p.reserveVon, p.reserveBis]).toEqual([3, 4]);
    }
    expect(plan.gruende).toContain("anfaenger_reserve");
    expect(plan.gruende).not.toContain("zeit_saetze_reduziert");
  });
});

describe("generierePlan: Struktur und Variation", () => {
  it("A und B waehlen verschiedene Uebungen je Pflichtbaustein, wenn mindestens 2 Kandidaten", () => {
    const [a, b] = generierePlan(eingabe()).einheiten;
    for (const baustein of ["beine_knie", "beine_huefte", "druecken", "ziehen"] as const) {
      const ea = a!.positionen.find((p) => p.baustein === baustein)!.exerciseId;
      const eb = b!.positionen.find((p) => p.baustein === baustein)!.exerciseId;
      expect(ea).not.toBe(eb);
    }
  });

  it("bei einem Kandidaten gleiche Uebung, kein Fehler", () => {
    const [a, b] = generierePlan(eingabe({ kandidaten: ohne("incline_press") })).einheiten;
    const druecken = (e: PlanEinheit) => e.positionen.find((p) => p.baustein === "druecken")!.exerciseId;
    expect(druecken(a!)).toBe("chest_press");
    expect(druecken(b!)).toBe("chest_press");
  });

  it("4 Tage: vier Einheiten OK_A, UK_A, OK_B, UK_B; Oberkoerper enthaelt nur druecken/ziehen/schulter/arme", () => {
    const plan = generierePlan(eingabe({ tage: 4 }));
    expect(plan.struktur).toBe("ober_unter");
    expect(plan.gruende).toContain("struktur_ober_unter");
    expect(plan.einheiten.map((e) => e.key)).toEqual(["OK_A", "UK_A", "OK_B", "UK_B"]);
    for (const e of plan.einheiten.filter((x) => x.key.startsWith("OK"))) {
      for (const p of e.positionen) expect(["druecken", "ziehen", "schulter", "arme"]).toContain(p.baustein);
    }
    // A und B desselben Typs wechseln die Uebung, sonst waere die B-Einheit eine Kopie.
    const druecken = (key: string) =>
      plan.einheiten.find((e) => e.key === key)!.positionen.find((p) => p.baustein === "druecken")!.exerciseId;
    expect(druecken("OK_A")).not.toBe(druecken("OK_B"));
  });

  it("Strukturcodes fuer 1 und 5 Tage", () => {
    expect(generierePlan(eingabe({ tage: 1 })).gruende).toContain("struktur_ganzkoerper_eine_einheit");
    const abc = generierePlan(eingabe({ tage: 5 }));
    expect(abc.gruende).toContain("struktur_ganzkoerper_abc");
    expect(abc.einheiten).toHaveLength(3);
  });
});

describe("generierePlan: Fokus", () => {
  // Zweiter Po-Kandidat, damit auch Einheit B (hip_thrust als Pflicht) eine eigene Fokusuebung hat.
  const mitKickback = [...KATALOG, k("glute_kickback", "beine_ergaenzung", "isolation", ["glutes"])];

  it("Fokus po: jede Einheit mit passendem Kandidaten enthaelt genau eine Fokusposition, Zahl der Positionen gleich wie ohne Fokus", () => {
    const basis = generierePlan(eingabe({ kandidaten: mitKickback }));
    const plan = generierePlan(eingabe({ kandidaten: mitKickback, fokus: ["po"] }));
    plan.einheiten.forEach((e, i) => {
      const fokus = e.positionen.filter((p) => p.rolle === "fokus");
      expect(fokus).toHaveLength(1);
      expect(fokus[0]!.hauptmuskeln).toContain("glutes");
      expect(e.positionen).toHaveLength(basis.einheiten[i]!.positionen.length);
      // Fokus steht nach den Pflichtpositionen und vor den Ergaenzungen.
      expect(rollen(e).indexOf("fokus")).toBe(4);
      const ids = e.positionen.map((p) => p.exerciseId);
      expect(new Set(ids).size).toBe(ids.length);
    });
    expect(plan.gruende).toContain("fokus_po");
  });

  it("Fokus ohne passenden Kandidaten in der Einheit entfaellt dort", () => {
    // Nur hip_thrust traegt glutes: B hat ihn schon als Pflicht, also kein Fokus in B.
    const plan = generierePlan(eingabe({ fokus: ["po"] }));
    expect(rollen(plan.einheiten[0]!)).toContain("fokus");
    expect(rollen(plan.einheiten[1]!)).not.toContain("fokus");
  });

  it("Fokus bauch + Abnehmen: Code bauch_kein_fettabbau", () => {
    const plan = generierePlan(eingabe({ ziel: "abnehmen", fokus: ["bauch"] }));
    expect(plan.gruende).toContain("bauch_kein_fettabbau");
    expect(generierePlan(eingabe({ fokus: ["bauch"] })).gruende).not.toContain("bauch_kein_fettabbau");
  });

  it("zwei Fokusse, Zeit reicht nur fuer einen: fokus_zweiter_entfallen", () => {
    // 30 min: Pflicht 25,5 + ein Fokus 4,5 = 30 <= 31,5; ein zweiter Fokus waere 34,5.
    const plan = generierePlan(eingabe({ minuten: 30, kandidaten: mitKickback, fokus: ["po", "arme"] }));
    for (const e of plan.einheiten) {
      expect(e.positionen.filter((p) => p.rolle === "fokus")).toHaveLength(1);
      expect(e.geschaetzteMinuten).toBeLessThanOrEqual(31.5);
    }
    expect(plan.gruende).toContain("fokus_po");
    expect(plan.gruende).not.toContain("fokus_arme");
    expect(plan.gruende).toContain("fokus_zweiter_entfallen");
  });
});

describe("generierePlan: Beschwerden", () => {
  it("meiden knie: keine Position hat bereich knie", () => {
    const plan = generierePlan(eingabe({ beschwerden: { knie: "meiden" } }));
    for (const p of plan.einheiten.flatMap((e) => e.positionen)) {
      expect(bereicheVon(p.exerciseId)).not.toContain("knie");
    }
    expect(plan.gruende).toContain("beschwerden_meiden");
  });

  it("vorsichtig knie: Kandidat mit knie steht hinten, wird aber gewaehlt, wenn er der einzige ist", () => {
    const plan = generierePlan(
      eingabe({ beschwerden: { knie: "vorsichtig" }, kandidaten: [k("leg_press", "beine_knie", "mehrgelenk", ["quads"], ["knie"]), ...ohne("leg_press", "belt_squat")] }),
    );
    expect(plan.einheiten[0]!.positionen[0]!.exerciseId).toBe("leg_press");
    expect(plan.gruende).toContain("beschwerden_vorsichtig");

    // leg_curl (knie) steht im Katalog vorn, wird bei "vorsichtig" aber nach hinten sortiert.
    const sortiert = generierePlan(eingabe({ beschwerden: { knie: "vorsichtig" } }));
    expect(sortiert.einheiten[0]!.positionen[1]!.exerciseId).toBe("hip_thrust");
    expect(sortiert.einheiten[1]!.positionen[1]!.exerciseId).toBe("leg_curl");
  });

  it("Pflichtbaustein ohne Kandidat wirft PlanNichtMoeglichError(kein_geraet)", () => {
    try {
      generierePlan(eingabe({ kandidaten: ohne("chest_press", "incline_press") }));
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(PlanNichtMoeglichError);
      const fehler = e as PlanNichtMoeglichError;
      expect(fehler.baustein).toBe("druecken");
      expect(fehler.grund).toBe("kein_geraet");
      expect(fehler.code).toBe("plan_nicht_moeglich");
    }
  });

  it("alle Kandidaten eines Pflichtbausteins gemieden wirft PlanNichtMoeglichError(beschwerden)", () => {
    try {
      generierePlan(eingabe({ beschwerden: { schulter: "meiden" } }));
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(PlanNichtMoeglichError);
      expect((e as PlanNichtMoeglichError).baustein).toBe("druecken");
      expect((e as PlanNichtMoeglichError).grund).toBe("beschwerden");
    }
  });
});

describe("generierePlan: Determinismus und Eingabe", () => {
  it("Determinismus: zweimal dieselbe Eingabe, tiefes Gleichheitsergebnis", () => {
    const e = eingabe({ ziel: "abnehmen", fokus: ["po", "arme"], beschwerden: { knie: "vorsichtig" } });
    expect(generierePlan(e)).toEqual(generierePlan(e));
  });

  it("Geschlecht/Alter sind kein Eingabefeld", () => {
    expectTypeOf<keyof GeneratorEingabe>().toEqualTypeOf<
      "ziel" | "tage" | "minuten" | "fokus" | "erfahrung" | "beschwerden" | "kandidaten"
    >();
  });

  it("Gruende ohne Duplikate", () => {
    const plan = generierePlan(eingabe({ ziel: "abnehmen", minuten: 45, fokus: ["bauch", "po"], erfahrung: "neu" }));
    expect(new Set(plan.gruende).size).toBe(plan.gruende.length);
  });
});
