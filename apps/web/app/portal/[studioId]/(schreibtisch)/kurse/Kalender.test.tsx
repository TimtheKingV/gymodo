// @vitest-environment jsdom
import { cleanup, render, screen, within } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { AnsichtUmschalter, Monatsraster, Wochenstreifen } from "./Kalender";
import { kalenderTage } from "./woche";

afterEach(cleanup);

const sessions = [{ localDay: "2026-09-01", status: "planned" }];

/** Testnotiz 25.09., #1. */
describe("AnsichtUmschalter", () => {
  it("markiert die aktive Ansicht und verlinkt die andere", () => {
    render(<AnsichtUmschalter ansicht="woche" wocheHref="/k?woche=x" monatHref="/k?ansicht=monat" />);
    const leiste = screen.getByRole("navigation", { name: "Ansicht" });
    expect(within(leiste).getByRole("link", { name: "Woche" }).getAttribute("aria-current")).toBe(
      "page",
    );
    const monat = within(leiste).getByRole("link", { name: "Monat" });
    expect(monat.getAttribute("aria-current")).toBeNull();
    expect(monat.getAttribute("href")).toBe("/k?ansicht=monat");
  });
});

describe("Wochenstreifen", () => {
  it("zeigt sieben Tage, die zum Abschnitt des Tages springen", () => {
    render(<Wochenstreifen tage={kalenderTage("2026-08-31", 7, "2026-09-02", sessions)} />);
    const links = screen.getAllByRole("link");
    expect(links).toHaveLength(7);
    expect(links[1]!.getAttribute("href")).toBe("#tag-2026-09-01");
    expect(links[1]!.getAttribute("aria-label")).toBe("Dienstag, 1. September · 1 Kurs");
    expect(links[2]!.getAttribute("aria-current")).toBe("date");
  });
});

describe("Monatsraster", () => {
  it("fuehrt per Tipp in die Woche des Tages", () => {
    render(
      <Monatsraster
        basis="/k"
        tage={kalenderTage("2026-08-31", 35, "2026-09-02", sessions, "2026-09")}
      />,
    );
    const tag = screen.getByRole("link", { name: "Dienstag, 1. September · 1 Kurs" });
    expect(tag.getAttribute("href")).toBe("/k?woche=2026-09-01#tag-2026-09-01");
    expect(screen.getAllByRole("link")).toHaveLength(35);
  });
});
