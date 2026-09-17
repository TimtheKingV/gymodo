import { describe, expect, it } from "vitest";
import { rasten, rastenText } from "./rasten";

type Einstellung = Parameters<typeof rasten>[0];

function einstellung(teile: Partial<Einstellung>): Einstellung {
  return {
    id: "s1",
    key: "sitzhoehe",
    label: "Sitzhöhe",
    kind: "number",
    minValue: 1,
    maxValue: 8,
    stepValue: 1,
    unit: null,
    allowedValues: null,
    sortOrder: 1,
    ...teile,
  } as unknown as Einstellung;
}

describe("rasten", () => {
  it("zählt die Werte auf, die das Mitglied wirklich wählen kann", () => {
    expect(rastenText(einstellung({}))).toBe("1 · 2 · 3 · 4 · 5 · 6 … · 8 Rasten");
  });

  it("kürzt nicht, wenn alles hinpasst", () => {
    expect(rastenText(einstellung({ maxValue: 4 }))).toBe("1 · 2 · 3 · 4 · 4 Rasten");
  });

  /**
   * min + i * step summiert bei 2,5er-Schritten Fliesskommareste auf --
   * ohne Rundung stuende in der Zeile "12,500000000000002".
   */
  it("rechnet krumme Schrittweiten sauber", () => {
    const ergebnis = rasten(
      einstellung({ minValue: 2.5, maxValue: 20, stepValue: 2.5, unit: "cm" }),
    );
    expect(ergebnis).toMatchObject({ art: "liste", anzahl: 8, gekuerzt: true });
    expect(ergebnis.art === "liste" && ergebnis.werte).toEqual([
      "2,5 cm",
      "5 cm",
      "7,5 cm",
      "10 cm",
      "12,5 cm",
      "15 cm",
    ]);
  });

  it("nennt bei fehlender Schrittweite die Spanne statt zu raten", () => {
    expect(rastenText(einstellung({ stepValue: null }))).toBe("1 bis 8");
  });

  it("nennt bei fehlender Obergrenze ein Fragezeichen, keine erfundene Zahl", () => {
    expect(rastenText(einstellung({ maxValue: null }))).toBe(
      "1 bis ? in Schritten von 1",
    );
  });

  it("zeigt bei einer Auswahl die Werte selbst", () => {
    expect(
      rastenText(
        einstellung({
          kind: "enum",
          allowedValues: ["eng", "mittel", "breit"],
          minValue: null,
          maxValue: null,
          stepValue: null,
        }),
      ),
    ).toBe("eng · mittel · breit · 3 Rasten");
  });

  it("sagt es, wenn eine Auswahl gar keine Werte hat", () => {
    expect(
      rastenText(
        einstellung({ kind: "enum", allowedValues: [], minValue: null, maxValue: null }),
      ),
    ).toBe("Keine Werte hinterlegt");
  });
});
