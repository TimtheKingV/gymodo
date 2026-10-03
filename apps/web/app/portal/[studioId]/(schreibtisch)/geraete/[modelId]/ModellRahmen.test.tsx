// @vitest-environment jsdom
import { act, cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

const navigation = vi.hoisted(() => ({ segment: null as string | null, suche: "" }));

vi.mock("next/navigation", () => ({
  useSelectedLayoutSegment: () => navigation.segment,
  useSearchParams: () => new URLSearchParams(navigation.suche),
}));
vi.mock("next/link", () => ({
  default: ({ href, children, ...rest }: { href: string; children: React.ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}));

import { useFormularOffen } from "../../../../bausteine/FormularOffen";
import { ModellRahmen } from "./ModellRahmen";

afterEach(cleanup);

/** Steht fuer das Hinzufuegen-Formular auf der Seite darunter. */
let melden: (offen: boolean) => void = () => {};
function Seitenformular() {
  melden = useFormularOffen();
  return null;
}

function rahmen(
  segment: string | null,
  suche: string,
  anzahl = { einstellungen: 1, uebungen: 1 },
) {
  navigation.segment = segment;
  navigation.suche = suche;
  render(
    <ModellRahmen
      studioId="s1"
      modelId="m1"
      einstellungenZusatz="0 Einstellungen"
      uebungenZusatz="0 · 0 mit Video"
      instanzenZusatz="0 · 0 ohne Tag"
      einstellungenAnzahl={anzahl.einstellungen}
      uebungenAnzahl={anzahl.uebungen}
      nochZuTun={<p>BAND NOCH ZU TUN</p>}
    >
      <p>INHALT DES REITERS</p>
      <Seitenformular />
    </ModellRahmen>,
  );
}

describe("ModellRahmen", () => {
  it("zeigt ohne ?neu Reiterleiste und Band, keine Schrittleiste", () => {
    rahmen("einstellungen", "");
    expect(screen.getByRole("navigation", { name: "Modell" })).toBeTruthy();
    expect(screen.getByText("BAND NOCH ZU TUN")).toBeTruthy();
    expect(screen.getByText("INHALT DES REITERS")).toBeTruthy();
    expect(screen.queryByText(/Schritt \d von 4/)).toBeNull();
  });

  it("zeigt im Ablauf die Schrittleiste statt Reitern und Band", () => {
    rahmen("uebungen", "neu=1");
    expect(screen.getByText("Schritt 3 von 4 · Übungen")).toBeTruthy();
    expect(screen.queryByRole("navigation", { name: "Modell" })).toBeNull();
    expect(screen.queryByText("BAND NOCH ZU TUN")).toBeNull();
    expect(screen.getByText("INHALT DES REITERS")).toBeTruthy();
  });

  it("traegt unten Zurück und Weiter zum naechsten Schritt", () => {
    rahmen("uebungen", "neu=1");
    const fuss = screen.getByRole("navigation", { name: "Ablauf" });
    expect(fuss.querySelector('a[href="/portal/s1/geraete/m1/einstellungen?neu=1"]')!.textContent).toBe(
      "Zurück",
    );
    expect(
      screen.getByRole("link", { name: "Weiter zu den Geräten" }).getAttribute("href"),
    ).toBe("/portal/s1/geraete/m1/instanzen?neu=1");
  });

  it("endet im letzten Schritt mit Fertig auf der Geräteliste", () => {
    rahmen("instanzen", "neu=1");
    expect(screen.getByRole("link", { name: "Fertig" }).getAttribute("href")).toBe(
      "/portal/s1/geraete",
    );
  });

  it("hat im ersten Schritt kein Zurück", () => {
    rahmen(null, "neu=1");
    expect(screen.getByText("Schritt 1 von 4 · Stammdaten")).toBeTruthy();
    expect(screen.queryByRole("link", { name: "Zurück" })).toBeNull();
  });

  // Testnotiz 23.09. (zweite Sitzung), #1 und #5.
  it("zeigt kein Weiter, solange keine Einstellung gespeichert ist", () => {
    rahmen("einstellungen", "neu=1", { einstellungen: 0, uebungen: 0 });
    expect(screen.queryByRole("link", { name: "Weiter zu den Übungen" })).toBeNull();
    expect(screen.getByText("Zuerst eine Einstellung speichern.")).toBeTruthy();
    // Zurueck bleibt -- nur das Weiterkommen haengt am Speichern.
    expect(screen.getByRole("link", { name: "Zurück" })).toBeTruthy();
  });

  it("nimmt Weiter weg, solange das Formular offen ist", () => {
    rahmen("einstellungen", "neu=1", { einstellungen: 2, uebungen: 0 });
    expect(screen.getByRole("link", { name: "Weiter zu den Übungen" })).toBeTruthy();

    act(() => melden(true));
    expect(screen.queryByRole("link", { name: "Weiter zu den Übungen" })).toBeNull();
    expect(screen.getByText("Erst speichern oder abbrechen.")).toBeTruthy();

    act(() => melden(false));
    expect(screen.getByRole("link", { name: "Weiter zu den Übungen" })).toBeTruthy();
  });

  it("zeigt bei den Übungen Weiter erst ab einer Übung", () => {
    rahmen("uebungen", "neu=1", { einstellungen: 1, uebungen: 0 });
    expect(screen.queryByRole("link", { name: "Weiter zu den Geräten" })).toBeNull();
    expect(screen.getByText("Zuerst eine Übung anlegen.")).toBeTruthy();
  });
});
