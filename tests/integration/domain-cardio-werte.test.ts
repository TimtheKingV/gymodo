import { beforeAll, describe, expect, it } from "vitest";
import { completeSession, getBootstrap, getMachineContext, getProgress, getSessions, recordSet } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Testnotiz 14.10., 18:45 #7: Cardio-Werte (Spec 2026-10-15-cardio-werte-design).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();
const SPALTEN = "dauer_s, strecke_m, stufe, stufenanzahl, kmh, steigung_pct, watt, kcal, frequenz";
const OHNE_CARDIO = { dauer_s: null, strecke_m: null, stufe: null, stufenanzahl: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null };

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

  // Final-Review A: eine App von vor E2 (vielleicht aus der Warteschlange)
  // schickt load/volume. Der Server speichert den Satz wie vor E2 -- die
  // alte App liest load/volume als Pflichtfelder (Spec 8).
  it("speichert load/volume einer alten App wie vor E2", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, { ...basis(), machineId: wattMaschine, exerciseId: cardioUebung, load: 150, volume: 1200 });
    expect(satz).toMatchObject({ load: 150, volume: 1200, secondaryLoad: null, cardio: null });
    const { data: zeile } = await serviceClient()
      .from("workout_sets").select(`load, volume, ${SPALTEN}`).eq("id", satz.id).single();
    expect(zeile).toEqual({ load: 150, volume: 1200, ...OHNE_CARDIO });
  });

  it("prueft den alten Satz wie vor E2: Umfang ueber der Grenze der Uebung", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: wattMaschine, exerciseId: cardioUebung, load: 150, volume: 99999 }))
      .rejects.toMatchObject({ code: "validation_failed", message: "Mehr als vier Stunden sind kein Satz." });
  });

  it("prueft den alten Satz wie vor E2: Nebenbelastung an einem Geraet ohne", async () => {
    const client = await userClient(mitgliedEmail);
    await expect(recordSet(client, { ...basis(), machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 600, secondaryLoad: 2 }))
      .rejects.toMatchObject({ code: "validation_failed", message: "Dieses Geraet hat keine Nebenbelastung." });
  });

  // Final-Review C: ein fehlerhafter Client schickt Zaehlerdaten mit. Ein
  // 500 liesse die Warteschlange den Satz ewig wiederholen.
  it("speichert einen Cardio-Satz ohne Zaehlerstand und Ereignisse, auch wenn der Client sie schickt", async () => {
    const client = await userClient(mitgliedEmail);
    const satz = await recordSet(client, {
      ...basis(), machineId: wattMaschine, exerciseId: cardioUebung, cardio: { zeit: 300 },
      volumeSource: "korrigiert", volumeCounted: 1,
      repEvents: {
        algo: "test", befestigungsart: "langhantel", unsicher: null,
        wiederholungen: [{ beginn: 0, umkehr: 1, ende: 2, ausschlag: 1, sicherheit: 1 }],
      },
    });
    expect(satz).toMatchObject({ cardio: { zeit: 300 }, volumeSource: "eingegeben", volumeCounted: null });
    const { data: zeile } = await serviceClient()
      .from("workout_sets").select("volume_source, volume_counted, rep_events").eq("id", satz.id).single();
    expect(zeile).toEqual({ volume_source: "eingegeben", volume_counted: null, rep_events: null });
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
    // Erster Satz des Tages: der aus dem recordSet-Test oben (zeit 510, strecke 2000).
    expect(k.history[0]).toMatchObject({ load: null, volume: [], cardio: { zeit: 510, strecke: 2000 } });
    // Wie ohne Historie: kein Wert, Grund "kein_verlauf".
    expect(k.suggestion).toMatchObject({ resultLoad: null, reasonCode: "kein_verlauf" });
    const { data: vorschlaege } = await serviceClient()
      .from("progression_suggestions").select("id").eq("machine_id", cardioMaschine);
    expect(vorschlaege).toEqual([]);
  });

  it("Fortschritt laesst Cardio aus dem Bestlast-Diagramm", async () => {
    const client = await userClient(mitgliedEmail);
    const p = await getProgress(client);
    expect(p.exercises.find((x) => x.exerciseId === cardioUebung)).toBeUndefined();
  });
});

