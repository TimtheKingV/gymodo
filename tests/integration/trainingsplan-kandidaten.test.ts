import { beforeAll, describe, expect, it } from "vitest";
import { ladeKandidaten, type Kandidat } from "@fitretro/domain";
import { serviceClient } from "./helpers/clients.js";

// Task 6 Etappe 2: Planuebungen eines Studios als Generator-Kandidaten.
// Der echte Gymtavo-Katalog ist in Tests nicht geladen; die Typen und Uebungen
// legt die Datei selbst an und prueft auf Enthaltensein (andere Dateien
// legen ebenfalls Gymtavo-Typen an).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();
const admin = serviceClient();

let studio: string;
let fremdesStudio: string;
let katalogUebung: string; // am Typ, mit Plan, zwei Muskeln
let eigeneUebung: string; // am Studio-Modell, mit Plan
let ohnePlan: string; // am Typ, ohne Plan
let cardioUebung: string;
let aktiv: string;
let inaktiv: string;
let fremd: string;
let cardioGeraet: string;
let alle: Kandidat[];

async function einfuegen<T>(tabelle: string, zeilen: object | object[]): Promise<T[]> {
  const { data, error } = await admin.from(tabelle).insert(zeilen).select("id");
  if (error) throw error;
  return data as T[];
}

beforeAll(async () => {
  const studios = await einfuegen<{ id: string }>("studios", [
    { name: `Kandidaten A ${kennung}` },
    { name: `Kandidaten B ${kennung}` },
  ]);
  studio = studios[0]!.id;
  fremdesStudio = studios[1]!.id;

  const [typ, cardioTyp] = await einfuegen<{ id: string }>("equipment_models", [
    { studio_id: GYMTAVO, name: `Presse ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, load_start: 20, cardio_werte: [] },
    { studio_id: GYMTAVO, name: `Crosstrainer ${kennung}`, category: "cardio", load_unit: "level", load_step: 1, load_min: 0, cardio_werte: ["zeit", "watt"] },
  ]);
  const modelle = await einfuegen<{ id: string }>("equipment_models", [
    { studio_id: studio, name: `Presse A ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, cardio_werte: [], catalog_model_id: typ!.id },
    { studio_id: fremdesStudio, name: `Presse B ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, cardio_werte: [], catalog_model_id: typ!.id },
    { studio_id: studio, name: `Cross A ${kennung}`, category: "cardio", load_unit: "level", load_step: 1, load_min: 0, cardio_werte: [], catalog_model_id: cardioTyp!.id },
  ]);

  const uebungen = await einfuegen<{ id: string }>("exercises", [
    { studio_id: GYMTAVO, name: `Beinpresse ${kennung}`, muscles: [{ key: "quads", name: "Quadrizeps", role: "primary" }, { key: "glutes", name: "Gesaess", role: "secondary" }], target_min: 8, target_max: 12, plan_baustein: "beine_knie", plan_typ: "mehrgelenk", plan_bereiche: ["knie"] },
    { studio_id: studio, name: `Hausuebung ${kennung}`, muscles: [], target_min: 8, target_max: 12, plan_baustein: "arme", plan_typ: "isolation", plan_bereiche: [] },
    { studio_id: GYMTAVO, name: `Ohne Plan ${kennung}`, muscles: [], target_min: 8, target_max: 12, plan_bereiche: [] },
    { studio_id: GYMTAVO, name: `Cross ${kennung}`, muscles: [], target_min: 10, target_max: 20, plan_baustein: "cardio", plan_typ: "mehrgelenk", plan_bereiche: [] },
  ]);
  katalogUebung = uebungen[0]!.id;
  eigeneUebung = uebungen[1]!.id;
  ohnePlan = uebungen[2]!.id;
  cardioUebung = uebungen[3]!.id;

  await einfuegen("equipment_model_exercises", [
    { equipment_model_id: typ!.id, exercise_id: katalogUebung, sort_order: 1 },
    { equipment_model_id: typ!.id, exercise_id: ohnePlan, sort_order: 2 },
    { equipment_model_id: modelle[0]!.id, exercise_id: eigeneUebung, sort_order: 1 },
    // Zusaetzlich selbst angehaengt: darf nicht doppelt erscheinen.
    { equipment_model_id: modelle[0]!.id, exercise_id: katalogUebung, sort_order: 2 },
    { equipment_model_id: cardioTyp!.id, exercise_id: cardioUebung, sort_order: 1 },
  ]);

  const maschinen = await einfuegen<{ id: string }>("machines", [
    { studio_id: studio, equipment_model_id: modelle[0]!.id, label: "P1", status: "active" },
    { studio_id: studio, equipment_model_id: modelle[0]!.id, label: "P2", status: "inactive" },
    { studio_id: fremdesStudio, equipment_model_id: modelle[1]!.id, label: "P3", status: "active" },
    { studio_id: studio, equipment_model_id: modelle[2]!.id, label: "C1", status: "active" },
  ]);
  aktiv = maschinen[0]!.id;
  inaktiv = maschinen[1]!.id;
  fremd = maschinen[2]!.id;
  cardioGeraet = maschinen[3]!.id;

  alle = await ladeKandidaten(admin, studio);
});

describe("ladeKandidaten", () => {
  it("liefert nur aktive Geraete des Studios", () => {
    const geraete = new Set(alle.map((k) => k.machineId));
    expect(geraete.has(aktiv)).toBe(true);
    expect(geraete.has(inaktiv)).toBe(false);
    expect(geraete.has(fremd)).toBe(false);
  });

  it("ignoriert Uebungen ohne plan", () => {
    expect(alle.some((k) => k.exerciseId === ohnePlan)).toBe(false);
  });

  it("fuehrt Katalog- und eigene Uebungen zusammen, ohne Doppelte", () => {
    const amGeraet = alle.filter((k) => k.machineId === aktiv);
    expect(amGeraet.map((k) => k.exerciseId).sort()).toEqual([katalogUebung, eigeneUebung].sort());
    expect(amGeraet.find((k) => k.exerciseId === katalogUebung)).toMatchObject({
      baustein: "beine_knie",
      typ: "mehrgelenk",
      bereiche: ["knie"],
    });
  });

  it("hauptmuskeln enthaelt nur primary", () => {
    expect(alle.find((k) => k.exerciseId === katalogUebung)!.hauptmuskeln).toEqual(["quads"]);
    expect(alle.find((k) => k.exerciseId === eigeneUebung)!.hauptmuskeln).toEqual([]);
  });

  it("Cardiogeraet liefert Kandidat mit baustein cardio", () => {
    expect(alle.find((k) => k.machineId === cardioGeraet && k.exerciseId === cardioUebung)).toMatchObject({
      baustein: "cardio",
    });
  });

  it("Reihenfolge ist deterministisch", async () => {
    const nochmal = await ladeKandidaten(admin, studio);
    expect(nochmal).toEqual(alle);
    const sortiert = [...alle].sort(
      (a, b) => a.exerciseId.localeCompare(b.exerciseId) || a.machineId.localeCompare(b.machineId),
    );
    expect(alle).toEqual(sortiert);
  });
});
