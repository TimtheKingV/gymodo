// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { FormularOffenKontext } from "./FormularOffen";
import { Hinzufuegen, useHinzufuegen } from "./Hinzufuegen";

afterEach(cleanup);

describe("Hinzufuegen", () => {
  function formular(offen: boolean) {
    render(
      <Hinzufuegen knopf="Gerät hinzufügen" titel="Modell anlegen" offen={offen}>
        <form>
          <label>
            Name <input name="name" />
          </label>
        </form>
      </Hinzufuegen>,
    );
  }

  it("zeigt bei bestehender Liste nur den Knopf", () => {
    formular(false);
    expect(screen.getByRole("button", { name: "+ Gerät hinzufügen" })).toBeTruthy();
    expect(screen.queryByLabelText("Name")).toBeNull();
  });

  it("klappt auf Klick auf, setzt den Fokus ins erste Feld und klappt wieder zu", () => {
    formular(false);
    fireEvent.click(screen.getByRole("button", { name: "+ Gerät hinzufügen" }));
    const feld = screen.getByLabelText("Name");
    expect(document.activeElement).toBe(feld);

    fireEvent.click(screen.getByRole("button", { name: "Modell anlegen schließen" }));
    expect(screen.queryByLabelText("Name")).toBeNull();
    expect(document.activeElement).toBe(
      screen.getByRole("button", { name: "+ Gerät hinzufügen" }),
    );
  });

  it("steht bei leerer Liste offen, ohne Schliessen und ohne Fokus zu stehlen", () => {
    formular(true);
    expect(screen.getByLabelText("Name")).toBeTruthy();
    expect(screen.queryByRole("button", { name: /schließen/ })).toBeNull();
    expect(document.activeElement).toBe(document.body);
  });

  /**
   * Testnotiz 23.09. (zweite Sitzung), #1: offen stehen unten "Abbrechen"
   * und Speichern, nach dem Speichern klappt es zu -- auch wenn es fuer eine
   * leere Liste offen begonnen hat.
   */
  function FormularMitAbbrechen() {
    const hinzufuegen = useHinzufuegen();
    return (
      <form>
        <label>
          Name <input name="name" />
        </label>
        <button type="button" onClick={() => hinzufuegen?.schliessen()}>
          Abbrechen
        </button>
      </form>
    );
  }

  it("schliesst mit abbrechenImFormular ueber das Formular, ohne Schliessen im Kopf", () => {
    render(
      <Hinzufuegen knopf="Weitere Einstellung hinzufügen" titel="Einstellung anlegen" offen abbrechenImFormular>
        <FormularMitAbbrechen />
      </Hinzufuegen>,
    );
    expect(screen.queryByRole("button", { name: /schließen/ })).toBeNull();
    fireEvent.click(screen.getByRole("button", { name: "Abbrechen" }));
    expect(screen.queryByLabelText("Name")).toBeNull();
    expect(screen.getByRole("button", { name: "+ Weitere Einstellung hinzufügen" })).toBeTruthy();
  });

  it("meldet dem Ablauf, ob es offen ist", () => {
    const melden = vi.fn();
    render(
      <FormularOffenKontext.Provider value={melden}>
        <Hinzufuegen knopf="Weitere Einstellung hinzufügen" titel="Einstellung anlegen" offen abbrechenImFormular>
          <FormularMitAbbrechen />
        </Hinzufuegen>
      </FormularOffenKontext.Provider>,
    );
    expect(melden).toHaveBeenLastCalledWith(true);
    fireEvent.click(screen.getByRole("button", { name: "Abbrechen" }));
    expect(melden).toHaveBeenLastCalledWith(false);
  });
});
