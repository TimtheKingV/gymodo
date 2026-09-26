// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";

import { ExemplarFormular } from "./ExemplarFormular";

// jsdom kennt scrollIntoView nicht; die Auswahl ruft es beim Oeffnen.
beforeAll(() => {
  Element.prototype.scrollIntoView = () => {};
});

afterEach(cleanup);

const typen = [
  { id: "m-1", name: "Beinpresse", geraete: ["1", "2"] },
  { id: "m-2", name: "Latzug", geraete: [] },
];

/** Testnotiz 25.09., #7: ein weiteres Geraet eines vorhandenen Typs. */
describe("ExemplarFormular", () => {
  it("traegt den gewaehlten Geraetetyp ins Formular", () => {
    const { container } = render(<ExemplarFormular action={vi.fn()} typen={typen} />);
    const versteckt = container.querySelector<HTMLInputElement>('input[name="modelId"]');
    expect(versteckt?.value).toBe("m-1");

    fireEvent.click(screen.getByRole("button", { name: /Gerätetyp/ }));
    fireEvent.click(screen.getByRole("option", { name: /Latzug/ }));
    expect(versteckt?.value).toBe("m-2");
  });

  it("fragt nur Nummer und Standort ab -- der Rest kommt vom Geraetetyp", () => {
    render(<ExemplarFormular action={vi.fn()} typen={typen} />);
    expect(screen.getByLabelText("Nummer")).toBeTruthy();
    expect(screen.getByLabelText("Standort")).toBeTruthy();
    expect(screen.queryByLabelText("Hersteller")).toBeNull();
    expect(screen.getByRole("button", { name: "Gerät anlegen" })).toBeTruthy();
  });

  it("nennt die schon vergebenen Nummern des Typs", () => {
    render(<ExemplarFormular action={vi.fn()} typen={typen} />);
    expect(screen.getByText(/Schon vergeben: 1, 2/)).toBeTruthy();
  });
});
