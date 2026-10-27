import { describe, expect, it } from "vitest";
import {
  aenderungZumLetzten,
  bloeckeUm,
  folgeEinheiten,
  hatZielgewicht,
  vorschlagAusZiel,
  ladeArbeitssaetze,
  ladeGrenzen,
  uebungsSchluessel,
  zielFuerPosition,
  zielFuerUebung,
  zielNachPause,
  zielSchluessel,
  type PositionsZiel,
} from "./plangewichte.js";
import { berechnePlanGewicht, PLANGEWICHT_ALGO_VERSION } from "./plangewicht.js";
import type { SupabaseClient } from "@supabase/supabase-js";
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
  it("ohne Grund am Ziel: letztes_gewicht, weil es eine Zahl gibt (Final-Fix I3)", () => {
    expect(vorschlagAusZiel(ziel(40, null), { load: 40, secondaryLoad: null }, GERAET).reasonCode).toBe("letztes_gewicht");
    expect(vorschlagAusZiel(ziel(40, null), null, GERAET)).toMatchObject({ resultLoad: 40, reasonCode: "letztes_gewicht" });
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
  it("haelt das Ziel in den aktuellen Geraetegrenzen, abgerundet auf die aktuelle Stufe (Final-Fix M1)", () => {
    expect(vorschlagAusZiel(ziel(42.5), null, { loadStep: 5, loadMin: 0, loadMax: 100 }).resultLoad).toBe(40);
    expect(vorschlagAusZiel(ziel(42.5), null, { loadStep: 2.5, loadMin: 5, loadMax: 35 }).resultLoad).toBe(35);
    expect(vorschlagAusZiel(ziel(2.5), null, { loadStep: 2.5, loadMin: 5, loadMax: 100 }).resultLoad).toBe(5);
  });
  it("ohne beides: kein_verlauf ohne Zahl", () => {
    const v = vorschlagAusZiel(null, null, GERAET);
    expect(v).toMatchObject({ resultLoad: null, resultSecondaryLoad: null, reasonCode: "kein_verlauf" });
    expect(v.inputs.currentLoad).toBeNull();
  });
});

const pos = (key: string, exerciseId: string, modelId: string) =>
  ({ key, exerciseId, modelId, typ: "kraft", rolle: "pflicht" }) as unknown as PlanEinheit["positionen"][number];
const einheit = (key: string, ...positionen: PlanEinheit["positionen"]): PlanEinheit => ({
  key,
  positionen,
  geschaetzteMinuten: 30,
});

describe("zielFuerPosition", () => {
  it("liest das Ziel genau dieser Einheit und Position", () => {
    const ziele = { [zielSchluessel("A", "0")]: ziel(50), [zielSchluessel("B", "0")]: ziel(60) };
    expect(zielFuerPosition(ziele, "B", "0")?.load).toBe(60);
    expect(zielFuerPosition(ziele, "A", "1")).toBeNull();
  });
});

describe("zielFuerUebung (G17)", () => {
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
    expect(zielFuerUebung(einheiten, "B", ziele, "e1")?.load).toBe(60);
    expect(zielFuerUebung(einheiten, "A", ziele, "e1")?.load).toBe(50);
  });
  it("sonst die fruehste spaetere Einheit, zyklisch", () => {
    expect(zielFuerUebung(einheiten, "C", ziele, "e1")?.load).toBe(50);
    expect(zielFuerUebung(einheiten, "B", ziele, "e4")?.load).toBe(80);
    expect(zielFuerUebung(einheiten, "C", ziele, "e3")?.load).toBe(70);
  });
  it("nur die Uebung zaehlt, nicht das Modell", () => {
    expect(zielFuerUebung(einheiten, "A", ziele, "e9")).toBeNull();
  });
  it("Position ohne Ziel zaehlt nicht, die naechste mit Ziel gewinnt", () => {
    const ohneA = { ...ziele };
    delete ohneA[zielSchluessel("A", "0")];
    expect(zielFuerUebung(einheiten, "A", ohneA, "e1")?.load).toBe(60);
  });
  it("unbekannte naechste Einheit beginnt vorn; ohne Treffer null", () => {
    expect(zielFuerUebung(einheiten, "X", ziele, "e1")?.load).toBe(50);
    expect(zielFuerUebung(einheiten, "A", {}, "e1")).toBeNull();
  });
});

