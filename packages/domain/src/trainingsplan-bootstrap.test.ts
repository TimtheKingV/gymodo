import { describe, expect, it } from "vitest";
import type { Kandidat } from "./trainingsplan-auswahl.js";
import { alternativenJeBaustein, gezaehlteEinheiten, planFuerApp } from "./trainingsplan-bootstrap.js";
import type { TrainingPlan } from "./trainingsplan.js";
import type { TrainingProfile } from "./trainingsprofil.js";

const JETZT = new Date("2026-10-24T12:00:00Z");
const vor = (minuten: number) => new Date(JETZT.getTime() - minuten * 60_000).toISOString();

type Zeile = Parameters<typeof gezaehlteEinheiten>[0][number];

function session(z: Partial<Zeile> & { id: string }): Zeile {
  return {
    einheitKey: "A",
    startedAt: vor(600),
    completedAt: null,
    letzterSatzAm: null,
    zaehlt: true,
    ...z,
  };
}

describe("gezaehlteEinheiten", () => {
  it("beendete Einheit mit erledigter Position zaehlt", () => {
    const s = session({ id: "s1", completedAt: vor(500), letzterSatzAm: vor(510) });
    expect(gezaehlteEinheiten([s], JETZT)).toEqual([{ sessionId: "s1", einheitKey: "A", startedAt: s.startedAt }]);
  });

  it("beendete Einheit zaehlt auch ohne Saetze, wenn ein Status erledigt ist", () => {
    expect(gezaehlteEinheiten([session({ id: "s1", completedAt: vor(500) })], JETZT)).toHaveLength(1);
  });

  it("nie beendete, 5 h stillstehende zaehlt", () => {
    expect(gezaehlteEinheiten([session({ id: "s1", letzterSatzAm: vor(300) })], JETZT)).toHaveLength(1);
  });

  it("laufende (letzter Satz vor 10 min) zaehlt nicht", () => {
    expect(gezaehlteEinheiten([session({ id: "s1", letzterSatzAm: vor(10) })], JETZT)).toEqual([]);
  });

  it("genau 4 h nach dem letzten Satz zaehlt noch nicht", () => {
    expect(gezaehlteEinheiten([session({ id: "s1", letzterSatzAm: vor(240) })], JETZT)).toEqual([]);
  });

  it("nicht beendete Einheit ohne Saetze zaehlt nicht", () => {
    expect(gezaehlteEinheiten([session({ id: "s1" })], JETZT)).toEqual([]);
  });

  it("Einheit ohne erledigte/optionale Position zaehlt nicht", () => {
    expect(
      gezaehlteEinheiten([session({ id: "s1", zaehlt: false, completedAt: vor(500), letzterSatzAm: vor(510) })], JETZT),
    ).toEqual([]);
  });

  it("Reihenfolge nach startedAt", () => {
    const fertig = { completedAt: vor(1), letzterSatzAm: vor(2) };
    const liste = gezaehlteEinheiten(
      [
        session({ id: "mitte", einheitKey: "B", startedAt: vor(2000), ...fertig }),
        session({ id: "neu", einheitKey: "A", startedAt: vor(1000), ...fertig }),
        session({ id: "alt", einheitKey: "A", startedAt: vor(3000), ...fertig }),
      ],
      JETZT,
    );
    expect(liste.map((e) => e.sessionId)).toEqual(["alt", "mitte", "neu"]);
  });
});

const k = (exerciseId: string, baustein: Kandidat["baustein"], bereiche: Kandidat["bereiche"] = []): Kandidat => ({
  exerciseId, machineId: `m-${exerciseId}`, baustein, typ: "mehrgelenk", bereiche, hauptmuskeln: [],
});

describe("alternativenJeBaustein", () => {
  it("laesst meiden weg, stellt vorsichtig nach hinten und gibt nur IDs aus", () => {
    const a = alternativenJeBaustein(
      [k("1", "beine_knie", ["huefte"]), k("2", "beine_knie", ["knie"]), k("3", "beine_knie"), k("4", "ziehen")],
      { knie: "meiden", huefte: "vorsichtig" },
    );
    expect(a).toEqual({
      beine_knie: [{ exerciseId: "3", machineId: "m-3" }, { exerciseId: "1", machineId: "m-1" }],
      ziehen: [{ exerciseId: "4", machineId: "m-4" }],
    });
  });
});

describe("planFuerApp", () => {
  const plan = {
    id: "p", studioId: "s", version: 2, status: "aktiv", regelVersion: "1.2.0", struktur: "gk_ab",
    eingabe: { ziel: "muskelaufbau", tage: 3, minuten: 60, fokus: [], erfahrung: "neu", anfaengerBeendet: false,
      beschwerdenBeruecksichtigt: false },
    einheiten: [{ key: "A", positionen: [], geschaetzteMinuten: 50 }, { key: "B", positionen: [], geschaetzteMinuten: 50 }],
    gruende: [], createdAt: "", acceptedAt: null,
  } as TrainingPlan;
  const neu: TrainingProfile = { minutes: 60, experience: "neu", focus: [] };
  const einheiten = (n: number) =>
    Array.from({ length: n }, (_, i) => ({ sessionId: `s${i}`, einheitKey: i % 2 ? "B" : "A", startedAt: vor(1000 - i) }));

  it("ohne gezaehlte Einheit beginnt die Folge bei der ersten", () => {
    expect(planFuerApp(plan, [], neu, {})).toMatchObject({ naechsteEinheitKey: "A", zuletztEinheitKey: null, einheitenErledigt: 0 });
  });

  it("anfaengerUebergang erst ab 8 bei neu, nie nach anfaengerBeendet", () => {
    expect(planFuerApp(plan, einheiten(7), neu, {}).anfaengerUebergang).toBe(false);
    expect(planFuerApp(plan, einheiten(8), neu, {})).toMatchObject({
      anfaengerUebergang: true, zuletztEinheitKey: "B", naechsteEinheitKey: "A",
    });
    expect(planFuerApp(plan, einheiten(8), { ...neu, experience: "regelmaessig" }, {}).anfaengerUebergang).toBe(false);
    expect(planFuerApp(plan, einheiten(8), null, {}).anfaengerUebergang).toBe(false);
    const beendet = { ...plan, eingabe: { ...plan.eingabe, anfaengerBeendet: true } };
    expect(planFuerApp(beendet, einheiten(8), neu, {}).anfaengerUebergang).toBe(false);
  });
});
