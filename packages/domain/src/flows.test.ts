import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { flowDauerS, listFlows, pruefeFlowRun, type FlowRunEingabe } from "./flows.js";

const basis: FlowRunEingabe = {
  id: "11111111-1111-4111-8111-111111111111",
  flowId: "22222222-2222-4222-8222-222222222222",
  startedAt: "2026-11-26T10:00:00Z",
  endedAt: "2026-11-26T10:20:00Z",
  lastStep: 20,
  outcome: "finished",
};

describe("flowDauerS", () => {
  it("summiert Arbeit und Pause aller Schritte", () => {
    expect(flowDauerS([{ workS: 40, restS: 20 }, { workS: 40, restS: 0 }])).toBe(100);
  });
  it("ignoriert die Pause des letzten Schritts", () => {
    expect(flowDauerS([{ workS: 40, restS: 20 }, { workS: 40, restS: 20 }])).toBe(100);
    expect(flowDauerS([{ workS: 30, restS: 99 }])).toBe(30);
  });
  it("ist 0 ohne Schritte", () => {
    expect(flowDauerS([])).toBe(0);
  });
});

describe("pruefeFlowRun", () => {
  it("nimmt einen beendeten Lauf", () => {
    expect(pruefeFlowRun(basis, 20)).toEqual(basis);
  });
  it("nimmt Bruchsekunden und Offset", () => {
    const run = { ...basis, startedAt: "2026-11-26T11:00:00.250+01:00", endedAt: "2026-11-26T10:20:00.5Z" };
    expect(pruefeFlowRun(run, 20)).toEqual(run);
  });
  it("nimmt einen Abbruch bei Schritt 3 von 20", () => {
    const run = { ...basis, outcome: "aborted" as const, lastStep: 3 };
    expect(pruefeFlowRun(run, 20)).toEqual(run);
  });
  it.each([
    ["lastStep 0", { lastStep: 0, outcome: "aborted" as const }],
    ["lastStep ueber Schrittzahl", { lastStep: 21, outcome: "aborted" as const }],
    ["Ende vor Start", { endedAt: "2026-11-26T09:00:00Z" }],
    ["finished mit lastStep ungleich Schrittzahl", { lastStep: 19 }],
    ["id keine UUID", { id: "abc" }],
    ["flowId keine UUID", { flowId: "nicht-uuid" }],
    ["Datum ohne Zeitzone", { startedAt: "2026-11-26T10:00:00" }],
    ["Datum nur Tag", { startedAt: "2026-11-26" }],
    ["Datum lose formatiert", { endedAt: "Nov 26 2026 10:20" }],
    ["30. Februar", { startedAt: "2026-02-30T10:00:00Z" }],
    ["Stunde 25", { endedAt: "2026-11-26T25:00:00Z" }],
  ])("weist ab: %s", (_n, abw) => {
    expect(() => pruefeFlowRun({ ...basis, ...abw }, 20)).toThrow(expect.objectContaining({ code: "validation_failed" }));
  });
});

describe("listFlows", () => {
  it("bildet exercise_id auf exerciseId ab (null bleibt null) und fragt die Spalte ab", async () => {
    let auswahl = "";
    const client = {
      from: () => ({
        select: (spalten: string) => {
          auswahl = spalten;
          return {
            order: async () => ({
              data: [
                {
                  id: "f1",
                  studio_id: "s1",
                  key: "k",
                  titel: "T",
                  beschreibung: null,
                  level: null,
                  flow_steps: [
                    { position: 2, name: "B", beschreibung: null, work_s: 30, rest_s: 0, is_warmup: false, exercise_id: null },
                    { position: 1, name: "A", beschreibung: null, work_s: 30, rest_s: 10, is_warmup: false, exercise_id: "u1" },
                  ],
                },
              ],
              error: null,
            }),
          };
        },
      }),
    } as unknown as SupabaseClient;
    const [flow] = await listFlows(client);
    expect(auswahl).toContain("exercise_id");
    expect(flow!.schritte.map((s) => s.exerciseId)).toEqual(["u1", null]);
  });
});
