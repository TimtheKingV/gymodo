// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
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

function zeilen(spalte: string): (string | null)[] {
  return [...screen.getByRole("listbox", { name: spalte }).querySelectorAll('[role="option"]')].map(
    (zeile) => zeile.textContent,
  );
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

  // Testnotiz 23.09. (zweite Sitzung), #3 -- vormals in ModellGewichtRad.test.tsx.
  it("zaehlt Minimum und Maximum im Takt des Schritts, mit ∞ am Ende", () => {
    render(<ModellBelastungRad />);

    expect(zeilen("Minimum").slice(0, 3)).toEqual(["0", "2,5", "5"]);
    expect(zeilen("Maximum").slice(0, 3)).toEqual(["0", "2,5", "5"]);
    expect(zeilen("Maximum").at(-1)).toBe("∞");
  });

  it("folgt einem neu gewaehlten Schritt", async () => {
    render(
      <ModellBelastungRad
        start={{
          category: "kraft",
          loadUnit: "kg",
          loadMin: 5,
          loadMax: null,
          loadStep: 2.5,
          secondaryUnit: null,
          secondaryMin: null,
          secondaryMax: null,
          secondaryStep: null,
        }}
      />,
    );

    const schritt = screen.getByRole("listbox", { name: "Schritt" });
    schritt.scrollTop = zeilen("Schritt").indexOf("10") * 40;
    fireEvent.scroll(schritt);
    await act(() => new Promise((fertig) => requestAnimationFrame(() => fertig(null))));

    expect(zeilen("Minimum").slice(0, 3)).toEqual(["0", "10", "20"]);
    // 5 liegt zwischen 0 und 10 -- der naechstliegende ist der erste Treffer.
    expect(feldwert("loadMin")).toBe("0");
  });

  it("zaehlt auch am Laufband im Takt des Schritts", async () => {
    render(<ModellBelastungRad />);

    await auswaehlen("Belastung", "km/h");

    expect(zeilen("Minimum").slice(0, 3)).toEqual(["0", "0,5", "1"]);
    expect(zeilen("Maximum").at(-1)).toBe("∞");
  });
});
