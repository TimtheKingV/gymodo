import { beforeAll, describe, expect, it, vi } from "vitest";
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
