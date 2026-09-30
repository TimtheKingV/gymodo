// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen, waitFor } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { Hinzufuegen } from "./bausteine/Hinzufuegen";
import { EinstellungFormular } from "./EinstellungFormular";
import type { ActionResult } from "./actions";

vi.mock("./actions", () => ({}));

afterEach(cleanup);

function imHinzufuegen(
  action = vi.fn(async (): Promise<ActionResult> => ({ ok: true })),
) {
  render(
    <Hinzufuegen
      knopf="Weitere Einstellung hinzufügen"
      titel="Einstellung anlegen"
      offen
      abbrechenImFormular
    >
      <EinstellungFormular action={action} />
    </Hinzufuegen>,
  );
  return action;
}

/** Testnotiz 23.09. (zweite Sitzung), #1. */
describe("EinstellungFormular im Ablauf", () => {
  it("traegt unten Speichern und Abbrechen", () => {
    imHinzufuegen();
    expect(screen.getByRole("button", { name: "Einstellung speichern" })).toBeTruthy();
    fireEvent.click(screen.getByRole("button", { name: "Abbrechen" }));
    expect(screen.getByRole("button", { name: "+ Weitere Einstellung hinzufügen" })).toBeTruthy();
  });

  it("klappt nach dem Speichern zu", async () => {
    const action = imHinzufuegen();
    fireEvent.click(screen.getByRole("button", { name: "Einstellung speichern" }));
    await waitFor(() => expect(action).toHaveBeenCalledTimes(1));
    await waitFor(() =>
      expect(screen.getByRole("button", { name: "+ Weitere Einstellung hinzufügen" })).toBeTruthy(),
    );
  });

  it("klappt bei einem Fehler nicht zu", async () => {
    imHinzufuegen(vi.fn(async (): Promise<ActionResult> => ({ ok: false, error: "Gibt es schon." })));
    fireEvent.click(screen.getByRole("button", { name: "Einstellung speichern" }));
    await waitFor(() => expect(screen.getByRole("alert").textContent).toBe("Gibt es schon."));
    expect(screen.getByRole("button", { name: "Einstellung speichern" })).toBeTruthy();
  });
});

/** Die Spalte so scrollen, wie es der Finger tut, und das Bild abwarten. */
async function drehen(spalte: string, anzeige: string) {
  const rad = screen.getByRole("listbox", { name: spalte });
  const zeilen = [...rad.querySelectorAll('[role="option"]')].map((zeile) => zeile.textContent);
  const index = zeilen.indexOf(anzeige);
  expect(index, `${anzeige} in ${spalte}`).toBeGreaterThanOrEqual(0);
  rad.scrollTop = index * 40;
  fireEvent.scroll(rad);
  await act(() => new Promise((fertig) => requestAnimationFrame(() => fertig(null))));
}

function gewaehlt(spalte: string): string | null {
  return screen
    .getByRole("listbox", { name: spalte })
    .querySelector('[aria-selected="true"]')!.textContent;
}

function feldwert(name: string): string {
  return document.querySelector<HTMLInputElement>(`input[name="${name}"]`)!.value;
}

/** Testnotiz 23.09. (zweite Sitzung), #2. */
describe("EinstellungFormular: Name aus dem Rad", () => {
  it("zeigt zuerst nur das Rad, kein Textfeld", () => {
    imHinzufuegen();
    expect(screen.getByRole("listbox", { name: "Einstellung" })).toBeTruthy();
    expect(screen.queryByLabelText("Beschriftung")).toBeNull();
    // Der erste Vorschlag ist schon gewaehlt und die Beschriftung.
    expect(feldwert("label")).toBe("Wiederholungen");
  });

  it("uebernimmt den gewaehlten Vorschlag als Beschriftung", async () => {
    imHinzufuegen();
    await drehen("Einstellung", "Sitzhöhe");
    expect(feldwert("label")).toBe("Sitzhöhe");
    expect(feldwert("key")).toBe("sitzhoehe");
  });

  it("zeigt bei Sonstiges das Textfeld", async () => {
    imHinzufuegen();
    await drehen("Einstellung", "Sonstiges …");
    const feld = screen.getByLabelText("Beschriftung") as HTMLInputElement;
    expect(feld.required).toBe(true);
    fireEvent.change(feld, { target: { value: "Fußstütze" } });
    expect(feldwert("key")).toBe("fussstuetze");
  });

  it("stellt fuer Winkel Grad, Schritt 5 und 0 bis 90 vor", async () => {
    imHinzufuegen();
    await drehen("Einstellung", "Winkel");
    expect(gewaehlt("Einheit")).toBe("°");
    expect(gewaehlt("Schritt")).toBe("5");
    expect(gewaehlt("Minimum")).toBe("0");
    expect(gewaehlt("Maximum")).toBe("90");
    expect(feldwert("unit")).toBe("°");
  });
});

/** Testnotiz 23.09. (zweite Sitzung), #3. */
describe("EinstellungFormular: Minimum/Maximum im Takt", () => {
  it("zaehlt nach Schritt 5 in 5er-Schritten", async () => {
    imHinzufuegen();
    await drehen("Schritt", "5");
    const minimum = [
      ...screen.getByRole("listbox", { name: "Minimum" }).querySelectorAll('[role="option"]'),
    ].map((zeile) => zeile.textContent);
    expect(minimum.slice(0, 4)).toEqual(["0", "5", "10", "15"]);
  });
});
