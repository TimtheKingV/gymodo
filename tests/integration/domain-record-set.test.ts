import { beforeAll, describe, expect, it } from "vitest";
import { DomainError, recordSet } from "@fitretro/domain";
import {
  anonClient,
  createTestUser,
  serviceClient,
  uniqueEmail,
  userClient,
} from "./helpers/clients.js";

let studioA: string;
let studioB: string;
let memberAEmail: string;
let memberAId: string;
let machineA: string;
let machineB: string;
let laufband: string;
let exerciseA: string;
let exerciseB: string;
let dauerlauf: string;

function newId(): string {
  return crypto.randomUUID();
}

beforeAll(async () => {
  const admin = serviceClient();

  const { data: studios, error: studioError } = await admin
    .from("studios")
    .insert([{ name: "recordSet Studio A" }, { name: "recordSet Studio B" }])
    .select("id");
  if (studioError) throw studioError;
  studioA = studios[0]!.id;
  studioB = studios[1]!.id;

  memberAEmail = uniqueEmail("record-member-a");
  memberAId = await createTestUser(memberAEmail);
  const memberBId = await createTestUser(uniqueEmail("record-member-b"));

  const { error: membershipError } = await admin
    .from("studio_memberships")
    .insert([
      { studio_id: studioA, user_id: memberAId, role: "member" },
      { studio_id: studioB, user_id: memberBId, role: "member" },
    ]);
  if (membershipError) throw membershipError;

  const { data: models, error: modelError } = await admin
    .from("equipment_models")
    .insert([
      { studio_id: studioA, name: "Beinpresse", load_step: 2.5 },
      { studio_id: studioB, name: "Fremdpresse", load_step: 2.5 },
      // Laufband mit Neigung als Nebenbelastung (Cardio-Spec 3.1b).
      {
        studio_id: studioA,
        name: "Laufband",
        category: "cardio",
        load_unit: "kmh",
        load_step: 0.5,
        load_min: 0,
        load_max: 20,
        secondary_unit: "pct",
        secondary_step: 0.5,
        secondary_min: 0,
        secondary_max: 15,
      },
    ])
    .select("id");
  if (modelError) throw modelError;

  const { data: machines, error: machineError } = await admin
    .from("machines")
    .insert([
      { studio_id: studioA, equipment_model_id: models[0]!.id, label: "07" },
      { studio_id: studioB, equipment_model_id: models[1]!.id, label: "99" },
      { studio_id: studioA, equipment_model_id: models[2]!.id, label: "L1" },
    ])
    .select("id");
  if (machineError) throw machineError;
  machineA = machines[0]!.id;
  machineB = machines[1]!.id;
  laufband = machines[2]!.id;

  const { data: exercises, error: exerciseError } = await admin
    .from("exercises")
    .insert([
      {
        studio_id: studioA,
        name: "Beidbeinig",
        target_min: 8,
        target_max: 12,
      },
      {
        studio_id: studioB,
        name: "Fremduebung",
        target_min: 8,
        target_max: 12,
      },
      {
        studio_id: studioA,
        name: "Dauerlauf",
        volume_kind: "seconds",
        target_min: 900,
        target_max: 1200,
      },
    ])
    .select("id");
  if (exerciseError) throw exerciseError;
  exerciseA = exercises[0]!.id;
  exerciseB = exercises[1]!.id;
  dauerlauf = exercises[2]!.id;
});

function payload(overrides: Record<string, unknown> = {}) {
  return {
    sessionId: newId(),
    setId: newId(),
    machineId: machineA,
    exerciseId: exerciseA,
    setIndex: 1,
    load: 80,
    volume: 10,
    ...overrides,
  };
}

