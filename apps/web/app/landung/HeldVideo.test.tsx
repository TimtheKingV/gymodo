// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HeldVideo } from "./HeldVideo";
import { stubIntersectionObserver, stubMatchMedia } from "./testhilfen";

const play = () => HTMLMediaElement.prototype.play;
const pause = () => HTMLMediaElement.prototype.pause;

beforeEach(() => {
  // jsdom implementiert keine Medienwiedergabe.
  vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
  vi.spyOn(HTMLMediaElement.prototype, "pause").mockImplementation(() => {});
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("HeldVideo", () => {
  it("bei reduzierter Bewegung kein Video -- das Poster im Held bleibt", () => {
    stubIntersectionObserver();
    stubMatchMedia((q) => q.includes("reduce") || q.includes("max-width"));
    const { container } = render(<HeldVideo src="/v.mp4" poster="/p.png" />);
    expect(container.querySelector("video")).toBeNull();
  });

  it("ab 990 px kein Video", () => {
    stubIntersectionObserver();
    stubMatchMedia(() => false);
    const { container } = render(<HeldVideo src="/v.mp4" poster="/p.png" />);
    expect(container.querySelector("video")).toBeNull();
  });

  it("spielt erst, wenn es sichtbar ist, und laesst sich anhalten (WCAG 2.2.2)", async () => {
    const io = stubIntersectionObserver();
    stubMatchMedia((q) => q.includes("max-width"));
    const { container } = render(<HeldVideo src="/v.mp4" poster="/p.png" />);
    const video = container.querySelector("video")!;
    expect(play()).not.toHaveBeenCalled();

    await act(async () => io.melden(video, { isIntersecting: true }));
    expect(play()).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole("button", { name: "Video anhalten" }));
    expect(pause()).toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Video abspielen" })).toBeDefined();

    // Von Hand angehalten bleibt angehalten, auch wenn es wieder ins Bild kommt.
    await act(async () => io.melden(video, { isIntersecting: false }));
    await act(async () => io.melden(video, { isIntersecting: true }));
    expect(play()).toHaveBeenCalledTimes(1);
  });
});
