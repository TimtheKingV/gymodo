import { describe, expect, it } from "vitest";
import { DomainError } from "./errors.js";
import type { EinheitEingabePosition, EinheitVorgaben, UebungsMerkmale } from "./plan-einheit-ersetzen.js";
import { baueEinheit, positionMinuten, vorgabenAusEingabe } from "./plan-einheit-ersetzen.js";
import type { Kandidat, PlanEinheit, PlanPosition } from "./trainingsplan-generator.js";
import { generierePlan } from "./trainingsplan-generator.js";
import { ZEIT } from "./trainingsplan-zeit.js";

// (P4) Fixture: alte Einheit mit Beinpresse (mehrgelenk), Curl (isolation), Laufband (cardio).
const VORGABEN: EinheitVorgaben = vorgabenAusEingabe({ ziel: "muskelaufbau", erfahrung: "regelmaessig", minuten: 60 });

function pos(teil: Partial<PlanPosition> & Pick<PlanPosition, "key" | "exerciseId">): PlanPosition {
  return {
    baustein: "beine_knie",
    rolle: "pflicht",
    modelId: `m_${teil.exerciseId}`,
    typ: "mehrgelenk",
    saetze: 3,
    wdhVon: 8,
    wdhBis: 12,
    reserveVon: 1,
    reserveBis: 3,
    pauseSek: 150,
    aufwaermsatz: true,
    dauerMin: null,
    hauptmuskeln: ["quads"],
    ...teil,
  };
}

const ALT: PlanEinheit = {
  key: "A",
  geschaetzteMinuten: 0,
  positionen: [
    pos({ key: "0", exerciseId: "beinpresse" }),
    pos({
      key: "1",
      exerciseId: "curl",
      baustein: "arme",
      rolle: "ergaenzung",
      typ: "isolation",
      wdhVon: 10,
      wdhBis: 15,
      reserveVon: 2,
      reserveBis: 3,
      pauseSek: 90,
      aufwaermsatz: false,
      hauptmuskeln: ["biceps"],
    }),
    pos({
      key: "2",
      exerciseId: "laufband",
      baustein: "cardio",
      rolle: "cardio",
      typ: "isolation",
      saetze: 1,
      wdhVon: null,
      wdhBis: null,
      pauseSek: 0,
      aufwaermsatz: false,
      dauerMin: 20,
      hauptmuskeln: [],
    }),
  ],
};

const M: Record<string, UebungsMerkmale> = {
  beinpresse: { baustein: "beine_knie", typ: "mehrgelenk", hauptmuskeln: ["quads"] },
  curl: { baustein: "arme", typ: "isolation", hauptmuskeln: ["biceps"] },
  laufband: { baustein: "cardio", typ: "isolation", hauptmuskeln: [] },
  rudern: { baustein: "ziehen", typ: "mehrgelenk", hauptmuskeln: ["upper_back"] },
  trizeps: { baustein: "arme", typ: "isolation", hauptmuskeln: ["triceps"] },
  bike: { baustein: "cardio", typ: "isolation", hauptmuskeln: [] },
  ohne_merkmal: { baustein: null, typ: null, hauptmuskeln: [] },
};

const e = (key: string | null, exerciseId: string, rest: Partial<EinheitEingabePosition> = {}): EinheitEingabePosition => ({
  key,
  exerciseId,
  modelId: `m_${exerciseId}`,
  ...rest,
});

const UNVERAENDERT = [e("0", "beinpresse"), e("1", "curl"), e("2", "laufband")];
const baue = (eingabe: EinheitEingabePosition[]) => baueEinheit(ALT, eingabe, M, VORGABEN);
const code = (f: () => unknown) => {
  try {
    f();
  } catch (err) {
    return err instanceof DomainError ? err.code : "anderer_fehler";
  }
  return "kein_fehler";
};

