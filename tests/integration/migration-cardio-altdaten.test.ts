import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Testnotiz 14.10., 18:45 #7: Migration 0055 schreibt alte Cardio-Saetze um.
// Jeder Test ruft die Funktion selbst auf (sie ist wiederholbar) und prueft
// alle acht Cardio-Spalten -- ein NULL, das zu -10 % oder 0 /min wird, faellt
// nur so auf (Final-Review G).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();
const SPALTEN = "load, volume, secondary_load, volume_source, volume_counted, rep_events, dauer_s, strecke_m, stufe, kmh, steigung_pct, watt, kcal, frequenz";
const LEER = { dauer_s: null, strecke_m: null, stufe: null, kmh: null, steigung_pct: null, watt: null, kcal: null, frequenz: null };
const UMGESCHRIEBEN = { load: null, volume: null, secondary_load: null, volume_source: "eingegeben", volume_counted: null, rep_events: null };

const satz: Record<string, string> = {};

async function umschreiben() {
  const { error } = await serviceClient().rpc("cardio_altdaten_umschreiben");
  expect(error).toBeNull();
}

async function zeile(id: string) {
  const { data, error } = await serviceClient().from("workout_sets").select(SPALTEN).eq("id", id).single();
  if (error) throw error;
  // numeric kommt als Zahl oder Zeichenkette; fuer den Vergleich als Zahl.
  const z = data as Record<string, unknown>;
  for (const k of ["load", "secondary_load", "kmh", "steigung_pct"]) {
    if (z[k] !== null) z[k] = Number(z[k]);
  }
  return z;
}

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error: studioError } = await admin
    .from("studios").insert({ name: `Altdaten ${kennung}` }).select("id").single();
  if (studioError) throw studioError;

  const email = uniqueEmail("altdaten");
  const userId = await createTestUser(email);

  const { data: typ, error: typError } = await admin
    .from("equipment_models")
    .insert({
      studio_id: GYMTAVO, name: `Altdaten-Typ ${kennung}`, category: "cardio", load_unit: "level",
      load_step: 1, load_min: 0, cardio_werte: ["zeit", "stufe"],
    })
    .select("id").single();
  if (typError) throw typError;

  const modellBasis = { studio_id: studio.id, category: "cardio", load_step: 1, load_min: 0 };
  // Eine Sammel-Einfuegung setzt fehlende Spalten auf NULL statt auf den
  // Default -- deshalb nennt jede Zeile cardio_werte.
  const { data: modelle, error: modellError } = await admin
    .from("equipment_models")
    .insert([
      // 0: Stufe, Liste vom Typ geerbt (zeit, stufe) -- ohne Steigung und Frequenz.
      { ...modellBasis, name: `Cardio ${kennung}`, load_unit: "level", catalog_model_id: typ.id, cardio_werte: [] },
      // 1: Kraft.
      { studio_id: studio.id, name: `Kraft ${kennung}`, category: "kraft", load_unit: "kg", load_step: 2.5, load_min: 0, cardio_werte: [] },
      // 2: Laufband mit Neigung als Nebenbelastung, Liste mit Steigung.
      {
        ...modellBasis, name: `Laufband ${kennung}`, load_unit: "kmh", load_step: 0.1,
        secondary_unit: "pct", secondary_step: 0.5, secondary_min: 0, secondary_max: 15,
        cardio_werte: ["zeit", "strecke", "kmh", "steigung"],
      },
      // 3: Laufband mit Neigung, Liste OHNE Steigung.
      {
        ...modellBasis, name: `Laufband ohne Neigung ${kennung}`, load_unit: "kmh", load_step: 0.1,
        secondary_unit: "pct", secondary_step: 0.5, secondary_min: 0, secondary_max: 15,
        cardio_werte: ["zeit", "kmh"],
      },
      // 4: Watt.
      { ...modellBasis, name: `Ruder ${kennung}`, load_unit: "watt", load_step: 5, cardio_werte: ["zeit", "watt"] },
      // 5: nur kcal -- aus load/volume laesst sich nichts davon ableiten.
      { ...modellBasis, name: `Nur kcal ${kennung}`, load_unit: "level", cardio_werte: ["kcal"] },
      // 6: Watt mit Stufe als Nebenbelastung -- wie altEingabeUmwandeln
      // wird auch eine Nebenbelastung in Stufe/km/h/Watt umgeschrieben.
      {
        ...modellBasis, name: `Ergometer ${kennung}`, load_unit: "watt", load_step: 5,
        secondary_unit: "level", secondary_step: 1, secondary_min: 1, secondary_max: 20,
        cardio_werte: ["zeit", "stufe", "watt"],
      },
    ])
    .select("id");
  if (modellError) throw modellError;
  const m = modelle!.map((x) => x.id);

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: studio.id, name: `Rudern ${kennung}`, volume_kind: "seconds", target_min: 60, target_max: 600 },
      { studio_id: studio.id, name: `Curl ${kennung}`, volume_kind: "reps", target_min: 8, target_max: 12 },
      { studio_id: studio.id, name: `Laufen ${kennung}`, volume_kind: "meters", target_min: 100, target_max: 10000 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  const [sekunden, wiederholungen, meter] = uebungen!.map((x) => x.id);

  const sessionId = crypto.randomUUID();
  const { error: sessionError } = await admin
    .from("workout_sessions").insert({ id: sessionId, studio_id: studio.id, user_id: userId });
  if (sessionError) throw sessionError;

  const basis = { studio_id: studio.id, user_id: userId, session_id: sessionId };
  const zeilen: Array<[string, Record<string, unknown>]> = [
    ["stufe", { equipment_model_id: m[0], exercise_id: sekunden, load: 5, volume: 1200 }],
    ["zuHoch", { equipment_model_id: m[0], exercise_id: sekunden, load: 150, volume: 1200 }],
    ["kraft", { equipment_model_id: m[1], exercise_id: wiederholungen, load: 40, volume: 10 }],
    ["neigung", { equipment_model_id: m[2], exercise_id: sekunden, load: 8.46, secondary_load: 2.34, volume: 900 }],
    ["meter", { equipment_model_id: m[2], exercise_id: meter, load: 10, secondary_load: 0, volume: 2000 }],
    ["ohneNeigung", { equipment_model_id: m[3], exercise_id: sekunden, load: 9, secondary_load: 3, volume: 600 }],
    ["nichts", { equipment_model_id: m[5], exercise_id: wiederholungen, load: 5, volume: 10 }],
    ["nebenStufe", { equipment_model_id: m[6], exercise_id: sekunden, load: 150, secondary_load: 8, volume: 600 }],
    [
      "gemessen",
      {
        equipment_model_id: m[4], exercise_id: wiederholungen, load: 150, volume: 1,
        volume_source: "gemessen", volume_counted: 1,
        rep_events: {
          algo: "test", befestigungsart: "langhantel", unsicher: null,
          wiederholungen: [{ beginn: 0, umkehr: 1, ende: 2, ausschlag: 1, sicherheit: 1 }],
        },
      },
    ],
  ];
  // Einzeln: eine Sammel-Einfuegung setzt fehlende Spalten auf NULL statt
  // auf ihren Default.
  for (const [i, [name, werte]] of zeilen.entries()) {
    satz[name] = crypto.randomUUID();
    const { error: satzError } = await admin
      .from("workout_sets").insert({ ...basis, id: satz[name], set_index: i + 1, ...werte });
    if (satzError) throw satzError;
  }
});

