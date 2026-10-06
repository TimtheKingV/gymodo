// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { SchritteIndikatoren } from "./SchritteIndikatoren";
import { stubIntersectionObserver, stubMatchMedia } from "./testhilfen";

let io: ReturnType<typeof stubIntersectionObserver>;
const scrollIntoView = vi.fn();

beforeEach(() => {
  io = stubIntersectionObserver();
  Element.prototype.scrollIntoView = scrollIntoView;
  document.body.innerHTML = '<ol><li id="s-1"></li><li id="s-2"></li><li id="s-3"></li></ol>';
});
afterEach(() => {
  cleanup();
  scrollIntoView.mockReset();
  vi.unstubAllGlobals();
});

const ids = ["s-1", "s-2", "s-3"];
const titel = ["Tippen", "Trainieren", "Weiterkommen"];

describe("SchritteIndikatoren", () => {
  it("markiert die Folie, die zu 60 % sichtbar ist", () => {
    stubMatchMedia(() => false);
    render(<SchritteIndikatoren ids={ids} titel={titel} />);
    act(() => io.melden(document.getElementById("s-2")!, { isIntersecting: true }));
    expect(screen.getByRole("button", { name: "Schritt 2: Trainieren" }).getAttribute("aria-current")).toBe("step");
    expect(screen.getByRole("button", { name: "Schritt 1: Tippen" }).hasAttribute("aria-current")).toBe(false);
  });

  it("Tipp scrollt weich, bei reduzierter Bewegung sofort", () => {
    stubMatchMedia(() => false);
    render(<SchritteIndikatoren ids={ids} titel={titel} />);
    fireEvent.click(screen.getByRole("button", { name: "Schritt 3: Weiterkommen" }));
    expect(scrollIntoView).toHaveBeenLastCalledWith({ behavior: "smooth", block: "nearest", inline: "start" });
    cleanup();

    stubMatchMedia((q) => q.includes("reduce"));
    render(<SchritteIndikatoren ids={ids} titel={titel} />);
    fireEvent.click(screen.getByRole("button", { name: "Schritt 3: Weiterkommen" }));
    expect(scrollIntoView).toHaveBeenLastCalledWith({ behavior: "auto", block: "nearest", inline: "start" });
  });
});
