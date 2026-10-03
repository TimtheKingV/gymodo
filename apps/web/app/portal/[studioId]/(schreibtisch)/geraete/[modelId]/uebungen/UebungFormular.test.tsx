// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("../../../../../actions", () => ({ videoBestaetigen: vi.fn() }));
vi.mock("../../../../../bausteine/videoUpload", () => ({ ladeVideoHoch: vi.fn() }));

import { UebungFormular } from "./UebungFormular";

beforeAll(() => {
  URL.createObjectURL = () => "blob:video";
  URL.revokeObjectURL = () => {};
});

afterEach(cleanup);

function formular() {
  render(
    <UebungFormular
      studioId="s1"
      modelId="m1"
      action={vi.fn(async () => ({ ok: true as const, linkId: "l1" }))}
    />,
  );
}

/** Testnotiz 23.09. (zweite Sitzung), #4. */
describe("UebungFormular: Einweisungsvideo", () => {
  it("zeigt ohne Video eine Flaeche statt der kleinen Kachel", () => {
    formular();
    expect(screen.queryByText("Kein Video")).toBeNull();
    expect(screen.getByRole("button", { name: /Video aufnehmen oder auswählen/ })).toBeTruthy();
  });

  it("zeigt nach der Wahl das Video in voller Breite", () => {
    formular();
    const datei = new File(["x"], "latzug.mp4", { type: "video/mp4" });
    fireEvent.change(screen.getByLabelText("Einweisungsvideo wählen"), {
      target: { files: [datei] },
    });
    expect(screen.getByRole("button", { name: "Video Einweisungsvideo abspielen" })).toBeTruthy();
    expect(screen.getByRole("button", { name: "Anderes Video wählen" })).toBeTruthy();
  });
});