// Ein Client, der jede Abfrage aufzeichnet und feste Zeilen liefert.
function fakeClient(zeilen: unknown[]) {
  const aufrufe: Array<[string, unknown[]]> = [];
  const b: Record<string, unknown> = {};
  for (const m of ["from", "select", "eq", "not", "in", "gte", "lt", "order", "range", "limit"]) {
    b[m] = (...args: unknown[]) => {
      aufrufe.push([m, args]);
      return b;
    };
  }
  b.then = (ok: (v: unknown) => unknown) => Promise.resolve({ data: zeilen, error: null }).then(ok);
  return { client: b as unknown as SupabaseClient, aufrufe };
}

describe("uebungsSchluessel", () => {
  it("ist die Uebung selbst", () => {
    expect(uebungsSchluessel("e1")).toBe("e1");
  });
});

describe("ladeArbeitssaetze je Uebung", () => {
  const satz = (id: string, machine: string | null, exercise: string, minute: number) => ({
    id,
    session_id: "s" + minute,
    machine_id: machine,
    exercise_id: exercise,
    performed_at: new Date(Date.UTC(2026, 9, 1, 10, minute)).toISOString(),
    load: 40,
    secondary_load: null,
    volume: 10,
    rir: null,
    problem_flag: false,
  });

  it("rechnet aus Saetzen derselben Uebung an zwei Geraeten", async () => {
    const { client, aufrufe } = fakeClient([satz("1", "mA", "e1", 20), satz("2", "mB", "e1", 10)]);
    const r = await ladeArbeitssaetze(client, "u", ["e1"], new Date(0));
    expect(r.get(uebungsSchluessel("e1"))?.map((z) => (z as unknown as { id: string }).id)).toEqual(["1", "2"]);
    expect(aufrufe.some(([m, a]) => m === "in" && a[0] === "machine_id")).toBe(false);
  });
  it("zaehlt Saetze ohne Geraet", async () => {
    const { client, aufrufe } = fakeClient([satz("1", null, "e1", 20), satz("2", "mB", "e1", 10)]);
    const r = await ladeArbeitssaetze(client, "u", ["e1"], new Date(0));
    expect(r.get("e1")).toHaveLength(2);
    expect(aufrufe.some(([m, a]) => m === "not" && a[0] === "machine_id")).toBe(false);
  });
});

describe("ladeGrenzen aus dem Katalogmodell", () => {
  it("Grenzen kommen vom Katalogmodell der Position", async () => {
    const { client, aufrufe } = fakeClient([
      { id: "mod1", load_step: "2.5", load_min: "5", load_max: "100", load_start: "20" },
    ]);
    const g = await ladeGrenzen(client, ["mod1", "mod1"]);
    expect(aufrufe[0]).toEqual(["from", ["equipment_models"]]);
    expect(g.get("mod1")).toEqual({ loadStep: 2.5, loadMin: 5, loadMax: 100, loadStart: 20 });
  });
  it("Uebung ohne einstellbare Stufe hat kein Ziel", async () => {
    const { client } = fakeClient([
      { id: "cardio", load_step: null, load_min: null, load_max: null, load_start: null },
      { id: "null", load_step: 0, load_min: 0, load_max: 10, load_start: null },
    ]);
    expect((await ladeGrenzen(client, ["cardio", "null"])).size).toBe(0);
  });
});

describe("Gewicht aus einem anderen Geraet (Anti-Ziel)", () => {
  const satz = (load: number, volume: number) => ({ load, secondaryLoad: null, volume, rir: 2, problemFlag: false });
  const position = { wdhVon: 8, wdhBis: 12, reserveVon: 2 };
  const modell = { loadStep: 2.5, loadMin: 5, loadMax: 80 };
  it("Gewicht springt nicht, wenn das letzte Gewicht aus einem anderen Geraet stammt", () => {
    // Anderes Geraet: 120 kg, krumm auf der Stufe; das Modell der Position endet bei 80.
    const r = berechnePlanGewicht({
      position,
      geraet: modell,
      block: [satz(121, 12), satz(121, 12)],
      vorher: null,
      aktuellesZiel: null,
    });
    expect(r.load).not.toBeNull();
    expect(r.load!).toBeLessThanOrEqual(80);
    expect((r.load! - 5) % 2.5).toBe(0);
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
