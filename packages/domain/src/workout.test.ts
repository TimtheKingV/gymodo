import { describe, expect, it } from "vitest";
import {
  completeSessionInputSchema,
  recordSetInputSchema,
  REOPEN_FENSTER_MS,
  wiederoeffnenEntscheidung,
} from "./workout.js";

const basis = {
  sessionId: "11111111-1111-4111-8111-111111111111",
  setId: "22222222-2222-4222-8222-222222222222",
  machineId: "33333333-3333-4333-8333-333333333333",
  exerciseId: "44444444-4444-4444-8444-444444444444",
  setIndex: 1,
  load: 80,
  volume: 10,
};

describe("recordSetInputSchema", () => {
  it("nimmt den Beginn der Einheit an", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis,
      sessionStartedAt: "2026-09-15T16:04:00.000Z",
      performedAt: "2026-09-15T16:14:00.000Z",
    });
    expect(ergebnis.success).toBe(true);
  });

  it("nimmt die Nebenbelastung an und laesst sie sonst weg", () => {
    const mit = recordSetInputSchema.safeParse({ ...basis, secondaryLoad: 6 });
    const ohne = recordSetInputSchema.safeParse(basis);
    expect(mit.success && mit.data.secondaryLoad).toBe(6);
    expect(ohne.success && ohne.data.secondaryLoad).toBeUndefined();
  });

  // Der Alias faellt mit dem uebernaechsten Release (Cardio-Spec 5.1). Wer
  // ihn entfernt, entfernt diesen Test -- und prueft vorher, dass keine
  // App mehr im Umlauf ist, die weightKg/reps schickt.
  it("nimmt weightKg und reps fuer einen Release als Aliase an", () => {
    const { load, volume, ...alt } = basis;
    const ergebnis = recordSetInputSchema.safeParse({ ...alt, weightKg: load, reps: volume });
    expect(ergebnis.success).toBe(true);
    if (ergebnis.success) {
      expect(ergebnis.data.load).toBe(80);
      expect(ergebnis.data.volume).toBe(10);
      expect("weightKg" in ergebnis.data).toBe(false);
    }
  });

  it("laesst den neuen Namen gewinnen, wenn beide geschickt werden", () => {
    const ergebnis = recordSetInputSchema.safeParse({ ...basis, weightKg: 999, reps: 99 });
    expect(ergebnis.success && ergebnis.data.load).toBe(80);
    expect(ergebnis.success && ergebnis.data.volume).toBe(10);
  });

  it("laesst bis zur Datenbankschranke zu -- die Grenze je Art prueft recordSet", () => {
    expect(recordSetInputSchema.safeParse({ ...basis, volume: 100000 }).success).toBe(true);
    expect(recordSetInputSchema.safeParse({ ...basis, volume: 100001 }).success).toBe(false);
  });

  // Ein Beginn nach dem Satz waere eine negative Dauer auf Home.
  it("weist einen Beginn nach dem Satz ab", () => {
    const ergebnis = recordSetInputSchema.safeParse({
      ...basis,
      sessionStartedAt: "2026-09-15T16:20:00.000Z",
      performedAt: "2026-09-15T16:14:00.000Z",
    });
    expect(ergebnis.success).toBe(false);
  });
});

describe("recordSetInputSchema -- Station", () => {
  const { machineId: _geraet, ...ohneGeraet } = basis;
  const typ = "55555555-5555-4555-8555-555555555555";
  const studio = "66666666-6666-4666-8666-666666666666";

  it("nimmt einen Geraetetyp statt eines Geraets an, mit und ohne Studio", () => {
    const frei = recordSetInputSchema.safeParse({ ...ohneGeraet, equipmentModelId: typ });
    const imStudio = recordSetInputSchema.safeParse({
      ...ohneGeraet,
      equipmentModelId: typ,
      studioId: studio,
    });
    expect(frei.success).toBe(true);
    expect(imStudio.success).toBe(true);
  });

  it("weist Geraet und Geraetetyp zugleich ab", () => {
    const ergebnis = recordSetInputSchema.safeParse({ ...basis, equipmentModelId: typ });
    expect(ergebnis.success).toBe(false);
  });

  it("weist einen Satz ohne Geraet und ohne Geraetetyp ab", () => {
    const ergebnis = recordSetInputSchema.safeParse(ohneGeraet);
    expect(ergebnis.success).toBe(false);
  });

  it("laesst ein Studio neben einem Geraet zu -- recordSet nimmt dann das des Geraets", () => {
    const ergebnis = recordSetInputSchema.safeParse({ ...basis, studioId: studio });
    expect(ergebnis.success).toBe(true);
  });
});

