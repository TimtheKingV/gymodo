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

import { StiftLink } from "./Stift";

afterEach(cleanup);

describe("StiftLink", () => {
  it("traegt die Zahl offener Punkte als Marke und im Namen", () => {
    render(<StiftLink href="/x" label="Bizeps Curl bearbeiten" offen={2} />);
    const link = screen.getByRole("link", { name: "Bizeps Curl bearbeiten (2 Punkte offen)" });
    expect(link.textContent).toBe("2");
  });

  it("sagt einen offenen Punkt in der Einzahl", () => {
    render(<StiftLink href="/x" label="Beinpresse bearbeiten" offen={1} />);
    expect(screen.getByRole("link", { name: "Beinpresse bearbeiten (1 Punkt offen)" })).toBeTruthy();
  });

  it("zeigt ohne offene Punkte keine Marke", () => {
    render(<StiftLink href="/x" label="Latzug bearbeiten" />);
    expect(screen.getByRole("link", { name: "Latzug bearbeiten" }).textContent).toBe("");
  });
});
