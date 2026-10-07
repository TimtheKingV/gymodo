import { beforeAll, describe, expect, it } from "vitest";
import { completeSession, getProgress, getSessions, recordSet } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 8.1:
// Verlauf, Abschluss und Fortschritt kennen Saetze ohne Geraet.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

let mitgliedEmail: string;
let studioA: string;
let typ: string;
let maschine: string;
let uebung: string;
let freieEinheit: string;
let gemischteEinheit: string;

// Frische Zeitpunkte: eine Einheit, deren letzter Satz ueber vier Stunden
// zurueckliegt, beendet getSessions selbsttaetig -- und fuer die liefert der
// Abschluss bewusst keine Vorschlaege (abschluss.ts, ausGespeichertenZeilen).
const MINUTE = 60 * 1000;
function vorMinuten(minuten: number): string {
  return new Date(Date.now() - minuten * MINUTE).toISOString();
}

function satz(overrides: Record<string, unknown>) {
  return {
    setId: crypto.randomUUID(),
    exerciseId: uebung,
    setIndex: 1,
    volume: 10,
    ...overrides,
  };
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: `Stationsverlauf ${kennung}` })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studioA = studio.id;

  mitgliedEmail = uniqueEmail("stationsverlauf");
  const mitgliedId = await createTestUser(mitgliedEmail);
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: mitgliedId, role: "member" });
  if (rolleError) throw rolleError;

  const { data: typRow, error: typError } = await admin
    .from("equipment_models")
    .insert({ studio_id: GYMTAVO, name: `SZ-Stange ${kennung}`, load_step: 2.5, load_min: 10 })
    .select("id")
    .single();
  if (typError) throw typError;
  typ = typRow.id;

  const { data: modell, error: modellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioA, name: `Bizepspult ${kennung}`, load_step: 5, load_min: 5, catalog_model_id: typ })
    .select("id")
    .single();
  if (modellError) throw modellError;

  const { data: maschineRow, error: maschineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: modell.id, label: "P4" })
    .select("id")
    .single();
  if (maschineError) throw maschineError;
  maschine = maschineRow.id;

  const { data: uebungRow, error: uebungError } = await admin
    .from("exercises")
    .insert({ studio_id: GYMTAVO, name: `Bizepscurl ${kennung}`, target_min: 8, target_max: 12 })
    .select("id")
    .single();
  if (uebungError) throw uebungError;
  uebung = uebungRow.id;

  const client = await userClient(mitgliedEmail);

  // Freies Training am Typ, zwei Saetze.
  freieEinheit = crypto.randomUUID();
  for (const [setIndex, load] of [[1, 25], [2, 25]] as const) {
    await recordSet(
      client,
      satz({
        sessionId: freieEinheit,
        equipmentModelId: typ,
        setIndex,
        load,
        performedAt: vorMinuten(50 - setIndex),
        sessionStartedAt: vorMinuten(55),
      }),
    );
  }

  // Im Studio gemischt: am Geraet und ohne Geraet am Typ, dieselbe Uebung.
  gemischteEinheit = crypto.randomUUID();
  await recordSet(
    client,
    satz({
      sessionId: gemischteEinheit,
      machineId: maschine,
      load: 30,
      performedAt: vorMinuten(20),
      sessionStartedAt: vorMinuten(25),
    }),
  );
  await recordSet(
    client,
    satz({
      sessionId: gemischteEinheit,
      equipmentModelId: typ,
      studioId: studioA,
      load: 27.5,
      performedAt: vorMinuten(15),
    }),
  );
});

describe("Verlauf ueber Stationen", () => {
  it("zeigt den Block im Freien Training mit Typ statt Geraet", async () => {
    const client = await userClient(mitgliedEmail);

    const { sessions } = await getSessions(client);
    const frei = sessions.find((s) => s.id === freieEinheit);

    expect(frei?.blocks).toEqual([
      expect.objectContaining({
        machineId: null,
        equipmentModelId: typ,
        machineLabel: `SZ-Stange ${kennung}`,
        exerciseId: uebung,
        loadUnit: "kg",
      }),
    ]);
    expect(frei?.blocks[0]?.sets).toHaveLength(2);
  });

  it("haelt in der gemischten Einheit Geraet und Typ als zwei Bloecke auseinander", async () => {
    const client = await userClient(mitgliedEmail);

    const { sessions } = await getSessions(client);
    const gemischt = sessions.find((s) => s.id === gemischteEinheit);

    expect(gemischt?.blocks.map((b) => [b.machineId, b.equipmentModelId !== null])).toEqual([
      [maschine, true],
      [null, true],
    ]);
  });
});

describe("Abschluss ueber Stationen", () => {
  it("schlaegt im Freien Training je Typ vor und liest den Vorschlag spaeter zurueck", async () => {
    const client = await userClient(mitgliedEmail);

    const erster = await completeSession(client, { sessionId: freieEinheit });
    const zweiter = await completeSession(client, { sessionId: freieEinheit });

    expect(erster.vorschlaege).toEqual([
      expect.objectContaining({ machineId: null, equipmentModelId: typ, exerciseId: uebung, loadUnit: "kg" }),
    ]);
    expect(zweiter.vorschlaege).toEqual(erster.vorschlaege);

    const admin = serviceClient();
    const { data } = await admin
      .from("progression_suggestions")
      .select("studio_id, machine_id, equipment_model_id")
      .eq("equipment_model_id", typ)
      .eq("exercise_id", uebung)
      .eq("studio_id", GYMTAVO);
    expect(data).toEqual([{ studio_id: GYMTAVO, machine_id: null, equipment_model_id: typ }]);
  });

  it("schlaegt in der gemischten Einheit je Station einmal vor", async () => {
    const client = await userClient(mitgliedEmail);

    const { vorschlaege } = await completeSession(client, { sessionId: gemischteEinheit });

    expect(vorschlaege.map((v) => v.machineId)).toEqual([maschine, null]);
  });
});

describe("Fortschritt ueber Stationen", () => {
  it("fuehrt dieselbe Gymtavo-Uebung an allen Stationen in einer Kurve", async () => {
    const client = await userClient(mitgliedEmail);

    const { exercises } = await getProgress(client);
    const kurve = exercises.filter((e) => e.exerciseId === uebung);

    // Alle Saetze liegen am selben Tag; je Tag zaehlt der schwerste -- 30 kg
    // am Studio-Geraet, nicht 25 frei. Die Beschriftung folgt dem juengsten
    // Satz, und der war frei an der SZ-Stange.
    expect(kurve).toHaveLength(1);
    expect(kurve[0]?.currentLoad).toBe(30);
    expect(kurve[0]?.machineLabel).toBe(`SZ-Stange ${kennung}`);
  });
});
