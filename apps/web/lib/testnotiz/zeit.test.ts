import { describe, expect, it } from "vitest";
import { datumUhrzeit, ordnername, uhrzeit, zeitstempel } from "./zeit";

describe("zeitstempel", () => {
  it("schreibt den Offset der Zeitzone, nicht Z", () => {
    const datum = new Date("2026-09-21T12:12:03Z");
    expect(zeitstempel(datum, 120)).toBe("2026-09-21T14:12:03+02:00");
  });

  it("kommt mit westlichen Offsets und halben Stunden zurecht", () => {
    const datum = new Date("2026-09-21T12:12:03Z");
    expect(zeitstempel(datum, -420)).toBe("2026-09-21T05:12:03-07:00");
    expect(zeitstempel(datum, 330)).toBe("2026-09-21T17:42:03+05:30");
  });

  it("traegt keine Sekundenbruchteile", () => {
    const datum = new Date("2026-09-21T12:12:03.456Z");
    expect(zeitstempel(datum, 0)).toBe("2026-09-21T12:12:03+00:00");
  });
});

describe("Ableitungen", () => {
  const zeitpunkt = "2026-09-21T14:12:03+02:00";

  it("Ordnername ist Datum und Uhrzeit ohne Trenner", () => {
    expect(ordnername(zeitpunkt)).toBe("2026-09-21-1412");
  });

  it("Uhrzeit wahlweise mit Sekunden", () => {
    expect(uhrzeit(zeitpunkt)).toBe("14:12");
    expect(uhrzeit(zeitpunkt, true)).toBe("14:12:03");
  });

  it("Datum und Uhrzeit fuer die Kopfzeile", () => {
    expect(datumUhrzeit(zeitpunkt)).toBe("2026-09-21 14:12");
  });
});
