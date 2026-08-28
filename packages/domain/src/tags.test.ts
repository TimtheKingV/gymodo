import { describe, expect, it } from "vitest";
import { createTagToken, hashTagToken, isValidTagToken } from "./tags.js";

describe("createTagToken", () => {
  it("erzeugt 22 Zeichen base64url", () => {
    const token = createTagToken();
    expect(token).toHaveLength(22);
    expect(token).toMatch(/^[A-Za-z0-9_-]{22}$/);
  });

  it("erzeugt bei 1000 Aufrufen keine Kollision", () => {
    const tokens = new Set(
      Array.from({ length: 1000 }, () => createTagToken()),
    );
    expect(tokens.size).toBe(1000);
  });
});

describe("hashTagToken", () => {
  it("liefert 64 Zeichen Hex", () => {
    expect(hashTagToken("abc")).toMatch(/^[0-9a-f]{64}$/);
  });

  it("ist deterministisch", () => {
    expect(hashTagToken("abc")).toBe(hashTagToken("abc"));
  });

  it("liefert fuer verschiedene Eingaben verschiedene Hashes", () => {
    expect(hashTagToken("abc")).not.toBe(hashTagToken("abd"));
  });

  it("enthaelt den Token nicht im Ergebnis", () => {
    const token = createTagToken();
    expect(hashTagToken(token)).not.toContain(token);
  });
});

describe("isValidTagToken", () => {
  it("akzeptiert einen erzeugten Token", () => {
    expect(isValidTagToken(createTagToken())).toBe(true);
  });

  it.each([
    ["zu kurz", "abc"],
    ["zu lang", "a".repeat(23)],
    ["unerlaubtes Zeichen", "a".repeat(21) + "/"],
    ["leer", ""],
    ["Pfadanteil", "../".padEnd(22, "a")],
  ])("weist %s zurueck", (_name, value) => {
    expect(isValidTagToken(value)).toBe(false);
  });
});
