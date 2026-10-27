import { beforeAll, describe, expect, it } from "vitest";
import { ladeKandidaten, ladeMerkliste, type Kandidat, type Merkliste } from "@fitretro/domain";
import { createTestUser, serviceClient, uniqueEmail } from "./helpers/clients.js";

// Planuebungen des Gymtavo-Katalogs als Generator-Kandidaten (Plan aus dem Katalog).
// Der echte Katalog ist in Tests nicht geladen; Modelle und Uebungen legt die Datei
// selbst unter dem Katalog-Studio an und prueft auf Enthaltensein (andere Dateien
// legen ebenfalls Katalogmodelle an).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();
const admin = serviceClient();
const KEINE: Merkliste = { nichtVorhanden: [], gefaelltNicht: [] };

let studio: string;
let modellFrueh: string; // sort_order 1
let modellSpaet: string;
let presse: string; // an beiden Modellen, frueh gewinnt
let curl: string; // nur am spaeten Modell
let ohnePlan: string;
let cardio: string;
let alle: Kandidat[];

async function einfuegen<T>(tabelle: string, zeilen: object | object[]): Promise<T[]> {
  const { data, error } = await admin.from(tabelle).insert(zeilen).select("id");
  if (error) throw error;
  return data as T[];
}

const von = (liste: Kandidat[], id: string) => liste.find((k) => k.exerciseId === id);

beforeAll(async () => {
  studio = (await einfuegen<{ id: string }>("studios", { name: `Kandidaten ${kennung}` }))[0]!.id;
  const modelle = await einfuegen<{ id: string }>("equipment_models", [
    { studio_id: GYMTAVO, name: `Presse ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, cardio_werte: [] },
    { studio_id: GYMTAVO, name: `Curl-Station ${kennung}`, category: "kraft", load_unit: "kg", load_step: 5, load_min: 5, cardio_werte: [] },
    { studio_id: GYMTAVO, name: `Crosstrainer ${kennung}`, category: "cardio", load_unit: "level", load_step: 1, load_min: 0, cardio_werte: ["zeit"] },
  ]);
  modellFrueh = modelle[0]!.id;
  modellSpaet = modelle[1]!.id;
  const uebungen = await einfuegen<{ id: string }>("exercises", [
    { studio_id: GYMTAVO, name: `Beinpresse ${kennung}`, muscles: [{ key: "quads", name: "Quadrizeps", role: "primary" }, { key: "glutes", name: "Gesaess", role: "secondary" }], target_min: 8, target_max: 12, plan_baustein: "beine_knie", plan_typ: "mehrgelenk", plan_bereiche: ["knie"] },
    { studio_id: GYMTAVO, name: `Curl ${kennung}`, muscles: [], target_min: 8, target_max: 12, plan_baustein: "arme", plan_typ: "isolation", plan_bereiche: [] },
    { studio_id: GYMTAVO, name: `Ohne Plan ${kennung}`, muscles: [], target_min: 8, target_max: 12, plan_bereiche: [] },
    { studio_id: GYMTAVO, name: `Cross ${kennung}`, muscles: [], target_min: 10, target_max: 20, plan_baustein: "cardio", plan_typ: "mehrgelenk", plan_bereiche: [] },
  ]);
  [presse, curl, ohnePlan, cardio] = uebungen.map((u) => u.id) as [string, string, string, string];
  await einfuegen("equipment_model_exercises", [
    { equipment_model_id: modellFrueh, exercise_id: presse, sort_order: 1 },
    { equipment_model_id: modellSpaet, exercise_id: presse, sort_order: 2 },
    { equipment_model_id: modellSpaet, exercise_id: curl, sort_order: 1 },
    { equipment_model_id: modellFrueh, exercise_id: ohnePlan, sort_order: 2 },
    { equipment_model_id: modelle[2]!.id, exercise_id: cardio, sort_order: 1 },
  ]);
  alle = await ladeKandidaten(admin, KEINE);
});

describe("ladeKandidaten", () => {
  it("liefert einen Kandidaten je Uebung mit dem ersten Katalogmodell", () => {
    expect(alle.filter((k) => k.exerciseId === presse)).toHaveLength(1);
    expect(von(alle, presse)).toMatchObject({
      modelId: modellFrueh,
      baustein: "beine_knie",
      typ: "mehrgelenk",
      bereiche: ["knie"],
      hauptmuskeln: ["quads"],
    });
    expect(von(alle, curl)).toMatchObject({ modelId: modellSpaet, baustein: "arme" });
    expect(von(alle, cardio)).toMatchObject({ baustein: "cardio" });
    expect(von(alle, presse)).not.toHaveProperty("machineId");
    expect(von(alle, presse)).not.toHaveProperty("gefaelltNicht");
  });

  it("ignoriert Uebungen ohne Planfreigabe", () => {
    expect(von(alle, ohnePlan)).toBeUndefined();
  });

  it("laesst nicht_vorhanden am Ort weg", async () => {
    const ohne = await ladeKandidaten(admin, { nichtVorhanden: [presse], gefaelltNicht: [] });
    expect(von(ohne, presse)).toBeUndefined();
    expect(von(ohne, curl)).toBeDefined();
  });

  it("markiert gefaellt_nicht", async () => {
    const markiert = await ladeKandidaten(admin, { nichtVorhanden: [], gefaelltNicht: [curl] });
    expect(von(markiert, curl)).toMatchObject({ gefaelltNicht: true });
    expect(von(markiert, presse)).not.toHaveProperty("gefaelltNicht");
  });

  it("ohne Katalogmodelle: leere Liste", async () => {
    // Das Katalog-Studio ist in der geteilten Testdatenbank nie leer; ein Client, der
    // das Studio findet, aber keine Modelle, belegt den Zweig.
    const leer = {
      from: (tabelle: string) => {
        const kette: Record<string, unknown> = {};
        kette.select = () => kette;
        kette.eq = () => kette;
        kette.maybeSingle = async () => ({ data: { id: GYMTAVO }, error: null });
        kette.then = (ok: (v: unknown) => unknown) => ok({ data: tabelle === "equipment_models" ? [] : null, error: null });
        return kette;
      },
    };
    expect(await ladeKandidaten(leer as never, KEINE)).toEqual([]);
  });

  it("Reihenfolge ist deterministisch, nach exerciseId", async () => {
    const nochmal = await ladeKandidaten(admin, KEINE);
    expect(nochmal).toEqual(alle);
    const ids = alle.map((k) => k.exerciseId);
    expect(ids).toEqual([...ids].sort((a, b) => (a < b ? -1 : a > b ? 1 : 0)));
  });
});

describe("ladeMerkliste", () => {
  it("nicht_vorhanden nur fuer den Ort, gefaellt_nicht ueberall", async () => {
    const userId = await createTestUser(uniqueEmail("merkliste"));
    const anderes = (await einfuegen<{ id: string }>("studios", { name: `Kandidaten 2 ${kennung}` }))[0]!.id;
    const { error } = await admin.from("plan_merkliste").insert([
      { user_id: userId, exercise_id: presse, art: "nicht_vorhanden", studio_id: studio },
      { user_id: userId, exercise_id: curl, art: "nicht_vorhanden", studio_id: anderes },
      { user_id: userId, exercise_id: cardio, art: "gefaellt_nicht" },
    ]);
    if (error) throw error;
    const m = await ladeMerkliste(admin, userId, studio);
    expect(m).toEqual({ nichtVorhanden: [presse], gefaelltNicht: [cardio] });
  });
});
