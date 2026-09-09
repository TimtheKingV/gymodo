import { describe, expect, it } from "vitest";
import { zaehleDieseWoche } from "./sessions.js";

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
