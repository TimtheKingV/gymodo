// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { ModellGewichtRad } from "./ModellGewichtRad";

afterEach(cleanup);

function zeilen(spalte: string): (string | null)[] {
  return [...screen.getByRole("listbox", { name: spalte }).querySelectorAll('[role="option"]')].map(
    (zeile) => zeile.textContent,
  );
}

/** Testnotiz 23.09. (zweite Sitzung), #3: Gewicht in Schritten von 5 kg
    heisst Minimum und Maximum 0, 5, 10 … */
describe("ModellGewichtRad", () => {
  it("zaehlt Minimum und Maximum im Takt des Startschritts", () => {
    render(<ModellGewichtRad schrittStart="5" />);
    expect(zeilen("Minimum").slice(0, 3)).toEqual(["0", "5", "10"]);
    expect(zeilen("Maximum").slice(0, 3)).toEqual(["0", "5", "10"]);
    expect(zeilen("Maximum").at(-1)).toBe("∞");
  });

  it("folgt einem neu gewaehlten Schritt", async () => {
    render(<ModellGewichtRad schrittStart="2,5" minStart="5" />);
    expect(zeilen("Minimum").slice(0, 3)).toEqual(["0", "2,5", "5"]);

    const schritt = screen.getByRole("listbox", { name: "Schritt" });
    schritt.scrollTop = zeilen("Schritt").indexOf("10") * 40;
    fireEvent.scroll(schritt);
    await act(() => new Promise((fertig) => requestAnimationFrame(() => fertig(null))));

    expect(zeilen("Minimum").slice(0, 3)).toEqual(["0", "10", "20"]);
    // 5 liegt zwischen 0 und 10 -- der naechstliegende ist der erste Treffer.
    expect(document.querySelector<HTMLInputElement>('input[name="minWeightKg"]')!.value).toBe("0");
  });
});
