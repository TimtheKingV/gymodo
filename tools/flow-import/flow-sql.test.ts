import { readFileSync } from "node:fs";
import { join } from "node:path";
import { flowDauerS } from "@fitretro/domain";
import { describe, expect, it } from "vitest";
import { pruefeFlowEntwurf, type FlowEntwurf } from "./entwurf";
import { flowZuSql } from "./flow-sql";

const STUDIO = "11111111-2222-4333-8444-555555555555";

function entwurf(): FlowEntwurf {
  return {
    key: "test-flow",
    titel: "Test Flow",
    beschreibung: null,
    level: "mittel",
    quelle: { url: "https://www.youtube.com/watch?v=abc", kanal: "Kanal" },
    schritte: [
      { name: "Farmer's Walk", beschreibung: "Gehen mit Gewicht.", workS: 40, restS: 20, istWarmup: true },
      { name: "Plank", beschreibung: null, workS: 40, restS: 0, istWarmup: false },
    ],
  };
}

describe("flowZuSql", () => {
  it("erzeugt eine Transaktion mit Upsert und je einem Insert pro Schritt ab Position 1", () => {
    const sql = flowZuSql(entwurf(), STUDIO);
    expect(sql).toMatch(/^begin;/);
    expect(sql.trimEnd()).toMatch(/commit;$/);
    expect(sql).toContain("on conflict (studio_id, key) do update set");
    expect(sql).toContain("delete from public.flow_steps");
    const inserts = sql.match(/insert into public\.flow_steps/g) ?? [];
    expect(inserts).toHaveLength(2);
    expect(sql).toMatch(/,\s*1,\s*'Farmer''s Walk'/);
    expect(sql).toMatch(/,\s*2,\s*'Plank'/);
  });

  it("maskiert Hochkommata", () => {
    expect(flowZuSql(entwurf(), STUDIO)).toContain("'Farmer''s Walk'");
  });

  it("wirft bei unsicheren Schritten", () => {
    const e = entwurf();
    e.schritte[0]!.unsicher = true;
    expect(() => flowZuSql(e, STUDIO)).toThrow(/unsicher/);
  });

  it("wirft bei ungueltiger Studio-ID", () => {
    expect(() => flowZuSql(entwurf(), "x'; drop table flows;--")).toThrow(/UUID/);
  });

  it("ist deterministisch", () => {
    expect(flowZuSql(entwurf(), STUDIO)).toBe(flowZuSql(entwurf(), STUDIO));
  });
});

describe("flows/hiit-20-min.json", () => {
  const roh: unknown = JSON.parse(readFileSync(join(__dirname, "flows", "hiit-20-min.json"), "utf8"));

  it("besteht die Entwurfspruefung mit 20 Schritten, 3 Warm-ups und 1180 s", () => {
    const e = pruefeFlowEntwurf(roh);
    expect(e.schritte).toHaveLength(20);
    expect(e.schritte.filter((s) => s.istWarmup)).toHaveLength(3);
    expect(flowDauerS(e.schritte)).toBe(1180);
  });

  it("markiert genau Schritt 7 und 14 als unsicher", () => {
    const e = pruefeFlowEntwurf(roh);
    const pos = e.schritte.flatMap((s, i) => (s.unsicher ? [i + 1] : []));
    expect(pos).toEqual([7, 14]);
  });
});
