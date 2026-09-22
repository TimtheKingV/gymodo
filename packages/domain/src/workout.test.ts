import { describe, expect, it } from "vitest";
import { recordSetInputSchema } from "./workout.js";

const basis = {
  sessionId: "11111111-1111-4111-8111-111111111111",
  setId: "22222222-2222-4222-8222-222222222222",
  machineId: "33333333-3333-4333-8333-333333333333",
  exerciseId: "44444444-4444-4444-8444-444444444444",
  setIndex: 1,
  load: 80,
  volume: 10,
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

  it("nimmt die Nebenbelastung an und laesst sie sonst weg", () => {
    const mit = recordSetInputSchema.safeParse({ ...basis, secondaryLoad: 6 });
    const ohne = recordSetInputSchema.safeParse(basis);
    expect(mit.success && mit.data.secondaryLoad).toBe(6);
    expect(ohne.success && ohne.data.secondaryLoad).toBeUndefined();
  });

  // Der Alias faellt mit dem uebernaechsten Release (Cardio-Spec 5.1). Wer
  // ihn entfernt, entfernt diesen Test -- und prueft vorher, dass keine
  // App mehr im Umlauf ist, die weightKg/reps schickt.
  it("nimmt weightKg und reps fuer einen Release als Aliase an", () => {
    const { load, volume, ...alt } = basis;
    const ergebnis = recordSetInputSchema.safeParse({ ...alt, weightKg: load, reps: volume });
    expect(ergebnis.success).toBe(true);
    if (ergebnis.success) {
      expect(ergebnis.data.load).toBe(80);
      expect(ergebnis.data.volume).toBe(10);
      expect("weightKg" in ergebnis.data).toBe(false);
    }
  });

  it("laesst den neuen Namen gewinnen, wenn beide geschickt werden", () => {
    const ergebnis = recordSetInputSchema.safeParse({ ...basis, weightKg: 999, reps: 99 });
    expect(ergebnis.success && ergebnis.data.load).toBe(80);
    expect(ergebnis.success && ergebnis.data.volume).toBe(10);
  });

  it("laesst bis zur Datenbankschranke zu -- die Grenze je Art prueft recordSet", () => {
    expect(recordSetInputSchema.safeParse({ ...basis, volume: 100000 }).success).toBe(true);
    expect(recordSetInputSchema.safeParse({ ...basis, volume: 100001 }).success).toBe(false);
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
