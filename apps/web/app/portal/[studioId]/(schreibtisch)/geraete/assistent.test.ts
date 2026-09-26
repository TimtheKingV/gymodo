import { describe, expect, it } from "vitest";
import {
  ASSISTENT_SCHRITTE,
  assistentSchritt,
  assistentStart,
  neuAnsicht,
  weiterSperre,
} from "./assistent";

const studio = "s1";
const modell = "m1";
const basis = "/portal/s1/geraete/m1";

describe("assistentSchritt", () => {
  it("zaehlt vier Schritte in der Reihenfolge der Reiter", () => {
    expect(ASSISTENT_SCHRITTE).toBe(4);
  });

  it("Stammdaten ist Schritt 1 und fuehrt zu den Einstellungen", () => {
    expect(assistentSchritt(studio, modell, null)).toEqual({
      nummer: 1,
      titel: "Stammdaten",
      zurueck: null,
      weiter: { href: `${basis}/einstellungen?neu=1`, label: "Weiter zu den Einstellungen" },
    });
  });

  it("Einstellungen ist Schritt 2, zurueck zu den Stammdaten, weiter zu den Übungen", () => {
    expect(assistentSchritt(studio, modell, "einstellungen")).toEqual({
      nummer: 2,
      titel: "Einstellungen",
      zurueck: `${basis}?neu=1`,
      weiter: { href: `${basis}/uebungen?neu=1`, label: "Weiter zu den Übungen" },
    });
  });

  it("Übungen ist Schritt 3 und fuehrt zu den einzelnen Geräten", () => {
    expect(assistentSchritt(studio, modell, "uebungen")).toEqual({
      nummer: 3,
      titel: "Übungen",
      zurueck: `${basis}/einstellungen?neu=1`,
      weiter: { href: `${basis}/instanzen?neu=1`, label: "Weiter zu den Geräten" },
    });
  });

  it("Einzelne Geräte ist der letzte Schritt und endet auf der Geräteliste", () => {
    expect(assistentSchritt(studio, modell, "instanzen")).toEqual({
      nummer: 4,
      titel: "Einzelne Geräte",
      zurueck: `${basis}/uebungen?neu=1`,
      weiter: { href: "/portal/s1/geraete", label: "Fertig" },
    });
  });

  it("kennt kein anderes Segment", () => {
    expect(assistentSchritt(studio, modell, "irgendwas")).toBeNull();
  });
});

describe("assistentStart", () => {
  it("ist der zweite Schritt: nach dem Anlegen geht es mit den Einstellungen weiter", () => {
    expect(assistentStart(studio, modell)).toBe(`${basis}/einstellungen?neu=1`);
  });
});

/**
 * Testnotiz 23.09. (zweite Sitzung), #1 und #5: "Weiter" erst, wenn in
 * diesem Schritt etwas gespeichert ist -- und bei den Einstellungen nicht,
 * solange das Formular offen steht.
 */
describe("weiterSperre", () => {
  const leer = { einstellungen: 0, uebungen: 0, formularOffen: false };

  it("sperrt die Einstellungen, bis eine gespeichert ist", () => {
    expect(weiterSperre("einstellungen", leer)).toBe("Zuerst eine Einstellung speichern.");
    expect(weiterSperre("einstellungen", { ...leer, einstellungen: 1 })).toBeNull();
  });

  it("sperrt die Einstellungen, solange das Formular offen ist", () => {
    expect(
      weiterSperre("einstellungen", { ...leer, einstellungen: 2, formularOffen: true }),
    ).toBe("Erst speichern oder abbrechen.");
  });

  it("sperrt die Übungen, bis eine angelegt ist", () => {
    expect(weiterSperre("uebungen", leer)).toBe("Zuerst eine Übung anlegen.");
    expect(weiterSperre("uebungen", { ...leer, uebungen: 1, formularOffen: true })).toBeNull();
  });

  it("sperrt Stammdaten und Einzelne Geräte nie", () => {
    expect(weiterSperre(null, leer)).toBeNull();
    expect(weiterSperre("instanzen", leer)).toBeNull();
  });
});

/** Testnotiz 25.09., #7: erst fragen, ob es das Geraet schon gibt. */
describe("neuAnsicht", () => {
  it("fragt zuerst, sobald es einen Geraetetyp gibt", () => {
    expect(neuAnsicht(undefined, 2)).toBe("frage");
  });

  it("ohne Geraetetyp gibt es nichts zu fragen -- direkt die Stammdaten", () => {
    expect(neuAnsicht(undefined, 0)).toBe("typ");
    expect(neuAnsicht("exemplar", 0)).toBe("typ");
  });

  it("folgt der Wahl", () => {
    expect(neuAnsicht("typ", 2)).toBe("typ");
    expect(neuAnsicht("exemplar", 2)).toBe("exemplar");
  });

  it("eine unbekannte Wahl fragt erneut", () => {
    expect(neuAnsicht("quatsch", 2)).toBe("frage");
  });
});
