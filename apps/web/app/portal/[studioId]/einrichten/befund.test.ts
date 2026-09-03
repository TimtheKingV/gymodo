import { describe, expect, it } from "vitest";
import { antwortAuf } from "./befund";

describe("antwortAuf", () => {
  it("bietet bei einem freien Tag das Verbinden an und nennt die Charge", () => {
    const antwort = antwortAuf(
      { verdikt: "frei", batchCode: "7", batchIndex: 42 },
      "Kabelzug 14",
    );
    expect(antwort.titel).toBe("Tag erkannt");
    expect(antwort.text).toContain("Charge 7");
    expect(antwort.hauptaktion).toBe("verbinden");
    expect(antwort.ton).toBe("gut");
  });

  // Entscheidung 8: "Ein vergebener Tag wird nicht mit einem Tap umgehaengt."
  // Sonst verliert ein Geraet seinen Tag, ohne dass jemand davorsteht.
  it("bietet bei einem vergebenen Tag KEINE Hauptaktion, sondern nennt das Geraet", () => {
    const antwort = antwortAuf(
      { verdikt: "vergeben", machineId: "abc", machineLabel: "Beinpresse 7" },
      "Kabelzug 14",
    );
    expect(antwort.text).toContain("Beinpresse 7");
    expect(antwort.hauptaktion).toBeNull();
  });

  it("laesst einen gesperrten Tag gesperrt", () => {
    const antwort = antwortAuf({ verdikt: "gesperrt" }, "Kabelzug 14");
    expect(antwort.titel).toContain("Gesperrt");
    expect(antwort.hauptaktion).toBeNull();
    expect(antwort.ton).toBe("warnung");
  });

  // Spec 4: eine Sackgasse mit genau einem Ausgang. Das Schild ist ab der
  // Lieferung gueltig -- hier gibt es nichts zu verbinden.
  it("sagt beim Aushangschild, was in der Hand liegt, und bietet nichts an", () => {
    const antwort = antwortAuf({ verdikt: "aushangschild" }, "Kabelzug 14");
    expect(antwort.titel).toBe("Das ist ein Aushangschild");
    expect(antwort.text).toContain("an die Wand");
    expect(antwort.hauptaktion).toBeNull();
  });

  it("gibt fuer unbekannt und fremdes Studio dieselbe Antwort", () => {
    const antwort = antwortAuf({ verdikt: "unbekannt" }, "Kabelzug 14");
    expect(antwort.text).toContain("Melde dich beim Betreiber");
    expect(antwort.hauptaktion).toBeNull();
  });

  // Der Fall "am Geraet klebt schon einer": derselbe freie Tag, aber die
  // Hauptaktion heisst Ersetzen statt Verbinden (Zustaende, "Am Geraet").
  it("macht aus Verbinden ein Ersetzen, wenn das Geraet schon einen Tag traegt", () => {
    const antwort = antwortAuf(
      { verdikt: "frei", batchCode: "7", batchIndex: 42 },
      "Kabelzug 14",
      { geraetHatTag: true },
    );
    expect(antwort.hauptaktion).toBe("ersetzen");
    expect(antwort.text).toContain("wird dabei ungültig");
  });
});
