// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { stubMatchMedia } from "./testhilfen";
import { useReduzierteBewegung } from "./useMedienabfrage";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function Anzeige() {
  return <p>{useReduzierteBewegung() ? "ruhig" : "bewegt"}</p>;
}

describe("useReduzierteBewegung", () => {
  it("liest prefers-reduced-motion", () => {
    stubMatchMedia((q) => q === "(prefers-reduced-motion: reduce)");
    render(<Anzeige />);
    expect(screen.getByText("ruhig")).toBeDefined();
  });

  it("ohne Wunsch bewegt", () => {
    stubMatchMedia(() => false);
    render(<Anzeige />);
    expect(screen.getByText("bewegt")).toBeDefined();
  });
});
