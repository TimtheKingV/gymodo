import { describe, expect, expectTypeOf, it } from "vitest";
import { PlanNichtMoeglichError } from "./errors.js";
import type { GeneratorEingabe, Kandidat, PlanEinheit } from "./trainingsplan-generator.js";
import { generierePlan, tauschVorgaben } from "./trainingsplan-generator.js";
import { waehleFokus, waehleKandidat } from "./trainingsplan-auswahl.js";
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
  return { exerciseId, modelId: `m_${exerciseId}`, baustein, typ, bereiche, hauptmuskeln };
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
        "beine_knie", "druecken", "ziehen", "beine_huefte", "schulter", "rumpf", "arme",
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
    const huefte = plan.einheiten[0]!.positionen.find((p) => p.baustein === "beine_huefte")!;
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
        rolle: "cardio", baustein: "cardio", exerciseId: "bike", modelId: "m_bike",
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

  it("Variation ueber Uebungen, nicht ueber Geraete: zwei Geraete derselben Uebung zaehlen einmal", () => {
    const zweiGeraete = [
      { ...k("chest_press", "druecken", "mehrgelenk", ["pectorals"]), modelId: "m1" },
      { ...k("chest_press", "druecken", "mehrgelenk", ["pectorals"]), modelId: "m2" },
      k("incline_press", "druecken", "mehrgelenk", ["pectorals"]),
      ...ohne("chest_press", "incline_press"),
    ];
    const [a, b] = generierePlan(eingabe({ kandidaten: zweiGeraete })).einheiten;
    const druecken = (e: PlanEinheit) => e.positionen.find((p) => p.baustein === "druecken")!;
    expect(druecken(a!)).toMatchObject({ exerciseId: "chest_press", modelId: "m1" });
    expect(druecken(b!).exerciseId).toBe("incline_press");

    const eineUebung = zweiGeraete.filter((c) => c.exerciseId !== "incline_press");
    const [a2, b2] = generierePlan(eingabe({ kandidaten: eineUebung })).einheiten;
    expect(druecken(a2!).exerciseId).toBe("chest_press");
    expect(druecken(b2!).exerciseId).toBe("chest_press");
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

  it("90 und 75 min: Fokus ersetzt eine Ergaenzung, nie eine zusaetzliche Position (F9)", () => {
    // Seit dem Auffuellen bis zum Budget (1.1.0) ist exakte Gleichheit nicht mehr garantiert:
    // der Fokus verbraucht einen Kandidaten, der sonst beim Auffuellen genommen wuerde. Zugesagt
    // bleibt: Fokus vorhanden, Zeit im Rahmen, nie mehr Positionen als ohne Fokus.
    for (const minuten of [90, 75] as const) {
      for (const katalog of [mitKickback, VOLL]) {
        const basis = generierePlan(eingabe({ minuten, kandidaten: katalog }));
        const plan = generierePlan(eingabe({ minuten, kandidaten: katalog, fokus: ["po"] }));
        plan.einheiten.forEach((e, i) => {
          expect(rollen(e).filter((r) => r === "fokus")).toHaveLength(1);
          expect(e.positionen.length).toBeLessThanOrEqual(basis.einheiten[i]!.positionen.length);
          expect(e.geschaetzteMinuten).toBeLessThanOrEqual(minuten * 1.05 + 1e-9);
        });
      }
    }
  });

  it("Fokus aus beine_ergaenzung erzeugt keine zusaetzliche beine_ergaenzung-Position", () => {
    // Einheit B: hip_thrust ist Pflicht, also wird glute_kickback (beine_ergaenzung) der Fokus.
    // 75 min: Platz fuer alle Ergaenzungen und eine Auffuellrunde, aber nicht fuer eine
    // weitere beine_ergaenzung (die waere erst nach schulter in der Runde dran).
    const plan = generierePlan(eingabe({ minuten: 75, kandidaten: mitKickback, fokus: ["po"] }));
    const b = plan.einheiten[1]!;
    const beinErg = b.positionen.filter((p) => p.baustein === "beine_ergaenzung");
    expect(beinErg).toHaveLength(1);
    expect(beinErg[0]).toMatchObject({ rolle: "fokus", exerciseId: "glute_kickback" });
    expect(b.positionen.map((p) => p.baustein).slice(0, 8)).toEqual([
      // Seit 1.2.0: Mehrgelenk zuerst; bei den Isolationen Pflicht, Fokus, Auffuellung, Ergaenzung.
      "beine_knie", "druecken", "ziehen", "beine_huefte", "beine_ergaenzung", "beine_huefte", "schulter", "rumpf",
    ]);
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
    // Die A/B-Rotation laeuft nur ueber unbedenkliche Uebungen, solange es welche gibt:
    // sonst bekaeme B bei zwei Kandidaten immer die vorsichtige.
    expect(sortiert.einheiten[0]!.positionen.find((p) => p.baustein === "beine_huefte")!.exerciseId).toBe("hip_thrust");
    expect(sortiert.einheiten[1]!.positionen.find((p) => p.baustein === "beine_huefte")!.exerciseId).toBe("hip_thrust");
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

  it("Pflichtbaustein ohne freie Uebung (dieselbe Uebung in zwei Pflichtbausteinen) wirft kein_geraet statt abzustuerzen", () => {
    const geteilt = [
      k("multi_press", "druecken", "mehrgelenk", ["pectorals"]),
      { ...k("multi_press", "ziehen", "mehrgelenk", ["lats"]), modelId: "m_zug" },
      ...ohne("chest_press", "incline_press", "row", "lat_pulldown"),
    ];
    try {
      generierePlan(eingabe({ kandidaten: geteilt }));
      expect.unreachable();
    } catch (e) {
      expect(e).toBeInstanceOf(PlanNichtMoeglichError);
      expect((e as PlanNichtMoeglichError).baustein).toBe("ziehen");
      expect((e as PlanNichtMoeglichError).grund).toBe("kein_geraet");
    }
  });

  it("Abnehmen, alle Cardiogeraete gemieden: kein Cardio, aber kein abnehmen_kein_cardio_geraet", () => {
    const katalog = [...ohne("bike"), k("stepper", "cardio", "isolation", [], ["knie"])];
    const plan = generierePlan(eingabe({ ziel: "abnehmen", kandidaten: katalog, beschwerden: { knie: "meiden" } }));
    for (const e of plan.einheiten) expect(rollen(e)).not.toContain("cardio");
    expect(plan.gruende).not.toContain("abnehmen_kein_cardio_geraet");
    expect(plan.gruende).not.toContain("abnehmen_cardio_zone");
    expect(plan.gruende).toContain("beschwerden_meiden");
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
      "ziel" | "tage" | "minuten" | "fokus" | "erfahrung" | "anfaengerBeendet" | "beschwerden" | "kandidaten"
    >();
  });

  it("Gruende ohne Duplikate", () => {
    const plan = generierePlan(eingabe({ ziel: "abnehmen", minuten: 45, fokus: ["bauch", "po"], erfahrung: "neu" }));
    expect(new Set(plan.gruende).size).toBe(plan.gruende.length);
  });
});

// Realistischer Katalog: mindestens 3 Uebungen je Baustein (auch Cardio), damit die
// Auffuellung genug Auswahl hat wie in einem echten Studio.
const VOLL: Kandidat[] = [
  k("leg_press", "beine_knie", "mehrgelenk", ["quads"], ["knie"]),
  k("hack_squat", "beine_knie", "mehrgelenk", ["quads", "glutes"], ["knie"]),
  k("belt_squat", "beine_knie", "mehrgelenk", ["quads", "glutes"], ["huefte"]),
  k("hip_thrust", "beine_huefte", "mehrgelenk", ["glutes"], ["huefte"]),
  k("leg_curl_seated", "beine_huefte", "isolation", ["hamstrings"], ["knie"]),
  k("leg_curl_prone", "beine_huefte", "isolation", ["hamstrings"], ["knie"]),
  k("chest_press", "druecken", "mehrgelenk", ["pectorals"], ["schulter"]),
  k("incline_press", "druecken", "mehrgelenk", ["pectorals"], ["schulter"]),
  k("shoulder_press", "druecken", "mehrgelenk", ["deltoid_anterior"], ["schulter"]),
  k("row", "ziehen", "mehrgelenk", ["upper_back"]),
  k("lat_pulldown", "ziehen", "mehrgelenk", ["lats"], ["schulter"]),
  k("high_row", "ziehen", "mehrgelenk", ["upper_back", "lats"]),
  k("lateral_raise", "schulter", "isolation", ["deltoid_lateral"], ["schulter"]),
  k("cable_lateral", "schulter", "isolation", ["deltoid_lateral"], ["schulter"]),
  k("reverse_fly", "schulter", "isolation", ["deltoid_posterior"]),
  k("ab_crunch", "rumpf", "isolation", ["abs"]),
  k("cable_crunch", "rumpf", "isolation", ["abs", "obliques"]),
  k("back_extension", "rumpf", "isolation", ["lower_back"], ["unterer_ruecken"]),
  k("curl", "arme", "isolation", ["biceps"], ["ellenbogen_handgelenk"]),
  k("triceps_ext", "arme", "isolation", ["triceps"], ["ellenbogen_handgelenk"]),
  k("cable_curl", "arme", "isolation", ["biceps"], ["ellenbogen_handgelenk"]),
  k("leg_extension", "beine_ergaenzung", "isolation", ["quads"], ["knie"]),
  k("calf_raise", "beine_ergaenzung", "isolation", ["calves"]),
  k("abductor", "beine_ergaenzung", "isolation", ["glutes"], ["huefte"]),
  k("bike", "cardio", "isolation", []),
  k("treadmill", "cardio", "isolation", [], ["knie"]),
  k("crosstrainer", "cardio", "isolation", []),
];

describe("generierePlan: Zeitbudget ausschoepfen", () => {
  it("Ober/Unter 60 min Muskelaufbau fuellt mit weiteren Uebungen auf, statt nach 4 Uebungen aufzuhoeren", () => {
    const plan = generierePlan(eingabe({ tage: 4, kandidaten: VOLL }));
    for (const e of plan.einheiten) {
      expect(e.geschaetzteMinuten).toBeGreaterThanOrEqual(0.9 * 60);
      expect(e.geschaetzteMinuten).toBeLessThanOrEqual(63 + 1e-9);
      const ids = e.positionen.map((p) => p.exerciseId);
      expect(new Set(ids).size).toBe(ids.length);
      // Auffuellung bleibt in den Bausteinen der Einheit (Oberkoerper bleibt Oberkoerper).
      if (e.key.startsWith("OK")) {
        for (const p of e.positionen) expect(["druecken", "ziehen", "schulter", "arme"]).toContain(p.baustein);
      }
    }
    expect(plan.gruende).not.toContain("zeit_budget_nicht_ausgeschoepft");
    expect(plan.regelVersion).toBe("1.2.0");
  });

  it("zu wenig Uebungen fuer das Budget: Code zeit_budget_nicht_ausgeschoepft", () => {
    const plan = generierePlan(eingabe({ tage: 4, minuten: 90, ziel: "fitness" }));
    expect(plan.einheiten.some((e) => e.geschaetzteMinuten < 0.9 * 90)).toBe(true);
    expect(plan.gruende).toContain("zeit_budget_nicht_ausgeschoepft");
  });

  it("Auffuellung meidet gemiedene und nimmt vorsichtige zuletzt", () => {
    const plan = generierePlan(eingabe({ tage: 4, minuten: 90, kandidaten: VOLL, beschwerden: { knie: "meiden", schulter: "vorsichtig" } }));
    for (const p of plan.einheiten.flatMap((e) => e.positionen)) {
      expect(VOLL.find((c) => c.exerciseId === p.exerciseId)!.bereiche).not.toContain("knie");
    }
    // OK_A: Ziehen ohne Schulterbezug (row, high_row) kommt vor lat_pulldown.
    const okA = plan.einheiten[0]!.positionen.filter((p) => p.baustein === "ziehen").map((p) => p.exerciseId);
    expect(okA.slice(0, 2).sort()).toEqual(["high_row", "row"]);
  });

  it("Eigenschaft: ueber Strukturen, Minuten, Ziele und Erfahrung ausgeschoepft oder begruendet, nie ueber 105 %", () => {
    for (const tage of [1, 3, 4, 5])
      for (const minuten of [30, 45, 60, 75, 90] as const)
        for (const ziel of ["muskelaufbau", "fitness", "abnehmen"] as const)
          for (const erfahrung of ["neu", "unregelmaessig", "regelmaessig"] as const) {
            const plan = generierePlan(eingabe({ tage, minuten, ziel, erfahrung, kandidaten: VOLL }));
            for (const e of plan.einheiten) {
              const fall = `${tage}T ${minuten}min ${ziel} ${erfahrung} ${e.key}: ${e.geschaetzteMinuten}`;
              expect(e.geschaetzteMinuten, fall).toBeLessThanOrEqual(minuten * 1.05 + 1e-9);
              const imRahmen = e.geschaetzteMinuten >= 0.85 * minuten;
              expect(imRahmen || plan.gruende.includes("zeit_budget_nicht_ausgeschoepft"), fall).toBe(true);
              const ids = e.positionen.map((p) => p.exerciseId);
              expect(new Set(ids).size, fall).toBe(ids.length);
            }
          }
  });
});

describe("generierePlan: Regelversion 1.2.0", () => {
  it("Regelversion ist 1.2.0", () => {
    expect(PLAN_REGEL_VERSION).toBe("1.2.0");
    expect(generierePlan(eingabe()).regelVersion).toBe("1.2.0");
  });

  it("auffuellpositionen tragen die Rolle auffuellung", () => {
    const plan = generierePlan(eingabe({ tage: 4, kandidaten: VOLL }));
    for (const e of plan.einheiten) {
      const r = rollen(e);
      expect(r.filter((x) => x === "pflicht").length).toBe(2);
      expect(r.filter((x) => x === "ergaenzung").length).toBe(2);
      expect(r.filter((x) => x === "auffuellung").length).toBeGreaterThan(0);
    }
  });

  it("Mehrgelenk steht vor Isolation, Cardio zuletzt, keys sind 0..n-1 in Anzeigereihenfolge", () => {
    const plan = generierePlan(eingabe({ tage: 4, ziel: "abnehmen", kandidaten: [...VOLL, k("bike", "cardio", "isolation", [])] }));
    const rang = { pflicht: 0, fokus: 1, auffuellung: 2, ergaenzung: 3, cardio: 4 } as const;
    for (const e of plan.einheiten) {
      expect(e.positionen.map((p) => p.key)).toEqual(e.positionen.map((_, i) => String(i)));
      expect(e.positionen.at(-1)!.rolle).toBe("cardio");
      const kr = kraft(e);
      const erstesIso = kr.findIndex((p) => p.typ === "isolation");
      if (erstesIso >= 0) expect(kr.slice(erstesIso).every((p) => p.typ === "isolation")).toBe(true);
      for (const typ of ["mehrgelenk", "isolation"] as const) {
        const r = kr.filter((p) => p.typ === typ).map((p) => rang[p.rolle]);
        expect(r).toEqual([...r].sort((a, b) => a - b));
      }
    }
  });

  it("anfaengerBeendet bei Erfahrung neu plant 3 Saetze Reserve [1,3] bei Muskelaufbau", () => {
    const plan = generierePlan(eingabe({ erfahrung: "neu", anfaengerBeendet: true }));
    for (const p of plan.einheiten.flatMap((e) => e.positionen)) {
      expect(p.saetze).toBe(3);
      expect([p.reserveVon, p.reserveBis]).toEqual([1, 3]);
    }
  });

  it("ohne anfaengerBeendet bleibt neu bei 2 Saetzen, Reserve [3,4]", () => {
    const plan = generierePlan(eingabe({ erfahrung: "neu" }));
    for (const p of plan.einheiten.flatMap((e) => e.positionen)) {
      expect(p.saetze).toBe(2);
      expect([p.reserveVon, p.reserveBis]).toEqual([3, 4]);
    }
  });
});

// Uebergabe Etappe 3, Punkt 2: ein Tausch ueber die Typgrenze bekommt die Vorgaben des
// neuen Typs. tauschVorgaben ist dieselbe Quelle wie der Generator (zielprofil).
describe("tauschVorgaben", () => {
  it("Muskelaufbau, regelmaessig: Werte je Typ", () => {
    expect(tauschVorgaben({ ziel: "muskelaufbau", erfahrung: "regelmaessig" })).toEqual({
      mehrgelenk: { typ: "mehrgelenk", wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 3, pauseSek: 150, aufwaermsatz: true },
      isolation: { typ: "isolation", wdhVon: 10, wdhBis: 15, reserveVon: 1, reserveBis: 3, pauseSek: 90, aufwaermsatz: false },
    });
  });

  it.each([
    ["muskelaufbau", "regelmaessig", false],
    ["fitness", "neu", false],
    ["abnehmen", "neu", true],
    ["fitness", "unregelmaessig", false],
  ] as const)("stimmt mit jeder Kraftposition des Generators ueberein (%s, %s, beendet %s)", (ziel, erfahrung, beendet) => {
    const plan = generierePlan(eingabe({ ziel, erfahrung, anfaengerBeendet: beendet }));
    const v = tauschVorgaben({ ziel, erfahrung, anfaengerBeendet: beendet });
    const kraft = plan.einheiten.flatMap((e) => e.positionen).filter((p) => p.rolle !== "cardio");
    expect(kraft.length).toBeGreaterThan(0);
    for (const p of kraft) {
      const { typ, wdhVon, wdhBis, reserveVon, reserveBis, pauseSek, aufwaermsatz } = p;
      expect({ typ, wdhVon, wdhBis, reserveVon, reserveBis, pauseSek, aufwaermsatz }).toEqual(v[p.typ]);
    }
  });
});

describe("gefaelltNicht (Merkliste)", () => {
  const gut = k("gut", "druecken", "mehrgelenk", ["pectorals"]);
  const mag = { ...k("mag_ich_nicht", "druecken", "mehrgelenk", ["pectorals"]), gefaelltNicht: true };

  it("waehleKandidat nimmt gefaelltNicht nur ohne Alternative", () => {
    // Auch bei variation 1 (sonst die zweite Uebung) bleibt die ungeliebte hinten.
    expect(waehleKandidat([mag, gut], 0, new Set())!.exerciseId).toBe("gut");
    expect(waehleKandidat([mag, gut], 1, new Set())!.exerciseId).toBe("gut");
    expect(waehleKandidat([mag, gut], 0, new Set(["gut"]))!.exerciseId).toBe("mag_ich_nicht");
    expect(waehleKandidat([mag], 0, new Set())!.exerciseId).toBe("mag_ich_nicht");
  });

  it("waehleFokus ebenso", () => {
    const fokus = (liste: Kandidat[], belegt: string[] = []) =>
      waehleFokus(liste, "brust", ["druecken"], new Set(belegt))?.exerciseId;
    expect(fokus([mag, gut])).toBe("gut");
    expect(fokus([mag, gut], ["gut"])).toBe("mag_ich_nicht");
    expect(fokus([mag])).toBe("mag_ich_nicht");
  });

  it("nur gefaelltNicht-Kandidaten gelten fuer einen Pflichtbaustein als vorhanden", () => {
    const nurUngeliebt = KATALOG.map((c) => (c.baustein === "druecken" ? { ...c, gefaelltNicht: true } : c));
    const plan = generierePlan(eingabe({ kandidaten: nurUngeliebt }));
    expect(plan.einheiten[0]!.positionen.some((p) => p.baustein === "druecken")).toBe(true);
  });

  it("gefaelltNicht-Cardio wird nicht gewaehlt, wenn eine andere existiert, sonst schon", () => {
    const cardioVon = (kandidaten: Kandidat[]) =>
      generierePlan(eingabe({ ziel: "abnehmen", kandidaten })).einheiten[0]!.positionen.find((p) => p.rolle === "cardio")?.exerciseId;
    const ungeliebt = { ...k("aaa_bike", "cardio", "isolation", []), gefaelltNicht: true };
    expect(cardioVon([ungeliebt, ...KATALOG])).toBe("bike");
    expect(cardioVon([ungeliebt, ...ohne("bike")])).toBe("aaa_bike");
  });
});
