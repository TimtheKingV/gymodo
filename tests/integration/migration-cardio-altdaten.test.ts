import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail, userClient } from "./helpers/clients.js";

// Testnotiz 14.10., 18:45 #7: Migration 0055 schreibt alte Cardio-Saetze um.
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

let alterCardioSatz: string;
let zuHoherSatz: string;
let kraftSatz: string;

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

  const { data: modelle, error: modellError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studio.id, name: `Cardio ${kennung}`, category: "cardio", load_unit: "level", load_step: 1, load_min: 0, catalog_model_id: typ.id },
      { studio_id: studio.id, name: `Kraft ${kennung}`, category: "kraft", load_unit: "kg", load_step: 2.5, load_min: 0 },
    ])
    .select("id");
  if (modellError) throw modellError;

  const { data: maschinen, error: maschineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studio.id, equipment_model_id: modelle![0]!.id, label: "C1" },
      { studio_id: studio.id, equipment_model_id: modelle![1]!.id, label: "K1" },
    ])
    .select("id");
  if (maschineError) throw maschineError;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: studio.id, name: `Rudern ${kennung}`, volume_kind: "seconds", target_min: 60, target_max: 600 },
      { studio_id: studio.id, name: `Curl ${kennung}`, volume_kind: "reps", target_min: 8, target_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;

  const sessionId = crypto.randomUUID();
  const { error: sessionError } = await admin
    .from("workout_sessions").insert({ id: sessionId, studio_id: studio.id, user_id: userId });
  if (sessionError) throw sessionError;

  alterCardioSatz = crypto.randomUUID();
  zuHoherSatz = crypto.randomUUID();
  kraftSatz = crypto.randomUUID();
  const basis = { studio_id: studio.id, user_id: userId, session_id: sessionId };
  const { error: satzError } = await admin.from("workout_sets").insert([
    { ...basis, id: alterCardioSatz, machine_id: maschinen![0]!.id, equipment_model_id: modelle![0]!.id, exercise_id: uebungen![0]!.id, set_index: 1, load: 5, volume: 1200 },
    { ...basis, id: zuHoherSatz, machine_id: maschinen![0]!.id, equipment_model_id: modelle![0]!.id, exercise_id: uebungen![0]!.id, set_index: 2, load: 150, volume: 1200 },
    { ...basis, id: kraftSatz, machine_id: maschinen![1]!.id, equipment_model_id: modelle![1]!.id, exercise_id: uebungen![1]!.id, set_index: 1, load: 40, volume: 10 },
  ]);
  if (satzError) throw satzError;
});

describe("cardio_altdaten_umschreiben", () => {
  it("schreibt alte Cardio-Saetze um und laesst Kraft stehen", async () => {
    const admin = serviceClient();
    const { error } = await admin.rpc("cardio_altdaten_umschreiben");
    expect(error).toBeNull();
    const { data: cardio } = await admin.from("workout_sets").select("load, volume, dauer_s, stufe").eq("id", alterCardioSatz).single();
    expect(cardio).toEqual({ load: null, volume: null, dauer_s: 1200, stufe: 5 });
    const { data: kraft } = await admin.from("workout_sets").select("load, volume, dauer_s").eq("id", kraftSatz).single();
    expect(kraft).toEqual({ load: 40, volume: 10, dauer_s: null });
  });

  it("kappt Altwerte ausserhalb des Spaltenbereichs", async () => {
    const { data } = await serviceClient().from("workout_sets").select("load, volume, dauer_s, stufe").eq("id", zuHoherSatz).single();
    expect(data).toEqual({ load: null, volume: null, dauer_s: 1200, stufe: 100 });
  });

  it("ist wiederholbar", async () => {
    const { error } = await serviceClient().rpc("cardio_altdaten_umschreiben");
    expect(error).toBeNull();
  });

  it("ist fuer angemeldete Nutzer gesperrt", async () => {
    const email = uniqueEmail("altdaten-sperre");
    await createTestUser(email);
    const client = await userClient(email);
    const { error } = await client.rpc("cardio_altdaten_umschreiben");
    expect(error).not.toBeNull();
  });
});
