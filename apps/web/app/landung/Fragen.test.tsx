// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it } from "vitest";
import { Fragen } from "./Fragen";

afterEach(cleanup);

const fragen = [
  { frage: "Kostet die App etwas?", antwort: "Nein." },
  { frage: "Was misst sie?", antwort: "Nichts </script><b>x</b>" },
];

describe("Fragen", () => {
  it("jede Frage ist ein aufklappbares details mit der Frage als summary", () => {
    const { container } = render(<Fragen id="fragen" titel="Fragen" fragen={fragen} />);
    expect(container.querySelectorAll("details")).toHaveLength(2);
    expect(screen.getByText("Kostet die App etwas?").tagName).toBe("SUMMARY");
  });

  it("liefert FAQPage-JSON-LD mit denselben Texten", () => {
    const { container } = render(<Fragen id="fragen" titel="Fragen" fragen={fragen} />);
    const ld = JSON.parse(container.querySelector('script[type="application/ld+json"]')!.textContent!);
    expect(ld["@type"]).toBe("FAQPage");
    expect(ld.mainEntity).toHaveLength(2);
    expect(ld.mainEntity[1].acceptedAnswer.text).toBe("Nichts </script><b>x</b>");
  });

  it("ein < im Text bricht nicht aus dem script aus", () => {
    const { container } = render(<Fragen id="fragen" titel="Fragen" fragen={fragen} />);
    const roh = container.querySelector('script[type="application/ld+json"]')!.innerHTML;
    expect(roh).not.toContain("</script>");
  });
});
