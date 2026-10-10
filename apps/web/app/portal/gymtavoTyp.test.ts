import { describe, expect, it } from "vitest";
import { TYP_FELD, typAusFormular } from "./gymtavoTyp";

function formular(wert?: string): FormData {
  const daten = new FormData();
  if (wert !== undefined) daten.set(TYP_FELD, wert);
  return daten;
}

describe("typAusFormular", () => {
  it("uebernimmt einen gewaehlten Typ", () => {
    expect(typAusFormular(formular("typ-1"), true)).toEqual({ ok: true, catalogModelId: "typ-1" });
  });

  it("verlangt den Typ, sobald es Typen gibt -- leer gewaehlt", () => {
    const antwort = typAusFormular(formular(""), true);
    expect(antwort.ok).toBe(false);
    expect(!antwort.ok && antwort.error).toMatch(/Gymtavo-Gerätetyp/);
  });

  it("verlangt den Typ auch, wenn das Formular noch ohne Feld geladen war", () => {
    expect(typAusFormular(formular(), true).ok).toBe(false);
  });

  it("laesst ohne Typen alles beim Alten", () => {
    expect(typAusFormular(formular(), false)).toEqual({ ok: true, catalogModelId: undefined });
    expect(typAusFormular(formular(""), false)).toEqual({ ok: true, catalogModelId: undefined });
  });
});
