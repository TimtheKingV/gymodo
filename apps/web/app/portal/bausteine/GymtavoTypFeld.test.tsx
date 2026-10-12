// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { GymtavoTypFeld } from "./GymtavoTypFeld";

afterEach(cleanup);

// jsdom kennt kein scrollIntoView; Auswahl.tsx ruft es beim Oeffnen auf.
beforeAll(() => {
  Element.prototype.scrollIntoView = vi.fn();
});

const typen = [
  { id: "k", name: "Kabelzug", manufacturer: null, retired: false },
  { id: "alt", name: "Hoher Kabelzug + Seil", manufacturer: null, retired: true },
];

function optionen(): string[] {
  fireEvent.click(screen.getByRole("button", { name: "Gymtavo-Gerätetyp" }));
  return screen.getAllByRole("option").map((o) => o.textContent ?? "");
}

// Testnotiz 12.10., #1: abgeloeste Typen nicht mehr anbieten -- ein schon
// zugeordneter bleibt aber stehen, sonst verloere das Formular still die
// Zuordnung beim naechsten Speichern.
describe("GymtavoTypFeld", () => {
  it("bietet abgeloeste Typen nicht an", () => {
    render(<GymtavoTypFeld typen={typen} start={null} />);
    expect(optionen()).toEqual(["Kabelzug"]);
  });

  it("zeigt den schon zugeordneten abgeloesten Typ weiter", () => {
    render(<GymtavoTypFeld typen={typen} start="alt" />);
    expect(optionen()).toEqual(["Kabelzug", "Hoher Kabelzug + Seil"]);
  });
});
