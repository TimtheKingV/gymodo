import type { Page } from "@playwright/test";

/**
 * Die drei Abnahmen, die keine Meinung brauchen. Aussehen testet kein Test
 * -- aber ob es genau eine Hauptlandmarke gibt, wie viele Akzentflaechen
 * auf dem Schirm stehen und ob man die Knoepfe trifft, ist zaehlbar.
 */

/** #d4ff3f, so wie getComputedStyle es zurueckgibt. */
export const AKZENT = "rgb(212, 255, 63)";

/**
 * Genau eine erwartet. Zwei bedeuten verschachtelte <main> -- ein
 * Screenreader zaehlt dann zwei Hauptbereiche und sagt bei "zum Hauptteil
 * springen" nicht, welcher gemeint ist.
 */
export async function hauptlandmarken(page: Page): Promise<number> {
  return await page.getByRole("main").count();
}

/**
 * Elemente mit Akzent als FLAECHE. Raender zaehlen nicht: die aktive
 * Rail-Zeile ist eine 2-px-Kante, der Fokusring ein outline, die
 * Sucherecken sind Winkel. Flaeche ist Flaeche.
 *
 * Fortschritt zaehlt ebenso wenig (Befund 11, entschieden am 5.
 * September). Der Uploadbalken traegt den Akzent und behaelt ihn:
 * TelefonVideo.dc.html zeichnet ihn so, TelefonUploads.dc.html zeigt
 * gleich drei davon, und Designsystem 5.1 nennt den Zweck der Regel
 * selbst -- der Akzent sagt, "wo der Nutzer hinfassen muss". Ein Balken
 * ist nichts, wohin man fasst. Die Regel lautet daher: genau eine
 * Akzentflaeche je Bildschirm unter den BEDIENBAREN Flaechen.
 *
 * Diese Funktion sieht den Balken ohnehin nie -- er steht nur waehrend
 * eines laufenden Uploads im Dokument. Nicht, weil sie ihn uebersieht,
 * sondern weil es ihn dann nicht gibt. Die Ausnahme steht hier trotzdem:
 * eine benannte Ausnahme ist besser als eine stille.
 *
 * Gibt Beschreibungen zurueck, keine Zahl -- bei "erwartet 1, waren 2"
 * will man wissen, welche zwei.
 */
export async function akzentflaechen(page: Page): Promise<string[]> {
  return await page.evaluate((akzent) => {
    const treffer: string[] = [];
    for (const el of Array.from(document.querySelectorAll<HTMLElement>("*"))) {
      if (getComputedStyle(el).backgroundColor !== akzent) continue;
      const kasten = el.getBoundingClientRect();
      if (kasten.width === 0 || kasten.height === 0) continue;
      const text = (el.textContent ?? "").trim().slice(0, 40);
      treffer.push(`${el.tagName.toLowerCase()}${text ? ` "${text}"` : ""}`);
    }
    return treffer;
  }, AKZENT);
}

/**
 * Sichtbare Bedienelemente, die niedriger sind als verlangt.
 *
 * Die Mindesthoehe ist ein Parameter, kein fester Wert. Die Global
 * Constraints sagten im selben Satz "Trefferflaechen >= 44 px" und
 * "Nebenaktion 40 px"; entschieden ist: am Schreibtisch gelten 40 px fuer
 * Nebenaktion und zerstoerende Aktion, 44 px fuer Hauptaktion und
 * Eingabefeld. Die Halle unter einrichten/ hat eigene, groessere Masse
 * (Hauptaktion 56, Nebenaktion 48, Feld 52) und wird gegen die geprueft --
 * deshalb ein Parameter und keine Konstante.
 *
 * Textlinks im Fliesstext sind ausgenommen -- ein Link mitten in einem Satz
 * kann keine 44 px hoch sein, ohne die Zeile aufzureissen.
 *
 * #next-logo ist ebenso ausgenommen: Nexts eigener Dev-Tools-Knopf unten
 * links, nicht Teil der Anwendung. Er existiert nur unter `next dev`, nicht
 * im Produktionsbau, den die CI prueft. Er ist zudem ein Timing-Fall, kein
 * fester Befund: derselbe Knopf steht ebenso auf /portal/<id>/tags, aber
 * der dortige Bestandstest in bausteine.spec.ts trifft ihn nicht -- vermutlich,
 * weil der Knopf erst mit einer Verzoegerung nach `load` mountet und dieser
 * Test die Pruefung schneller erreicht, als der Knopf braucht. Ohne den
 * Ausschluss haengt das Ergebnis vom Zufall dieses Wettlaufs ab, nicht vom
 * Seiteninhalt.
 */
export async function zuKleineBedienelemente(
  page: Page,
  mindestHoehe: number,
): Promise<string[]> {
  const auswahl =
    'button:not(#next-logo), [role="button"], input:not([type="hidden"]), select, textarea';
  const elemente = await page.locator(auswahl).all();
  const zuKlein: string[] = [];

  for (const element of elemente) {
    if (!(await element.isVisible())) continue;
    const kasten = await element.boundingBox();
    if (!kasten) continue;
    if (kasten.height + 0.5 < mindestHoehe) {
      const text = ((await element.textContent()) ?? "").trim().slice(0, 40);
      zuKlein.push(`${text || "(ohne Text)"} — ${Math.round(kasten.height)} px`);
    }
  }
  return zuKlein;
}

/**
 * Die eine echte Fehlermeldung einer Seite.
 *
 * getByRole("alert") allein ist in einer Next-Anwendung IMMER mehrdeutig:
 * Next legt einen leeren Route-Announcer mit role="alert" und der id
 * __next-route-announcer__ ins Dokument, damit Screenreader den
 * Seitenwechsel mitbekommen. Playwrights strict mode bricht dann ab, sobald
 * eine echte Meldung dazukommt -- also genau im Fehlerfall, den der Test
 * pruefen will.
 *
 * Der Befund stand seit Phase 2 als Kommentar in einstellungen.spec.ts und
 * ist trotzdem zweimal neu gestolpert worden. Deshalb steht er jetzt hier,
 * als Helfer statt als Kommentar: der Announcer ist der einzige role=alert
 * ohne Text, und ein Ausschluss ueber seine id trifft ihn genau.
 */
export function fehlermeldung(page: Page) {
  return page.getByRole("alert").and(page.locator(":not(#__next-route-announcer__)"));
}
