import { describe, expect, it } from "vitest";
import type { SupabaseClient } from "@supabase/supabase-js";
import {
  gruppeDesModells,
  ladeTrainingsteil,
  letzteSaetze,
  startDesModells,
  uebungAusZeile,
  zaehleBesucheJeGeraet,
} from "./bootstrap.js";

describe("zaehleBesucheJeGeraet", () => {
  it("zaehlt zwei Saetze derselben Session als einen Besuch", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m1", session_id: "s1" },
    ]);

    expect(besuche.get("m1")).toBe(1);
  });

  it("zaehlt zwei Sessions als zwei Besuche", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m1", session_id: "s2" },
    ]);

    expect(besuche.get("m1")).toBe(2);
  });

  it("haelt Geraete auseinander", () => {
    const besuche = zaehleBesucheJeGeraet([
      { machine_id: "m1", session_id: "s1" },
      { machine_id: "m2", session_id: "s1" },
      { machine_id: "m2", session_id: "s2" },
    ]);

    expect(besuche.get("m1")).toBe(1);
    expect(besuche.get("m2")).toBe(2);
  });

  it("liefert fuer ein nie benutztes Geraet keinen Eintrag", () => {
    const besuche = zaehleBesucheJeGeraet([]);

    expect(besuche.get("m1")).toBeUndefined();
  });
});

// Testnotiz 12.10., #3: unter welcher Kachel ein Geraet in der App steht.
describe("gruppeDesModells", () => {
  it("nimmt die eigene Gruppe vor der des Gymtavo-Typs", () => {
    expect(gruppeDesModells({ eigene: "freihantel", katalog: "kabelzug", category: "kraft" })).toBe("freihantel");
  });

  it("erbt die Gruppe des zugeordneten Gymtavo-Typs", () => {
    expect(gruppeDesModells({ eigene: null, katalog: "kabelzug", category: "kraft" })).toBe("kabelzug");
  });

  it("faellt ohne Zuordnung auf die Kategorie zurueck", () => {
    expect(gruppeDesModells({ eigene: null, katalog: null, category: "cardio" })).toBe("cardio");
    expect(gruppeDesModells({ eigene: null, katalog: null, category: "kraft" })).toBe("geraete");
  });
});

// Testnotiz 12.10. abends, #3: wo das Rad ohne Historie steht.
describe("startDesModells", () => {
  it("nimmt den eigenen Startwert vor dem des Gymtavo-Typs", () => {
    expect(startDesModells({ eigener: 30, katalog: { start: 20, einheit: "kg" }, einheit: "kg" })).toBe(30);
  });

  it("erbt den Startwert des Gymtavo-Typs bei gleicher Einheit", () => {
    expect(startDesModells({ eigener: null, katalog: { start: 20, einheit: "kg" }, einheit: "kg" })).toBe(20);
  });

  it("erbt nicht ueber verschiedene Einheiten und ohne Zuordnung", () => {
    expect(startDesModells({ eigener: null, katalog: { start: 20, einheit: "kg" }, einheit: "level" })).toBeNull();
    expect(startDesModells({ eigener: null, katalog: null, einheit: "kg" })).toBeNull();
  });
});

