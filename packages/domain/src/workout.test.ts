import { describe, expect, it } from "vitest";
import { recordSetInputSchema } from "./workout.js";

const basis = {
  sessionId: "11111111-1111-4111-8111-111111111111",
  setId: "22222222-2222-4222-8222-222222222222",
  machineId: "33333333-3333-4333-8333-333333333333",
  exerciseId: "44444444-4444-4444-8444-444444444444",
  setIndex: 1,
  weightKg: 80,
  reps: 10,
};

describe("recordSetInputSchema", () => {
  it("nimmt den Beginn der Einheit an", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis,
      sessionStartedAt: "2026-09-15T16:04:00.000Z",
      performedAt: "2026-09-15T16:14:00.000Z",
    });
    expect(ergebnis.success).toBe(true);
  });

  // Ein Beginn nach dem Satz waere eine negative Dauer auf Home.
  it("weist einen Beginn nach dem Satz ab", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis,
      sessionStartedAt: "2026-09-15T16:20:00.000Z",
      performedAt: "2026-09-15T16:14:00.000Z",
    });
    expect(ergebnis.success).toBe(false);
  });
});
