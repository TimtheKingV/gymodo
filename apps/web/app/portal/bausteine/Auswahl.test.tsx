// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Auswahl } from "./Auswahl";

afterEach(cleanup);

// jsdom kennt kein Layout und damit kein scrollIntoView; Auswahl ruft es
// beim Oeffnen, damit die markierte Zeile sichtbar ist.
Element.prototype.scrollIntoView = vi.fn();

/**
 * Die Suche ist fuer lange Listen da (Gymtavo-Typen, Nachtrag 10.1): ohne
 * sie muesste der Trainer durch hunderte Zeilen blaettern. Geprueft wird,
 * was sie zeigt und was ein Enter waehlt -- nicht, wie sie aussieht.
 */
const optionen = [
  { wert: "a", anzeige: "Kabelzug" },
  { wert: "b", anzeige: "Langhantel" },
  { wert: "c", anzeige: "Beinpresse" },
];

describe("Auswahl mit Suche", () => {
  it("filtert die Zeilen nach dem Suchtext und waehlt mit Enter", () => {
    const onChange = vi.fn();
    render(
      <Auswahl value="" onChange={onChange} optionen={optionen} ariaLabel="Typ" suche="Typ suchen" />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Typ" }));
    const feld = screen.getByRole("searchbox", { name: "Typ suchen" });
    fireEvent.change(feld, { target: { value: "HANT" } });
    expect(screen.getAllByRole("option").map((o) => o.textContent)).toEqual(["Langhantel"]);
    fireEvent.keyDown(feld, { key: "Enter" });
    expect(onChange).toHaveBeenCalledWith("b");
  });

  it("sagt, wenn nichts passt", () => {
    render(
      <Auswahl value="" onChange={() => {}} optionen={optionen} ariaLabel="Typ" suche="Typ suchen" />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Typ" }));
    fireEvent.change(screen.getByRole("searchbox", { name: "Typ suchen" }), {
      target: { value: "xyz" },
    });
    expect(screen.queryAllByRole("option")).toHaveLength(0);
    expect(screen.getByText("Kein Treffer.")).toBeTruthy();
  });

  it("ohne suche bleibt es die bisherige Auswahl", () => {
    render(<Auswahl value="" onChange={() => {}} optionen={optionen} ariaLabel="Typ" />);
    fireEvent.click(screen.getByRole("button", { name: "Typ" }));
    expect(screen.queryByRole("searchbox")).toBeNull();
    expect(screen.getAllByRole("option")).toHaveLength(3);
  });
});
