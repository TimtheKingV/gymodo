// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { ModellBelastungRad } from "./ModellBelastungRad";

afterEach(cleanup);

// jsdom kennt kein scrollIntoView; Auswahl.tsx ruft es beim Oeffnen fuer
// die hervorgehobene Zeile auf.
beforeAll(() => {
  Element.prototype.scrollIntoView = vi.fn();
});

/** Der Wert, den die Spalte gerade ins Formular traegt. */
function feldwert(name: string): string | null {
  const feld = document.querySelector<HTMLInputElement>(`input[name="${name}"]`);
  return feld ? feld.value : null;
}

async function auswaehlen(label: string, anzeige: string) {
  fireEvent.click(screen.getByRole("button", { name: label }));
  fireEvent.click(await screen.findByRole("option", { name: anzeige }));
}

describe("ModellBelastungRad", () => {
  it("steht ohne Startwerte auf Kraft, kg und den bisherigen Radwerten", () => {
    render(<ModellBelastungRad />);

    expect(feldwert("category")).toBe("kraft");
    expect(feldwert("loadUnit")).toBe("kg");
    expect(feldwert("loadMin")).toBe("0");
    expect(feldwert("loadMax")).toBe("");
    expect(feldwert("loadStep")).toBe("2,5");
    expect(feldwert("secondaryUnit")).toBe("");
    // Kein zweites Rad, solange die Nebenbelastung auf "keine" steht.
    expect(screen.queryByRole("listbox", { name: "Nebenbelastung ab" })).toBeNull();
  });

  it("laedt nach einem Einheitenwechsel die Rastung der neuen Einheit", async () => {
    render(<ModellBelastungRad />);

    await auswaehlen("Belastung", "km/h");

    expect(feldwert("loadUnit")).toBe("kmh");
    expect(feldwert("loadStep")).toBe("0,5");
    expect(feldwert("loadMax")).toBe("20");
  });

  it("zeigt das zweite Rad erst mit einer Nebenbelastung, mit eigenen Spaltennamen", async () => {
    render(<ModellBelastungRad />);

    await auswaehlen("Nebenbelastung", "%");

    expect(feldwert("secondaryUnit")).toBe("pct");
    expect(screen.getByRole("listbox", { name: "Nebenbelastung ab" })).toBeTruthy();
    expect(feldwert("secondaryMin")).toBe("0");
    expect(feldwert("secondaryMax")).toBe("15");
    expect(feldwert("secondaryStep")).toBe("0,5");
    // Die Hauptspalten bleiben eindeutig.
    expect(screen.getAllByRole("listbox", { name: "Minimum" })).toHaveLength(1);
  });

  it("nimmt Bestandswerte als Start und behaelt sie bei gleicher Einheit", () => {
    render(
      <ModellBelastungRad
        start={{
          category: "cardio",
          loadUnit: "kmh",
          loadMin: 0,
          loadMax: 18,
          loadStep: 0.5,
          secondaryUnit: "pct",
          secondaryMin: 0,
          secondaryMax: 12,
          secondaryStep: 0.5,
        }}
      />,
    );

    expect(feldwert("category")).toBe("cardio");
    expect(feldwert("loadUnit")).toBe("kmh");
    expect(feldwert("loadMax")).toBe("18");
    expect(feldwert("secondaryUnit")).toBe("pct");
    expect(feldwert("secondaryMax")).toBe("12");
  });
});
