import { describe, expect, it } from "vitest";
import { kalenderTage, monatsFenster, nachTagenGruppieren, wochenFenster } from "./woche";

const BERLIN = "Europe/Berlin";

describe("wochenFenster", () => {
  it("ohne Anker beginnt das Fenster am Montag und umfasst sieben Ortstage", () => {
    const fenster = wochenFenster(undefined, BERLIN);
    const stunden =
      (new Date(fenster.bis).getTime() - new Date(fenster.von).getTime()) / 3_600_000;
    // NICHT auf 168 festgenagelt: zweimal im Jahr sind es 167 oder 169,
    // und ein Test, der in der Umstellungswoche rot wird, ist ein Test,
    // den man abschaltet. Der naechste Fall prueft die Umstellung genau.
    expect([167, 168, 169]).toContain(stunden);
    expect(nachTagenGruppieren([], fenster.von, BERLIN)).toHaveLength(7);
  });

  it("mit Anker beginnt es am Montag der Ankerwoche", () => {
    // Der 3. September 2026 ist ein Donnerstag; die Woche beginnt am 31. August.
    const fenster = wochenFenster("2026-09-03", BERLIN);
    expect(fenster.titel).toBe("Mo., 31. August – So., 6. September 2026");
    expect(fenster.vorige).toBe("2026-08-24");
    expect(fenster.naechste).toBe("2026-09-07");
  });

  it("ein Anker, der kein Datum ist, faellt auf die aktuelle Woche zurueck, statt abzustuerzen", () => {
    // ?woche=abc erreicht wochenFenster AUSSERHALB des try/catch von
    // page.tsx -- ein RangeError hier landet auf Nexts Standard-
    // Fehlerseite, und diese Anwendung hat kein error.tsx (Finding 6 des
    // Gesamtreviews). Ein verunstaltetes Lesezeichen soll diese Woche
    // zeigen, keinen Fehler.
    expect(() => wochenFenster("abc", BERLIN)).not.toThrow();
    const fenster = wochenFenster("abc", BERLIN);
    const erwartet = wochenFenster(undefined, BERLIN);
    expect(fenster.von).toBe(erwartet.von);
    expect(fenster.bis).toBe(erwartet.bis);
  });

  it("ein Anker mit falscher Form (kein YYYY-MM-DD) faellt ebenfalls zurueck", () => {
    expect(() => wochenFenster("03.09.2026", BERLIN)).not.toThrow();
    expect(() => wochenFenster("2026-9-3", BERLIN)).not.toThrow();
  });

  it("die Woche MIT der Zeitumstellung ist 169 Stunden lang und trotzdem sieben Tage", () => {
    // Die Umstellung liegt 2026 auf dem 25. Oktober, einem Sonntag --
    // also im letzten Tag der Woche vom 19. bis 25. Oktober.
    //
    // Nachgerechnet: von 19.10. 00:00 MESZ (= 18.10. 22:00Z)
    //                bis 26.10. 00:00 MEZ  (= 25.10. 23:00Z)  = 169 h.
    const fenster = wochenFenster("2026-10-19", BERLIN);
    expect(fenster.titel).toBe("Mo., 19. Oktober – So., 25. Oktober 2026");

    const stunden =
      (new Date(fenster.bis).getTime() - new Date(fenster.von).getTime()) / 3_600_000;
    expect(stunden).toBe(169);
    expect(nachTagenGruppieren([], fenster.von, BERLIN)).toHaveLength(7);
  });

  it("die Woche DANACH ist wieder 168 Stunden lang", () => {
    // Die Gegenprobe zum vorigen Fall: haette man die Woche vom 26.10.
    // genommen, waere sie durchgehend MEZ -- und der Test haette die
    // Sommerzeit nie beruehrt.
    const fenster = wochenFenster("2026-10-26", BERLIN);
    const stunden =
      (new Date(fenster.bis).getTime() - new Date(fenster.von).getTime()) / 3_600_000;
    expect(stunden).toBe(168);
  });
});

