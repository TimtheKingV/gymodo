// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useState } from "react";
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

describe("Auswahl im Formular", () => {
  // AktionsFormular mit nurBeiAenderung sieht nur input-Ereignisse; ein
  // verstecktes Feld, dessen Wert React setzt, meldet keines. Ohne dieses
  // Ereignis bliebe "Änderungen speichern" nach einer Typwahl gesperrt.
  function ImFormular({ onInput }: { onInput: () => void }) {
    const [wert, setWert] = useState("");
    return (
      <form onInput={onInput}>
        <Auswahl name="typ" value={wert} onChange={setWert} optionen={optionen} ariaLabel="Typ" />
      </form>
    );
  }

  it("meldet eine Wahl als input-Ereignis an das Formular", () => {
    const onInput = vi.fn();
    render(<ImFormular onInput={onInput} />);
    expect(onInput).not.toHaveBeenCalled();

    fireEvent.click(screen.getByRole("button", { name: "Typ" }));
    fireEvent.click(screen.getByRole("option", { name: "Beinpresse" }));

    expect(onInput).toHaveBeenCalledTimes(1);
    expect((document.querySelector('input[name="typ"]') as HTMLInputElement).value).toBe("c");
  });
});

describe("Auswahl als Pflichtfeld", () => {
  // React 19 leert ein Formular nach jeder Server-Action, auch nach einer
  // abgelehnten. Ohne Pruefung im Browser verloere der Trainer seine
  // Eingaben, nur weil er den Gymtavo-Typ vergessen hat.
  function Pflicht({ onSubmit }: { onSubmit: () => void }) {
    const [wert, setWert] = useState("");
    return (
      <form
        onSubmit={(ereignis) => {
          ereignis.preventDefault();
          onSubmit();
        }}
      >
        <Auswahl
          name="typ"
          value={wert}
          onChange={setWert}
          optionen={optionen}
          ariaLabel="Typ"
          pflicht="Wähle den Typ."
        />
        <button type="submit">Weiter</button>
      </form>
    );
  }

  it("haelt das Absenden ohne Wahl an und sagt warum", () => {
    const onSubmit = vi.fn();
    render(<Pflicht onSubmit={onSubmit} />);

    act(() => (document.querySelector("form") as HTMLFormElement).requestSubmit());

    expect(onSubmit).not.toHaveBeenCalled();
    expect(screen.getByText("Wähle den Typ.")).toBeTruthy();
  });

  it("laesst nach einer Wahl absenden", () => {
    const onSubmit = vi.fn();
    render(<Pflicht onSubmit={onSubmit} />);
    fireEvent.click(screen.getByRole("button", { name: "Typ" }));
    fireEvent.click(screen.getByRole("option", { name: "Kabelzug" }));

    act(() => (document.querySelector("form") as HTMLFormElement).requestSubmit());

    expect(onSubmit).toHaveBeenCalledTimes(1);
    expect(screen.queryByText("Wähle den Typ.")).toBeNull();
  });
});

