import { describe, expect, it } from "vitest";
import {
  MAX_SERIENTERMINE,
  ortszeitTeile,
  ortszeitZuInstant,
  serienTermine,
} from "./serie.js";

const BERLIN = "Europe/Berlin";

describe("ortszeitZuInstant", () => {
  it("deutet eine Sommerzeit-Wandzeit richtig -- 18:00 MESZ ist 16:00 UTC", () => {
    const instant = ortszeitZuInstant(
      { jahr: 2026, monat: 10, tag: 22, stunde: 18, minute: 0 },
      BERLIN,
    );
    expect(instant.toISOString()).toBe("2026-10-22T16:00:00.000Z");
  });

  it("deutet eine Winterzeit-Wandzeit richtig -- 18:00 MEZ ist 17:00 UTC", () => {
    const instant = ortszeitZuInstant(
      { jahr: 2026, monat: 10, tag: 29, stunde: 18, minute: 0 },
      BERLIN,
    );
    expect(instant.toISOString()).toBe("2026-10-29T17:00:00.000Z");
  });

  it("und zurueck ergibt wieder dieselbe Wandzeit", () => {
    for (const tag of [22, 29]) {
      const instant = ortszeitZuInstant(
        { jahr: 2026, monat: 10, tag, stunde: 18, minute: 0 },
        BERLIN,
      );
      expect(ortszeitTeile(instant, BERLIN)).toEqual({
        jahr: 2026,
        monat: 10,
        tag,
        stunde: 18,
        minute: 0,
      });
    }
  });
});

describe("serienTermine", () => {
  it("ohne Wiederholung ist die Serie der eine Termin", () => {
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 9, tag: 3, stunde: 18, minute: 0 },
      BERLIN,
    );
    expect(serienTermine(start, start, BERLIN)).toEqual([start]);
  });

  it("woechentlich bis zum 3. Dezember ergibt die 14 Termine des Artboards", () => {
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 9, tag: 3, stunde: 18, minute: 0 },
      BERLIN,
    );
    const bis = ortszeitZuInstant(
      { jahr: 2026, monat: 12, tag: 3, stunde: 18, minute: 0 },
      BERLIN,
    );
    expect(serienTermine(start, bis, BERLIN)).toHaveLength(14);
  });

  it("JEDER Termin liegt um 18:00 Ortszeit -- auch nach der Zeitumstellung", () => {
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 10, tag: 8, stunde: 18, minute: 0 },
      BERLIN,
    );
    const bis = ortszeitZuInstant(
      { jahr: 2026, monat: 11, tag: 12, stunde: 18, minute: 0 },
      BERLIN,
    );
    const termine = serienTermine(start, bis, BERLIN);

    // Die Probe, um die es geht: sieben mal 24 Stunden zu addieren
    // ergaebe ab dem 29. Oktober 17:00 Ortszeit.
    for (const termin of termine) {
      const teile = ortszeitTeile(termin, BERLIN);
      expect(teile.stunde).toBe(18);
      expect(teile.minute).toBe(0);
    }

    // Und auf dem Zeitstrahl liegt genau ein Sprung von einer Stunde.
    const abstaende = termine
      .slice(1)
      .map((t, i) => (t.getTime() - termine[i]!.getTime()) / 3_600_000);
    expect(abstaende.filter((h) => h === 169)).toHaveLength(1);
    expect(abstaende.filter((h) => h === 168)).toHaveLength(abstaende.length - 1);
  });

  it("und dasselbe im Fruehjahr, wo die Stunde verschwindet", () => {
    const start = ortszeitZuInstant(
      { jahr: 2027, monat: 3, tag: 25, stunde: 18, minute: 0 },
      BERLIN,
    );
    const bis = ortszeitZuInstant(
      { jahr: 2027, monat: 4, tag: 8, stunde: 18, minute: 0 },
      BERLIN,
    );
    const termine = serienTermine(start, bis, BERLIN);
    for (const termin of termine) {
      expect(ortszeitTeile(termin, BERLIN).stunde).toBe(18);
    }
  });

  it("ein Enddatum vor dem Start ergibt trotzdem den Starttermin", () => {
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 9, tag: 3, stunde: 18, minute: 0 },
      BERLIN,
    );
    const frueher = new Date(start.getTime() - 7 * 24 * 3_600_000);
    expect(serienTermine(start, frueher, BERLIN)).toEqual([start]);
  });

  it("ein Enddatum am selben Ortstag zaehlt mit, auch bei frueherer Uhrzeit", () => {
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 9, tag: 3, stunde: 18, minute: 0 },
      BERLIN,
    );
    const bisFrueh = ortszeitZuInstant(
      { jahr: 2026, monat: 9, tag: 10, stunde: 6, minute: 0 },
      BERLIN,
    );
    // Der Trainer waehlt ein DATUM, keine Uhrzeit -- der 10. gehoert dazu.
    expect(serienTermine(start, bisFrueh, BERLIN)).toHaveLength(2);
  });

  it("die Serie ist gedeckelt -- niemand legt versehentlich zehn Jahre an", () => {
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 1, tag: 1, stunde: 18, minute: 0 },
      BERLIN,
    );
    const bis = ortszeitZuInstant(
      { jahr: 2036, monat: 1, tag: 1, stunde: 18, minute: 0 },
      BERLIN,
    );
    expect(serienTermine(start, bis, BERLIN)).toHaveLength(MAX_SERIENTERMINE);
  });

  it("eine andere Zeitzone rechnet nach ihrer eigenen Umstellung", () => {
    // New York stellt eine Woche spaeter um als Berlin.
    const start = ortszeitZuInstant(
      { jahr: 2026, monat: 10, tag: 22, stunde: 18, minute: 0 },
      "America/New_York",
    );
    const bis = ortszeitZuInstant(
      { jahr: 2026, monat: 11, tag: 12, stunde: 18, minute: 0 },
      "America/New_York",
    );
    for (const termin of serienTermine(start, bis, "America/New_York")) {
      expect(ortszeitTeile(termin, "America/New_York").stunde).toBe(18);
    }
  });
});
