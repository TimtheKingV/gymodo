import { describe, expect, it } from "vitest";
import type { Kandidat } from "./trainingsplan-auswahl.js";
import {
  alternativenJeBaustein,
  gezaehlteEinheiten,
  istKatalogPlan,
  merklisteFuerApp,
  nachzuholendeSessions,
  planFuerApp,
} from "./trainingsplan-bootstrap.js";
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

const k = (
  exerciseId: string,
  baustein: Kandidat["baustein"],
  bereiche: Kandidat["bereiche"] = [],
  extra: Partial<Kandidat> = {},
): Kandidat => ({
  exerciseId, modelId: `m-${exerciseId}`, baustein, typ: "mehrgelenk", bereiche, hauptmuskeln: [], ...extra,
});

describe("alternativenJeBaustein", () => {
  it("Alternativen tragen modelId und haben gefaellt_nicht am Ende", () => {
    const a = alternativenJeBaustein(
      [
        k("1", "beine_knie", [], { gefaelltNicht: true }),
        k("2", "beine_knie", ["huefte"]),
        k("3", "beine_knie"),
        k("4", "ziehen"),
      ],
      { huefte: "vorsichtig" },
    );
    expect(a).toEqual({
      beine_knie: [
        { exerciseId: "3", modelId: "m-3" },
        { exerciseId: "2", modelId: "m-2" },
        { exerciseId: "1", modelId: "m-1" },
      ],
      ziehen: [{ exerciseId: "4", modelId: "m-4" }],
    });
  });

  it("Alternativen nennen keine Beschwerden-Bereiche und lassen meiden weg", () => {
    const a = alternativenJeBaustein(
      [k("1", "beine_knie", ["huefte"]), k("2", "beine_knie", ["knie"]), k("3", "beine_knie")],
      { knie: "meiden", huefte: "vorsichtig" },
    );
    expect(a.beine_knie).toEqual([{ exerciseId: "3", modelId: "m-3" }, { exerciseId: "1", modelId: "m-1" }]);
    for (const x of a.beine_knie!) expect(Object.keys(x).sort()).toEqual(["exerciseId", "modelId"]);
    expect(JSON.stringify(a)).not.toMatch(/huefte|meiden|vorsichtig|bereich/);
  });
});

describe("merklisteFuerApp", () => {
  it("merkliste faltet nichtVorhanden je Ort und gefaelltNicht ueberall", () => {
    expect(
      merklisteFuerApp([
        { exercise_id: "e1", art: "nicht_vorhanden", studio_id: "ortA" },
        { exercise_id: "e2", art: "nicht_vorhanden", studio_id: "ortA" },
        { exercise_id: "e1", art: "nicht_vorhanden", studio_id: "ortB" },
        { exercise_id: "e3", art: "gefaellt_nicht", studio_id: null },
      ]),
    ).toEqual({ nichtVorhanden: { ortA: ["e1", "e2"], ortB: ["e1"] }, gefaelltNicht: ["e3"] });
    expect(merklisteFuerApp([])).toEqual({ nichtVorhanden: {}, gefaelltNicht: [] });
  });
});

describe("istKatalogPlan", () => {
  const mitPositionen = (positionen: object[]) =>
    ({ einheiten: [{ key: "A", positionen }] }) as unknown as TrainingPlan;
  it("alter Plan mit machineId-Positionen ist kein Katalogplan", () => {
    expect(istKatalogPlan(mitPositionen([{ key: "p0", exerciseId: "e", machineId: "m" }]))).toBe(false);
    expect(istKatalogPlan(mitPositionen([{ key: "p0", exerciseId: "e", modelId: "x" }]))).toBe(true);
  });
});

describe("planFuerApp", () => {
  const LEER = { nichtVorhanden: {}, gefaelltNicht: [] };
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
    expect(planFuerApp(plan, [], neu, {}, {}, LEER)).toMatchObject({ naechsteEinheitKey: "A", zuletztEinheitKey: null, einheitenErledigt: 0 });
  });

  it("anfaengerUebergang erst ab 8 bei neu, nie nach anfaengerBeendet", () => {
    expect(planFuerApp(plan, einheiten(7), neu, {}, {}, LEER).anfaengerUebergang).toBe(false);
    expect(planFuerApp(plan, einheiten(8), neu, {}, {}, LEER)).toMatchObject({
      anfaengerUebergang: true, zuletztEinheitKey: "B", naechsteEinheitKey: "A",
    });
    expect(planFuerApp(plan, einheiten(8), { ...neu, experience: "regelmaessig" }, {}, {}, LEER).anfaengerUebergang).toBe(false);
    expect(planFuerApp(plan, einheiten(8), null, {}, {}, LEER).anfaengerUebergang).toBe(false);
    const beendet = { ...plan, eingabe: { ...plan.eingabe, anfaengerBeendet: true } };
    expect(planFuerApp(beendet, einheiten(8), neu, {}, {}, LEER).anfaengerUebergang).toBe(false);
  });
});

describe("nachzuholendeSessions", () => {
  const s = (id: string, z: Partial<Parameters<typeof nachzuholendeSessions>[0][number]>) => ({
    id,
    startedAt: vor(600),
    completedAt: null,
    letzterSatzAm: null,
    gewichteBerechnetAm: null,
    ...z,
  });

  it("beendet oder nach 4 h Stillstand, ohne Marke: nachholen; laufend nicht", () => {
    expect(
      nachzuholendeSessions(
        [
          s("beendet", { completedAt: vor(300) }),
          s("still", { letzterSatzAm: vor(241) }),
          s("laeuft", { letzterSatzAm: vor(239) }),
          s("ohneSatzStill", { startedAt: vor(500) }),
          s("ohneSatzLaeuft", { startedAt: vor(10) }),
        ],
        JETZT,
      ),
    ).toEqual(["ohneSatzStill", "beendet", "still"]);
  });

  it("Marke vor dem Abschluss (wieder geoeffnet und erneut beendet): nachholen; danach nicht", () => {
    expect(
      nachzuholendeSessions(
        [
          s("wieder", { completedAt: vor(100), gewichteBerechnetAm: vor(130) }),
          s("fertig", { completedAt: vor(100), gewichteBerechnetAm: vor(99) }),
          s("still", { letzterSatzAm: vor(300), gewichteBerechnetAm: vor(50) }),
        ],
        JETZT,
      ),
    ).toEqual(["wieder"]);
  });

  it("aufsteigend nach Stand, hoechstens die juengsten fuenf", () => {
    const liste = [6, 1, 4, 2, 5, 3].map((n) => s(`s${n}`, { completedAt: vor(1000 - n * 10) }));
    expect(nachzuholendeSessions(liste, JETZT)).toEqual(["s2", "s3", "s4", "s5", "s6"]);
  });
});

describe("planFuerApp -- Merkliste", () => {
  it("reicht die Merkliste unveraendert in den Plan", () => {
    const plan = { id: "p", studioId: "k", version: 1, regelVersion: "x", struktur: "gk_ab", einheiten: [{ key: "A", positionen: [] }], gruende: [], eingabe: {} } as unknown as TrainingPlan;
    const merkliste = { nichtVorhanden: { o: ["e1"] }, gefaelltNicht: ["e2"] };
    expect(planFuerApp(plan, [], null, {}, {}, merkliste).merkliste).toEqual(merkliste);
  });
});
