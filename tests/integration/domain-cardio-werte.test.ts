import { beforeAll, describe, expect, it } from "vitest";
import { getBootstrap, getMachineContext, getProgress, getSessions, recordSet } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Testnotiz 14.10., 18:45 #7: Cardio-Werte (Spec 2026-10-15-cardio-werte-design).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

let mitgliedEmail: string;
let mitgliedId: string;
let studio: string;
let cardioMaschine: string;
let wattMaschine: string;
let cardioUebung: string;
let kraftMaschine: string;
let kraftModell: string;
let kraftUebung: string;
let vorhandeneSession: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studioZeile, error: studioError } = await admin
    .from("studios")
    .insert({ name: `Cardio-Werte ${kennung}` })
    .select("id")
    .single();
  if (studioError) throw studioError;
  studio = studioZeile.id;

  mitgliedEmail = uniqueEmail("cardio-werte");
  mitgliedId = await createTestUser(mitgliedEmail);
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio, user_id: mitgliedId, role: "member" });
  if (rolleError) throw rolleError;

  // Katalog-Typ mit Liste, Studio-Modell erbt sie (leere eigene Liste).
  const { data: typ, error: typError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: GYMTAVO, name: `Cardio-Typ ${kennung}`, category: "cardio", load_unit: "level",
      load_step: 1, load_min: 0, cardio_werte: ["zeit", "strecke", "watt"],
    })
    .select("id")
    .single();
  if (typError) throw typError;

  const { data: modelle, error: modellError } = await admin
    .from("equipment_models")
    .insert([
      {
        studio_id: studio, name: `Cardio-Modell ${kennung}`, category: "cardio", load_unit: "level",
        load_step: 1, load_min: 0, catalog_model_id: typ.id,
      },
      { studio_id: studio, name: `Kraft-Modell ${kennung}`, category: "kraft", load_unit: "kg", load_step: 2.5, load_min: 0 },
      {
        studio_id: studio, name: `Watt-Modell ${kennung}`, category: "cardio", load_unit: "watt",
        load_step: 5, load_min: 0, catalog_model_id: typ.id,
      },
    ])
    .select("id");
  if (modellError) throw modellError;
  kraftModell = modelle[1]!.id;

  const { data: maschinen, error: maschineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studio, equipment_model_id: modelle[0]!.id, label: "C1" },
      { studio_id: studio, equipment_model_id: kraftModell, label: "K1" },
      { studio_id: studio, equipment_model_id: modelle[2]!.id, label: "W1" },
    ])
    .select("id");
  if (maschineError) throw maschineError;
  cardioMaschine = maschinen[0]!.id;
  kraftMaschine = maschinen[1]!.id;
  wattMaschine = maschinen[2]!.id;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: studio, name: `Rudern ${kennung}`, volume_kind: "seconds", target_min: 60, target_max: 600 },
      { studio_id: studio, name: `Curl ${kennung}`, volume_kind: "reps", target_min: 8, target_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  cardioUebung = uebungen[0]!.id;
  kraftUebung = uebungen[1]!.id;

  vorhandeneSession = crypto.randomUUID();
  const { error: sessionError } = await admin
    .from("workout_sessions")
    .insert({ id: vorhandeneSession, studio_id: studio, user_id: mitgliedId });
  if (sessionError) throw sessionError;
});

