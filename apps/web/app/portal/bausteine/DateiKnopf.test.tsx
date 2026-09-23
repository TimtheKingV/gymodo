// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { DateiKnopf } from "./DateiKnopf";

afterEach(cleanup);

/** Testnotiz 23.09. (zweite Sitzung), #4: das leere Videofeld selbst oeffnet
    die Auswahl -- aufnehmen oder aus der Mediathek. */
describe("DateiKnopf als Flaeche", () => {
  it("oeffnet auf Klick das versteckte Dateifeld", () => {
    const oeffnen = vi.spyOn(HTMLInputElement.prototype, "click").mockImplementation(() => {});
    render(
      <DateiKnopf
        art="flaeche"
        label="Video aufnehmen oder auswählen"
        ariaLabel="Einweisungsvideo wählen"
        accept="video/mp4"
        onDatei={() => {}}
      />,
    );
    const flaeche = screen.getByRole("button", { name: /Video aufnehmen oder auswählen/ });
    fireEvent.click(flaeche);
    expect(oeffnen).toHaveBeenCalledTimes(1);
    // Kein capture: sonst bietet iOS nur die Kamera an (Testnotiz 22.09., #13).
    expect(screen.getByLabelText("Einweisungsvideo wählen").hasAttribute("capture")).toBe(false);
    oeffnen.mockRestore();
  });

  it("sieht anders aus als der Knopf", () => {
    const { rerender } = render(<DateiKnopf label="A" onDatei={() => {}} />);
    const knopf = screen.getByRole("button", { name: "A" }).className;
    rerender(<DateiKnopf art="flaeche" label="A" onDatei={() => {}} />);
    expect(screen.getByRole("button", { name: /A/ }).className).not.toBe(knopf);
  });
});
