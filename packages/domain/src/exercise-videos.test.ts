import { describe, expect, it } from "vitest";
import { videoPfadJeUebung } from "./exercise-videos.js";

function link(modell: string, uebung: string, pfad?: string) {
  return {
    equipment_model_id: modell,
    exercises: { id: uebung },
    instruction_assets: pfad ? [{ storage_path: pfad }] : [],
  };
}

describe("videoPfadJeUebung", () => {
  it("nimmt das Video des Gymtavo-Typs", () => {
    const pfade = videoPfadJeUebung([link("typ", "u1", "gymtavo/u1.mp4")], new Set(["typ"]));

    expect(pfade.get("u1")).toBe("gymtavo/u1.mp4");
  });

  it("zieht das Video des Studios dem des Katalogs vor, egal in welcher Reihenfolge", () => {
    const pfade = videoPfadJeUebung(
      [link("typ", "u1", "gymtavo/u1.mp4"), link("modell", "u1", "studio/u1.mp4")],
      new Set(["typ"]),
    );

    expect(pfade.get("u1")).toBe("studio/u1.mp4");
  });

  it("faellt auf das Katalogvideo zurueck, wenn das Studio keins hat", () => {
    const pfade = videoPfadJeUebung(
      [link("modell", "u1"), link("typ", "u1", "gymtavo/u1.mp4")],
      new Set(["typ"]),
    );

    expect(pfade.get("u1")).toBe("gymtavo/u1.mp4");
  });

  it("laesst eine Uebung ohne Video weg", () => {
    const pfade = videoPfadJeUebung([link("modell", "u1")], new Set());

    expect(pfade.has("u1")).toBe(false);
  });
});
