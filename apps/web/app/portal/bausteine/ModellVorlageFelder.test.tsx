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
    expect(feldwert("loadMax")).toBe("");
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
    const onTyp = vi.fn();
    render(<ModellVorlageFelder typen={[brust]} onTyp={onTyp} />);
    await typWaehlen("Brustpresse");
    expect(onTyp).toHaveBeenLastCalledWith(brust);
  });
});
