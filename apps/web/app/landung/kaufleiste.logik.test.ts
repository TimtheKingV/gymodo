import { describe, expect, it } from "vitest";
import {
  KAUFLEISTE_START,
  naechsterZustand,
  type KaufleistenMessung,
  type KaufleistenZustand,
} from "./kaufleiste.logik";

const basis: KaufleistenMessung = {
  y: 0,
  maxY: 5000,
  ankerVorbei: false,
  schwelleY: 800,
  verdeckt: false,
  fokusDrin: false,
};

// Spielt eine Folge von Scrollpositionen durch, wie sie der rAF-Takt liefert.
function folge(ys: number[], m: Partial<KaufleistenMessung> = {}, start = KAUFLEISTE_START) {
  return ys.reduce<KaufleistenZustand>(
    (z, y) => naechsterZustand(z, { ...basis, ...m, y }),
    start,
  );
}

describe("naechsterZustand", () => {
  it("bleibt verborgen, solange der Hero-Knopf nicht vorbei ist", () => {
    expect(folge([100, 50]).sichtbar).toBe(false);
  });

  it("erscheint direkt hinter der Schwelle, auch beim Runterscrollen", () => {
    expect(folge([700, 810], { ankerVorbei: true }).sichtbar).toBe(true);
  });

  it("weicht beim Runterscrollen, sobald sie 24 px hinter der Schwelle ist", () => {
    expect(folge([700, 900, 1000], { ankerVorbei: true }).sichtbar).toBe(false);
  });

  it("kommt erst nach 12 px am Stueck nach oben zurueck", () => {
    const unten = folge([700, 900, 1400], { ankerVorbei: true });
    expect(folge([1392], { ankerVorbei: true }, unten).sichtbar).toBe(false);
    expect(folge([1392, 1388], { ankerVorbei: true }, unten).sichtbar).toBe(true);
  });

  it("flackert nicht bei Zittern unter der Hysterese", () => {
    const unten = folge([700, 900, 1400], { ankerVorbei: true });
    const z = folge([1395, 1400, 1395, 1400, 1394], { ankerVorbei: true }, unten);
    expect(z.richtung).toBe("runter");
    expect(z.sichtbar).toBe(false);
  });

  it("weicht jedem Verdecker, auch beim Hochscrollen", () => {
    const unten = folge([700, 900, 1400], { ankerVorbei: true });
    expect(folge([1300], { ankerVorbei: true, verdeckt: true }, unten).sichtbar).toBe(false);
  });

  it("bleibt stehen, solange der Fokus in ihr liegt", () => {
    expect(folge([700, 900, 1400], { ankerVorbei: true, fokusDrin: true }).sichtbar).toBe(true);
  });

  it("klemmt das iOS-Gummiband: negative Werte und Ueberhang kippen die Richtung nicht", () => {
    const oben = folge([0, -40]);
    expect(oben.y).toBe(0);
    expect(oben.richtung).toBe("runter");
    const ganzUnten = folge([4990, 5000, 5060, 5000], { ankerVorbei: true });
    expect(ganzUnten.y).toBe(5000);
    expect(ganzUnten.richtung).toBe("runter");
  });
});
