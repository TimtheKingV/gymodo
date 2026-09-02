import { beforeAll, describe, expect, it } from "vitest";
import { listStudioExercises } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let trainerA: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioFehler } = await admin
    .from("studios")
    .insert([{ name: "Uebungen Studio A" }, { name: "Uebungen Studio B" }])
    .select("id");
  if (studioFehler) throw studioFehler;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  trainerA = uniqueEmail("uebungen-trainer-a");
  const nutzer = await createTestUser(trainerA);
  const { error: mitgliedFehler } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: nutzer, role: "trainer" });
  if (mitgliedFehler) throw mitgliedFehler;

  const { data: modelle, error: modellFehler } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Uebungen-Modell 1", weight_step_kg: 5 },
      { studio_id: studioA, name: "Uebungen-Modell 2", weight_step_kg: 5 },
    ])
    .select("id");
  if (modellFehler) throw modellFehler;

  const { data: uebungen, error: uebungFehler } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Rudern sitzend",
        target_reps_min: 10,
        target_reps_max: 15,
      },
      {
        studio_id: studioA,
        name: "Trizepsdruecken am Seil",
        target_reps_min: 10,
        target_reps_max: 15,
      },
      {
        studio_id: studioB,
        name: "Fremde Uebung",
        target_reps_min: 8,
        target_reps_max: 12,
      },
    ])
    .select("id");
  if (uebungFehler) throw uebungFehler;

  // "Rudern sitzend" haengt an beiden Modellen, "Trizepsdruecken" an keinem.
  const { error: linkFehler } = await admin
    .from("equipment_model_exercises")
    .insert([
      {
        equipment_model_id: modelle[0]!.id,
        exercise_id: uebungen[0]!.id,
        sort_order: 1,
      },
      {
        equipment_model_id: modelle[1]!.id,
        exercise_id: uebungen[0]!.id,
        sort_order: 1,
      },
    ]);
  if (linkFehler) throw linkFehler;
});

describe("listStudioExercises", () => {
  it("nennt auch die Uebung, die an keinem Modell haengt", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioA);

    const namen = liste.map((uebung) => uebung.name);
    expect(namen).toContain("Rudern sitzend");
    // Genau der Fall, den getStudioCatalog nicht kennt -- und den das
    // Auswahl-Sheet zeigt.
    expect(namen).toContain("Trizepsdruecken am Seil");
  });

  it("zaehlt, an wie vielen Modellen eine Uebung haengt", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioA);

    const rudern = liste.find((uebung) => uebung.name === "Rudern sitzend")!;
    expect(rudern.modelCount).toBe(2);
    expect(rudern.targetRepsMin).toBe(10);
    expect(rudern.targetRepsMax).toBe(15);

    const trizeps = liste.find(
      (uebung) => uebung.name === "Trizepsdruecken am Seil",
    )!;
    expect(trizeps.modelCount).toBe(0);
  });

  it("sortiert nach Namen -- das Sheet wird gelesen, nicht durchsucht", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioA);
    const namen = liste.map((uebung) => uebung.name);
    expect(namen).toEqual([...namen].sort((a, b) => a.localeCompare(b, "de")));
  });

  it("gibt die Uebungen eines fremden Studios nicht heraus", async () => {
    const client = await userClient(trainerA);
    const liste = await listStudioExercises(client, studioB);
    expect(liste).toEqual([]);
  });
});
