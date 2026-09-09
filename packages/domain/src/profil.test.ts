import { describe, expect, it } from "vitest";
import { DomainError } from "./errors.js";
import { pruefeAnzeigename } from "./profil.js";

describe("pruefeAnzeigename", () => {
  it("nimmt einen gewoehnlichen Vornamen an", () => {
    expect(pruefeAnzeigename({ displayName: "Lena" })).toBe("Lena");
  });

  it("schneidet Leerzeichen ab", () => {
    expect(pruefeAnzeigename({ displayName: "  Lena  " })).toBe("Lena");
  });

  it("weist einen leeren Namen ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "   " })).toThrow(DomainError);
  });

  it("weist einen zu langen Namen ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "L".repeat(61) })).toThrow(DomainError);
  });

  it("weist einen fehlenden Rumpf ab", () => {
    expect(() => pruefeAnzeigename({})).toThrow(DomainError);
  });

  // Der Name steht auf einem Screen, nicht in einem Log --
  // Zeilenumbrueche haetten dort nichts zu suchen.
  it("weist einen Zeilenumbruch ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "Lena\nWagner" })).toThrow(DomainError);
  });
});