describe("recordSetInputSchema -- plan (0063)", () => {
  const plan = {
    planId: "55555555-5555-4555-8555-555555555555",
    einheitKey: "A",
    stand: 1,
    positionen: [
      { key: "A1", status: "erledigt" },
      { key: "A2", status: "getauscht", exerciseId: "44444444-4444-4444-8444-444444444444" },
      { key: "A3", status: "offen", exerciseId: null },
    ],
  };

  it("nimmt eine Momentaufnahme an und laesst sie sonst weg wie eine alte App", () => {
    const mit = recordSetInputSchema.safeParse({ ...basis, plan });
    const ohne = recordSetInputSchema.safeParse(basis);
    expect(mit.success && mit.data.plan?.positionen).toHaveLength(3);
    expect(ohne.success && ohne.data.plan).toBeUndefined();
  });

  it("weist stand 0, unbekannten Status und kaputte Ersatzuebung ab", () => {
    expect(recordSetInputSchema.safeParse({ ...basis, plan: { ...plan, stand: 0 } }).success).toBe(false);
    expect(
      recordSetInputSchema.safeParse({ ...basis, plan: { ...plan, positionen: [{ key: "A1", status: "fertig" }] } }).success,
    ).toBe(false);
    expect(
      recordSetInputSchema.safeParse({
        ...basis,
        plan: { ...plan, positionen: [{ key: "A1", status: "getauscht", exerciseId: "x" }] },
      }).success,
    ).toBe(false);
  });
});

describe("completeSessionInputSchema", () => {
  const sessionId = "6f1c2b9e-3c1a-4a51-9a4e-1d2f3a4b5c6d";

  // Testnotiz 14.10., 18:45 #3/#4: die Pausensumme kommt mit dem Abschluss.
  it("nimmt eine Pausensumme an", () => {
    expect(completeSessionInputSchema.parse({ sessionId, pausedSeconds: 1080 }).pausedSeconds).toBe(1080);
  });

  it("laesst die Pausensumme weg, wie eine alte App", () => {
    expect(completeSessionInputSchema.parse({ sessionId }).pausedSeconds).toBeUndefined();
  });

  it("weist eine negative oder gebrochene Pausensumme ab", () => {
    expect(completeSessionInputSchema.safeParse({ sessionId, pausedSeconds: -1 }).success).toBe(false);
    expect(completeSessionInputSchema.safeParse({ sessionId, pausedSeconds: 1.5 }).success).toBe(false);
  });
});

describe("wiederoeffnenEntscheidung", () => {
  const ende = "2026-10-14T18:52:00.000Z";
  const nach = (min: number) => new Date(Date.parse(ende) + min * 60_000);

  it("oeffnet 29 Minuten nach dem Beenden", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "manual" }, nach(29))).toBe("oeffnen");
  });

  it("oeffnet genau an der Grenze", () => {
    expect(REOPEN_FENSTER_MS).toBe(30 * 60 * 1000);
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "manual" }, nach(30))).toBe("oeffnen");
  });

  it("lehnt nach 31 Minuten ab", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "manual" }, nach(31)))
      .toEqual({ fehler: "Zu spät zum Fortsetzen." });
  });

  it("lehnt eine selbsttaetig beendete Einheit ab", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: ende, completed_reason: "auto" }, nach(1)))
      .toEqual({ fehler: "Dieses Training wurde automatisch beendet." });
  });

  // Doppeltipp oder Wiederholer: schon offen ist kein Fehler.
  it("laesst eine offene Einheit offen", () => {
    expect(wiederoeffnenEntscheidung({ completed_at: null, completed_reason: null }, nach(0))).toBe("offen");
  });
});
