import { describe, expect, it } from "vitest";
import { istEinladungsToken } from "./einladungen.js";

describe("istEinladungsToken", () => {
  it("nimmt 64 Hex-Zeichen an, wie create_staff_invite sie erzeugt", () => {
    expect(istEinladungsToken("a".repeat(64))).toBe(true);
    expect(istEinladungsToken("0123456789abcdef".repeat(4))).toBe(true);
  });

  it("weist alles andere ab, bevor die Datenbank gefragt wird", () => {
    expect(istEinladungsToken("")).toBe(false);
    expect(istEinladungsToken("a".repeat(63))).toBe(false);
    expect(istEinladungsToken("A".repeat(64))).toBe(false);
    expect(istEinladungsToken(`${"a".repeat(63)}g`)).toBe(false);
    expect(istEinladungsToken("../../etc")).toBe(false);
  });
});
