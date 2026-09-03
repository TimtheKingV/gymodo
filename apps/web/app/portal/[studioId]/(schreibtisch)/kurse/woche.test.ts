import { describe, expect, it } from "vitest";
import { nachTagenGruppieren, wochenFenster } from "./woche";

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
