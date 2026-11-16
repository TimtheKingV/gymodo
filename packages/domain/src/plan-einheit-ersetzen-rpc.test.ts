import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import { ersetzePlanEinheit } from "./trainingsplan.js";

const UEBUNG = "11111111-1111-4111-8111-111111111111";
const MODELL = "22222222-2222-4222-8222-222222222222";

function pos(key: string) {
  return {
    key, baustein: "druecken", rolle: "pflicht", exerciseId: UEBUNG, modelId: MODELL, typ: "mehrgelenk",
    saetze: 3, wdhVon: 8, wdhBis: 12, reserveVon: 1, reserveBis: 3, pauseSek: 90, aufwaermsatz: false,
    dauerMin: null, hauptmuskeln: ["brust"],
  };
}

/** Minimaler Client: liest Plan und Uebungen, die RPC liefert den vorgegebenen Fehler. */
function client(rpcFehler: { code: string; message: string }): SupabaseClient {
  const lesen = (daten: unknown) => {
    const kette: Record<string, unknown> = {};
    kette.select = () => kette;
    kette.eq = () => kette;
    kette.in = () => Promise.resolve({ data: daten, error: null });
    kette.maybeSingle = () => Promise.resolve({ data: daten, error: null });
    return kette;
  };
  return {
    from: (tabelle: string) =>
      tabelle === "training_plans"
        ? lesen({
            einheiten: [{ key: "A", name: "A", geschaetzteMinuten: 30, positionen: [pos("p1")] }],
            eingabe: { ziel: "muskelaufbau", erfahrung: "fortgeschritten", minuten: 60, anfaengerBeendet: true },
          })
        : lesen([{ id: UEBUNG, plan_baustein: "druecken", plan_typ: "mehrgelenk", muscles: [{ key: "brust", role: "primary" }] }]),
    rpc: () => ({ single: () => Promise.resolve({ data: null, error: rpcFehler }) }),
  } as unknown as SupabaseClient;
}

describe("ersetzePlanEinheit RPC-Fehler", () => {
  const eingabe = { einheitKey: "A", positionen: [{ key: "p1", exerciseId: UEBUNG, modelId: MODELL }] };
  const faelle: Array<[string, string]> = [
    ["plan_nicht_annehmbar", "conflict"],
    ["plan_ungueltig", "validation_failed"],
    ["modell_ungueltig", "validation_failed"],
    ["uebung_ohne_planmerkmale", "uebung_ohne_planmerkmale"],
    ["uebung_gemieden", "uebung_gemieden"],
  ];
  it.each(faelle)("%s -> %s", async (nachricht, code) => {
    await expect(
      ersetzePlanEinheit(client({ code: "P0001", message: nachricht }), "u", "p", eingabe),
    ).rejects.toMatchObject({ code });
  });
  it("23505 -> conflict", async () => {
    await expect(ersetzePlanEinheit(client({ code: "23505", message: "dup" }), "u", "p", eingabe)).rejects.toMatchObject({
      code: "conflict",
    });
  });
});
