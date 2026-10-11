// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";
import { ModellVorlageFelder } from "./ModellVorlageFelder";
import type { TypVorlage } from "./typVorlage";

afterEach(cleanup);

// jsdom kennt kein scrollIntoView; Auswahl.tsx ruft es beim Oeffnen fuer
// die hervorgehobene Zeile auf.
beforeAll(() => {
  Element.prototype.scrollIntoView = vi.fn();
});

const brust: TypVorlage = {
  id: "t1", name: "Brustpresse", manufacturer: null, category: "kraft",
  loadUnit: "kg", loadStep: 5, loadMin: 0, loadMax: 100,
  secondaryUnit: null, secondaryStep: null, secondaryMin: null, secondaryMax: null, hatFoto: true,
  fotoUrl: null, produkte: [],
};
const platzhalter: TypVorlage = { ...brust, id: "t2", name: "Beinpresse", loadStep: 1, loadMax: null, hatFoto: false };
const laufband: TypVorlage = {
  ...brust, id: "t3", name: "Laufband", category: "cardio", loadUnit: "kmh", loadStep: 0.5,
  loadMax: null, secondaryUnit: "pct", secondaryStep: 0.5, secondaryMin: 0, secondaryMax: 15,
};

function feldwert(name: string): string | null {
  return document.querySelector<HTMLInputElement>(`input[name="${name}"]`)?.value ?? null;
}

async function typWaehlen(name: string) {
  fireEvent.click(screen.getByRole("button", { name: "Gymtavo-Gerätetyp" }));
  fireEvent.click(await screen.findByRole("option", { name }));
}

describe("ModellVorlageFelder", () => {
  it("fuellt Name und Belastung vom Typ und sagt es", async () => {
    render(<ModellVorlageFelder typen={[brust, platzhalter]} kategorie="kraft" />);
    await typWaehlen("Brustpresse");
    expect(feldwert("catalogModelId")).toBe("t1");
    expect(feldwert("name")).toBe("Brustpresse");
    expect(feldwert("loadStep")).toBe("5");
    expect(feldwert("loadMax")).toBe("100");
    expect(screen.getByText("Werte vom Typ Brustpresse übernommen – bitte ans Gerät anpassen.")).toBeTruthy();
  });

  it("ein Typwechsel ueberschreibt Belastung und vorgeschlagenen Namen", async () => {
    render(<ModellVorlageFelder typen={[brust, platzhalter]} kategorie="kraft" />);
    await typWaehlen("Brustpresse");
    await typWaehlen("Beinpresse");
    expect(feldwert("name")).toBe("Beinpresse");
    // Review Focus 1: 1 kg gibt es im kg-Rad nicht, es rastet auf 1,25.
    expect(feldwert("loadStep")).toBe("1,25");
    // Minimum und Maximum im Takt des eingerasteten Schritts, nicht in 1 kg:
    // sonst schluege die Progression Gewichte vor, die es am Geraet nicht gibt.
    expect(feldwert("loadMin")).toBe("1,25");
    expect(feldwert("loadMax")).toBe("");
    const maxima = [...screen.getByRole("listbox", { name: "Maximum" }).querySelectorAll('[role="option"]')]
      .map((zeile) => zeile.textContent);
    expect(maxima).toContain("2,5");
    expect(maxima).not.toContain("2");
  });

  it("ein selbst getippter Name bleibt beim Typwechsel", async () => {
    render(<ModellVorlageFelder typen={[brust, platzhalter]} kategorie="kraft" />);
    fireEvent.change(screen.getByLabelText("Name"), { target: { value: "Brustpresse links" } });
    await typWaehlen("Brustpresse");
    await typWaehlen("Beinpresse");
    expect(feldwert("name")).toBe("Brustpresse links");
  });

  it("in der Halle kommt die Kategorie vom Typ, samt Nebenbelastung", async () => {
    render(<ModellVorlageFelder typen={[brust, laufband]} />);
    await typWaehlen("Laufband");
    expect(feldwert("category")).toBe("cardio");
    expect(feldwert("loadUnit")).toBe("kmh");
    expect(feldwert("secondaryUnit")).toBe("pct");
    expect(feldwert("secondaryMax")).toBe("15");
  });

  it("meldet den gewaehlten Typ nach aussen", async () => {
    const onVorlage = vi.fn();
    render(<ModellVorlageFelder typen={[brust]} onVorlage={onVorlage} />);
    await typWaehlen("Brustpresse");
    expect(onVorlage).toHaveBeenLastCalledWith({ typ: brust, produkt: null });
  });
});