// Final-Review A: Saetze einer alten App an Cardio-Geraeten bleiben lesbar
// fuer die alte App (load/volume als Zahl) und zeigen in der neuen App ihre
// Cardio-Werte -- aber nie eine Progression oder einen Bestlast-Punkt.
describe("Alte App an einem Cardio-Geraet (Spec 8)", () => {
  let altEmail: string;
  let altSession: string;

  beforeAll(async () => {
    altEmail = uniqueEmail("cardio-alt");
    const altId = await createTestUser(altEmail);
    const { error } = await serviceClient()
      .from("studio_memberships").insert({ studio_id: studio, user_id: altId, role: "member" });
    if (error) throw error;
    const client = await userClient(altEmail);
    altSession = crypto.randomUUID();
    await recordSet(client, {
      sessionId: altSession, setId: crypto.randomUUID(), setIndex: 1,
      machineId: cardioMaschine, exerciseId: cardioUebung, load: 5, volume: 1200,
    });
    await recordSet(client, {
      sessionId: altSession, setId: crypto.randomUUID(), setIndex: 1,
      machineId: wattMaschine, exerciseId: cardioUebung, load: 150, volume: 1500,
    });
  });

  it("Bootstrap: load/volume als Zahl, dazu die abgeleiteten Cardio-Werte", async () => {
    const b = await getBootstrap(await userClient(altEmail));
    // level -> stufe steht nicht in der Liste und faellt weg, Sekunden -> zeit.
    expect(b.lastSets.find((s) => s.machineId === cardioMaschine)).toMatchObject({
      load: 5, volume: 1200, cardio: { zeit: 1200 },
    });
    expect(b.lastSets.find((s) => s.machineId === wattMaschine)).toMatchObject({
      load: 150, volume: 1500, cardio: { zeit: 1500, watt: 150 },
    });
  });

  it("Sessions: load/volume als Zahl, dazu die abgeleiteten Cardio-Werte", async () => {
    const { sessions } = await getSessions(await userClient(altEmail));
    const satz = sessions.find((s) => s.id === altSession)?.blocks.find((b) => b.machineId === wattMaschine)?.sets[0];
    expect(satz).toMatchObject({ load: 150, volume: 1500, cardio: { zeit: 1500, watt: 150 } });
  });

  it("Geraetekontext: Historie mit Zahlen und Cardio-Werten, kein Vorschlag", async () => {
    const client = await userClient(altEmail);
    const k = await getMachineContext(client, wattMaschine);
    expect(k.history[0]).toMatchObject({ load: 150, volume: [1500], cardio: { zeit: 1500, watt: 150 } });
    expect(k.suggestion).toMatchObject({ resultLoad: null, reasonCode: "kein_verlauf" });
    const { data: vorschlaege } = await serviceClient()
      .from("progression_suggestions").select("id").eq("machine_id", wattMaschine)
      .eq("user_id", (await client.auth.getUser()).data.user!.id);
    expect(vorschlaege).toEqual([]);
  });

  it("Abschluss: kein Vorschlag und keine Nachweiszeile fuer den alten Satz", async () => {
    const client = await userClient(altEmail);
    const fertig = await completeSession(client, { sessionId: altSession });
    expect(fertig.vorschlaege).toEqual([]);
    const { data: vorschlaege } = await serviceClient()
      .from("progression_suggestions").select("id")
      .eq("user_id", (await client.auth.getUser()).data.user!.id);
    expect(vorschlaege).toEqual([]);
  });

  it("Fortschritt: kein Bestlast-Punkt fuer den alten Satz", async () => {
    const p = await getProgress(await userClient(altEmail));
    expect(p.exercises.find((x) => x.exerciseId === cardioUebung)).toBeUndefined();
  });
});
