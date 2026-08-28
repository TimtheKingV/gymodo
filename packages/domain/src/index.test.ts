import { describe, expect, it } from "vitest";
import { DOMAIN_PACKAGE_NAME } from "./index.js";

describe("domain package", () => {
  it("ist eingebunden und auflösbar", () => {
    expect(DOMAIN_PACKAGE_NAME).toBe("@fitretro/domain");
  });
});
