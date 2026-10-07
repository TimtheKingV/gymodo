import { beforeAll, describe, expect, it } from "vitest";
import { getBootstrap, getProgress, getSessions } from "@fitretro/domain";
import {
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

// Spec 2026-10-06-gymtavo-katalog-offener-zugang-design.md, E5: der Verlauf
// gehoert dem Nutzer. Nach dem Austritt sind Geraet und Uebung des Studios
// nicht mehr lesbar -- Verlauf und Fortschritt muessen ihre Namen trotzdem
// zeigen und duerfen nicht an der fehlenden Einbettung scheitern.

let ehemaligEmail: string;
let ohneStudioEmail: string;
let maschine: string;
let uebung: string;
const kennung = crypto.randomUUID();

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studio, error: studioError } = await admin
    .from("studios")
    .insert({ name: `Austritt Studio ${kennung}` })
    .select("id")
    .single();
  if (studioError) throw studioError;

  ehemaligEmail = uniqueEmail("verlauf-ehemalig");
  ohneStudioEmail = uniqueEmail("verlauf-ohne-studio");
  const ehemaligId = await createTestUser(ehemaligEmail);
  await createTestUser(ohneStudioEmail);
  const { error: rolleError } = await admin
    .from("studio_memberships")
    .insert({ studio_id: studio.id, user_id: ehemaligId, role: "member" });
  if (rolleError) throw rolleError;

  const { data: modell, error: modellError } = await admin
    .from("equipment_models")
    .insert({ studio_id: studio.id, name: "Latzug", load_step: 5 })
    .select("id")
    .single();
  if (modellError) throw modellError;

  const { data: geraet, error: geraetError } = await admin
    .from("machines")
    .insert({ studio_id: studio.id, equipment_model_id: modell.id, label: "L3" })
    .select("id")
    .single();
  if (geraetError) throw geraetError;
  maschine = geraet.id;

  const { data: neueUebung, error: uebungError } = await admin
    .from("exercises")
    .insert({ studio_id: studio.id, name: `Latziehen breit ${kennung}`, target_min: 8, target_max: 12 })
    .select("id")
    .single();
  if (uebungError) throw uebungError;
  uebung = neueUebung.id;

  const sessionId = crypto.randomUUID();
  const { error: sessionError } = await admin.from("workout_sessions").insert({
    id: sessionId,
    studio_id: studio.id,
    user_id: ehemaligId,
    started_at: new Date(Date.now() - 60 * 60 * 1000).toISOString(),
    completed_at: new Date(Date.now() - 30 * 60 * 1000).toISOString(),
    completed_reason: "manual",
  });
  if (sessionError) throw sessionError;

  const { error: satzError } = await admin.from("workout_sets").insert({
    id: crypto.randomUUID(),
    studio_id: studio.id,
    user_id: ehemaligId,
    session_id: sessionId,
    machine_id: maschine,
    exercise_id: uebung,
    set_index: 1,
    performed_at: new Date(Date.now() - 45 * 60 * 1000).toISOString(),
    load: 50,
    volume: 10,
  });
  if (satzError) throw satzError;

  const client = await userClient(ehemaligEmail);
  const { error: austrittError } = await client
    .from("studio_memberships")
    .delete()
    .eq("studio_id", studio.id)
    .eq("user_id", ehemaligId);
  if (austrittError) throw austrittError;
});

describe("Verlauf nach dem Austritt", () => {
  it("getSessions zeigt die Einheit mit Geraet und Uebung", async () => {
    const client = await userClient(ehemaligEmail);

    const { sessions } = await getSessions(client);

    const block = sessions[0]?.blocks[0];
    expect(block).toMatchObject({
      machineId: maschine,
      machineLabel: "L3",
      exerciseId: uebung,
      exerciseName: `Latziehen breit ${kennung}`,
      loadUnit: "kg",
      volumeKind: "reps",
    });
  });

  it("getProgress zeigt die Uebung mit Namen", async () => {
    const client = await userClient(ehemaligEmail);

    const { exercises } = await getProgress(client);

    expect(exercises).toEqual([
      expect.objectContaining({
        exerciseId: uebung,
        exerciseName: `Latziehen breit ${kennung}`,
        machineLabel: "L3",
        loadUnit: "kg",
        currentLoad: 50,
      }),
    ]);
  });
});

describe("Bootstrap und der Gymtavo-Katalog", () => {
  it("ohne Studio meldet der Bootstrap kein Studio", async () => {
    const client = await userClient(ohneStudioEmail);

    const bootstrap = await getBootstrap(client);

    expect(bootstrap.studios).toEqual([]);
  });
});
