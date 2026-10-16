import { beforeAll, describe, expect, it } from "vitest";
import { serviceClient } from "./helpers/clients.js";

// Migration 0056: exercises.muscles ist eine Liste, bestehende Uebungen
// bekommen die leere Liste, ein Objekt wird abgelehnt.
const kennung = crypto.randomUUID();
let studioId: string;

beforeAll(async () => {
  const { data, error } = await serviceClient()
    .from("studios").insert({ name: `Muskeln ${kennung}` }).select("id").single();
  if (error) throw error;
  studioId = data.id;
});

describe("exercises.muscles", () => {
  it("ist fuer eine Uebung ohne Angabe eine leere Liste", async () => {
    const { data, error } = await serviceClient()
      .from("exercises")
      .insert({ studio_id: studioId, name: `Leer ${kennung}`, volume_kind: "reps", target_min: 8, target_max: 12 })
      .select("muscles").single();
    expect(error).toBeNull();
    expect(data?.muscles).toEqual([]);
  });

  it("nimmt eine Liste an", async () => {
    const muscles = [{ key: "brust", name: "Brust", role: "primary" }];
    const { data, error } = await serviceClient()
      .from("exercises")
      .insert({ studio_id: studioId, name: `Liste ${kennung}`, volume_kind: "reps", target_min: 8, target_max: 12, muscles })
      .select("muscles").single();
    expect(error).toBeNull();
    expect(data?.muscles).toEqual(muscles);
  });

  it("lehnt ein Objekt statt einer Liste ab", async () => {
    const { error } = await serviceClient()
      .from("exercises")
      .insert({ studio_id: studioId, name: `Objekt ${kennung}`, volume_kind: "reps", target_min: 8, target_max: 12, muscles: { key: "brust" } });
    expect(error?.code).toBe("23514");
  });
});
