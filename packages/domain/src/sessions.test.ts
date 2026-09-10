import { describe, expect, it } from "vitest";
import { serienstand, zaehleDieseWoche } from "./sessions.js";

const BERLIN = "Europe/Berlin";
/** Mittwoch, 9. September 2026, 12:00 Ortszeit (MESZ = UTC+2). */
const mittwoch = new Date("2026-09-09T10:00:00.000Z");

describe("zaehleDieseWoche", () => {
  it("zaehlt eine Einheit von heute", () => {
    expect(zaehleDieseWoche(["2026-09-09T08:00:00.000Z"], mittwoch, BERLIN)).toBe(1);
  });

  it("zaehlt ab Montag, nicht ab Sonntag", () => {
    const montag = "2026-09-07T08:00:00.000Z";
    const sonntagDavor = "2026-09-06T08:00:00.000Z";

    expect(zaehleDieseWoche([montag, sonntagDavor], mittwoch, BERLIN)).toBe(1);
  });

  // Der eigentliche Grund fuer den Zeitzonen-Parameter: 00:30 MESZ am
  // Montag ist noch Sonntag 22:30 UTC. Ohne die Zeitzone faellt diese
  // Einheit in die vorige Woche -- und das Mitglied saehe eine andere
  // Woche als sein Studio.
  it("legt die Wochengrenze in die Studio-Zeitzone", () => {
    const montagKurzNachMitternacht = "2026-09-06T22:30:00.000Z";

    expect(zaehleDieseWoche([montagKurzNachMitternacht], mittwoch, BERLIN)).toBe(1);
    expect(zaehleDieseWoche([montagKurzNachMitternacht], mittwoch, "UTC")).toBe(0);
  });

  it("zaehlt am Sonntag noch die ablaufende Woche", () => {
    const sonntag = new Date("2026-09-13T10:00:00.000Z");

    expect(zaehleDieseWoche(["2026-09-07T08:00:00.000Z"], sonntag, BERLIN)).toBe(1);
  });

  it("zaehlt eine leere Liste als null", () => {
    expect(zaehleDieseWoche([], mittwoch, BERLIN)).toBe(0);
  });
});

describe("serienstand", () => {
  it("zaehlt die laufende Woche, sobald sie ihre erste Einheit hat", () => {
    expect(serienstand(["2026-09-09T08:00:00.000Z"], mittwoch, BERLIN).weeks).toBe(1);
  });

  // Der Kern der Regel: eine Woche zaehlt, wenn in ihr mindestens eine
  // Einheit liegt. Die laufende Woche ist noch leer -- gerissen ist die
  // Serie deshalb nicht, sie steht auf dem Wert der Vorwoche.
  it("laesst die Serie stehen, solange die laufende Woche nur leer ist", () => {
    const vorwoche = "2026-09-02T08:00:00.000Z";

    expect(serienstand([vorwoche], mittwoch, BERLIN).weeks).toBe(1);
  });

  it("springt um eins hoch, sobald die laufende Woche ihre Einheit hat", () => {
    const vorwoche = "2026-09-02T08:00:00.000Z";
    const dieseWoche = "2026-09-09T08:00:00.000Z";

    expect(serienstand([vorwoche, dieseWoche], mittwoch, BERLIN).weeks).toBe(2);
  });

  it("zaehlt nur ununterbrochene Wochen", () => {
    const dieseWoche = "2026-09-09T08:00:00.000Z";
    const vorwoche = "2026-09-02T08:00:00.000Z";
    const luecke = "2026-08-26T08:00:00.000Z"; // wird uebersprungen
    const davor = "2026-08-19T08:00:00.000Z";

    expect(serienstand([dieseWoche, vorwoche, davor], mittwoch, BERLIN).weeks).toBe(2);
    expect(serienstand([dieseWoche, vorwoche, luecke, davor], mittwoch, BERLIN).weeks).toBe(4);
  });

  it("ist null, wenn auch die Vorwoche leer blieb", () => {
    const vorvorwoche = "2026-08-26T08:00:00.000Z";

    expect(serienstand([vorvorwoche], mittwoch, BERLIN).weeks).toBe(0);
    expect(serienstand([], mittwoch, BERLIN).weeks).toBe(0);
  });

  it("nennt Wochenbeginn und heute als Ortsdatum", () => {
    const stand = serienstand([], mittwoch, BERLIN);

    expect(stand.weekStart).toBe("2026-09-07");
    expect(stand.today).toBe("2026-09-09");
  });

  it("nennt die Trainingstage der laufenden Woche, aufsteigend und ohne Doppel", () => {
    const stand = serienstand(
      [
        "2026-09-09T08:00:00.000Z",
        "2026-09-07T08:00:00.000Z",
        "2026-09-07T17:00:00.000Z",
        "2026-09-02T08:00:00.000Z", // Vorwoche, gehoert nicht in den Streifen
      ],
      mittwoch,
      BERLIN,
    );

    expect(stand.trainedDays).toEqual(["2026-09-07", "2026-09-09"]);
  });

  // Dieselbe Begruendung wie bei zaehleDieseWoche: 00:30 MESZ am Montag
  // ist Sonntag 22:30 UTC. In UTC gerechnet faellt die Einheit in die
  // Vorwoche -- die Serie stuende dann auf 1 statt auf 2.
  it("legt die Wochengrenze in die Studio-Zeitzone", () => {
    const montagKurzNachMitternacht = "2026-09-06T22:30:00.000Z";
    const vorwoche = "2026-09-02T08:00:00.000Z";

    expect(serienstand([montagKurzNachMitternacht, vorwoche], mittwoch, BERLIN).weeks).toBe(2);
    expect(serienstand([montagKurzNachMitternacht, vorwoche], mittwoch, "UTC").weeks).toBe(1);
  });

  // Eine kuenftig datierte Einheit gibt es nicht, aber eine falsch
  // gestellte Uhr schon. Sie darf die Serie nicht verlaengern.
  it("ignoriert Einheiten, die in der Zukunft liegen", () => {
    const naechsteWoche = "2026-09-16T08:00:00.000Z";

    expect(serienstand([naechsteWoche], mittwoch, BERLIN).weeks).toBe(0);
  });
});