describe("baueEinheit", () => {
  it("ordnet und entfernt", () => {
    const neu = baue([e("1", "curl"), e("0", "beinpresse")]);
    expect(neu.positionen.map((p) => p.key)).toEqual(["1", "0"]);
    expect(neu.key).toBe("A");
  });

  it("neue Position bekommt Schluessel 3 und Vorgaben", () => {
    const neu = baue([...UNVERAENDERT, e(null, "trizeps")]);
    expect(neu.positionen[3]).toMatchObject({
      key: "3",
      saetze: VORGABEN.saetze,
      wdhVon: 10,
      wdhBis: 15,
      pauseSek: 90,
      rolle: "ergaenzung",
      aufwaermsatz: false,
      baustein: "arme",
      typ: "isolation",
      hauptmuskeln: ["triceps"],
    });
  });

  it("vergibt neue Schluessel fortlaufend in Listenreihenfolge", () => {
    const neu = baue([e(null, "trizeps"), e("0", "beinpresse"), e(null, "rudern")]);
    expect(neu.positionen.map((p) => p.key)).toEqual(["3", "0", "4"]);
  });

  it("Tausch Kraft->Kraft behaelt Saetze Wdh Pause Reserve, Aufwaermsatz nach neuer Uebung", () => {
    const neu = baue([e("1", "rudern")]);
    expect(neu.positionen[0]).toMatchObject({
      key: "1",
      exerciseId: "rudern",
      saetze: 3,
      wdhVon: 10,
      wdhBis: 15,
      pauseSek: 90,
      reserveVon: 2,
      reserveBis: 3,
      aufwaermsatz: true,
      rolle: "ergaenzung",
      typ: "mehrgelenk",
      baustein: "ziehen",
    });
  });

  it("Tausch Kraft->Cardio setzt Cardio-Werte", () => {
    const neu = baue([e("1", "bike")]);
    expect(neu.positionen[0]).toMatchObject({
      saetze: 1,
      wdhVon: null,
      wdhBis: null,
      pauseSek: 0,
      aufwaermsatz: false,
      dauerMin: VORGABEN.cardioMin,
      rolle: "cardio",
      baustein: "cardio",
    });
  });

  it("Tausch Cardio->Kraft setzt Kraft-Vorgaben", () => {
    const neu = baue([e("2", "trizeps")]);
    expect(neu.positionen[0]).toMatchObject({
      saetze: VORGABEN.saetze,
      wdhVon: 10,
      wdhBis: 15,
      pauseSek: 90,
      dauerMin: null,
      rolle: "ergaenzung",
      aufwaermsatz: false,
    });
  });

  it("gleiche Uebung behaelt alle Werte aus alt", () => {
    const neu = baue(UNVERAENDERT);
    expect(neu.positionen).toEqual(ALT.positionen);
  });

  it("gelieferte Werte ueberschreiben", () => {
    const neu = baue([e("0", "beinpresse", { saetze: 4, wdhVon: 6, wdhBis: 8, pauseSek: 120 })]);
    expect(neu.positionen[0]).toMatchObject({ saetze: 4, wdhVon: 6, wdhBis: 8, pauseSek: 120 });
  });

  it("Cardio-Dauer ueberschreibbar", () => {
    expect(baue([e("2", "laufband", { dauerMin: 30 })]).positionen[0]?.dauerMin).toBe(30);
  });

  it.each([
    ["saetze 0", e("0", "beinpresse", { saetze: 0 })],
    ["saetze 11", e("0", "beinpresse", { saetze: 11 })],
    ["saetze 2,5", e("0", "beinpresse", { saetze: 2.5 })],
    ["wdhVon 0", e("0", "beinpresse", { wdhVon: 0 })],
    ["wdhBis kleiner wdhVon", e("0", "beinpresse", { wdhVon: 10, wdhBis: 9 })],
    ["wdhBis 51", e("0", "beinpresse", { wdhBis: 51 })],
    ["pauseSek 601", e("0", "beinpresse", { pauseSek: 601 })],
    ["pauseSek -1", e("0", "beinpresse", { pauseSek: -1 })],
    ["dauerMin 4", e("2", "laufband", { dauerMin: 4 })],
    ["dauerMin 121", e("2", "laufband", { dauerMin: 121 })],
  ])("Grenze: %s", (_name, p) => {
    expect(code(() => baue([p]))).toBe("validation_failed");
  });

  it("Grenzen gelten auch fuer die Obergrenzen selbst", () => {
    expect(() => baue([e("0", "beinpresse", { saetze: 10, wdhVon: 1, wdhBis: 50, pauseSek: 600 })])).not.toThrow();
    expect(() => baue([e("2", "laufband", { dauerMin: 5 })])).not.toThrow();
    expect(() => baue([e("2", "laufband", { dauerMin: 120 })])).not.toThrow();
  });

  it("Cardio erlaubt nur Cardio-Werte", () => {
    expect(code(() => baue([e("2", "laufband", { saetze: 2 })]))).toBe("validation_failed");
    expect(code(() => baue([e("2", "laufband", { wdhVon: 8 })]))).toBe("validation_failed");
    expect(code(() => baue([e("2", "laufband", { pauseSek: 30 })]))).toBe("validation_failed");
  });

  it("Kraft erlaubt keine Dauer", () => {
    expect(code(() => baue([e("0", "beinpresse", { dauerMin: 20 })]))).toBe("validation_failed");
  });

  it("leere Liste, doppelter Key, fremder Key, doppelte Uebung, 21 Positionen", () => {
    expect(code(() => baue([]))).toBe("validation_failed");
    expect(code(() => baue([e("0", "beinpresse"), e("0", "curl")]))).toBe("validation_failed");
    expect(code(() => baue([e("9", "beinpresse")]))).toBe("validation_failed");
    expect(code(() => baue([e("0", "beinpresse"), e(null, "beinpresse")]))).toBe("validation_failed");
    const viele = Array.from({ length: 21 }, (_, i) => e(null, `u${i}`));
    const merkmale = Object.fromEntries(viele.map((p) => [p.exerciseId, M.trizeps!]));
    expect(code(() => baueEinheit(ALT, viele, merkmale, VORGABEN))).toBe("validation_failed");
  });

  it("20 Positionen sind erlaubt", () => {
    const zwanzig = Array.from({ length: 20 }, (_, i) => e(null, `u${i}`));
    const merkmale = Object.fromEntries(zwanzig.map((p) => [p.exerciseId, M.trizeps!]));
    expect(baueEinheit(ALT, zwanzig, merkmale, VORGABEN).positionen).toHaveLength(20);
  });

  it("Uebung ohne Planmerkmale", () => {
    expect(code(() => baue([e(null, "ohne_merkmal")]))).toBe("uebung_ohne_planmerkmale");
    expect(code(() => baue([e(null, "unbekannt")]))).toBe("uebung_ohne_planmerkmale");
  });

  it("Minuten: Cardio zaehlt dauerMin, Kraft Einstellen + Saetze + Pausen + Aufwaermsatz", () => {
    expect(positionMinuten(ALT.positionen[2]!)).toBe(20);
    expect(positionMinuten(ALT.positionen[0]!)).toBeCloseTo(
      ZEIT.einstellenMin + 3 * ZEIT.satzMin + 2 * 2.5 + ZEIT.aufwaermsatzMin,
    );
  });

  it("Minuten neu gerechnet: wie vom Generator", () => {
    const k = (exerciseId: string, baustein: Kandidat["baustein"], typ: Kandidat["typ"], m: string[]): Kandidat => ({
      exerciseId,
      modelId: `m_${exerciseId}`,
      baustein,
      typ,
      bereiche: [],
      hauptmuskeln: m,
    });
    const kandidaten = [
      k("squat", "beine_knie", "mehrgelenk", ["quads"]),
      k("hip", "beine_huefte", "isolation", ["glutes"]),
      k("press", "druecken", "mehrgelenk", ["pectorals"]),
      k("row", "ziehen", "mehrgelenk", ["upper_back"]),
      k("curl2", "arme", "isolation", ["biceps"]),
      k("bike", "cardio", "isolation", []),
    ];
    const eingabe = { ziel: "abnehmen", erfahrung: "regelmaessig", minuten: 60, tage: 2, fokus: [], beschwerden: {}, kandidaten } as const;
    const gen = generierePlan({ ...eingabe, fokus: [] }).einheiten[0]!;
    const merkmale = Object.fromEntries(
      gen.positionen.map((p) => [p.exerciseId, { baustein: p.baustein, typ: p.typ, hauptmuskeln: p.hauptmuskeln }]),
    );
    const vorgaben = vorgabenAusEingabe({ ziel: "abnehmen", erfahrung: "regelmaessig", minuten: 60 });
    const neu = baueEinheit(
      gen,
      gen.positionen.map((p) => e(p.key, p.exerciseId)),
      merkmale,
      vorgaben,
    );
    expect(neu.geschaetzteMinuten).toBeCloseTo(gen.geschaetzteMinuten, 9);
    expect(neu.positionen).toEqual(gen.positionen);
  });

  it("Minuten: ein Satz mehr kostet Satz plus Pause", () => {
    const vorher = baue([e("0", "beinpresse")]).geschaetzteMinuten;
    const nachher = baue([e("0", "beinpresse", { saetze: 4 })]).geschaetzteMinuten;
    expect(nachher - vorher).toBeCloseTo(ZEIT.satzMin + 150 / 60, 9);
  });
});

describe("vorgabenAusEingabe", () => {
  it("leitet Saetze, Cardio und Aufwaermen aus Profil und Zeit ab", () => {
    expect(VORGABEN).toMatchObject({ saetze: 3, cardioMin: 20, aufwaermenMin: 5 });
    expect(VORGABEN.typ.mehrgelenk.wdhVon).toBe(8);
  });

  it("Cardio-Vorgabe bleibt bei kurzer Einheit gueltig (mindestens 5)", () => {
    expect(vorgabenAusEingabe({ ziel: "fitness", erfahrung: "neu", minuten: 30 }).cardioMin).toBeGreaterThanOrEqual(5);
  });
});
