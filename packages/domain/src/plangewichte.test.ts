import { describe, expect, it } from "vitest";
import {
  aenderungZumLetzten,
  bloeckeUm,
  folgeEinheiten,
  hatZielgewicht,
  vorschlagAusZiel,
  zielFuerGeraet,
  zielNachPause,
  zielSchluessel,
  type PositionsZiel,
} from "./plangewichte.js";
import { PLANGEWICHT_ALGO_VERSION } from "./plangewicht.js";
import type { PlanEinheit } from "./trainingsplan-generator.js";
import type { SatzZeile } from "./progression.js";
import type { PlanPosition } from "./trainingsplan-generator.js";

describe("folgeEinheiten (G3, G21)", () => {
  it("nimmt die naechsten drei nach der abgeschlossenen, zyklisch", () => {
    expect(folgeEinheiten(["A", "B", "C", "D", "E"], "A")).toEqual(["B", "C", "D"]);
    expect(folgeEinheiten(["A", "B", "C", "D", "E"], "D")).toEqual(["E", "A", "B"]);
  });
  it("bei weniger Einheiten alle, auch die abgeschlossene selbst", () => {
    expect(folgeEinheiten(["A", "B"], "A")).toEqual(["B", "A"]);
    expect(folgeEinheiten(["A"], "A")).toEqual(["A"]);
    expect(folgeEinheiten(["A", "B", "C"], "B")).toEqual(["C", "A", "B"]);
  });
  it("unbekannte Einheit beginnt vorn", () => {
    expect(folgeEinheiten(["A", "B", "C", "D"], "X")).toEqual(["A", "B", "C"]);
    expect(folgeEinheiten([], "A")).toEqual([]);
  });
});

describe("aenderungZumLetzten (G17)", () => {
  it("Ziel minus letztes Gewicht, gerundet", () => {
    expect(aenderungZumLetzten(42.5, 40)).toBe(2.5);
    expect(aenderungZumLetzten(37.5, 40)).toBe(-2.5);
    expect(aenderungZumLetzten(0.3, 0.1)).toBe(0.2);
  });
  it("null ohne Vorgaenger oder bei Gleichheit", () => {
    expect(aenderungZumLetzten(40, null)).toBeNull();
    expect(aenderungZumLetzten(40, 40)).toBeNull();
  });
});

const zeile = (session: string, minute: number, load: number): SatzZeile => ({
  session_id: session,
  performed_at: new Date(Date.UTC(2026, 9, 1, 10, minute)).toISOString(),
  load,
  secondary_load: null,
  volume: 10,
  rir: null,
  problem_flag: false,
});

describe("bloeckeUm", () => {
  // Absteigend wie aus der Datenbank.
  const historie = [zeile("s3", 50, 50), zeile("s2", 31, 45), zeile("s2", 30, 45), zeile("s1", 10, 40)];

  it("Block der Session, Vorgaenger und ob ein neuerer existiert", () => {
    const um = bloeckeUm(historie, "s2")!;
    expect(um.block.sets.map((s) => s.load)).toEqual([45, 45]);
    expect(um.vorher?.sets.map((s) => s.load)).toEqual([40]);
    expect(um.neuerVorhanden).toBe(true);
    expect(bloeckeUm(historie, "s3")!.neuerVorhanden).toBe(false);
    expect(bloeckeUm(historie, "s1")!.vorher).toBeNull();
  });
  it("null, wenn die Session dort keinen Satz hat", () => {
    expect(bloeckeUm(historie, "s9")).toBeNull();
  });
});

describe("hatZielgewicht", () => {
  const p = (x: Partial<PlanPosition>) => ({ rolle: "pflicht", baustein: "druecken", wdhVon: 8, wdhBis: 12, ...x }) as PlanPosition;
  it("Kraft ja, Cardio nein", () => {
    expect(hatZielgewicht(p({}))).toBe(true);
    expect(hatZielgewicht(p({ rolle: "cardio", baustein: "cardio", wdhVon: null, wdhBis: null }))).toBe(false);
    expect(hatZielgewicht(p({ wdhVon: null }))).toBe(false);
  });
});

const GERAET = { loadStep: 2.5, loadMin: 5, loadMax: 100 };
const ziel = (load: number, grund: PositionsZiel["grund"] = "korridor_oben_erreicht"): PositionsZiel => ({
  load,
  secondaryLoad: null,
  aenderung: null,
  grund,
});

describe("vorschlagAusZiel (G17, G19)", () => {
  it("nimmt das Ziel als Ergebnis, seinen Grund als Code und das letzte Gewicht als Bisher", () => {
    const v = vorschlagAusZiel(ziel(42.5), { load: 40, secondaryLoad: null }, GERAET);
    expect(v).toMatchObject({
      algoVersion: PLANGEWICHT_ALGO_VERSION,
      resultLoad: 42.5,
      resultSecondaryLoad: null,
      reasonCode: "korridor_oben_erreicht",
    });
    expect(v.inputs).toMatchObject({ currentLoad: 40, loadStep: 2.5, loadMin: 5, loadMax: 100 });
  });
  it("gibt die Nebenbelastung des Ziels weiter", () => {
    const v = vorschlagAusZiel({ ...ziel(8), secondaryLoad: 6 }, { load: 7.5, secondaryLoad: 6 }, GERAET);
    expect(v.resultSecondaryLoad).toBe(6);
  });
  it("ohne letztes Gewicht ist Bisher leer, das Ziel gilt trotzdem", () => {
    const v = vorschlagAusZiel(ziel(40, "startschaetzung"), null, GERAET);
    expect(v).toMatchObject({ resultLoad: 40, reasonCode: "startschaetzung" });
    expect(v.inputs.currentLoad).toBeNull();
  });
  it("ohne Grund am Ziel: kein erfundener Grund, sondern kein_verlauf", () => {
    expect(vorschlagAusZiel(ziel(40, null), { load: 40, secondaryLoad: null }, GERAET).reasonCode).toBe("kein_verlauf");
  });
  it("ohne Ziel: das letzte Gewicht, letztes_gewicht", () => {
    const v = vorschlagAusZiel(null, { load: 37.5, secondaryLoad: 4 }, GERAET);
    expect(v).toMatchObject({
      algoVersion: PLANGEWICHT_ALGO_VERSION,
      resultLoad: 37.5,
      resultSecondaryLoad: 4,
      reasonCode: "letztes_gewicht",
    });
    expect(v.inputs).toMatchObject({ currentLoad: 37.5, currentSecondaryLoad: 4 });
  });
  it("ohne beides: kein_verlauf ohne Zahl", () => {
    const v = vorschlagAusZiel(null, null, GERAET);
    expect(v).toMatchObject({ resultLoad: null, resultSecondaryLoad: null, reasonCode: "kein_verlauf" });
    expect(v.inputs.currentLoad).toBeNull();
  });
});

