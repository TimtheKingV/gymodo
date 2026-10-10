import { beforeAll, describe, expect, it } from "vitest";
import { createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

// Die Datenbank prueft die einfache Konsistenz selbst (Sensor-Spec B 6.1),
// damit kein zweiter Schreibweg je einen "gemessenen" Satz ohne Zaehlerstand
// ablegen kann. Die Regeln, die die Uebung kennen muessen, prueft recordSet.

const ereignisse = {
  algo: "langhantel/1",
  befestigungsart: "langhantel",
  unsicher: null,
  wiederholungen: Array.from({ length: 10 }, (_, i) => ({
    beginn: i * 2, umkehr: i * 2 + 1, ende: i * 2 + 1.9, ausschlag: 110, sicherheit: 0.9,
  })),
};

let basis: Record<string, unknown>;

beforeAll(async () => {
  const admin = serviceClient();
  const { data: studio, error: e1 } = await admin.from("studios").insert({ name: "Herkunft DB" }).select("id").single();
  if (e1) throw e1;
  const userId = await createTestUser(uniqueEmail("herkunft-db"));
  await admin.from("studio_memberships").insert({ studio_id: studio.id, user_id: userId, role: "member" });
  const { data: modell, error: e2 } = await admin.from("equipment_models")
    .insert({ studio_id: studio.id, name: "Curlbank", load_step: 2.5 }).select("id").single();
  if (e2) throw e2;
  const { data: maschine, error: e3 } = await admin.from("machines")
    .insert({ studio_id: studio.id, equipment_model_id: modell.id, label: "C1" }).select("id").single();
  if (e3) throw e3;
  const { data: uebung, error: e4 } = await admin.from("exercises")
    .insert({ studio_id: studio.id, name: "Curl", target_min: 8, target_max: 12 }).select("id").single();
  if (e4) throw e4;
  const sessionId = crypto.randomUUID();
  const { error: e5 } = await admin.from("workout_sessions").insert({ id: sessionId, studio_id: studio.id, user_id: userId });
  if (e5) throw e5;
  basis = {
    studio_id: studio.id, user_id: userId, session_id: sessionId, machine_id: maschine.id,
    exercise_id: uebung.id, load: 20, volume: 10,
  };
});

let setIndex = 0;
async function einfuegen(felder: Record<string, unknown>) {
  setIndex += 1;
  return serviceClient().from("workout_sets")
    .insert({ ...basis, id: crypto.randomUUID(), set_index: setIndex, ...felder })
    .select("volume_source, volume_counted, rep_events").single();
}

describe("workout_sets: Herkunft", () => {
  it("setzt ohne Angabe eingegeben", async () => {
    const { data, error } = await einfuegen({});
    expect(error).toBeNull();
    expect(data).toEqual({ volume_source: "eingegeben", volume_counted: null, rep_events: null });
  });

  it("nimmt gemessen mit Zaehlerstand gleich Umfang an", async () => {
    const { error } = await einfuegen({ volume_source: "gemessen", volume_counted: 10, rep_events: ereignisse });
    expect(error).toBeNull();
  });

  it("nimmt korrigiert mit abweichendem Zaehlerstand an", async () => {
    const { error } = await einfuegen({ volume_source: "korrigiert", volume_counted: 9, rep_events: ereignisse });
    expect(error).toBeNull();
  });

  it.each([
    ["eingegeben mit Zaehlerstand", { volume_source: "eingegeben", volume_counted: 10 }],
    ["gemessen ohne Ereignisse", { volume_source: "gemessen", volume_counted: 10 }],
    ["gemessen mit abweichendem Stand", { volume_source: "gemessen", volume_counted: 9, rep_events: ereignisse }],
    ["korrigiert mit gleichem Stand", { volume_source: "korrigiert", volume_counted: 10, rep_events: ereignisse }],
    ["unbekannte Herkunft", { volume_source: "geschaetzt" }],
    ["Zaehlerstand null Wiederholungen", { volume_source: "korrigiert", volume_counted: 0, rep_events: ereignisse }],
  ])("weist ab: %s", async (_name, felder) => {
    const { error } = await einfuegen(felder);
    expect(error?.code).toBe("23514");
  });
});