describe("letzteSaetze", () => {
  const satz = (o: {
    machine_id: string | null;
    equipment_model_id?: string;
    exercise_id: string;
    session_id: string;
    performed_at: string;
    load?: number | null;
    volume?: number | null;
    dauer_s?: number | null;
    strecke_m?: number | null;
  }) => ({
    equipment_model_id: "em1",
    load: 10 as number | null,
    secondary_load: null,
    volume: 10 as number | null,
    rir: null,
    dauer_s: null,
    strecke_m: null,
    stufe: null,
    stufenanzahl: null,
    kmh: null,
    steigung_pct: null,
    watt: null,
    kcal: null,
    frequenz: null,
    ...o,
  });

  it("liefert Cardio-Werte am letzten Satz und null bei Kraft", () => {
    const { lastSets } = letzteSaetze([
      satz({ machine_id: "m1", exercise_id: "c1", session_id: "s1", performed_at: "2026-10-14T10:00:00Z", load: null, volume: null, dauer_s: 510, strecke_m: 2000 }),
      satz({ machine_id: "m2", exercise_id: "u1", session_id: "s1", performed_at: "2026-10-14T09:00:00Z" }),
    ]);
    expect(lastSets[0]).toMatchObject({ load: null, volume: null, cardio: { zeit: 510, strecke: 2000 } });
    expect(lastSets[1]).toMatchObject({ load: 10, cardio: null });
  });

  // Testnotiz 14.10., 18:25: die Uebungsliste am Geraet sortiert nach
  // Haeufigkeit -- gezaehlt in Einheiten, nicht in Saetzen.
  it("zaehlt je Geraet und Uebung die Einheiten, nicht die Saetze", () => {
    const { lastSets } = letzteSaetze([
      satz({ machine_id: "m1", exercise_id: "u1", session_id: "s2", performed_at: "2026-10-14T10:02:00Z", load: 30 }),
      satz({ machine_id: "m1", exercise_id: "u1", session_id: "s2", performed_at: "2026-10-14T10:01:00Z" }),
      satz({ machine_id: "m1", exercise_id: "u1", session_id: "s1", performed_at: "2026-10-10T10:00:00Z" }),
      satz({ machine_id: "m1", exercise_id: "u2", session_id: "s1", performed_at: "2026-10-10T09:00:00Z" }),
    ]);

    expect(lastSets).toEqual([
      expect.objectContaining({ machineId: "m1", exerciseId: "u1", load: 30, sessionCount: 2 }),
      expect.objectContaining({ machineId: "m1", exerciseId: "u2", sessionCount: 1 }),
    ]);
  });

  it("zaehlt am Typ getrennt vom Geraet", () => {
    const { lastSets, lastTypeSets } = letzteSaetze([
      satz({ machine_id: null, equipment_model_id: "t1", exercise_id: "u1", session_id: "s1", performed_at: "2026-10-14T10:00:00Z" }),
      satz({ machine_id: "m1", equipment_model_id: "t1", exercise_id: "u1", session_id: "s2", performed_at: "2026-10-13T10:00:00Z" }),
    ]);

    expect(lastTypeSets).toEqual([
      expect.objectContaining({ equipmentModelId: "t1", exerciseId: "u1", sessionCount: 1 }),
    ]);
    expect(lastSets).toEqual([
      expect.objectContaining({ machineId: "m1", exerciseId: "u1", sessionCount: 1 }),
    ]);
  });
});

describe("uebungAusZeile", () => {
  it("reicht die Beschreibung fuer die Einweisung offline durch", () => {
    expect(
      uebungAusZeile({ id: "e1", name: "Face Pull", description: "Ellbogen hoch.", volume_kind: "reps", target_min: 12, target_max: 15 }),
    ).toEqual({ id: "e1", name: "Face Pull", description: "Ellbogen hoch.", volumeKind: "reps", targetMin: 12, targetMax: 15, muscles: [] });
  });

  it("reicht die Muskeln unveraendert durch", () => {
    const muscles = [
      { key: "rear-delt", name: "Hintere Schulter", role: "primary" as const },
      { key: "trapezius", name: "Trapezmuskel", role: "secondary" as const },
    ];
    expect(
      uebungAusZeile({ id: "e1", name: "Face Pull", description: null, volume_kind: "reps", target_min: 12, target_max: 15, muscles }).muscles,
    ).toEqual(muscles);
  });

  it("liefert [] statt null, wenn die Spalte fehlt oder null ist", () => {
    const basis = { id: "e2", name: "X", description: null, volume_kind: "reps" as const, target_min: 8, target_max: 12 };
    expect(uebungAusZeile(basis).muscles).toEqual([]);
    expect(uebungAusZeile({ ...basis, muscles: null }).muscles).toEqual([]);
  });

  it("liefert null ohne gepflegte Beschreibung", () => {
    expect(
      uebungAusZeile({ id: "e2", name: "X", description: null, volume_kind: "reps", target_min: 8, target_max: 12 }).description,
    ).toBeNull();
  });
});

type Antwort = { data: unknown; error: { message: string } | null };

/**
 * Minimaler Supabase-Ersatz: jede Tabelle liefert eine feste Antwort, egal welche Filter
 * die Abfrage setzt. Reicht, um das Rueckfallverhalten ohne Datenbank zu pruefen.
 */
function falscherClient(tabellen: Record<string, Antwort>): SupabaseClient {
  const builder = (antwort: Antwort): unknown => {
    const b: Record<string, unknown> = {};
    for (const m of ["select", "eq", "in", "not", "order", "limit"]) b[m] = () => b;
    b.maybeSingle = () => Promise.resolve(antwort);
    b.single = () => Promise.resolve(antwort);
    b.then = (ok: (a: Antwort) => unknown, fehler: (e: unknown) => unknown) => Promise.resolve(antwort).then(ok, fehler);
    return b;
  };
  return {
    from: (tabelle: string) => builder(tabellen[tabelle] ?? { data: [], error: null }),
  } as unknown as SupabaseClient;
}

