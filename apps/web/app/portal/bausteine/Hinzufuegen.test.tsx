// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { Hinzufuegen } from "./Hinzufuegen";

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
});