describe("nachTagenGruppieren", () => {
  it("liefert immer sieben Tage, auch wenn nichts stattfindet", () => {
    const gruppen = nachTagenGruppieren([], "2026-08-31T00:00:00Z", BERLIN);
    expect(gruppen).toHaveLength(7);
    expect(gruppen.every((g) => g.sessions.length === 0)).toBe(true);
  });

  it("die Ueberschriften stehen wie auf dem Artboard", () => {
    const gruppen = nachTagenGruppieren([], "2026-08-31T00:00:00Z", BERLIN);
    expect(gruppen[0]!.ueberschrift).toBe("Montag, 31. August");
    expect(gruppen[6]!.ueberschrift).toBe("Sonntag, 6. September");
  });

  it("ordnet jeden Termin seinem local_day zu -- nicht dem UTC-Tag", () => {
    const spaeterTermin = {
      sessionId: "a",
      templateId: "t",
      name: "Spaetkurs",
      description: null,
      // 22:30 UTC am 31.08. ist 00:30 Ortszeit am 1.09.
      startsAt: "2026-08-31T22:30:00Z",
      localDay: "2026-09-01",
      durationMin: 60,
      capacity: 10,
      room: null,
      instructorName: null,
      status: "planned" as const,
      bookedCount: 0,
      waitlistCount: 0,
      freeSeats: 10,
      ownStatus: null,
      ownBookingId: null,
      ownWaitlistPosition: null,
    };
    const gruppen = nachTagenGruppieren([spaeterTermin], "2026-08-31T00:00:00Z", BERLIN);
    expect(gruppen[0]!.sessions).toHaveLength(0);
    expect(gruppen[1]!.sessions).toHaveLength(1);
  });
});

/** Testnotiz 25.09., #1: Wochenstreifen wie in der App, dazu ein Monat. */
describe("wochenFenster: Anschluss an den Kalender", () => {
  it("nennt den Montag und den Monat, in dem der groessere Teil der Woche liegt", () => {
    // Mo 31. August bis So 6. September: sechs Tage im September.
    const fenster = wochenFenster("2026-09-03", BERLIN);
    expect(fenster.montag).toBe("2026-08-31");
    expect(fenster.monat).toBe("2026-09");
  });
});

describe("monatsFenster", () => {
  it("umfasst volle Wochen von Montag vor dem Ersten bis Sonntag nach dem Letzten", () => {
    // Der 1. September 2026 ist ein Dienstag, der 30. ein Mittwoch.
    const fenster = monatsFenster("2026-09", BERLIN);
    expect(fenster.titel).toBe("September 2026");
    expect(fenster.erster).toBe("2026-08-31");
    expect(fenster.tage).toBe(35);
    expect(fenster.von).toBe("2026-08-30T22:00:00.000Z");
    expect(fenster.bis).toBe("2026-10-04T22:00:00.000Z");
    expect(fenster.vorige).toBe("2026-08");
    expect(fenster.naechste).toBe("2026-10");
  });

  it("rechnet ueber die Zeitumstellung auf der Wanduhr", () => {
    // Maerz 2026: der 1. ist ein Sonntag, die Uhr springt am 29.
    const fenster = monatsFenster("2026-03", BERLIN);
    expect(fenster.erster).toBe("2026-02-23");
    expect(fenster.tage).toBe(42);
    expect(fenster.von).toBe("2026-02-22T23:00:00.000Z");
    expect(fenster.bis).toBe("2026-04-05T22:00:00.000Z");
  });

  it("wechselt ueber den Jahreswechsel", () => {
    expect(monatsFenster("2026-12", BERLIN).naechste).toBe("2027-01");
    expect(monatsFenster("2026-01", BERLIN).vorige).toBe("2025-12");
  });

  it("ein unlesbarer Anker faellt auf den aktuellen Monat zurueck", () => {
    expect(() => monatsFenster("abc", BERLIN)).not.toThrow();
    expect(monatsFenster("2026-13", BERLIN).von).toBe(monatsFenster(undefined, BERLIN).von);
  });
});

describe("kalenderTage", () => {
  const sessions = [
    { localDay: "2026-09-01", status: "planned" as const },
    { localDay: "2026-09-01", status: "planned" as const },
    { localDay: "2026-09-02", status: "cancelled" as const },
  ];

  it("zaehlt je Tag die stattfindenden Kurse, abgesagte nicht", () => {
    const tage = kalenderTage("2026-08-31", 7, "2026-09-02", sessions);
    expect(tage.map((tag) => tag.kurse)).toEqual([0, 2, 0, 0, 0, 0, 0]);
  });

  it("traegt Buchstabe, Nummer und heute wie der Streifen der App", () => {
    const tage = kalenderTage("2026-08-31", 7, "2026-09-02", sessions);
    expect(tage.map((tag) => tag.buchstabe).join("")).toBe("MDMDFSS");
    expect(tage.map((tag) => tag.nummer)).toEqual([31, 1, 2, 3, 4, 5, 6]);
    expect(tage.filter((tag) => tag.istHeute).map((tag) => tag.iso)).toEqual(["2026-09-02"]);
  });

  it("markiert Tage ausserhalb des Monats", () => {
    const tage = kalenderTage("2026-08-31", 35, "2026-09-02", sessions, "2026-09");
    expect(tage[0]!.imMonat).toBe(false);
    expect(tage[1]!.imMonat).toBe(true);
    expect(tage[34]!.iso).toBe("2026-10-04");
    expect(tage[34]!.imMonat).toBe(false);
  });
});
