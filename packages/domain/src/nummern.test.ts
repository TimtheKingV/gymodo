import { describe, expect, it } from "vitest";
import { naechsteGeraeteNummer } from "./nummern.js";

describe("naechsteGeraeteNummer", () => {
  it("faengt bei eins an, wenn noch kein Geraet steht", () => {
    expect(naechsteGeraeteNummer([])).toBe("1");
  });

  it("nimmt die naechste nach der hoechsten, nicht die naechste Luecke", () => {
    expect(naechsteGeraeteNummer(["12", "13"])).toBe("14");
    expect(naechsteGeraeteNummer(["1", "3"])).toBe("4");
  });

  it("achtet nicht auf die Reihenfolge der Liste", () => {
    expect(naechsteGeraeteNummer(["13", "7", "12"])).toBe("14");
  });

  // Der Entwurf raet nicht: wer "Beinpresse 7" schreibt, fuehrt keine
  // Nummern, und ein aus Prosa gezogener Vorschlag waere geraten.
  it("ueberliest Bezeichnungen, die keine blanke Zahl sind", () => {
    expect(naechsteGeraeteNummer(["Beinpresse 7", "Latzug"])).toBe("1");
    expect(naechsteGeraeteNummer(["7", "Beinpresse 9"])).toBe("8");
  });

  it("nimmt Leerraum um die Zahl herum hin", () => {
    expect(naechsteGeraeteNummer([" 12 "])).toBe("13");
  });

  it("liest eine fuehrende Null als Zahl", () => {
    expect(naechsteGeraeteNummer(["07"])).toBe("8");
  });
});
