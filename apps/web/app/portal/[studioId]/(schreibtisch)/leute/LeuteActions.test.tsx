// @vitest-environment jsdom
import { cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import type { StudioMember } from "@fitretro/domain";

vi.mock("../../../actions", () => ({
  mitgliedEntfernen: vi.fn(),
  mitgliedRolleAendern: vi.fn(async () => ({ ok: true })),
}));
vi.mock("next/link", () => ({
  default: ({ href, children, ...rest }: { href: string; children: React.ReactNode }) => (
    <a href={href} {...rest}>
      {children}
    </a>
  ),
}));

import { MitarbeiterZeile } from "./LeuteActions";

afterEach(cleanup);

function person(role: StudioMember["role"]): StudioMember {
  return { userId: "u1", email: "anna@studio.de", role, joinedAt: "2026-09-01T10:00:00Z" };
}

function zeile(role: StudioMember["role"], selbst = false) {
  render(
    <ul>
      <MitarbeiterZeile
        studioId="s1"
        pfad="/portal/s1/leute/mitarbeiter"
        person={person(role)}
        seit="seit 1. September 2026"
        selbst={selbst}
      />
    </ul>,
  );
}

/** Testnotiz 25.09., #5: Stift statt breitem Knopf. */
describe("MitarbeiterZeile", () => {
  it("zeigt einen Stift und das Herabstufen erst nach dem Druck", () => {
    zeile("trainer");
    expect(screen.queryByRole("button", { name: /herabstufen/i })).toBeNull();

    fireEvent.click(screen.getByRole("button", { name: "anna@studio.de bearbeiten" }));
    expect(screen.getByRole("button", { name: "Zum Mitglied herabstufen" })).toBeTruthy();
  });

  it("die eigene Zeile traegt keinen Stift", () => {
    zeile("trainer", true);
    expect(screen.getByText("Das bist du")).toBeTruthy();
    expect(screen.queryByRole("button", { name: /bearbeiten/ })).toBeNull();
  });

  it("der Inhaber traegt keinen Stift", () => {
    zeile("owner");
    expect(screen.queryByRole("button", { name: /bearbeiten/ })).toBeNull();
  });
});
