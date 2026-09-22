// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { UebungUmfangRad } from "./UebungUmfangRad";

afterEach(cleanup);

beforeAll(() => {
  Element.prototype.scrollIntoView = vi.fn();
});

function feldwert(name: string): string | null {
  const feld = document.querySelector<HTMLInputElement>(`input[name="${name}"]`);
  return feld ? feld.value : null;
}

describe("UebungUmfangRad", () => {
  it("steht auf Wiederholungen 8 bis 12, mit den bisherigen Spaltennamen", () => {
    render(<UebungUmfangRad />);

    expect(feldwert("volumeKind")).toBe("reps");
    expect(feldwert("targetMin")).toBe("8");
    expect(feldwert("targetMax")).toBe("12");
    expect(screen.getByRole("listbox", { name: "Wiederholungen ab" })).toBeTruthy();
    expect(screen.getByRole("listbox", { name: "bis" })).toBeTruthy();
  });

  it("zeigt Minuten mit 15 bis 20, wenn die Art wechselt", async () => {
    render(<UebungUmfangRad />);

    fireEvent.click(screen.getByRole("button", { name: "Umfang" }));
    fireEvent.click(await screen.findByRole("option", { name: "Minuten" }));

    expect(feldwert("volumeKind")).toBe("seconds");
    expect(feldwert("targetMin")).toBe("15");
    expect(feldwert("targetMax")).toBe("20");
    expect(screen.getByRole("listbox", { name: "Minuten ab" })).toBeTruthy();
  });

  it("zeigt Meter mit 2000 bis 5000", async () => {
    render(<UebungUmfangRad />);

    fireEvent.click(screen.getByRole("button", { name: "Umfang" }));
    fireEvent.click(await screen.findByRole("option", { name: "Meter" }));

    expect(feldwert("volumeKind")).toBe("meters");
    expect(feldwert("targetMin")).toBe("2000");
    expect(feldwert("targetMax")).toBe("5000");
  });
});