describe("recordSet -- Cardio (Testnotiz 14.10., 18:45 #7)", () => {
  const basis = () => ({ sessionId: crypto.randomUUID(), setId: crypto.randomUUID(), setIndex: 1 });

  it("speichert Cardio-Werte an der Maschine, Liste vom Typ geerbt", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, cardio: { zeit: 510, strecke: 2000 } });
    expect(satz).toMatchObject({ load: null, volume: null, cardio: { zeit: 510, strecke: 2000 } });
  });

  it("lehnt einen Wert ab, den das Geraet nicht hat", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, cardio: { stufe: 5 } }))
      .rejects.toMatchObject({ code: "validation_failed", message: "Dieser Wert gehört nicht zu diesem Gerät." });
  });

  it("lehnt einen leeren Cardio-Satz ab", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, cardio: {} }))
      .rejects.toMatchObject({ message: "Mindestens ein Wert fehlt." });
  });

  // Review Focus 1: Satz einer alten App, vielleicht aus der Warteschlange.
  it("wandelt load/volume einer alten App um", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 1200 });
    // level -> stufe steht nicht in der Liste und faellt weg, Sekunden -> zeit.
    expect(satz).toMatchObject({ load: null, volume: null, cardio: { zeit: 1200 } });
  });

  it("verwirft bei einer alten App nur den ungueltigen Wert", async () => {
    const client = await userClient(mitgliedEmail);
    // Umfang 99999 s liegt ueber 86400 (zeit) und faellt weg; die Watt bleiben.
    const satz = await recordSet(client, { ...basis(), machineId: wattMaschine, exerciseId: cardioUebung, load: 150, volume: 99999 });
    expect(satz).toMatchObject({ load: null, volume: null, cardio: { watt: 150 } });
    expect(satz.cardio).not.toHaveProperty("zeit");
  });

  it("lehnt einen alten Satz ab, von dem nichts gueltig bleibt", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 99999 }))
      .rejects.toMatchObject({ message: "Mindestens ein Wert fehlt." });
  });

  it("lehnt cardio an einem Kraftgeraet ab", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: kraftMaschine, exerciseId: kraftUebung, load: 40, volume: 10, cardio: { zeit: 60 } }))
      .rejects.toMatchObject({ message: "Dieses Gerät hat keine Cardio-Werte." });
  });

  it("lehnt Belastung neben Cardio-Werten ab", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 60, cardio: { zeit: 60 } }))
      .rejects.toMatchObject({ message: "Ein Cardio-Gerät hat keine Belastung." });
  });

  it("Kraft bleibt wie bisher", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: kraftMaschine, exerciseId: kraftUebung, load: 40, volume: 10 });
    expect(satz).toMatchObject({ load: 40, volume: 10, cardio: null });
  });

  it("die Datenbank lehnt gemischte Saetze selbst ab", async () => {
    const { error } = await serviceClient().from("workout_sets").insert({
      id: crypto.randomUUID(), studio_id: studio, user_id: mitgliedId, session_id: vorhandeneSession,
      equipment_model_id: kraftModell, exercise_id: kraftUebung, set_index: 9, load: 40, volume: 10, dauer_s: 60,
    });
    expect(error?.message).toMatch(/workout_sets_art/);
  });
});

describe("Lesewege -- Cardio", () => {
  it("Bootstrap: Liste am Studio-Modell vom Typ geerbt, letzter Satz mit cardio", async () => {
    const client = await userClient(mitgliedEmail);
    await recordSet(client, {
      sessionId: crypto.randomUUID(), setId: crypto.randomUUID(), setIndex: 1,
      machineId: cardioMaschine, exerciseId: cardioUebung, cardio: { zeit: 600, watt: 150 },
    });
    const b = await getBootstrap(client);
    const m = b.machines.find((x) => x.id === cardioMaschine)!;
    expect(m.equipmentModel.cardioWerte).toEqual(["zeit", "strecke", "watt"]);
    expect(b.lastSets.find((s) => s.machineId === cardioMaschine)).toMatchObject({
      load: null, volume: null, cardio: { zeit: 600, watt: 150 },
    });
    const kraft = b.machines.find((x) => x.id === kraftMaschine)!;
    expect(kraft.equipmentModel.cardioWerte).toEqual([]);
  });

  it("Sessions liefern cardio am Satz", async () => {
    const client = await userClient(mitgliedEmail);
    const { sessions } = await getSessions(client);
    const satz = sessions.flatMap((s) => s.blocks).find((b) => b.machineId === cardioMaschine)?.sets[0];
    expect(satz?.cardio).toBeTruthy();
    expect(satz?.load).toBeNull();
    expect(satz?.volume).toBeNull();
  });

  it("Geraetekontext: Liste, Historie mit cardio, kein Vorschlag", async () => {
    const client = await userClient(mitgliedEmail);
    const k = await getMachineContext(client, cardioMaschine);
    expect(k.equipmentModel.cardioWerte).toEqual(["zeit", "strecke", "watt"]);
    expect(k.history[0]).toMatchObject({ load: null, volume: [], cardio: expect.any(Object) });
    // Wie ohne Historie: kein Wert, Grund "kein_verlauf".
    expect(k.suggestion).toMatchObject({ resultLoad: null, reasonCode: "kein_verlauf" });
  });

  it("Fortschritt laesst Cardio aus dem Bestlast-Diagramm", async () => {
    const client = await userClient(mitgliedEmail);
    const p = await getProgress(client);
    expect(p.exercises.find((x) => x.exerciseId === cardioUebung)).toBeUndefined();
  });
});