describe("recordSet", () => {
  it("legt den Satz an und liefert ihn kanonisch zurueck", async () => {
    const client = await userClient(memberAEmail);
    const input = payload();

    const saved = await recordSet(client, input);

    expect(saved.id).toBe(input.setId);
    expect(saved.load).toBe(80);
    expect(saved.volume).toBe(10);
    expect(saved.setIndex).toBe(1);
  });

  it("legt die Session mit dem ersten Satz an -- einen Start-Endpoint gibt es nicht", async () => {
    const client = await userClient(memberAEmail);
    const input = payload();

    await recordSet(client, input);

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sessions")
      .select("id, user_id, studio_id")
      .eq("id", input.sessionId)
      .single();
    expect(data?.user_id).toBe(memberAId);
    expect(data?.studio_id).toBe(studioA);
  });

  it("uebernimmt den Beginn der Einheit vom Client, und nur beim ersten Satz", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = newId();
    const beginn = "2026-09-15T16:04:00.000Z";

    await recordSet(client, payload({ sessionId, sessionStartedAt: beginn, performedAt: "2026-09-15T16:14:00.000Z" }));
    // Ein zweiter Satz mit anderem Beginn verschiebt nichts (ignoreDuplicates).
    await recordSet(client, payload({ sessionId, setIndex: 2, sessionStartedAt: "2026-09-15T16:30:00.000Z", performedAt: "2026-09-15T16:31:00.000Z" }));

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sessions")
      .select("started_at")
      .eq("id", sessionId)
      .single();
    expect(Date.parse(data!.started_at)).toBe(Date.parse(beginn));
  });

  it("kappt einen Beginn in der Zukunft auf die Serverzeit -- eine vorgehende Client-Uhr darf started_at nicht in die Zukunft schreiben", async () => {
    const client = await userClient(memberAEmail);
    const sessionId = newId();
    const inDerZukunft = new Date(Date.now() + 60 * 60 * 1000).toISOString();

    await recordSet(client, payload({ sessionId, sessionStartedAt: inDerZukunft }));

    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sessions")
      .select("started_at")
      .eq("id", sessionId)
      .single();
    // Toleranz statt exakter Gleichheit: der Server-now() zwischen recordSet
    // und dieser Abfrage liegt ein paar Millisekunden auseinander.
    expect(Date.parse(data!.started_at)).toBeLessThanOrEqual(Date.now());
    expect(Date.parse(data!.started_at)).toBeGreaterThan(Date.now() - 10_000);
  });

  it("leitet das Studio aus dem Geraet ab, statt es vom Client zu glauben", async () => {
    const client = await userClient(memberAEmail);
    const input = payload({ studioId: studioB });

    const saved = await recordSet(client, input);

    expect(saved.studioId).toBe(studioA);
  });

  it("Idempotenz: derselbe Satz zweimal geschickt bleibt eine Zeile", async () => {
    const client = await userClient(memberAEmail);
    const input = payload();

    const first = await recordSet(client, input);
    const second = await recordSet(client, input);

    expect(second).toEqual(first);
    const admin = serviceClient();
    const { data } = await admin
      .from("workout_sets")
      .select("id")
      .eq("id", input.setId);
    expect(data).toHaveLength(1);
  });

  it("nimmt die Problemmeldung als Feld des Satzes entgegen", async () => {
    const client = await userClient(memberAEmail);

    const saved = await recordSet(
      client,
      payload({ problemFlag: true, problemReason: "schmerz" }),
    );

    expect(saved.problemFlag).toBe(true);
    expect(saved.problemReason).toBe("schmerz");
  });

  it("nimmt weightKg und reps fuer einen Release als Aliase an", async () => {
    const client = await userClient(memberAEmail);
    const { load, volume, ...alt } = payload();

    const saved = await recordSet(client, { ...alt, weightKg: load, reps: volume });

    expect(saved.load).toBe(80);
    expect(saved.volume).toBe(10);
    expect(saved.secondaryLoad).toBeNull();
  });

  it("weist eine Nebenbelastung an einem Geraet ohne Nebenbelastung zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(recordSet(client, payload({ secondaryLoad: 6 }))).rejects.toMatchObject({
      code: "validation_failed",
    });
  });

  it("weist einen Umfang ueber der Grenze der Umfangsart zurueck", async () => {
    const client = await userClient(memberAEmail);

    // 1001 Wiederholungen: unter der Datenbankschranke, ueber der fachlichen.
    await expect(recordSet(client, payload({ volume: 1001 }))).rejects.toMatchObject({
      code: "validation_failed",
    });
  });

  describe("am Laufband (Nebenbelastung Pflicht)", () => {
    function laufbandSatz(overrides: Record<string, unknown> = {}) {
      return payload({
        machineId: laufband,
        exerciseId: dauerlauf,
        load: 8.5,
        secondaryLoad: 6,
        volume: 1200,
        ...overrides,
      });
    }

    it("speichert Tempo, Neigung und Sekunden", async () => {
      const client = await userClient(memberAEmail);

      const saved = await recordSet(client, laufbandSatz());

      expect(saved.load).toBe(8.5);
      expect(saved.secondaryLoad).toBe(6);
      expect(saved.volume).toBe(1200);
    });

    it("verlangt die Nebenbelastung", async () => {
      const client = await userClient(memberAEmail);

      await expect(
        recordSet(client, laufbandSatz({ secondaryLoad: undefined })),
      ).rejects.toMatchObject({ code: "validation_failed" });
      await expect(
        recordSet(client, laufbandSatz({ secondaryLoad: null })),
      ).rejects.toMatchObject({ code: "validation_failed" });
    });

    it("rastet die Nebenbelastung auf die Stufen des Modells", async () => {
      const client = await userClient(memberAEmail);

      const saved = await recordSet(client, laufbandSatz({ secondaryLoad: 6.26 }));

      expect(saved.secondaryLoad).toBe(6.5);
    });

    it("klemmt die Nebenbelastung an das Maximum des Modells", async () => {
      const client = await userClient(memberAEmail);

      const saved = await recordSet(client, laufbandSatz({ secondaryLoad: 40 }));

      expect(saved.secondaryLoad).toBe(15);
    });

    it("laesst mehr als die alte Wiederholungsgrenze zu, aber keine vier Stunden", async () => {
      const client = await userClient(memberAEmail);

      const saved = await recordSet(client, laufbandSatz({ volume: 3600 }));
      expect(saved.volume).toBe(3600);

      await expect(
        recordSet(client, laufbandSatz({ volume: 4 * 60 * 60 + 1 })),
      ).rejects.toMatchObject({ code: "validation_failed" });
    });
  });

  it("weist eine Wiederholungszahl von null als Eingabefehler zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(recordSet(client, payload({ volume: 0 }))).rejects.toMatchObject({
      code: "validation_failed",
    });
  });

  it("weist eine Problemursache ohne Kennzeichen zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      recordSet(client, payload({ problemReason: "schmerz" })),
    ).rejects.toBeInstanceOf(DomainError);
  });

  it("weist einen nicht angemeldeten Aufruf zurueck", async () => {
    await expect(recordSet(anonClient(), payload())).rejects.toMatchObject({
      code: "unauthorized",
    });
  });

  it("weist ein Geraet aus einem fremden Studio zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      recordSet(client, payload({ machineId: machineB })),
    ).rejects.toMatchObject({ code: "not_found" });
  });

  it("weist eine Uebung aus einem fremden Studio zurueck", async () => {
    const client = await userClient(memberAEmail);

    await expect(
      recordSet(client, payload({ exerciseId: exerciseB })),
    ).rejects.toBeInstanceOf(DomainError);
  });
});
