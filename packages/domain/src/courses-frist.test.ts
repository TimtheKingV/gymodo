import { describe, expect, it } from "vitest";
import { abmeldenBis } from "./courses.js";

describe("abmeldenBis", () => {
  it("zieht die Frist vom Beginn ab", () => {
    const grenze = abmeldenBis("2026-09-10T18:00:00Z", 2);

    expect(grenze).toBe("2026-09-10T16:00:00.000Z");
  });

  it("bei Frist null ist der Beginn die Grenze", () => {
    expect(abmeldenBis("2026-09-10T18:00:00Z", 0)).toBe(
      "2026-09-10T18:00:00.000Z",
    );
  });

  it("vertraegt eine Frist ueber einen Tag hinaus", () => {
    expect(abmeldenBis("2026-09-10T18:00:00Z", 48)).toBe(
      "2026-09-08T18:00:00.000Z",
    );
  });
});