const gym80: TypVorlage["produkte"][number] = {
  id: "p1", manufacturer: "gym80", series: "Pure Kraft", name: "Brustpresse", modelCode: "4345",
  note: "Scheibenbeladen, eigenes Lastprofil.", load: { unit: "kg", step: 2.5, min: 5, max: 150 }, secondary: null, fotoUrl: null,
};
const mitProdukten: TypVorlage = {
  ...brust, id: "t4", name: "Brustpresse Pro", fotoUrl: "https://bild/typ",
  produkte: [gym80, { ...gym80, id: "p2", manufacturer: "Technogym", series: null, name: "Chest Press", modelCode: null, note: null, load: null }],
};

async function herstellerWaehlen(anzeige: string) {
  fireEvent.click(screen.getByRole("button", { name: "Hersteller" }));
  fireEvent.click(await screen.findByRole("option", { name: anzeige }));
}

describe("ModellVorlageFelder Herstellermodelle", () => {
  it("ohne Produkte am Typ bleibt der Hersteller ein Textfeld", async () => {
    render(<ModellVorlageFelder typen={[brust]} kategorie="kraft" />);
    await typWaehlen("Brustpresse");
    expect(screen.getByLabelText("Hersteller").tagName).toBe("INPUT");
  });

  it("Modell gewaehlt: Name, Hersteller, Belastung, Hinweis und Herkunft kommen vom Produkt", async () => {
    render(<ModellVorlageFelder typen={[mitProdukten]} kategorie="kraft" />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("gym80 (1)");
    fireEvent.click(screen.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }));

    expect(feldwert("name")).toBe("Pure Kraft Brustpresse 4345");
    expect(feldwert("manufacturer")).toBe("gym80");
    expect(feldwert("catalogProductId")).toBe("p1");
    expect(feldwert("loadStep")).toBe("2,5");
    expect(feldwert("loadMin")).toBe("5");
    expect(feldwert("loadMax")).toBe("150");
    expect(screen.getByText("Scheibenbeladen, eigenes Lastprofil.")).toBeTruthy();
    // Ohne eigenes Produktfoto zeigt die Karte die Typzeichnung als Symbolbild.
    expect(screen.getByRole("radio", { name: /Symbolbild/ })).toBeTruthy();
  });

  it("Mein Modell ist nicht dabei: Typwerte bleiben, Hersteller gesetzt, keine Herkunft", async () => {
    render(<ModellVorlageFelder typen={[mitProdukten]} kategorie="kraft" />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("gym80 (1)");
    fireEvent.click(screen.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }));
    fireEvent.click(screen.getByRole("radio", { name: "Mein Modell ist nicht dabei" }));

    expect(feldwert("name")).toBe("Brustpresse Pro");
    expect(feldwert("manufacturer")).toBe("gym80");
    expect(feldwert("catalogProductId")).toBeNull();
    expect(feldwert("loadStep")).toBe("5");
  });

  it("Anderer Hersteller oeffnet das Textfeld", async () => {
    render(<ModellVorlageFelder typen={[mitProdukten]} kategorie="kraft" />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("Anderer Hersteller");
    fireEvent.change(screen.getByLabelText("Herstellername"), { target: { value: "Eigenbau" } });
    expect(feldwert("manufacturer")).toBe("Eigenbau");
    expect(screen.queryByRole("radio")).toBeNull();
  });

  it("Review Focus 1: ein Typwechsel setzt Hersteller und Modell zurueck", async () => {
    const onVorlage = vi.fn();
    render(<ModellVorlageFelder typen={[mitProdukten, brust]} kategorie="kraft" onVorlage={onVorlage} />);
    await typWaehlen("Brustpresse Pro");
    await herstellerWaehlen("gym80 (1)");
    fireEvent.click(screen.getByRole("radio", { name: /Pure Kraft Brustpresse 4345/ }));
    await typWaehlen("Brustpresse");

    expect(feldwert("catalogProductId")).toBeNull();
    expect(feldwert("name")).toBe("Brustpresse");
    expect(feldwert("loadStep")).toBe("5");
    expect(feldwert("loadMax")).toBe("100");
    expect(screen.getByLabelText("Hersteller").tagName).toBe("INPUT");
    expect(onVorlage).toHaveBeenLastCalledWith({ typ: brust, produkt: null });
  });
});