const FEHLER = { data: null, error: { message: "timeout" } };
const PLAN = {
  id: "p1", studio_id: "s1", version: 1, status: "aktiv", regel_version: "1.2.0",
  eingabe: { ziel: "muskelaufbau", tage: 3, minuten: 60, fokus: [], erfahrung: "neu", anfaengerBeendet: false,
    beschwerdenBeruecksichtigt: true },
  struktur: "gk_ab", einheiten: [{ key: "A", positionen: [], geschaetzteMinuten: 40 }], gruende: [],
  created_at: "2026-10-01T00:00:00Z", accepted_at: "2026-10-01T00:00:00Z",
};
const GESUND: Record<string, Antwort> = {
  training_profiles: { data: { minutes: 60, experience: "neu", focus: [] }, error: null },
  training_limits: { data: { consent_at: "2026-10-01T00:00:00Z", areas: { knie: "meiden" } }, error: null },
  studio_memberships: { data: [{ studio_id: "s1" }], error: null },
  training_plans: { data: [PLAN], error: null },
  machines: { data: [{ id: "m1", equipment_models: { id: "em1", catalog_model_id: null } }], error: null },
  equipment_model_exercises: {
    data: [
      { equipment_model_id: "em1", exercises: { id: "knie", muscles: [], plan_baustein: "beine_knie", plan_typ: "mehrgelenk", plan_bereiche: ["knie"] } },
      { equipment_model_id: "em1", exercises: { id: "zug", muscles: [], plan_baustein: "ziehen", plan_typ: "mehrgelenk", plan_bereiche: [] } },
    ],
    error: null,
  },
};

describe("ladeTrainingsteil", () => {
  const jetzt = new Date("2026-10-24T12:00:00Z");

  it("liefert Profil und Plan, gemiedene Uebungen fehlen in alternativen", async () => {
    const t = await ladeTrainingsteil(falscherClient(GESUND), "u1", jetzt, () => {});
    expect(t.trainingProfile).toEqual({ minutes: 60, experience: "neu", focus: [] });
    expect(t.plans).toHaveLength(1);
    expect(t.plans[0]!.alternativen).toEqual({ ziehen: [{ exerciseId: "zug", machineId: "m1" }] });
  });

  it("Beschwerden nicht lesbar: plans [] statt ungefilterter alternativen", async () => {
    const meldungen: string[] = [];
    const t = await ladeTrainingsteil(
      falscherClient({ ...GESUND, training_limits: FEHLER }), "u1", jetzt, (n) => meldungen.push(n),
    );
    expect(t.plans).toEqual([]);
    expect(t.trainingProfile).not.toBeNull();
    expect(meldungen).toHaveLength(1);
    expect(meldungen[0]).not.toMatch(/knie|meiden|vorsichtig/);
  });

  for (const tabelle of ["studio_memberships", "training_plans", "workout_sessions", "machines"]) {
    it(`Fehler in ${tabelle}: plans [] und kein Wurf`, async () => {
      const t = await ladeTrainingsteil(falscherClient({ ...GESUND, [tabelle]: FEHLER }), "u1", jetzt, () => {});
      expect(t.plans).toEqual([]);
      expect(t.trainingProfile).not.toBeNull();
    });
  }

  it("volle Seite Statuszeilen (moeglich abgeschnitten): plans [] statt zu wenig gezaehlt", async () => {
    const meldungen: string[] = [];
    const t = await ladeTrainingsteil(
      falscherClient({
        ...GESUND,
        workout_sessions: {
          data: [{ id: "x1", plan_einheit_key: "A", started_at: "2026-10-20T10:00:00Z", completed_at: "2026-10-20T11:00:00Z" }],
          error: null,
        },
        session_plan_status: { data: Array.from({ length: 1000 }, () => ({ session_id: "x1", status: "erledigt" })), error: null },
      }),
      "u1", jetzt, (n) => meldungen.push(n),
    );
    expect(t.plans).toEqual([]);
    // Davor koennen Meldungen des Nachholens der Zielgewichte stehen (die werfen nie).
    expect(meldungen.some((n) => n.includes("Zu viele Statuszeilen"))).toBe(true);
  });

  it("Profil nicht lesbar: trainingProfile null, Plaene bleiben", async () => {
    const t = await ladeTrainingsteil(falscherClient({ ...GESUND, training_profiles: FEHLER }), "u1", jetzt, () => {});
    expect(t.trainingProfile).toBeNull();
    expect(t.plans).toHaveLength(1);
    expect(t.plans[0]!.anfaengerUebergang).toBe(false);
  });
});
