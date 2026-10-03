import { describe, expect, it } from "vitest";
import {
  DOMAIN_PACKAGE_NAME,
  PROGRESSION_ALGO_VERSION,
  suggestNextLoad,
} from "./index.js";

describe("domain package", () => {
  it("ist eingebunden und auflösbar", () => {
    expect(DOMAIN_PACKAGE_NAME).toBe("@fitretro/domain");
  });

  it("stellt die Progressionsregel ueber den Paketeinstieg bereit", () => {
    expect(PROGRESSION_ALGO_VERSION).toBe("2.0.0");
    expect(
      suggestNextLoad({
        targetMin: 8,
        targetMax: 12,
        loadStep: 2.5,
        loadMin: 5,
        loadMax: 150,
        history: [],
      }).reasonCode,
    ).toBe("kein_verlauf");
  });
});
