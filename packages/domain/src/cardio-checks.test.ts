import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it } from "vitest";
import { deleteCardioCheck, listCardioChecks, pruefeTag, setCardioCheck } from "./cardio-checks.js";

// Die Format- und Zukunftspruefung passiert vor jedem Datenbankzugriff; der Client darf nie benutzt werden.
const keinZugriff = new Proxy({}, { get: () => { throw new Error("kein Datenbankzugriff erwartet"); } }) as unknown as SupabaseClient;
const U = "00000000-0000-0000-0000-000000000001";

describe("pruefeTag", () => {
  it("nimmt einen echten Kalendertag", () => {
    expect(pruefeTag("2026-10-28")).toBe("2026-10-28");
  });
  it.each(["2026-1-5", "28.10.2026", "2026-02-30", "2026-13-01", "", "2026-10-28T00:00:00Z"])("weist %j ab", (roh) => {
    expect(() => pruefeTag(roh)).toThrow(expect.objectContaining({ code: "validation_failed" }));
  });
});

describe("setCardioCheck", () => {
  it("weist einen Tag nach heute ab", async () => {
    await expect(setCardioCheck(keinZugriff, U, "2026-10-29", "2026-10-28")).rejects.toMatchObject({ code: "validation_failed" });
  });
  it("weist ein ungueltiges Format ab", async () => {
    await expect(setCardioCheck(keinZugriff, U, "morgen", "2026-10-28")).rejects.toMatchObject({ code: "validation_failed" });
    await expect(setCardioCheck(keinZugriff, U, "2026-10-28", "heute")).rejects.toMatchObject({ code: "validation_failed" });
  });
});

describe("deleteCardioCheck und listCardioChecks", () => {
  it("pruefen das Format", async () => {
    await expect(deleteCardioCheck(keinZugriff, U, "x")).rejects.toMatchObject({ code: "validation_failed" });
    await expect(listCardioChecks(keinZugriff, U, "2026-10-01", "x")).rejects.toMatchObject({ code: "validation_failed" });
    await expect(listCardioChecks(keinZugriff, U, "2026-10-10", "2026-10-01")).rejects.toMatchObject({ code: "validation_failed" });
  });
});
