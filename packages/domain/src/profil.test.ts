import { describe, expect, it } from "vitest";
import { DomainError } from "./errors.js";
import { pruefeAnzeigename, pruefeProfil } from "./profil.js";

describe("pruefeAnzeigename", () => {
  it("nimmt einen gewoehnlichen Vornamen an", () => {
    expect(pruefeAnzeigename({ displayName: "Lena" })).toBe("Lena");
  });

  it("schneidet Leerzeichen ab", () => {
    expect(pruefeAnzeigename({ displayName: "  Lena  " })).toBe("Lena");
  });

  it("weist einen leeren Namen ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "   " })).toThrow(DomainError);
  });

  it("weist einen zu langen Namen ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "L".repeat(61) })).toThrow(DomainError);
  });

  it("weist einen fehlenden Rumpf ab", () => {
    expect(() => pruefeAnzeigename({})).toThrow(DomainError);
  });

  // Der Name steht auf einem Screen, nicht in einem Log --
  // Zeilenumbrueche haetten dort nichts zu suchen.
  it("weist einen Zeilenumbruch ab", () => {
    expect(() => pruefeAnzeigename({ displayName: "Lena\nWagner" })).toThrow(DomainError);
  });
});

describe("pruefeProfil", () => {
  it("nimmt ein leeres Teilobjekt an -- nichts zu aendern ist erlaubt", () => {
    expect(pruefeProfil({})).toEqual({});
  });

  it("laesst jedes Feld einzeln setzen und mit null loeschen", () => {
    expect(pruefeProfil({ sex: "female" })).toEqual({ sex: "female" });
    expect(pruefeProfil({ ageBand: "25_34" })).toEqual({ ageBand: "25_34" });
    expect(pruefeProfil({ heightCm: 168 })).toEqual({ heightCm: 168 });
    expect(pruefeProfil({ trainingGoal: "lose_weight" })).toEqual({ trainingGoal: "lose_weight" });
    expect(pruefeProfil({ heightCm: null, sex: null })).toEqual({ heightCm: null, sex: null });
  });

  it("weist Werte ausserhalb der Listen ab", () => {
    expect(() => pruefeProfil({ ageBand: "30_35" })).toThrow(/Altersspanne/);
    expect(() => pruefeProfil({ sex: "x" })).toThrow(/Geschlecht/);
    expect(() => pruefeProfil({ trainingGoal: "run_marathon" })).toThrow(/Richtung/);
  });

  it("haelt die Groesse in 100 bis 250 cm und ganzzahlig", () => {
    expect(() => pruefeProfil({ heightCm: 99 })).toThrow(/100/);
    expect(() => pruefeProfil({ heightCm: 251 })).toThrow(/250/);
    expect(() => pruefeProfil({ heightCm: 168.5 })).toThrow();
  });

  it("nimmt onboardingDone nur als true", () => {
    expect(pruefeProfil({ onboardingDone: true })).toEqual({ onboardingDone: true });
    expect(() => pruefeProfil({ onboardingDone: false })).toThrow();
  });

  it("weist den Abschlusszeitpunkt als Feld ab -- den setzt der Server", () => {
    expect(() => pruefeProfil({ onboardingCompletedAt: "2026-09-14T10:00:00Z" })).toThrow();
  });

  it("prueft den Namen weiterhin wie bisher", () => {
    expect(pruefeProfil({ displayName: "  Lena " })).toEqual({ displayName: "Lena" });
    expect(() => pruefeProfil({ displayName: "" })).toThrow(/leer/);
  });
});
