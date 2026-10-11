import { describe, expect, it } from "vitest";
import { fotoPfadJeModell } from "./machine-photos.js";

describe("fotoPfadJeModell", () => {
  it("gibt einem Gymtavo-Typ sein eigenes Foto", () => {
    const pfade = fotoPfadJeModell([], [{ id: "typ", photo_path: "gymtavo/typ.png" }]);

    expect(pfade.get("typ")).toBe("gymtavo/typ.png");
  });

  it("laesst ein Studio-Modell ohne Foto das Foto seines Typs erben", () => {
    const pfade = fotoPfadJeModell(
      [{ id: "modell", photo_path: null, catalog_model_id: "typ" }],
      [{ id: "typ", photo_path: "gymtavo/typ.png" }],
    );

    expect(pfade.get("modell")).toBe("gymtavo/typ.png");
  });

  it("zieht das eigene Foto dem des Typs vor", () => {
    const pfade = fotoPfadJeModell(
      [{ id: "modell", photo_path: "studio/eigen.jpg", catalog_model_id: "typ" }],
      [{ id: "typ", photo_path: "gymtavo/typ.png" }],
    );

    expect(pfade.get("modell")).toBe("studio/eigen.jpg");
  });

  it("laesst ein Modell ohne Foto und ohne Typ weg", () => {
    const pfade = fotoPfadJeModell(
      [{ id: "modell", photo_path: null, catalog_model_id: null }],
      [{ id: "typ", photo_path: null }],
    );

    expect(pfade.has("modell")).toBe(false);
    expect(pfade.has("typ")).toBe(false);
  });
});
