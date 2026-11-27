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

describe("flowZuSql mit uebung", () => {
  const KATALOG = "00000000-0000-4000-8000-000000000001";

  function mitUebung(): FlowEntwurf {
    const e = entwurf();
    e.schritte[1]!.uebung = "bw_pushup";
    return e;
  }

  it("ohne uebung entsteht kein exercise_id und keine Sicherung", () => {
    const sql = flowZuSql(entwurf(), STUDIO);
    expect(sql).not.toContain("exercise_id");
    expect(sql).not.toContain("raise exception");
  });

  it("loest den Schluessel im Katalogstudio auf, unabhaengig vom Ziel-Studio", () => {
    const sql = flowZuSql(mitUebung(), STUDIO);
    expect(sql).toContain("exercise_id");
    expect(sql).toContain(
      `(select id from public.exercises where studio_id = '${KATALOG}' and catalog_key = 'bw_pushup')`,
    );
    const inserts = sql.split("insert into public.flow_steps").slice(1);
    expect(inserts[0]).not.toContain("exercise_id");
    expect(inserts[1]).toContain("exercise_id");
  });

  it("bricht die Transaktion ab, wenn nicht jeder Schluessel aufgeloest wurde", () => {
    const sql = flowZuSql(mitUebung(), STUDIO);
    expect(sql).toContain("raise exception");
    expect(sql).toMatch(/<> 1 then/);
    expect(sql.indexOf("raise exception")).toBeLessThan(sql.lastIndexOf("commit;"));
    expect(sql.indexOf("raise exception")).toBeGreaterThan(sql.lastIndexOf("insert into public.flow_steps"));
  });

  it("wirft bei Schluesseln, die der Katalog nicht kennt", () => {
    const e = entwurf();
    e.schritte[1]!.uebung = "bw_gibtsnicht";
    expect(() => flowZuSql(e, STUDIO, new Set(["bw_pushup"]))).toThrow("Unbekannte Katalogschluessel: 2 (bw_gibtsnicht).");
  });

  it("akzeptiert Schluessel, die der Katalog kennt", () => {
    expect(() => flowZuSql(mitUebung(), STUDIO, new Set(["bw_pushup"]))).not.toThrow();
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

  it("enthaelt nach Bestaetigung der Namen (26.11.) keine unsicheren Schritte mehr und laesst sich in SQL umsetzen", () => {
    const e = pruefeFlowEntwurf(roh);
    expect(e.schritte.some((s) => s.unsicher)).toBe(false);
    const sql = flowZuSql(e, STUDIO);
    expect(sql).toContain("Squat-Pulse");
    expect(sql).toContain("Strecksprung");
    expect(sql).not.toContain("Weitsprung mit Bodenberührung");
    expect((sql.match(/insert into public\.flow_steps/g) ?? []).length).toBeGreaterThanOrEqual(1);
  });

  // Flow vereinfacht (27.11.2026): eine Bewegung je Schritt, fuenf Schritte getauscht.
  it("fuehrt in den Schritten 4, 9, 11, 13 und 14 die einfachen Uebungen", () => {
    const e = pruefeFlowEntwurf(roh);
    const tausch = [4, 9, 11, 13, 14].map((n) => [n, e.schritte[n - 1]!.uebung, e.schritte[n - 1]!.name]);
    expect(tausch).toEqual([
      [4, "bw_v_up", "Klappmesser"],
      [9, "bw_back_extension_floor", "Rückenstrecken"],
      [11, "bw_reverse_lunge", "Ausfallschritt rückwärts"],
      [13, "bw_leg_raise_lying", "Beinheben"],
      [14, "bw_squat_jump", "Strecksprung"],
    ]);
    expect(e.schritte.every((s) => s.workS === 40)).toBe(true);
    expect(e.schritte.map((s) => s.restS)).toEqual([...Array(19).fill(20), 0]);
  });

  it("nennt nur Schluessel, die der Katalog kennt", () => {
    const katalog = JSON.parse(readFileSync(join(__dirname, "..", "..", "catalog", "gymtavo.json"), "utf8"));
    const schluessel = new Set<string>(katalog.exercises.map((u: { key: string }) => u.key));
    expect(() => flowZuSql(pruefeFlowEntwurf(roh), STUDIO, schluessel)).not.toThrow();
  });

  // Die Kamera-Schritte (data/koerperbild/flow-zuordnung.json) muessen im Flow vorkommen.
  it("hat in der Flow-Zuordnung der Kamera nur Uebungen des Flows", () => {
    const zuordnung = JSON.parse(
      readFileSync(join(__dirname, "..", "..", "data", "koerperbild", "flow-zuordnung.json"), "utf8"),
    );
    const imFlow = new Set(pruefeFlowEntwurf(roh).schritte.map((s) => s.uebung));
    expect(Object.keys(zuordnung).filter((key) => !imFlow.has(key))).toEqual([]);
  });
});
