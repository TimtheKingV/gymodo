import { expect, type Page } from "@playwright/test";

/**
 * Eine Zeile im Scroll-Rad auswaehlen (bausteine/ParameterRad.tsx) -- kein
 * Eingabefeld, kein Chip. Playwright kennt "an die Mitte scrollen" nicht
 * von selbst: dieser Helfer zentriert die Zielzeile direkt per scrollTop,
 * nach derselben Formel, die ein echter Scroll am Ende ebenso ergibt
 * (scrollTop = Index * Zeilenhoehe, siehe ParameterRad.tsx).
 *
 * `spalte` ist die Spaltenbeschriftung (z. B. "Von", "Minimum"), `wert` der
 * angezeigte Text der Zielzeile (z. B. "8", "keine").
 */
export async function radWaehlen(page: Page, spalte: string, wert: string) {
  const liste = page.getByRole("listbox", { name: spalte, exact: true });
  const zeile = liste.getByRole("option", { name: wert, exact: true });
  // getBoundingClientRect statt offsetTop: .rad ist selbst position:relative
  // (die Markierungsbahn braucht das), also waere die Zeile ueber
  // offsetTop/offsetParent nicht gegen ihren eigenen Scrollcontainer
  // gemessen, sondern gegen .rad -- die Rechnung stimmt dann nicht mehr.
  await zeile.evaluate((el) => {
    const feld = el.parentElement as HTMLElement;
    const feldKasten = feld.getBoundingClientRect();
    const elKasten = el.getBoundingClientRect();
    const mitteVersatz =
      elKasten.top + elKasten.height / 2 - (feldKasten.top + feldKasten.height / 2);
    feld.scrollTop += mitteVersatz;
    feld.dispatchEvent(new Event("scroll"));
  });
  await expect(zeile).toHaveAttribute("aria-selected", "true");
}
