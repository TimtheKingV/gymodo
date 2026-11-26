import { describe, expect, it } from "vitest";
import { flowDauerS, pruefeFlowRun, type FlowRunEingabe } from "./flows.js";

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
  it("ist 0 ohne Schritte", () => {
    expect(flowDauerS([])).toBe(0);
  });
});

describe("pruefeFlowRun", () => {
  it("nimmt einen beendeten Lauf", () => {
    expect(pruefeFlowRun(basis, 20)).toEqual(basis);
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
  ])("weist ab: %s", (_n, abw) => {
    expect(() => pruefeFlowRun({ ...basis, ...abw }, 20)).toThrow(expect.objectContaining({ code: "validation_failed" }));
  });
});
