// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { AktionsFormular, Feld } from "./Form";
import { Rad } from "./bausteine/EinstellungRad";

afterEach(cleanup);

/**
 * Testnotiz 22.09., #9: nach "Änderungen speichern" stand der Knopf
 * unveraendert da, und es sah aus, als haette es nicht geklappt. Mit
 * nurBeiAenderung ist der Knopf nur scharf, wenn sich etwas geaendert hat,
 * und nach dem Speichern steht der Erfolgstext daneben.
 */
describe("AktionsFormular mit nurBeiAenderung", () => {
  function formular() {
    const action = vi.fn(async () => ({ ok: true as const }));
    render(
      <AktionsFormular
        action={action}
        submitLabel="Änderungen speichern"
        erfolgText="Gespeichert ✓"
        nurBeiAenderung
      >
        <Feld name="name" label="Name" defaultValue="Latzug" />
        <Rad
          spalten={[
            {
              name: "schritt",
              label: "Schritt",
              werte: [
                { wert: "1", anzeige: "1" },
                { wert: "2", anzeige: "2" },
              ],
              start: "1",
            },
          ]}
        />
      </AktionsFormular>,
    );
    return {
      action,
      knopf: screen.getByRole<HTMLButtonElement>("button", { name: "Änderungen speichern" }),
      feld: screen.getByLabelText("Name"),
    };
  }

  it("ist ohne Aenderung aus", () => {
    const { knopf } = formular();
    expect(knopf.disabled).toBe(true);
  });

  it("wird durch Tippen scharf und beim Zuruecktippen wieder aus", () => {
    const { knopf, feld } = formular();
    fireEvent.input(feld, { target: { value: "Latzug breit" } });
    expect(knopf.disabled).toBe(false);
    fireEvent.input(feld, { target: { value: "Latzug" } });
    expect(knopf.disabled).toBe(true);
  });

  it("sieht auch eine Rad-Wahl als Aenderung", async () => {
    const { knopf } = formular();
    const spalte = screen.getByRole("listbox", { name: "Schritt" });
    spalte.scrollTop = 40;
    fireEvent.scroll(spalte);
    await waitFor(() => expect(knopf.disabled).toBe(false));
  });

  it("quittiert das Speichern und ist danach wieder aus", async () => {
    const { action, knopf, feld } = formular();
    fireEvent.input(feld, { target: { value: "Latzug breit" } });
    await act(async () => {
      fireEvent.click(knopf);
    });
    await waitFor(() => expect(screen.getByText("Gespeichert ✓")).toBeTruthy());
    expect(action).toHaveBeenCalledTimes(1);
    expect(knopf.disabled).toBe(true);

    // Neue Aenderung: Quittung weg, Knopf wieder scharf.
    fireEvent.input(feld, { target: { value: "Latzug eng" } });
    expect(screen.queryByText("Gespeichert ✓")).toBeNull();
    expect(knopf.disabled).toBe(false);
  });
});
