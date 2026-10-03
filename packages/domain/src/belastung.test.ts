import { describe, expect, it } from "vitest";
import {
  MAX_VOLUME,
  defaultLoadRange,
  defaultTargetRange,
  formatLoad,
  formatLoadDelta,
  formatVolume,
  formatVolumeRange,
  snapToStep,
} from "./belastung.js";

describe("formatLoad", () => {
  it("schreibt Kilogramm mit einer Nachkommastelle, wie das Portal bisher", () => {
    expect(formatLoad(80, "kg")).toBe("80,0 kg");
    expect(formatLoad(2.5, "kg")).toBe("2,5 kg");
    expect(formatLoad(100, "kg")).toBe("100,0 kg");
  });

  it("kennt jede Einheit", () => {
    expect(formatLoad(120, "watt")).toBe("120 W");
    expect(formatLoad(8, "level")).toBe("Level 8");
    expect(formatLoad(8.5, "kmh")).toBe("8,5 km/h");
    expect(formatLoad(6, "pct")).toBe("6,0 %");
    expect(formatLoad(85, "rpm")).toBe("85 U/min");
  });

  it("setzt Tausenderpunkte", () => {
    expect(formatLoad(1000, "watt")).toBe("1.000 W");
  });
});

describe("formatLoadDelta", () => {
  it("traegt immer ein Vorzeichen", () => {
    expect(formatLoadDelta(2.5, "kg")).toBe("+2,5 kg");
    expect(formatLoadDelta(-10, "watt")).toBe("-10 W");
    expect(formatLoadDelta(1, "level")).toBe("+1 Level");
    expect(formatLoadDelta(0, "kmh")).toBe("+0,0 km/h");
  });
});

describe("formatVolume", () => {
  it("Wiederholungen, Minuten mit Sekunden, Meter", () => {
    expect(formatVolume(12, "reps")).toBe("12 Wdh.");
    expect(formatVolume(1200, "seconds")).toBe("20:00 min");
    expect(formatVolume(750, "seconds")).toBe("12:30 min");
    expect(formatVolume(2000, "meters")).toBe("2.000 m");
  });
});

describe("formatVolumeRange", () => {
  it("nennt den Korridor in der Sprache der Uebung", () => {
    expect(formatVolumeRange(8, 12, "reps")).toBe("8–12 Wiederholungen");
    expect(formatVolumeRange(900, 1200, "seconds")).toBe("15–20 min");
    expect(formatVolumeRange(2000, 5000, "meters")).toBe("2.000–5.000 m");
  });
});

describe("Vorgaben", () => {
  it("Kilogramm-Vorgaben sind die bisherigen des Portals", () => {
    expect(defaultLoadRange("kg")).toEqual({ min: 0, max: null, step: 2.5 });
    expect(defaultTargetRange("reps")).toEqual({ min: 8, max: 12 });
  });

  it("Minuten-Korridor wird in Sekunden gespeichert", () => {
    expect(defaultTargetRange("seconds")).toEqual({ min: 900, max: 1200 });
  });

  it("Obergrenzen liegen unter der Datenbankschranke", () => {
    for (const grenze of Object.values(MAX_VOLUME)) {
      expect(grenze).toBeLessThanOrEqual(100_000);
    }
  });
});

describe("snapToStep", () => {
  it("rastet auf die naechste Stufe", () => {
    expect(snapToStep(82, 50, 120, 5)).toBe(80);
    expect(snapToStep(83, 50, 120, 5)).toBe(85);
  });

  it("klemmt an Minimum und Maximum", () => {
    expect(snapToStep(200, 50, 120, 5)).toBe(120);
    expect(snapToStep(10, 50, 120, 5)).toBe(50);
  });

  it("ohne Obergrenze nur nach unten geklemmt", () => {
    expect(snapToStep(1234.5, 0, null, 2.5)).toBe(1235);
  });

  it("uebersteht Gleitkomma bei Schritt 0,1", () => {
    expect(snapToStep(0.3, 0, 15, 0.1)).toBe(0.3);
    expect(snapToStep(6.26, 0, 15, 0.5)).toBe(6.5);
  });

  it("laesst den Wert bei unbrauchbarem Schritt in Ruhe", () => {
    expect(snapToStep(7, 0, 10, 0)).toBe(7);
  });
});
