// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OhneMit } from "./OhneMit";
import { stubIntersectionObserver } from "./testhilfen";

let io: ReturnType<typeof stubIntersectionObserver>;
beforeEach(() => {
  io = stubIntersectionObserver();
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

const props = {
  titel: "Weißt du noch?",
  marke: "Gymtavo",
  ohne: [
    { text: "Sitz 4 oder 5?", x: 26, y: 14 },
    { text: "Wo ist der Zettel?", x: 72, y: 44 },
  ],
  mit: ["Sitz 5 · Lehne 3", "Zuletzt 42,5 kg × 10", "Vorschlag +2,5 kg", "Einweisung ansehen"],
};

const schalter = () => screen.getByRole("switch", { name: "Mit Gymtavo" });

describe("OhneMit", () => {
  it("der Schalter ist ein echter switch und startet auf Ohne", () => {
    render(<OhneMit {...props} />);
    expect(schalter().tagName).toBe("BUTTON");
    expect(schalter().getAttribute("aria-checked")).toBe("false");
  });

  it("schaltet mit der Sonde", () => {
    render(<OhneMit {...props} />);
    act(() => io.melden(screen.getByTestId("ohnemit-sonde"), { isIntersecting: true }));
    expect(schalter().getAttribute("aria-checked")).toBe("true");
    expect(screen.getByTestId("ohnemit-karte").hasAttribute("data-mit")).toBe(true);
  });

  it("ein Tipp haelt gegen die Sonde, bis die Karte den Viewport verlaesst", () => {
    render(<OhneMit {...props} />);
    fireEvent.click(schalter());
    act(() => io.melden(screen.getByTestId("ohnemit-sonde"), { isIntersecting: false }));
    expect(schalter().getAttribute("aria-checked")).toBe("true");

    act(() => io.melden(screen.getByTestId("ohnemit-karte"), { isIntersecting: false }));
    expect(schalter().getAttribute("aria-checked")).toBe("false");
    act(() => io.melden(screen.getByTestId("ohnemit-sonde"), { isIntersecting: true }));
    expect(schalter().getAttribute("aria-checked")).toBe("true");
  });

  it("der Feed laeuft einen Durchgang und steht dann auf dem letzten Eintrag", () => {
    vi.useFakeTimers();
    render(<OhneMit {...props} />);
    fireEvent.click(schalter());
    const eintrag = (t: string) => screen.getByText(t);
    expect(eintrag("Sitz 5 · Lehne 3").style.getPropertyValue("--o")).toBe("0");
    act(() => vi.advanceTimersByTime(1220));
    expect(eintrag("Zuletzt 42,5 kg × 10").style.getPropertyValue("--o")).toBe("0");
    act(() => vi.advanceTimersByTime(10_000));
    expect(eintrag("Einweisung ansehen").style.getPropertyValue("--o")).toBe("0");
  });

  it("beide Listen stehen im Dokument -- der Vergleich ist der Inhalt", () => {
    render(<OhneMit {...props} />);
    expect(screen.getByRole("list", { name: "Ohne Gymtavo" })).toBeDefined();
    expect(screen.getByRole("list", { name: "Mit Gymtavo" })).toBeDefined();
  });
});
