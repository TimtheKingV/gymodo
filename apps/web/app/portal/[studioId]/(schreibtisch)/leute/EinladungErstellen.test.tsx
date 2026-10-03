// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

const token = "ab".repeat(32);
const { erstellen } = vi.hoisted(() => ({ erstellen: vi.fn() }));
vi.mock("../../../actions", () => ({ einladungErstellen: erstellen }));

import { EinladungErstellen } from "./EinladungErstellen";

afterEach(() => {
  cleanup();
  erstellen.mockReset();
});

/** Testnotiz 25.09., #6 -- Moeglichkeit 2. */
describe("EinladungErstellen", () => {
  it("zeigt nach dem Erstellen den Link, und nur dann", async () => {
    erstellen.mockResolvedValue({ ok: true, token });
    render(<EinladungErstellen studioId="s1" pfad="/p" />);
    expect(screen.queryByLabelText("Einladungslink")).toBeNull();

    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: "Einladungslink erstellen" }));
    });

    expect(erstellen).toHaveBeenCalledWith("s1", "/p");
    const feld = screen.getByLabelText<HTMLInputElement>("Einladungslink");
    expect(feld.value).toBe(`${window.location.origin}/einladung/${token}`);
    expect(screen.getByText(/nur jetzt angezeigt/)).toBeTruthy();
  });

  it("kopiert den Link in die Zwischenablage", async () => {
    erstellen.mockResolvedValue({ ok: true, token });
    const schreiben = vi.fn(async () => {});
    Object.defineProperty(navigator, "clipboard", {
      value: { writeText: schreiben },
      configurable: true,
    });
    render(<EinladungErstellen studioId="s1" pfad="/p" />);
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: "Einladungslink erstellen" }));
    });
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: "Link kopieren" }));
    });

    expect(schreiben).toHaveBeenCalledWith(`${window.location.origin}/einladung/${token}`);
    expect(screen.getByRole("button", { name: "Kopiert ✓" })).toBeTruthy();
  });

  it("zeigt einen Fehler statt eines Links", async () => {
    erstellen.mockResolvedValue({ ok: false, error: "Nur Trainer und Inhaber laden ein." });
    render(<EinladungErstellen studioId="s1" pfad="/p" />);
    await act(async () => {
      fireEvent.click(screen.getByRole("button", { name: "Einladungslink erstellen" }));
    });
    expect(screen.getByRole("alert").textContent).toBe("Nur Trainer und Inhaber laden ein.");
    expect(screen.queryByLabelText("Einladungslink")).toBeNull();
  });
});
