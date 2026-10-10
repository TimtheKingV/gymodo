// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("../../../../../VideoUpload", () => ({ VideoUpload: () => null }));
vi.mock("../../../../../actions", () => ({}));

import { GymtavoZeile } from "./GymtavoZeile";
import type { GymtavoZeileDaten } from "./gymtavo";

afterEach(cleanup);

function zeile(teile: Partial<GymtavoZeileDaten> = {}): GymtavoZeileDaten {
  return {
    exerciseId: "e1",
    name: "Face Pull",
    volumeKind: "reps",
    targetMin: 12,
    targetMax: 15,
    herkunft: "angehaengt",
    linkId: "l1",
    eigenesVideo: null,
    katalogVideo: null,
    ...teile,
  };
}

function zeigen(daten: GymtavoZeileDaten) {
  render(
    <ul>
      <GymtavoZeile
        studioId="s1"
        modelId="m1"
        zeile={daten}
        eigeneVideoUrl={undefined}
        katalogVideoUrl={undefined}
        verknuepfen={vi.fn()}
        loesen={vi.fn(async () => ({ ok: true as const }))}
      />
    </ul>,
  );
  fireEvent.click(screen.getByRole("button", { name: /Face Pull bearbeiten/ }));
  fireEvent.click(screen.getByRole("button", { name: "Übung lösen" }));
}

describe("GymtavoZeile", () => {
  // Loesen loescht ein eigenes Video mit (detachCatalogExercise) -- das muss
  // die Rueckfrage sagen, bevor es weg ist.
  it("nennt beim Loesen das eigene Video, das mitgeht", () => {
    zeigen(zeile({ eigenesVideo: { storagePath: "s1/v.mp4", durationS: 20 } }));
    expect(screen.getByRole("button", { name: /eigene Video/ })).toBeTruthy();
  });

  it("fragt ohne eigenes Video nur nach", () => {
    zeigen(zeile());
    expect(screen.getByRole("button", { name: "Wirklich lösen?" })).toBeTruthy();
  });
});
