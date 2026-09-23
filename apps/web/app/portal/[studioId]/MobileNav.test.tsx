// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeAll, describe, expect, it, vi } from "vitest";

vi.mock("next/navigation", () => ({ usePathname: () => "/portal/s1" }));
vi.mock("next/link", () => ({
  default: ({ href, children, ...rest }: { href: string; children: React.ReactNode }) => (
    <a
      href={href}
      {...rest}
      onClick={(event) => event.preventDefault()}
    >
      {children}
    </a>
  ),
}));
vi.mock("../actions", () => ({ abmelden: vi.fn() }));

import { MobileNav } from "./MobileNav";

// jsdom kennt showModal()/close() nicht vollstaendig -- nachgebildet, so wie
// der Browser das open-Attribut setzt und beim Schliessen "close" feuert.
beforeAll(() => {
  HTMLDialogElement.prototype.showModal = function showModal(this: HTMLDialogElement) {
    this.setAttribute("open", "");
  };
  HTMLDialogElement.prototype.close = function close(this: HTMLDialogElement) {
    if (!this.hasAttribute("open")) return;
    this.removeAttribute("open");
    this.dispatchEvent(new Event("close"));
  };
});

afterEach(cleanup);

describe("MobileNav", () => {
  function oeffnen() {
    render(
      <MobileNav
        studioId="s1"
        studioName="Studio Nord"
        email="trainer@example.org"
        zahlen={{ geraete: 2, erreichbar: 1, vorrat: 0, mitglieder: 3, mitarbeiter: 1 }}
      />,
    );
    fireEvent.click(screen.getByRole("button", { name: "Menü öffnen" }));
    return document.querySelector("dialog")!;
  }

  it("schliesst die Schublade sofort beim Klick auf einen Bereich, nicht erst nach dem Laden", () => {
    const schublade = oeffnen();
    expect(schublade.hasAttribute("open")).toBe(true);

    fireEvent.click(screen.getByRole("link", { name: /Geräte/ }));

    expect(schublade.hasAttribute("open")).toBe(false);
  });

  it("bleibt offen bei einem Klick in die Schublade, der kein Link ist", () => {
    const schublade = oeffnen();
    fireEvent.click(screen.getByText("Trainerportal"));
    expect(schublade.hasAttribute("open")).toBe(true);
  });
});
