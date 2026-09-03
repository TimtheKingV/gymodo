// @vitest-environment jsdom
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Zustand } from "./Zustand";

describe("Zustand", () => {
  it("leer nennt den naechsten Schritt", () => {
    render(
      <Zustand
        art="leer"
        titel="Noch kein Gerät angelegt."
        naechsterSchritt="Fang mit dem Gerät an, das am häufigsten benutzt wird."
      />,
    );
    expect(screen.getByText("Noch kein Gerät angelegt.")).toBeDefined();
    expect(
      screen.getByText("Fang mit dem Gerät an, das am häufigsten benutzt wird."),
    ).toBeDefined();
  });

  it("fehler meldet sich als Warnung an, damit ein Screenreader ihn ansagt", () => {
    render(<Zustand art="fehler" titel="Die Summen liessen sich nicht laden." />);
    expect(screen.getByRole("alert")).toBeDefined();
  });

  it("leer ist KEINE Warnung -- ein leeres Studio ist kein Fehler", () => {
    render(<Zustand art="leer" titel="Noch kein Kurs." />);
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("deaktiviert ist nie stumm -- daneben steht, was fehlt", () => {
    render(
      <Zustand art="deaktiviert" titel="Zuweisen" naechsterSchritt="Wähle zuerst ein Gerät." />,
    );
    expect(screen.getByText("Wähle zuerst ein Gerät.")).toBeDefined();
  });

  it("keinRecht sagt, wem die Seite gehoert, statt nur zu sperren", () => {
    render(
      <Zustand
        art="keinRecht"
        titel="Diese Seite ist Trainern und Inhabern vorbehalten."
        naechsterSchritt="Deine eigenen Trainingsdaten siehst du in der App, nicht hier."
      />,
    );
    expect(screen.getByText(/Trainern und Inhabern vorbehalten/)).toBeDefined();
    expect(screen.getByText(/in der App, nicht hier/)).toBeDefined();
  });
});
