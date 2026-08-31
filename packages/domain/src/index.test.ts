import { describe, expect, it } from "vitest";
import {
  DOMAIN_PACKAGE_NAME,
  PROGRESSION_ALGO_VERSION,
  suggestNextWeight,
} from "./index.js";

describe("domain package", () => {
  it("ist eingebunden und auflösbar", () => {
    expect(DOMAIN_PACKAGE_NAME).toBe("@fitretro/domain");
  });

  it("stellt die Progressionsregel ueber den Paketeinstieg bereit", () => {
    expect(PROGRESSION_ALGO_VERSION).toBe("1.0.0");
    expect(
      suggestNextWeight({
        targetRepsMin: 8,
        targetRepsMax: 12,
        weightStepKg: 2.5,
        minWeightKg: 5,
        maxWeightKg: 150,
        history: [],
      }).reasonCode,
    ).toBe("kein_verlauf");
  });
});