const pos = (key: string, exerciseId: string, machineId: string) =>
  ({ key, exerciseId, machineId, typ: "kraft", rolle: "pflicht" }) as unknown as PlanEinheit["positionen"][number];
const einheit = (key: string, ...positionen: PlanEinheit["positionen"]): PlanEinheit => ({
  key,
  positionen,
  geschaetzteMinuten: 30,
});

describe("zielFuerGeraet (G17)", () => {
  const einheiten = [
    einheit("A", pos("0", "e1", "m1"), pos("1", "e2", "m2")),
    einheit("B", pos("0", "e1", "m1"), pos("1", "e3", "m3")),
    einheit("C", pos("0", "e4", "m4")),
  ];
  const ziele = {
    [zielSchluessel("A", "0")]: ziel(50),
    [zielSchluessel("B", "0")]: ziel(60),
    [zielSchluessel("B", "1")]: ziel(70),
    [zielSchluessel("C", "0")]: ziel(80),
  };

  it("zwei Einheiten mit derselben Uebung: die naechste gewinnt", () => {
    expect(zielFuerGeraet(einheiten, "B", ziele, "m1", "e1")?.load).toBe(60);
    expect(zielFuerGeraet(einheiten, "A", ziele, "m1", "e1")?.load).toBe(50);
  });
  it("sonst die fruehste spaetere Einheit, zyklisch", () => {
    expect(zielFuerGeraet(einheiten, "C", ziele, "m1", "e1")?.load).toBe(50);
    expect(zielFuerGeraet(einheiten, "B", ziele, "m4", "e4")?.load).toBe(80);
    expect(zielFuerGeraet(einheiten, "C", ziele, "m3", "e3")?.load).toBe(70);
  });
  it("Uebung UND Geraet muessen passen", () => {
    expect(zielFuerGeraet(einheiten, "A", ziele, "m2", "e1")).toBeNull();
    expect(zielFuerGeraet(einheiten, "A", ziele, "m1", "e2")).toBeNull();
  });
  it("Position ohne Ziel zaehlt nicht, die naechste mit Ziel gewinnt", () => {
    const ohneA = { ...ziele };
    delete ohneA[zielSchluessel("A", "0")];
    expect(zielFuerGeraet(einheiten, "A", ohneA, "m1", "e1")?.load).toBe(60);
  });
  it("unbekannte naechste Einheit beginnt vorn; ohne Treffer null", () => {
    expect(zielFuerGeraet(einheiten, "X", ziele, "m1", "e1")?.load).toBe(50);
    expect(zielFuerGeraet(einheiten, "A", {}, "m1", "e1")).toBeNull();
  });
});

describe("zielNachPause (F18 beim Lesen, Final-Fix I2)", () => {
  const g = { loadStep: 2.5, loadMin: 5, loadMax: 100 };
  const schaetzung = () => 40;
  const ziel = { load: 62.5, grund: "korridor_oben_erreicht" as const };
  it("bis 7 Tage unveraendert", () => {
    expect(zielNachPause(ziel, 60, 7, g, schaetzung)).toEqual(ziel);
  });
  it("8 und 14 Tage: nie ueber dem letzten Gewicht", () => {
    expect(zielNachPause(ziel, 60, 8, g, schaetzung)).toEqual({ load: 60, grund: "wiedereinstieg" });
    expect(zielNachPause(ziel, 60, 14, g, schaetzung)).toEqual({ load: 60, grund: "wiedereinstieg" });
  });
  it("15 und 42 Tage: Abschlag vom letzten Gewicht", () => {
    expect(zielNachPause(ziel, 60, 15, g, schaetzung)).toEqual({ load: 55, grund: "wiedereinstieg" });
    expect(zielNachPause(ziel, 60, 42, g, schaetzung)).toEqual({ load: 52.5, grund: "wiedereinstieg" });
  });
  it("ueber 42 Tage die Startschaetzung", () => {
    expect(zielNachPause(ziel, 60, 43, g, schaetzung)).toEqual({ load: 40, grund: "startschaetzung" });
  });
  it("senkt nur: ein Ziel unter dem gemilderten Wert bleibt samt Grund", () => {
    const tief = { load: 50, grund: "korridor_unten_verfehlt" as const };
    expect(zielNachPause(tief, 60, 20, g, schaetzung)).toEqual(tief);
    expect(zielNachPause(tief, 60, 10, g, schaetzung)).toEqual(tief);
  });
});
