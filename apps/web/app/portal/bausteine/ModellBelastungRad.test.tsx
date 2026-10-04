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
    // Testnotiz 03.10., #2: kein Minimum im Rad, es ist der Schritt.
    expect(feldwert("loadMin")).toBe("2,5");
    expect(screen.queryByRole("listbox", { name: "Minimum" })).toBeNull();
    expect(feldwert("loadMax")).toBe("");
    expect(feldwert("loadStep")).toBe("2,5");
    // Kraft kennt keine Nebenbelastung (Testnotiz 03.10., #1): kein Feld,
    // die Aktion liest das fehlende Feld als "keine" (formfelder.ts).
    expect(feldwert("secondaryUnit")).toBeNull();
    expect(screen.queryByRole("listbox", { name: "Nebenbelastung ab" })).toBeNull();
  });

  it("laedt nach einem Einheitenwechsel die Rastung der neuen Einheit", async () => {
    render(<ModellBelastungRad />);

    await auswaehlen("Kategorie", "Cardio");
    await auswaehlen("Belastung", "km/h");

    expect(feldwert("loadUnit")).toBe("kmh");
    expect(feldwert("loadStep")).toBe("0,5");
    expect(feldwert("loadMin")).toBe("0,5");
    expect(feldwert("loadMax")).toBe("20");
  });

  it("zeigt das zweite Rad erst mit einer Nebenbelastung, mit eigenen Spaltennamen", async () => {
    render(<ModellBelastungRad />);

    await auswaehlen("Kategorie", "Cardio");
    await auswaehlen("Nebenbelastung", "%");

    expect(feldwert("secondaryUnit")).toBe("pct");
    expect(screen.getByRole("listbox", { name: "Nebenbelastung ab" })).toBeTruthy();
    expect(feldwert("secondaryMin")).toBe("0");
    expect(feldwert("secondaryMax")).toBe("15");
    expect(feldwert("secondaryStep")).toBe("0,5");
    // Die Hauptspalten bleiben eindeutig.
    expect(screen.getAllByRole("listbox", { name: "Schritt" })).toHaveLength(1);
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
  // Seit Testnotiz 03.10., #2 ohne Minimum: das Maximum beginnt beim Schritt.
  it("zaehlt das Maximum im Takt des Schritts, ab dem Schritt, mit ∞ am Ende", () => {
    render(<ModellBelastungRad />);

    expect(zeilen("Maximum").slice(0, 3)).toEqual(["2,5", "5", "7,5"]);
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

    expect(zeilen("Maximum").slice(0, 3)).toEqual(["10", "20", "30"]);
    // Das Bestandsminimum 5 liegt nicht im Takt von 10 -- es gilt der Schritt.
    expect(feldwert("loadMin")).toBe("10");
  });

  it("zaehlt auch am Laufband im Takt des Schritts", async () => {
    render(<ModellBelastungRad kategorie="cardio" />);

    await auswaehlen("Belastung", "km/h");

    expect(zeilen("Maximum").slice(0, 3)).toEqual(["0,5", "1", "1,5"]);
    expect(zeilen("Maximum").at(-1)).toBe("∞");
  });

  // Testnotiz 03.10., #2: wer links anfaengt, stellt zuerst den Takt ein.
  it("steht mit dem Schritt links, vor dem Maximum", () => {
    render(<ModellBelastungRad />);

    const spalten = screen.getAllByRole("listbox").map((liste) => liste.getAttribute("aria-label"));
    expect(spalten).toEqual(["Schritt", "Maximum"]);
  });

  // Testnotiz 03.10., #1: Kraft oder Cardio ist vorher gefragt.
  it("fest auf Cardio: kein Kategoriefeld und kein kg", async () => {
    render(<ModellBelastungRad kategorie="cardio" />);

    expect(screen.queryByRole("button", { name: "Kategorie" })).toBeNull();
    expect(feldwert("category")).toBe("cardio");
    expect(feldwert("loadUnit")).toBe("watt");

    fireEvent.click(screen.getByRole("button", { name: "Belastung" }));
    const optionen = (await screen.findAllByRole("option")).map((zeile) => zeile.textContent);
    expect(optionen).not.toContain("kg");
    expect(optionen).toContain("km/h");
  });

  it("fest auf Kraft: kg ohne Belastungs- und Nebenbelastungsfeld", () => {
    render(<ModellBelastungRad kategorie="kraft" />);

    expect(screen.queryByRole("button", { name: "Kategorie" })).toBeNull();
    expect(screen.queryByRole("button", { name: "Belastung" })).toBeNull();
    expect(screen.queryByRole("button", { name: "Nebenbelastung" })).toBeNull();
    expect(feldwert("category")).toBe("kraft");
    expect(feldwert("loadUnit")).toBe("kg");
  });

  it("stellt beim Wechsel auf Cardio eine Cardio-Einheit ein", async () => {
    render(<ModellBelastungRad />);

    await auswaehlen("Kategorie", "Cardio");

    expect(feldwert("loadUnit")).toBe("watt");
    expect(feldwert("loadStep")).toBe("5");
  });
});
