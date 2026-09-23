// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { VideoAbspieler } from "./VideoAbspieler";

// jsdom kennt showModal()/close() nicht vollstaendig -- nachgebildet, so wie
// der Browser das open-Attribut setzt und beim Schliessen "close" feuert.
beforeAll(() => {
  HTMLDialogElement.prototype.showModal = function showModal(this: HTMLDialogElement) {
    this.setAttribute("open", "");
  };
  HTMLDialogElement.prototype.close = function close(this: HTMLDialogElement) {
    if (!this.hasAttribute("open")) return;
    this.removeAttribute("open");
    this.dispatchEvent(new Event("close"));
  };
  // Autoplay gibt es in jsdom nicht.
  HTMLMediaElement.prototype.play = () => Promise.resolve();
  HTMLMediaElement.prototype.pause = () => {};
});

afterEach(cleanup);

describe("VideoAbspieler", () => {
  it("zeigt das Standbild als Knopf, der Player ist noch zu", () => {
    render(<VideoAbspieler url="https://x/v.mp4" titel="Beinpresse" />);
    expect(screen.getByRole("button", { name: "Video Beinpresse abspielen" })).toBeTruthy();
    expect(document.querySelector("dialog")!.hasAttribute("open")).toBe(false);
  });

  it("oeffnet auf Klick den Player im Vollbild-Dialog, startet ihn und schliesst ihn wieder", () => {
    const gestartet = vi.spyOn(HTMLMediaElement.prototype, "play");
    render(<VideoAbspieler url="https://x/v.mp4" titel="Beinpresse" />);
    fireEvent.click(screen.getByRole("button", { name: "Video Beinpresse abspielen" }));

    const dialog = document.querySelector("dialog")!;
    expect(dialog.hasAttribute("open")).toBe(true);
    const player = dialog.querySelector("video")!;
    expect(player.getAttribute("src")).toBe("https://x/v.mp4");
    expect(player.controls).toBe(true);
    // Im Klick gestartet, nicht per autoPlay -- sonst bleibt iOS stumm.
    expect(gestartet).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole("button", { name: "Video schließen" }));
    expect(dialog.hasAttribute("open")).toBe(false);
  });

  it("ist in voller Breite die Vorgabe und in der Zeile eine Kachel", () => {
    const { rerender } = render(<VideoAbspieler url="https://x/v.mp4" titel="A" />);
    const voll = screen.getByRole("button", { name: "Video A abspielen" }).className;
    rerender(<VideoAbspieler url="https://x/v.mp4" titel="A" groesse="zeile" />);
    const zeile = screen.getByRole("button", { name: "Video A abspielen" }).className;
    expect(voll).not.toBe(zeile);
  });
});
