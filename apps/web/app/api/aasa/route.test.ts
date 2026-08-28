import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { GET } from "./route";

beforeAll(() => {
  vi.stubEnv("APPLE_TEAM_ID", "ABCDE12345");
  vi.stubEnv("APPLE_BUNDLE_ID", "de.fitretro.member");
});

describe("apple-app-site-association", () => {
  it("liefert Content-Type application/json", async () => {
    const response = await GET();
    expect(response.headers.get("content-type")).toContain("application/json");
  });

  it("antwortet mit 200 und ohne Redirect", async () => {
    const response = await GET();
    expect(response.status).toBe(200);
    expect(response.headers.get("location")).toBeNull();
  });

  it("enthaelt genau einen applinks-Eintrag mit /t/*", async () => {
    const body = (await (await GET()).json()) as {
      applinks: {
        details: Array<{ appIDs: string[]; components: Array<{ "/": string }> }>;
      };
    };
    expect(body.applinks.details).toHaveLength(1);
    expect(body.applinks.details[0]!.components[0]!["/"]).toBe("/t/*");
  });

  it("nennt die App-ID aus der Umgebung", async () => {
    const body = (await (await GET()).json()) as {
      applinks: { details: Array<{ appIDs: string[] }> };
    };
    expect(body.applinks.details[0]!.appIDs[0]).toMatch(/^[A-Z0-9]{10}\..+/);
  });
});

describe("apple-app-site-association ohne vollstaendige Umgebungsvariablen", () => {
  // Sicherheitsrelevant: ein fehlender Wert darf beim statischen Produktiv-
  // Build (force-static, Task 6) nicht als "undefined.undefined" in eine
  // eingefrorene Datei einfrieren, sondern muss den Build hart scheitern
  // lassen. Nach jedem Testfall auf gueltige Werte zuruecksetzen, damit
  // andere Tests im selben Lauf nicht beeinflusst werden.
  afterEach(() => {
    vi.stubEnv("APPLE_TEAM_ID", "ABCDE12345");
    vi.stubEnv("APPLE_BUNDLE_ID", "de.fitretro.member");
  });

  it("wirft, wenn APPLE_TEAM_ID fehlt", () => {
    vi.stubEnv("APPLE_TEAM_ID", "");
    expect(() => GET()).toThrow();
  });

  it("wirft, wenn APPLE_BUNDLE_ID fehlt", () => {
    vi.stubEnv("APPLE_BUNDLE_ID", "");
    expect(() => GET()).toThrow();
  });
});
