// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";

vi.mock("next/link", () => ({
  default: ({ href, children, ...rest }: { href: string; children: React.ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}));

import { NochZuTun } from "./NochZuTun";

afterEach(cleanup);

const punkte = [
  {
    art: "blockiert" as const,
    titel: "Kein Foto",
    grund: "Niemand erkennt das Gerät wieder.",
    href: "/a",
    label: "Foto hinzufügen",
  },
  {
    art: "unvollstaendig" as const,
    titel: "1 Übung ohne Einweisungsvideo",
    grund: "Nutzbar, nur ohne Anleitung.",
    href: "/b",
    label: "Video hinzufügen",
  },
];

describe("NochZuTun", () => {
  it("steht eingeklappt da und nennt im Kopf nur die Anzahl", () => {
    const { container } = render(<NochZuTun punkte={punkte} />);
    const klappe = container.querySelector("details")!;
    expect(klappe).toBeTruthy();
    expect(klappe.open).toBe(false);

    const kopf = klappe.querySelector("summary")!;
    expect(kopf.textContent).toContain("Noch zu tun");
    expect(kopf.textContent).toContain("2 Punkte offen");
  });

  it("traegt die Punkte in der benannten Liste hinter dem Kopf", () => {
    const { container } = render(<NochZuTun punkte={punkte} />);
    container.querySelector("details")!.open = true;
    const liste = screen.getByRole("list", { name: "Noch zu tun" });
    expect(liste.querySelectorAll("li")).toHaveLength(2);
  });

  it("zeigt ohne offene Punkte nur den Fertig-Text", () => {
    const { container } = render(<NochZuTun punkte={[]} fertigText="Alles da." />);
    expect(container.querySelector("details")).toBeNull();
    expect(screen.getByText("Alles da.")).toBeTruthy();
  });
});
