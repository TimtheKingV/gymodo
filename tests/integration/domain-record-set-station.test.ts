import { beforeAll, describe, expect, it } from "vitest";
import { recordSet } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, Abschnitt 8.1:
// ein Satz haengt an einem Geraet ODER an einem Geraetetyp. Ohne Studio
// laeuft er im Gymtavo-Studio (Freies Training).
const GYMTAVO = "00000000-0000-4000-8000-000000000001";
const kennung = crypto.randomUUID();

let ohneStudioEmail: string;
let mitgliedEmail: string;
let studioA: string;
let studioB: string;
let typ: string;
let katalogUebung: string;
let maschineA: string;
let modellB: string;
let uebungB: string;

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: `Station A ${kennung}` }, { name: `Station B ${kennung}` }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  ohneStudioEmail = uniqueEmail("station-ohne");
  mitgliedEmail = uniqueEmail("station-mitglied");
  await createTestUser(ohneStudioEmail);
  const mitgliedId = await createTestUser(mitgliedEmail);
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studioA, user_id: mitgliedId, role: "member" });
  if (rolleError) throw rolleError;

  const { data: modelle, error: modellError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: GYMTAVO, name: `Kurzhantel ${kennung}`, load_step: 1, load_min: 1 },
      { studio_id: studioA, name: `Schraegbank ${kennung}`, load_step: 2.5, load_min: 0 },
      { studio_id: studioB, name: `Fremdbank ${kennung}`, load_step: 2.5, load_min: 0 },
    ])
    .select("id");
  if (modellError) throw modellError;
  typ = modelle[0]!.id;
  modellB = modelle[2]!.id;

  const { data: maschine, error: maschineError } = await admin
    .from("machines")
    .insert({ studio_id: studioA, equipment_model_id: modelle[1]!.id, label: "S1" })
    .select("id")
    .single();
  if (maschineError) throw maschineError;
  maschineA = maschine.id;

  const { data: uebungen, error: uebungError } = await admin
    .from("exercises")
    .insert([
      { studio_id: GYMTAVO, name: `Schraegbankdruecken KH ${kennung}`, target_min: 8, target_max: 12 },
      { studio_id: studioB, name: `Fremduebung ${kennung}`, target_min: 8, target_max: 12 },
    ])
    .select("id");
  if (uebungError) throw uebungError;
  katalogUebung = uebungen[0]!.id;
  uebungB = uebungen[1]!.id;
});

function satz(overrides: Record<string, unknown>) {
  return {
    sessionId: crypto.randomUUID(),
    setId: crypto.randomUUID(),
    exerciseId: katalogUebung,
    setIndex: 1,
    load: 16,
    volume: 10,
    ...overrides,
  };
}

describe("recordSet -- Station", () => {
  it("speichert ohne Studio im Freien Training am Gymtavo-Typ", async () => {
    const client = await userClient(ohneStudioEmail);

    const gespeichert = await recordSet(client, satz({ equipmentModelId: typ }));

    expect(gespeichert).toMatchObject({
      studioId: GYMTAVO,
      machineId: null,
      equipmentModelId: typ,
      load: 16,
    });
  });

  it("speichert im eigenen Studio am Gymtavo-Typ ohne Geraet", async () => {
    const client = await userClient(mitgliedEmail);

    const gespeichert = await recordSet(
      client,
      satz({ equipmentModelId: typ, studioId: studioA }),
    );

    expect(gespeichert).toMatchObject({ studioId: studioA, machineId: null, equipmentModelId: typ });
  });

  it("speichert am Studio-Geraet eine Gymtavo-Uebung", async () => {
    const client = await userClient(mitgliedEmail);

    const gespeichert = await recordSet(client, satz({ machineId: maschineA }));

    expect(gespeichert).toMatchObject({ studioId: studioA, machineId: maschineA });
    expect(gespeichert.equipmentModelId).toBeTruthy();
  });

  it("weist ein fremdes Studio zurueck, ohne es zu verraten", async () => {
    const client = await userClient(mitgliedEmail);

    await expect(
      recordSet(client, satz({ equipmentModelId: typ, studioId: studioB })),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist den Geraetetyp eines fremden Studios zurueck", async () => {
    const client = await userClient(mitgliedEmail);

    await expect(
      recordSet(client, satz({ equipmentModelId: modellB, studioId: studioA })),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist die Uebung eines dritten Studios zurueck", async () => {
    const client = await userClient(ohneStudioEmail);

    await expect(
      recordSet(client, satz({ equipmentModelId: typ, exerciseId: uebungB })),
    ).rejects.toMatchObject({ code: "not_found" });
  });
});