describe("cardio_altdaten_umschreiben", () => {
  it("schreibt einen alten Satz um und setzt nur die Spalten der Liste", async () => {
    await umschreiben();
    expect(await zeile(satz.stufe!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, dauer_s: 1200, stufe: 5 });
  });

  it("laesst Kraft stehen", async () => {
    await umschreiben();
    expect(await zeile(satz.kraft!)).toEqual({
      load: 40, volume: 10, secondary_load: null, volume_source: "eingegeben", volume_counted: null, rep_events: null, ...LEER,
    });
  });

  it("kappt Altwerte ausserhalb des Spaltenbereichs", async () => {
    await umschreiben();
    expect(await zeile(satz.zuHoch!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, dauer_s: 1200, stufe: 100 });
  });

  it("die Nebenbelastung in Prozent wird die Steigung, gerundet auf ein Zehntel", async () => {
    await umschreiben();
    expect(await zeile(satz.neigung!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, dauer_s: 900, kmh: 8.5, steigung_pct: 2.3 });
  });

  it("Meter werden die Strecke", async () => {
    await umschreiben();
    expect(await zeile(satz.meter!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, strecke_m: 2000, kmh: 10, steigung_pct: 0 });
  });

  it("eine Nebenbelastung in Stufe wird die Stufe", async () => {
    await umschreiben();
    expect(await zeile(satz.nebenStufe!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, dauer_s: 600, watt: 150, stufe: 8 });
  });

  it("ohne Steigung und Frequenz in der Liste bleiben beide leer", async () => {
    await umschreiben();
    expect(await zeile(satz.ohneNeigung!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, dauer_s: 600, kmh: 9 });
  });

  it("laesst einen Satz unveraendert, von dem nichts umzuschreiben ist", async () => {
    await umschreiben();
    expect(await zeile(satz.nichts!)).toEqual({
      load: 5, volume: 10, secondary_load: null, volume_source: "eingegeben", volume_counted: null, rep_events: null, ...LEER,
    });
  });

  it("setzt die Herkunft eines gezaehlten Altsatzes zurueck", async () => {
    await umschreiben();
    expect(await zeile(satz.gemessen!)).toEqual({ ...UMGESCHRIEBEN, ...LEER, watt: 150 });
  });

  it("ist wiederholbar: ein zweiter Lauf aendert nichts", async () => {
    await umschreiben();
    const vorher = await zeile(satz.neigung!);
    await umschreiben();
    expect(await zeile(satz.neigung!)).toEqual(vorher);
    expect(vorher).toEqual({ ...UMGESCHRIEBEN, ...LEER, dauer_s: 900, kmh: 8.5, steigung_pct: 2.3 });
  });

  it("ist fuer angemeldete Nutzer gesperrt", async () => {
    const email = uniqueEmail("altdaten-sperre");
    await createTestUser(email);
    const client = await userClient(email);
    const { error } = await client.rpc("cardio_altdaten_umschreiben");
    expect(error?.code).toBe("42501");
  });
});
