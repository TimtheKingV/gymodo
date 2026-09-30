import { expect, type Page } from "@playwright/test";

/**
 * Eine Zeile im Scroll-Rad auswaehlen (bausteine/EinstellungRad.tsx) -- kein
 * Eingabefeld, kein Chip. Playwright kennt "an die Mitte scrollen" nicht
 * von selbst: dieser Helfer zentriert die Zielzeile direkt per scrollTop,
 * nach derselben Formel, die ein echter Scroll am Ende ebenso ergibt
 * (scrollTop = Index * Zeilenhoehe, siehe EinstellungRad.tsx).
 *
 * `spalte` ist die Spaltenbeschriftung (z. B. "Von", "Minimum"), `wert` der
 * angezeigte Text der Zielzeile (z. B. "8", "keine").
 *
 * Gescrollt wird so lange, bis die Auswahl STEHT, nicht einmal.
 *
 * Der Grund ist ein Wettlauf mit der Hydrierung: RadSpalte stellt seine
 * Bahn beim Einhaengen in einem useEffect auf den Anfangswert. Trifft der
 * Testscroll die Seite, bevor ihr JavaScript uebernommen hat, hoert
 * niemand auf das Scroll-Ereignis -- und kurz darauf setzt genau dieser
 * Effekt die Bahn zurueck. Ein einmaliger Versuch wartet danach zwanzig
 * Sekunden auf eine Auswahl, die nie wieder angestossen wird. Schlimmer
 * noch, wenn der Effekt erst NACH der Zusicherung greift: der Test liest
 * seine Auswahl, geht weiter, und abgeschickt wird der Startwert. Der
 * Wiederholversuch deckt beide Faelle.
 */
export async function radWaehlen(page: Page, spalte: string, wert: string) {
  const liste = page.getByRole("listbox", { name: spalte, exact: true });
  const zeile = liste.getByRole("option", { name: wert, exact: true });

  await expect(async () => {
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
    // Kurz, damit ein verlorener Scroll schnell noch einmal gesetzt wird --
    // die Gesamtgeduld steht unten in toPass.
    await expect(zeile).toHaveAttribute("aria-selected", "true", { timeout: 1_000 });
  }).toPass({ timeout: 20_000 });
}
