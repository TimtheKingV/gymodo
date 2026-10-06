// @vitest-environment jsdom
import { act, cleanup, render } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Kaufleiste } from "./Kaufleiste";
import { stubIntersectionObserver } from "./testhilfen";

let io: ReturnType<typeof stubIntersectionObserver>;

function scrollen(y: number) {
  Object.defineProperty(window, "scrollY", { value: y, configurable: true });
  window.dispatchEvent(new Event("scroll"));
}

beforeEach(() => {
  io = stubIntersectionObserver();
  vi.stubGlobal("requestAnimationFrame", (cb: FrameRequestCallback) => {
    cb(0);
    return 1;
  });
  vi.stubGlobal("cancelAnimationFrame", () => {});
  document.body.innerHTML =
    '<a id="held-aktion" href="#"></a><section id="cta"><a id="cta-link" href="#">App laden</a></section><footer id="fuss"></footer>';
  Object.defineProperty(document.documentElement, "scrollHeight", { value: 5000, configurable: true });
  scrollen(0);
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const leiste = () => document.querySelector("aside")!;

function zeigen() {
  render(
    <Kaufleiste
      anker="held-aktion"
      verdecker={["cta", "fuss"]}
      titel="Gymtavo"
      merkmale={["Tap am Gerät", "Deine Werte", "Für iPhone"]}
      aktion={{ href: "https://apps.apple.com/", text: "App laden" }}
    />,
    { container: document.body.appendChild(document.createElement("div")) },
  );
}

describe("Kaufleiste", () => {
  it("startet versteckt: inert und aria-hidden, nicht nur unsichtbar", () => {
    zeigen();
    expect(leiste().hasAttribute("inert")).toBe(true);
    expect(leiste().getAttribute("aria-hidden")).toBe("true");
    expect(leiste().hasAttribute("data-sichtbar")).toBe(false);
  });

  it("erscheint, sobald der Hero-Knopf oben raus ist", () => {
    zeigen();
    act(() => {
      scrollen(820);
      io.melden(document.getElementById("held-aktion")!, {
        isIntersecting: false,
        boundingClientRect: { top: -40, bottom: -10 } as DOMRectReadOnly,
      });
    });
    expect(leiste().hasAttribute("data-sichtbar")).toBe(true);
    expect(leiste().hasAttribute("inert")).toBe(false);
    expect(leiste().getAttribute("aria-hidden")).toBeNull();
  });

  it("weicht dem Fuss", () => {
    zeigen();
    act(() => {
      scrollen(820);
      io.melden(document.getElementById("held-aktion")!, {
        isIntersecting: false,
        boundingClientRect: { top: -40, bottom: -10 } as DOMRectReadOnly,
      });
      io.melden(document.getElementById("fuss")!, { isIntersecting: true });
    });
    expect(leiste().hasAttribute("data-sichtbar")).toBe(false);
  });

  // Inert nimmt der Leiste den Fokus; ohne Weitergabe landete er auf body
  // und die Tastatur faenge oben neu an (WCAG 2.4.3).
  it("gibt den Fokus an den sichtbaren Verdecker weiter, bevor sie weicht", () => {
    zeigen();
    act(() => {
      scrollen(820);
      io.melden(document.getElementById("held-aktion")!, {
        isIntersecting: false,
        boundingClientRect: { top: -40, bottom: -10 } as DOMRectReadOnly,
      });
    });
    act(() => leiste().querySelector("a")!.focus());
    act(() => io.melden(document.getElementById("cta")!, { isIntersecting: true }));
    expect(leiste().hasAttribute("inert")).toBe(true);
    expect(document.activeElement?.id).toBe("cta-link");
  });

  it("gibt den Fokus an den Hero-Knopf zurueck, wenn der wieder im Bild ist", () => {
    zeigen();
    const anker = document.getElementById("held-aktion")!;
    act(() => {
      scrollen(820);
      io.melden(anker, { isIntersecting: false, boundingClientRect: { top: -40, bottom: -10 } as DOMRectReadOnly });
    });
    act(() => leiste().querySelector("a")!.focus());
    act(() => {
      scrollen(0);
      io.melden(anker, { isIntersecting: true, boundingClientRect: { top: 700, bottom: 764 } as DOMRectReadOnly });
    });
    expect(document.activeElement).toBe(anker);
  });
});
