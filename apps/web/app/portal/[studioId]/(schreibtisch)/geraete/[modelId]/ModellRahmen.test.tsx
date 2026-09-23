// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
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

import { ModellRahmen } from "./ModellRahmen";

afterEach(cleanup);

function rahmen(segment: string | null, suche: string) {
  navigation.segment = segment;
  navigation.suche = suche;
  render(
    <ModellRahmen
      studioId="s1"
      modelId="m1"
      einstellungenZusatz="0 Einstellungen"
      uebungenZusatz="0 · 0 mit Video"
      instanzenZusatz="0 · 0 ohne Tag"
      nochZuTun={<p>BAND NOCH ZU TUN</p>}
    >
      <p>INHALT DES REITERS</p>
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
});
