# Portal-Frontend — Umsetzungsplan

> **Für agentische Ausführung:** ERFORDERLICHE UNTER-SKILL: `superpowers:subagent-driven-development` (empfohlen) oder `superpowers:executing-plans`, Aufgabe für Aufgabe. Die Schritte tragen Checkboxen (`- [ ]`) zum Mitführen.

**Ziel:** Die neunzehn Schreibtisch- und Einstiegsbildschirme des Trainerportals nach den 39 Artboards gestalten — auf einer gemeinsamen Bausteinschicht, mit den vier Zuständen je Seite statt nur dem Gutfall.

**Architektur:** Eine Bausteinschicht unter `apps/web/app/portal/bausteine/` trägt Seitengerüst, Karte, Zeile, Reiter, Kachel und die vier Zustände; die Regeln des Designsystems stehen als Kommentar an genau einer Stelle statt achtmal abgeschrieben. Der Einstieg bekommt eine eigene Hülle, weil er keine Rail hat und andere Maße trägt (28 px Seitenrand statt 40). Die Rail wechselt von „ein Eintrag je Gerätemodell" auf sechs feste Einträge in drei Gruppen. **Keine Migration.**

**Tech-Stack:** Next.js 15 (App Router, Server Components, Server Actions), React 19, TypeScript, CSS-Module, `@fitretro/domain`, Supabase (RLS), Vitest (Unit + Integration), Playwright (E2E).

**Spec:** `docs/superpowers/specs/2026-09-03-portal-frontend-design.md`

**Artboards:** `docs/superpowers/design/portal/` — 39 `.dc.html`. **Dort steht die verbindliche Fassung jedes Bildschirms**, Text wie Anordnung. Der Plan verweist darauf, er zeichnet nicht nach.

**Vorgänger-Specs:** `2026-08-30-designsystem.md` (Tokens, Zustände, Texte), `2026-08-31-trainerportal-struktur-design.md` (§1 Informationsarchitektur, §5 Zustände, §6 Bildschirmverzeichnis), `../plans/2026-08-31-designplan-trainerportal.md` (Global Constraints, wörtlich aus dem Code).

---

## Wie dieser Plan geschrieben ist

Ein Hinweis vorweg, damit ein Prüfer die Dichte nicht für Nachlässigkeit hält:

**Testcode steht vollständig da. Gestaltung steht als Verweis plus Wortlaut.**

Der Grund ist die Rollenverteilung dieses Bauabschnitts. Beim Gang durch die Halle war der Code die Wahrheit und der Plan musste ihn vorwegnehmen. Hier ist das Artboard die Wahrheit — es ist versioniert, es liegt im Repo, und die Global Constraints erklären es ausdrücklich für verbindlich. Jede CSS-Deklaration in diesen Plan zu kopieren hieße, eine zweite Wahrheit anzulegen, die beim ersten Handgriff im Canvas-Editor auseinanderläuft.

Was der Plan deshalb liefert: welches Artboard, welcher Abschnitt daraus, welcher Wortlaut wörtlich, welche Zustände, und den Test, der es festnagelt. Was er nicht liefert: `padding: 16px 20px`.

---

## Globale Rahmenbedingungen

Aus Spec und Global Constraints, wörtlich. Jede Aufgabe steht implizit unter diesen Sätzen.

- **Keine Migration.** Alle Zahlen kommen aus `getStudioCatalog` und `listStudioMembers`, `abmelden` steht in `portal/actions.ts:473`. Wer in diesem Plan eine `.sql`-Datei anlegt, hat sich verlaufen. Die Nummern bleiben bei `0034`; Session 1 hält `0035ff`.
- **Farben.** `bg #0a0b0d` · `well #0f1114` · `surface #14161a` · `surface-raised #1d2026` · `surface-hover #232730` · `line #2a2e36` · `text #f2f4f7` · `text-muted #9ba3af` · `text-faint #5c636e` · `accent #d4ff3f` · `accent-pressed #a8cc2a` · `on-accent #0a0b0d` · `warn #ffb020` · `danger #ff5a4e`. **Immer als `var(--…)`, nie als Literal** — die Tokens stehen in `globals.css`.
- **Maße.** Abstände 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48. Radius 12 (Karte), 10 (Bedienelement), 999 (Pille). Rail 288 px. Inhalt `padding: 32px 40px 48px`, `max-width: 1000px`. **Seitenrand 28 px auf Einstiegsseiten.**
- **Der Einstieg hat eigene Maße — es sind drei Stufen, nicht zwei.** Am 4. September beim Bauen von Abschnitt 1 aufgefallen und an allen sechs Einstiegs-Artboards nachgezählt: sie zeichnen die Hauptaktion durchgehend mit **64 px Höhe, Radius 16, Schrift 17** und das Eingabefeld mit **52 px** — das sind die Maße der Member-App, nicht die des Schreibtischs. Das ist kein Zeichenfehler, sondern folgerichtig: Einstiegsbildschirme tragen eine einzige Handlung, keine dichten Formulare.

  | | Hauptaktion | Nebenaktion | Feld |
  | --- | --- | --- | --- |
  | Schreibtisch (`portal.module.css`) | 44 px, Radius 10 | 40 px | 44 px |
  | **Einstieg (`einstieg.module.css`)** | **64 px, Radius 16** | Textlinks | **52 px** |
  | Halle (`halle.module.css`) | 56 px | 48 px | 52 px |

  Der Implementierer von Aufgabe 6 hat das aus dem Artboard gelesen und richtig gebaut, **bevor** es hier stand. Die Aufgaben 9 bis 11 übernehmen es aus `einstieg.module.css`, statt es neu abzuleiten. **`KeinStudio.dc.html` ist die Ausnahme:** dort steht die Hauptaktion auf 52 px — nachsehen, nicht übernehmen.

- **Trefferflächen am Schreibtisch: Hauptaktion 44 px, Nebenaktion und zerstörende Aktion 40 px, Eingabefeld 44 px.** Das ist die Auflösung von Befund 16, entschieden am 3. September: die Global Constraints sagten im selben Satz „≥ 44 px" und „Nebenaktion 40 px". Code und Artboards sind sich bei 40 einig; die 44 stammt aus Designsystem §4 und ist dort für die Halle hergeleitet — einhändig, im Halbdunkel. Am Schreibtisch liegt eine Maus. **Die Hallenseiten unter `einrichten/` behalten ihre größeren Werte** (`halle.module.css`: Hauptaktion 56, Nebenaktion 48, Feld 52) und werden gegen die geprüft.
- **Genau eine Akzentfläche je Bildschirm.** Der Akzent gehört der einen Hauptaktion. Nebenaktionen sind `surface-raised` mit `line`-Rand, zerstörende Aktionen ein `danger`-Umriss ohne Fläche, `warn` erscheint ausschließlich als Umriss. **Ausnahme: die Tags-Seite trägt null** — sie legt nichts an, sie gibt Auskunft (Canvas-Notiz `note-akzent`).
- **Schrift.** Systemschrift über `--font`, **kein Webfont.** Die Artboards rendern Archivo, weil die Canvas es tut; der Code nimmt `-apple-system, BlinkMacSystemFont, "Segoe UI", …` wie in `globals.css`. Das ist keine Abweichung, sondern Designsystem §3: die erste externe Abhängigkeit löst das Privacy Manifest aus. Alle Ziffern tabellarisch (steht in `globals.css` auf `body`).
- **Texte.** Durchgehend Deutsch mit Umlauten, Du-Form, keine Ausrufezeichen, kein Motivationston. Dezimalkomma, Gewichte immer mit einer Nachkommastelle (`80,0 kg`). Datum ausgeschrieben (`Mo., 31. August 2026`). **Kein Freitext zu Schmerzen, Verletzungen oder Gesundheit — nirgends.**
- **Deutsche Bezeichner im Web-Layer**, englische Funktionsnamen in `packages/domain`. Quellcode-Kommentare in `packages/domain` schreiben Umlaute aus (`Geraet`), Oberflächentexte nicht.
- **Symbole werden gezeichnet.** Inline-SVG, strichbasiert, 14/16/20/24 px, `stroke-width` 1.75–2. Niemals Emoji, niemals Pfeil- oder Dreiecksglyphen.
- **Aussehen testet kein Test.** Keine Farbwerte, keine Pixelpositionen, keine Schriftgrößen in Zusicherungen. Geprüft werden Struktur, Zustände, Rollen, Maße und Zählungen.
- **Die Suiten bleiben auf ihrem Stand:** 85 Unit, **460 von 461** Integration, 30 E2E im warmen Lauf. Wird einer rot, ist das eine Verhaltensänderung — dann wird entschieden, welche Seite recht hat, nicht der Test angepasst.
- **Vor jedem lokalen E2E-Lauf: was lauscht auf Port 3000?** `reuseExistingServer` ist lokal `true`. Ein hängengebliebener Server bringt Code von vor der Änderung mit. Das hat am 3. September zwei Fehlsuchen gekostet.
- **`pnpm test:e2e -- <datei>` filtert nicht.** pnpm reicht das `--` nicht an Playwright durch; der Befehl läuft die **ganze** Suite. Zum Filtern: `pnpm exec playwright test <datei>`, für Unit-Tests `pnpm --filter @fitretro/web exec vitest run <muster>`. In Aufgabe 1 gemessen: der vermeintlich gefilterte Lauf zog 31 Tests über 4,6 Minuten mit und brachte zwei fremde Kaltstart-Flakes mit, die dann erst auseinanderzuhalten waren. Ein gefilterter Lauf derselben Datei kostet Sekunden.

### Zwei Messwerte, die vor der ersten Zeile Code aufgenommen wurden

- **Die Uhrendrift macht die Integrationszahl unbrauchbar als Tor.** Die Uhr im Datenbankcontainer läuft der Node-Uhr **0,86 bis 0,88 s voraus** — konstant, dreimal gemessen. Jeder Test, der `started_at` aus der Datenbank gegen `completed_at` aus `new Date()` setzt, fällt, wenn sein Rundlauf kürzer ist. Beobachtet: drei Tests in zwei Dateien (`rls-workout-sessions`, `domain-complete-session`), alle am selben Constraint `workout_sessions_completed_after_start`. Die Zahl schwankt zwischen Läufen von 458 bis 460 von 461.

  **Bindend ist deshalb nicht die Zahl, sondern die Ursache: jeder rote Integrationstest scheitert an `workout_sessions_completed_after_start`.** Scheitert einer an etwas anderem, ist es ein Regress. Bestand, nicht Phase 5 — dieser Bauabschnitt fasst `workout_sessions` nirgends an.
- **Der erste E2E-Lauf in einem frischen Worktree kostet zwei Tests** an kaltem `.next` — genau der Fall, den `playwright.config.ts` im Kommentar beschreibt. Er zählt nicht. Gemessen: erst 28/30, warm 30/30.

---

## Dateistruktur

### Neu — die Bausteinschicht

| Datei | Verantwortung |
| --- | --- |
| `apps/web/app/portal/bausteine/Seite.tsx` | Titel, Vorspann, Rumpf. **Rendert kein `<main>`** — das Layout tut es, genau einmal |
| `apps/web/app/portal/bausteine/Abschnitt.tsx` | Karte mit Kopf, Notiz, Rumpf |
| `apps/web/app/portal/bausteine/Zeile.tsx` | Listenzeile: Haupt, Meta, Aktionen |
| `apps/web/app/portal/bausteine/Reiter.tsx` | Reiterleiste als Links auf eigene Routen |
| `apps/web/app/portal/bausteine/Kachel.tsx` | Kennzahl des Überblicks |
| `apps/web/app/portal/bausteine/Zustand.tsx` | `art="leer" \| "fehler" \| "keinRecht" \| "deaktiviert"` |
| `apps/web/app/portal/bausteine/bausteine.module.css` | Die Klassen dazu |
| `apps/web/app/einstieg/Einstieg.tsx` | Wortmarke, zentrierte Karte, 28 px Rand — die Hülle ohne Rail |
| `apps/web/app/einstieg/einstieg.module.css` | Die Einstiegsebene der Tokens |

**Warum `einstieg.module.css` getrennt von `portal.module.css`:** derselbe Grund, aus dem `halle.module.css` in Phase 3 getrennt entstand. Der Einstieg hat keine Rail, keinen 1000-px-Inhaltsstrom und einen anderen Seitenrand. In `portal.module.css` gequetscht würde jede Regel eine Ausnahme brauchen, und die Ausnahmen wären die Mehrheit.

**Was kein Baustein wird:** einmaliges Layout — die Kachelreihe des Überblicks, die Lieferungsliste der Tags, die Anordnung der vier Modellreiter. Ein Baustein entsteht aus Wiederholung **plus Regel**, nicht aus Wiederholung allein. `Form.tsx` (`AktionsFormular`, `AktionsKnopf`, `Feld`) bleibt wo es ist und wird nicht angefasst; die Bausteinschicht ergänzt es.

### Neu — Zustandsrouten

| Datei | Verantwortung |
| --- | --- |
| `apps/web/app/portal/[studioId]/(schreibtisch)/loading.tsx` | Titel sofort, Rumpf still |
| `apps/web/app/portal/[studioId]/(schreibtisch)/error.tsx` | `"use client"`, Fehlerzustand mit Wiederholen |
| `apps/web/app/portal/[studioId]/(schreibtisch)/not-found.tsx` | schließt die weiße Standardseite |
| `apps/web/app/not-found.tsx` | dasselbe für alles außerhalb des Portals |

### Zu ändern

| Datei | Was |
| --- | --- |
| `(schreibtisch)/layout.tsx` | `<main>` bekommt `className`; die Seiten geben ihres ab |
| `[studioId]/Rail.tsx` | sechs feste Einträge, drei Gruppen, Zahlen, Fußzeile, Kein-Recht-Fall |
| `[studioId]/catalog.ts` | `railZahlen` — die Zahlen der Rail an einer Stelle, mit dem Kein-Recht-Fall |
| `(schreibtisch)/geraete/page.tsx` | **wird die Modellliste** (heute: flache Geräteliste) |
| `(schreibtisch)/modelle/page.tsx` | **wird eine Weiterleitung** auf `/geraete` |
| `(schreibtisch)/modelle/[modelId]/` | zerfällt in vier Reiterrouten |
| `(schreibtisch)/{page,tags,leute,einstellungen}` | auf Bausteine, nach Artboard |
| `login/`, `registrieren/`, `passwort-vergessen/` | auf die Einstieg-Hülle, nach Artboard |
| `page.tsx`, `BeitrittsFormular.tsx`, `portal/page.tsx` | Landeseite, Mitgliedsbildschirm, Studiowahl |

### Tests

| Datei | Deckt |
| --- | --- |
| `e2e/helpers/abnahme.ts` **(neu)** | die drei maschinellen Abnahmen: Landmarke, Trefferflächen, Akzentzählung |
| `e2e/helpers/studio.ts` **(ändern)** | `studioMitMitglied` — der Kein-Recht-Fall als Fixture |
| `apps/web/app/portal/bausteine/Zustand.test.tsx` **(neu)** | Aufgabe 2 |
| `e2e/bausteine.spec.ts` **(neu)** | Aufgaben 1, 4, 5 — die Zustandsschicht am lebenden Portal |
| `e2e/einstieg.spec.ts` **(neu)** | Aufgaben 6–9 |
| `e2e/wurzel.spec.ts` **(neu)** | Aufgaben 10–11 |
| `e2e/rail.spec.ts` **(neu)** | Aufgaben 12–13 |
| `e2e/schreibtisch.spec.ts` **(neu)** | Aufgaben 14–20 |
| `e2e/{auth,login,leute,einrichten,trainerportal,einstellungen}.spec.ts` **(ändern)** | Wege, die sich durch Aufgaben 11 und 13 verschieben |

---

## Was dieser Plan bewusst nicht baut

Damit ein Prüfer die Lücken nicht für Versehen hält:

- ~~**Kein Kurse-Eintrag in der Rail**, bis Aufgabe 22 läuft.~~ **Am 4. September überholt.** Phase 4 ist gemergt, die Kurse-Routen stehen, und Phase 4 hat den Eintrag selbst gesetzt. Designsystem §11 („Ein leerer Tab ist ein Versprechen ohne Gegenwert") greift nicht mehr — das Versprechen ist eingelöst. Aufgabe 22 wird damit zu **Fassung A**: die fünf Kurse-Bildschirme werden gestaltet, statt dass der Plan aufschreibt, was offen bleibt.
- **Kein Neubau der 16 `Telefon*`-Bildschirme.** Sie sind in Phase 3 gebaut und gestaltet. Aufgabe 21 gleicht ab und schreibt Befunde.
- **Kein Neubau von `/t/<token>`.** Trägt seit dem Medienplan `fallback.module.css` nach Member-Maßen. Ebenfalls nur Abgleich.
- **Kein visueller Regressionstest.** Kein Screenshot-Vergleich in der Suite. Ein Pixelvergleich wird bei jeder Verschiebung um zwei Punkte rot und wird dann weggeklickt statt gelesen; die Sichtprüfung bleibt Handarbeit gegen das Artboard (Fertig-Kriterium 6).
- **Kein Hell-Modus.** Designsystem §14: bewusst nicht gebaut.
- **Kein „Neuen Code anfordern" auf `Verifizieren`.** Das Artboard zeichnet den Link, der Code kennt den Weg nicht. Das wäre neues Verhalten, kein Aussehen — es bleibt offener Punkt der Spec, Abschnitt 8.
- **Keine Änderung an `Form.tsx`.** `AktionsFormular`, `AktionsKnopf` und `Feld` tragen bereits, was sie sollen.

---

## Reihenfolge und was sie kostet

```
Abschnitt 0   Aufgaben 1–5     Bausteine, Zustände, Referenzseite Tags
Abschnitt 1   Aufgaben 6–9     Einstieg — sechs Bildschirme          ] rebase-neutral
Abschnitt 2   Aufgaben 10–11   Wurzelseite                           ] gegen Phase 4
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Abschnitt 3   Aufgaben 12–13   Rail und Zusammenlegung   <- Kollisionsstelle
Abschnitt 4   Aufgaben 14–15   Überblick, Geräte
Abschnitt 5   Aufgaben 16–20   Modell, Leute, Einstellungen
Abschnitt 6   Aufgabe 21       Abgleich Telefon und Fallback
Abschnitt 7   Aufgabe 22       Kurse — nach Rebase, oder Vermerk
              Aufgabe 23       Fahrplan nachziehen
```

**Alles oberhalb der Linie ist rebase-neutral.** Phase 4 fasst die Rail und die Route-Gruppe `(schreibtisch)` an; Einstieg und Wurzelseite berührt sie nie. Deshalb stehen sie vorn: sie kosten keine Reihenfolge und machen die Bausteine hart, bevor sie an der Kollisionsstelle ankommen.

**Aufgabe 12 und 13 gehören in einen Commit je Aufgabe, aber in einen Rebase-Block.** Wer sie über acht Commits verteilt, löst acht Konflikte statt zwei.

---

# Abschnitt 0 — Bausteine und Zustände

Fünf Aufgaben. Am Ende steht die Schicht, auf der alles Weitere sitzt, plus **eine** Seite, die beweist, dass sie trägt.

---

## Aufgabe 1: Die drei maschinellen Abnahmen

Das Fertig-Kriterium der Spec nennt drei Prüfungen, die eine Maschine übernimmt: genau eine Hauptlandmarke, Trefferflächen, Akzentflächen zählen. Sie entstehen **zuerst**, weil jede folgende Aufgabe sie benutzt — und weil die erste von ihnen sofort einen echten Fehler findet.

**Der Fehler ist bekannt und gemessen:** `(schreibtisch)/layout.tsx:27` rendert `<main>{children}</main>`, und jede Seite darin rendert noch ein eigenes `<main className={styles.content}>`. Jede Schreibtischseite hat damit zwei verschachtelte Hauptbereiche. Der Helfer wird gegen genau diesen Zustand geschrieben und muss **rot** sein, bevor Aufgabe 4 ihn heilt.

**Dateien:**
- Anlegen: `e2e/helpers/abnahme.ts`
- Anlegen: `e2e/bausteine.spec.ts`
- Ändern: `e2e/helpers/studio.ts` — `studioMitMitglied` dazu

**Schnittstellen:**
- Nutzt: `studioMitTrainer` aus `e2e/helpers/studio.ts`
- Liefert:
  - `AKZENT: "rgb(212, 255, 63)"` — `#d4ff3f`, wie der Browser es zurückgibt
  - `hauptlandmarken(page): Promise<number>`
  - `akzentflaechen(page): Promise<string[]>` — je Fläche eine lesbare Beschreibung, damit ein Fehlschlag sagt, *welche* zu viel ist
  - `zuKleineBedienelemente(page, mindestHoehe): Promise<string[]>`
  - `studioMitMitglied(page, praefix): Promise<Halle>` — ein Studio, in dem das angemeldete Konto **Mitglied** ist, nicht Trainer. Der Kein-Recht-Fall als Fixture

- [ ] **Schritt 1: Die Helfer schreiben**

`e2e/helpers/abnahme.ts`:

```ts
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
 */
export async function zuKleineBedienelemente(
  page: Page,
  mindestHoehe: number,
): Promise<string[]> {
  const auswahl = 'button, [role="button"], input:not([type="hidden"]), select, textarea';
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
```

- [ ] **Schritt 2: Die Mitglieds-Fixture ergänzen**

An `e2e/helpers/studio.ts` anhängen. Sie unterscheidet sich von `studioMitTrainer` in genau einer Zeile — der Rolle — und trägt deshalb keine eigene Kopie der vierzig Zeilen:

```ts
/**
 * Ein Studio, in dem das angemeldete Konto einfaches Mitglied ist. Der
 * Kein-Recht-Fall: die Rail steht, die Trainerseiten sagen einen Satz statt
 * abzustuerzen.
 */
export async function studioMitMitglied(
  page: Page,
  praefix: string,
): Promise<Halle> {
  return await studioMitRolle(page, praefix, "member");
}
```

Dazu `studioMitTrainer` auf einen gemeinsamen Rumpf umstellen — `studioMitRolle(page, praefix, rolle)` mit dem bisherigen Inhalt und `role: rolle` beim Einfügen der Mitgliedschaft; `studioMitTrainer` ruft ihn mit `"trainer"`. **Signatur und Rückgabe von `studioMitTrainer` bleiben unverändert**, sonst brechen `e2e/einrichten.spec.ts` und `e2e/onboarding.spec.ts` — die beiden Dateien, die die Fixture heute importieren.

- [ ] **Schritt 3: Den fehlschlagenden Test schreiben**

`e2e/bausteine.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { hauptlandmarken } from "./helpers/abnahme";
import { studioMitTrainer } from "./helpers/studio";

/**
 * Die Landmarke ist die einzige der drei Abnahmen, die heute schon rot ist
 * -- und sie ist es auf jeder Schreibtischseite gleichzeitig. Aufgabe 4
 * heilt sie an einer Stelle: die Seiten geben ihr <main> ab, das Layout
 * behaelt seines.
 */
test("Jede Schreibtischseite hat genau eine Hauptlandmarke", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-landmarke");

  for (const pfad of ["", "/geraete", "/tags", "/leute", "/einstellungen", "/einstellungen/konto"]) {
    await page.goto(`/portal/${studioId}${pfad}`);
    expect(
      await hauptlandmarken(page),
      `/portal/<id>${pfad} traegt nicht genau eine <main>-Landmarke`,
    ).toBe(1);
  }
});
```

- [ ] **Schritt 4: Laufen lassen und den echten Fehler sehen**

```
pnpm exec playwright test bausteine.spec.ts
```

Erwartet: **FAIL**, `expected 1, received 2`, auf dem ersten Pfad. Ist er grün, hat jemand die Aufgabe vorweggenommen — dann nachsehen, nicht weitergehen.

- [ ] **Schritt 5: Commit**

```bash
git add e2e/helpers/abnahme.ts e2e/helpers/studio.ts e2e/bausteine.spec.ts
git commit -m "test(e2e): die drei maschinellen Abnahmen, und die doppelte Landmarke faellt auf"
```

---

## Aufgabe 2: Der Zustand-Baustein

Vier Spielarten, ein Baustein. `art="keinRecht"` ersetzt vier wörtlich gleiche Blöcke, die heute in `portal/page.tsx`, `leute/page.tsx`, `einstellungen/page.tsx` und `(schreibtisch)/page.tsx` stehen.

Die Regeln des Designsystems stehen als Kommentar **in dieser Datei** und nirgends sonst — das ist der ganze Zweck der Übung.

**Dateien:**
- Anlegen: `apps/web/app/portal/bausteine/Zustand.tsx`
- Anlegen: `apps/web/app/portal/bausteine/Zustand.test.tsx`
- Anlegen: `apps/web/app/portal/bausteine/bausteine.module.css`
- Ändern: `apps/web/vitest.config.ts` — **das Include-Muster**, siehe Schritt 0
- Ändern: `apps/web/package.json` — `@testing-library/react`, `jsdom`, `@vitejs/plugin-react` als `devDependencies`

> **Schritt 0 ist keine Formsache.** `apps/web/vitest.config.ts` sammelt heute `include: ["**/*.test.ts"]` — eine `.test.tsx` würde **nie laufen**, und der Lauf wäre trotzdem grün. Das ist die teuerste Sorte Fehlschlag: einer, der wie Erfolg aussieht.

**Schnittstellen:**
- Nutzt: nichts
- Liefert:
  ```ts
  type ZustandArt = "leer" | "fehler" | "keinRecht" | "deaktiviert";
  function Zustand(props: {
    art: ZustandArt;
    titel: string;
    naechsterSchritt?: React.ReactNode;
    aktion?: React.ReactNode;
  }): React.ReactElement;
  ```

- [ ] **Schritt 0: Vitest beibringen, dass es `.tsx` gibt**

`apps/web/package.json`, `devDependencies`:

```
"@testing-library/react": "^16.1.0",
"@vitejs/plugin-react": "^4.3.4",
"jsdom": "^25.0.1",
```

Dann `pnpm install`. `apps/web/vitest.config.ts`:

```ts
import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  test: {
    // Ohne eigene Config wuerde Vitest beim Hochlaufen im Verzeichnisbaum
    // bis zur Monorepo-Wurzel suchen und dort vitest.config.ts (Integrationstests,
    // include: "tests/integration/**") finden — das Include-Pattern passt
    // aber nicht auf die Unit-Tests hier. Deshalb eine eigene, unrestriktive Config.
    //
    // .tsx gehoert seit den Bausteinen dazu. Ohne die Erweiterung liefe
    // Zustand.test.tsx nie, und der Lauf waere trotzdem gruen.
    include: ["**/*.test.ts", "**/*.test.tsx"],
    exclude: ["node_modules", ".next"],
    // @testing-library/react raeumt den DOM nur automatisch zwischen Tests
    // auf, wenn es ein globales afterEach vorfindet. Ohne globals bleibt
    // der Zustand eines Tests stehen, und der naechste sieht ihn mit --
    // "leer ist KEINE Warnung" faende dann den role="alert" des
    // vorherigen fehler-Tests.
    globals: true,
  },
});
```

**`globals: true` ist nicht optional.** Ohne die Zeile schlägt der dritte der fünf Tests fehl, und zwar aus einem Grund, der wie ein Fehler im Baustein aussieht statt wie einer in der Konfiguration: `@testing-library/react` prüft beim Laden `typeof afterEach === "function"` und registriert sein Auto-Cleanup nur dann. Fehlt es, bleibt das gerenderte DOM des vorigen Tests stehen — und `queryByRole("alert")` findet die Warnung des Fehler-Tests im Leer-Test wieder.

**Kein globales `environment: "jsdom"`.** Die zwölf bestehenden Tests dieses Pakets laufen unter Node — `api/aasa/route.test.ts` prüft einen Route-Handler, und ein DOM darunter ist bestenfalls nutzlos. Die Umgebung steht deshalb je Datei im Kopf, als erste Zeile von `Zustand.test.tsx`:

```tsx
// @vitest-environment jsdom
```

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

`apps/web/app/portal/bausteine/Zustand.test.tsx` — geprüft wird die **Regel**, nicht das Aussehen:

```tsx
// @vitest-environment jsdom
import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";
import { Zustand } from "./Zustand";

describe("Zustand", () => {
  it("leer nennt den naechsten Schritt", () => {
    render(
      <Zustand
        art="leer"
        titel="Noch kein Gerät angelegt."
        naechsterSchritt="Fang mit dem Gerät an, das am häufigsten benutzt wird."
      />,
    );
    expect(screen.getByText("Noch kein Gerät angelegt.")).toBeDefined();
    expect(
      screen.getByText("Fang mit dem Gerät an, das am häufigsten benutzt wird."),
    ).toBeDefined();
  });

  it("fehler meldet sich als Warnung an, damit ein Screenreader ihn ansagt", () => {
    render(<Zustand art="fehler" titel="Die Summen liessen sich nicht laden." />);
    expect(screen.getByRole("alert")).toBeDefined();
  });

  it("leer ist KEINE Warnung -- ein leeres Studio ist kein Fehler", () => {
    render(<Zustand art="leer" titel="Noch kein Kurs." />);
    expect(screen.queryByRole("alert")).toBeNull();
  });

  it("deaktiviert ist nie stumm -- daneben steht, was fehlt", () => {
    render(
      <Zustand art="deaktiviert" titel="Zuweisen" naechsterSchritt="Wähle zuerst ein Gerät." />,
    );
    expect(screen.getByText("Wähle zuerst ein Gerät.")).toBeDefined();
  });

  it("keinRecht sagt, wem die Seite gehoert, statt nur zu sperren", () => {
    render(
      <Zustand
        art="keinRecht"
        titel="Diese Seite ist Trainern und Inhabern vorbehalten."
        naechsterSchritt="Deine eigenen Trainingsdaten siehst du in der App, nicht hier."
      />,
    );
    expect(screen.getByText(/Trainern und Inhabern vorbehalten/)).toBeDefined();
    expect(screen.getByText(/in der App, nicht hier/)).toBeDefined();
  });
});
```

- [ ] **Schritt 2: Laufen lassen**

```
pnpm --filter @fitretro/web exec vitest run Zustand
```

Erwartet: **FAIL** — `Cannot find module './Zustand'`.

- [ ] **Schritt 3: Den Baustein schreiben**

`apps/web/app/portal/bausteine/Zustand.tsx`. Der Kommentarkopf ist Teil des Ergebnisses, nicht Beiwerk — er ist der Ort, an dem die Regeln jetzt wohnen:

```tsx
import styles from "./bausteine.module.css";

export type ZustandArt = "leer" | "fehler" | "keinRecht" | "deaktiviert";

/**
 * Die vier Zustaende des Portals an einer Stelle.
 *
 * Designsystem Abschnitt 5 und trainerportal-struktur-design.md Abschnitt 5
 * geben die Regeln vor; sie stehen hier, weil ein Baustein sie tragen kann
 * und vier Kopien nicht -- so viele Kein-Recht-Bloecke standen vorher
 * wortgleich im Code (portal/page.tsx, (schreibtisch)/page.tsx, leute,
 * einstellungen):
 *
 *   leer          Ueberschrift plus naechster Schritt. NIE eine leere
 *                 Statistik mit Nullen -- vier Kacheln, die viermal 0
 *                 zeigen, sagen ueber ein neues Studio nichts.
 *   fehler        Sagt, was falsch ist UND was gilt ("Das Gewicht liegt
 *                 ueber dem Geraetemaximum von 100,0 kg"), nie nur
 *                 "ungueltig". danger-Umriss bei vollem Kontrast -- KEINE
 *                 getoente Flaeche: die 10-%-Flaeche gehoert zu Offline,
 *                 und Offline gilt im Portal nicht.
 *   deaktiviert   NIE stumm -- daneben steht, was fehlt.
 *   keinRecht     Ein einfaches Mitglied sieht einen Satz, keinen Absturz.
 *                 Kein neuer Zustand, sondern die benannte Fassung von
 *                 etwas, das vorher vier Mal ad hoc im Code stand.
 *
 * "Offline" gilt im Portal nicht -- ein Konzept der Halle, nicht des
 * Schreibtischs. "Skelett" gilt nur fuer Medien und ist deshalb kein
 * Zustand hier, sondern eine Flaeche in der Medienzeile.
 *
 * Nur `fehler` traegt role="alert": ein leeres Studio ist kein Fehler, und
 * ein Screenreader, der jede leere Liste als Warnung ansagt, wird
 * abgeschaltet.
 */
export function Zustand({
  art,
  titel,
  naechsterSchritt,
  aktion,
}: {
  art: ZustandArt;
  titel: string;
  naechsterSchritt?: React.ReactNode;
  aktion?: React.ReactNode;
}) {
  return (
    <div
      className={`${styles.zustand} ${styles[art]}`}
      role={art === "fehler" ? "alert" : undefined}
    >
      {/* deaktiviert hat eine eigene Gestalt: die abgeblendete Pille und
          der Grund liegen NEBENeinander, so wie im Artboard. Bei den
          uebrigen drei steht der Titel als Absatz ueber dem naechsten
          Schritt. */}
      {art === "deaktiviert" ? (
        <div className={styles.zustandDeaktiviert}>
          <button type="button" className={styles.zustandPille} disabled>
            {titel}
          </button>
          {naechsterSchritt ? (
            <span className={styles.zustandSchritt}>{naechsterSchritt}</span>
          ) : null}
        </div>
      ) : (
        <>
          <p className={styles.zustandTitel}>{titel}</p>
          {naechsterSchritt ? (
            <p className={styles.zustandSchritt}>{naechsterSchritt}</p>
          ) : null}
        </>
      )}
      {aktion ? <div className={styles.zustandAktion}>{aktion}</div> : null}
    </div>
  );
}
```

Dazu `bausteine.module.css` mit `.zustand`, `.leer`, `.fehler`, `.keinRecht`, `.deaktiviert`, `.zustandTitel`, `.zustandSchritt`, `.zustandAktion`. **Werte aus `Zustaende.dc.html`**, dem Artboard für genau diesen Bildschirm: `fehler` bekommt `border: 1px solid var(--danger)` auf `var(--surface)`, die übrigen `border: 1px solid var(--line)` auf `var(--surface)`. Alle Farben als `var(--…)`.

**Keine getönte Fehlerfläche.** Es liegt nahe, `rgba(255, 90, 78, 0.1)` zu nehmen — `portal.module.css` `.error` macht es heute so. Es ist trotzdem falsch: Designsystem §5 ordnet die 10-Prozent-Fläche **Offline** zu, nicht *Fehler*; *Fehler* ist dort „`danger`-Umriss, **voller Kontrast**". Und Offline gilt im Portal ausdrücklich nicht (Struktur-Spec §5). Das Artboard bestätigt es: die Fehler-Karte steht auf `#14161a`, und in der ganzen Datei kommt kein `rgba` vor. Wer die Tönung übernimmt, importiert die Regel eines Zustands, den es hier nicht gibt. `.error` in `portal.module.css` bleibt vorerst, wie es ist — Befund 18 der Spec.

**`deaktiviert` liegt in einer Zeile, nicht untereinander.** Das `<span>Deaktiviert</span>` in 11 px Versalien auf dem Artboard ist die Bildunterschrift des Musterblatts — sie steht auf allen drei Karten und gehört nicht zum Baustein. Der Zustand selbst ist eine deaktivierte Pille (`surface-raised`, `line`-Rand, `text-faint`, 40 px, Radius 10) und **daneben** der Text, der sagt, was fehlt. Für `art="deaktiviert"` rendert der Baustein deshalb `titel` als diese Pille und `naechsterSchritt` in derselben Zeile, `gap: var(--s12)`, `flex-wrap: wrap`. Die Schnittstelle bleibt unverändert.

- [ ] **Schritt 4: Laufen lassen**

```
pnpm --filter @fitretro/web exec vitest run Zustand
```

Erwartet: **PASS**, 5 Tests.

- [ ] **Schritt 5: Die Unit-Zahl nachziehen**

```
pnpm test
```

Erwartet: 85 + 5 = **90 grün**. Ab hier ist 90 die Zahl, gegen die geprüft wird.

- [ ] **Schritt 6: Commit**

```bash
git add apps/web/app/portal/bausteine apps/web/vitest.config.ts apps/web/package.json pnpm-lock.yaml
git commit -m "feat(web): der Zustand-Baustein -- vier Spielarten, die Regeln an einer Stelle"
```

---

## Aufgabe 3: Seitengerüst, Karte, Zeile, Reiter, Kachel

Die fünf Bausteine, die die Anordnung tragen. Sie haben keine Regel im Kopf außer einer — und die ist die wichtigste:

**`Seite` rendert kein `<main>`.** Das Layout tut es, genau einmal. Ein Baustein, der die Landmarke nicht mitbringt, macht den Fehler aus Aufgabe 1 strukturell unmöglich, statt ihn an zwölf Stellen zu reparieren.

**Dateien:**
- Anlegen: `apps/web/app/portal/bausteine/Seite.tsx`, `Abschnitt.tsx`, `Zeile.tsx`, `Reiter.tsx`, `Kachel.tsx`
- Ändern: `apps/web/app/portal/bausteine/bausteine.module.css`

**Schnittstellen:**
- Nutzt: `bausteine.module.css`
- Liefert:
  ```ts
  function Seite(props: { titel: string; vorspann?: React.ReactNode; children: React.ReactNode }): React.ReactElement;
  function Abschnitt(props: { titel: string; notiz?: React.ReactNode; children: React.ReactNode }): React.ReactElement;
  function Zeile(props: { titel: React.ReactNode; meta?: React.ReactNode; aktionen?: React.ReactNode }): React.ReactElement;
  function Zeilen(props: { children: React.ReactNode }): React.ReactElement;
  function Reiter(props: { name: string; eintraege: { href: string; label: string; zusatz?: string; aktiv: boolean }[] }): React.ReactElement;
  function Kachel(props: { zahl: React.ReactNode; label: string }): React.ReactElement;
  function Kacheln(props: { children: React.ReactNode }): React.ReactElement;
  ```

- [ ] **Schritt 1: Die Bausteine schreiben**

`Seite.tsx` — die Datei, in der die Landmarkenregel steht:

```tsx
import styles from "./bausteine.module.css";

/**
 * Titel, Vorspann, Rumpf.
 *
 * Rendert bewusst KEIN <main>. Bis Aufgabe 4 rendert das Layout
 * <main>{children}</main> und vier Seiten darin noch ein eigenes --
 * (schreibtisch)/page.tsx, leute, einstellungen und einstellungen/konto
 * tragen damit zwei verschachtelte Hauptbereiche. Vier weitere haben an
 * derselben Stelle ein <div>, das denselben Innenabstand mitbringt und
 * ihn nach Aufgabe 4 verdoppeln wuerde.
 *
 * Die Landmarke gehoert dem Layout, weil es genau eine gibt und es genau
 * ein Layout gibt. Ein Baustein, der sie nicht mitbringt, macht beide
 * Fehler unmoeglich statt sie zu reparieren.
 */
export function Seite({
  titel,
  vorspann,
  children,
}: {
  titel: string;
  vorspann?: React.ReactNode;
  children: React.ReactNode;
}) {
  return (
    <>
      <h1 className={styles.titel}>{titel}</h1>
      {vorspann ? <p className={styles.vorspann}>{vorspann}</p> : null}
      {children}
    </>
  );
}
```

`Reiter.tsx` — Links auf eigene Routen, kein Umschalter im selben Dokument. Der Grund steht schon in `portal.module.css` über `.tabs` und gilt weiter: *ein Reiter je Bildschirm bedeutet ein Formular je Bildschirm*, und damit hält die Akzentregel wörtlich statt nur dem Sinn nach.

```tsx
import Link from "next/link";
import styles from "./bausteine.module.css";

/**
 * Reiterleiste. Links auf eigene Routen, kein Umschalter im selben
 * Dokument (Struktur-Spec Abschnitt 1): ein Reiter je Bildschirm heisst ein
 * Formular je Bildschirm, und erst dadurch gibt es genau eine
 * Akzentflaeche. Die alte Modellseite zeigte fuenf gleichzeitig.
 *
 * `name` benennt die Leiste fuer Screenreader -- eine Seite kann zwei
 * Navigationen tragen (Rail und Reiter), und "Navigation" zweimal ist
 * keine Auskunft.
 *
 * `zusatz` traegt den Zustand in der Beschriftung ("2 · 1 mit Video") --
 * als eigene Zeile unter dem Label, 12 px in text-faint mit 2 px Abstand.
 * Dasselbe Muster wie .rowMeta und .navItemMeta.
 */
export function Reiter({
  name,
  eintraege,
}: {
  name: string;
  eintraege: { href: string; label: string; zusatz?: string; aktiv: boolean }[];
}) {
  return (
    <nav className={styles.reiter} aria-label={name}>
      {eintraege.map((eintrag) => (
        <Link
          key={eintrag.href}
          href={eintrag.href}
          className={eintrag.aktiv ? `${styles.reiterEintrag} ${styles.reiterAktiv}` : styles.reiterEintrag}
          aria-current={eintrag.aktiv ? "page" : undefined}
        >
          {/* Beschriftung und Zustand als Bloecke uebereinander, nicht
              nebeneinander -- so zeichnet es Modell.dc.html, und so macht
              es Rail.tsx mit .navItemTitle/.navItemMeta schon. */}
          <span className={styles.reiterLabel}>{eintrag.label}</span>
          {eintrag.zusatz ? <span className={styles.reiterZusatz}>{eintrag.zusatz}</span> : null}
        </Link>
      ))}
    </nav>
  );
}
```

`Abschnitt.tsx`, `Zeile.tsx` und `Kachel.tsx` analog, mit den Klassen aus `portal.module.css` als Vorlage (`.section`, `.sectionHead`, `.sectionTitle`, `.sectionNote`, `.row`, `.rowMain`, `.rowTitle`, `.rowMeta`, `.rowActions`, `.kachel`, `.kachelZahl`, `.kachelLabel`) — die Werte stehen dort schon und sind laut Global Constraints die Wahrheit. `Zeilen` und `Kacheln` sind die Umschläge (`.rows`, `.kacheln`).

**`Zeile` rendert ein `<li>`, `Zeilen` ein `<ul>`.** Eine Liste von Geräten ist eine Liste; ein Screenreader sagt dann „Liste mit 4 Einträgen", und das ist die Auskunft, um die es geht.

- [ ] **Schritt 2: Typecheck**

```
pnpm typecheck
```

Erwartet: grün. Die Bausteine haben noch keinen Aufrufer — das ist in Ordnung, Aufgabe 5 ist der erste.

- [ ] **Schritt 3: Commit**

```bash
git add apps/web/app/portal/bausteine
git commit -m "feat(web): Seitengeruest, Karte, Zeile, Reiter, Kachel -- und die Landmarke bleibt beim Layout"
```

---

## Aufgabe 4: Die Zustandsrouten, und die doppelte Landmarke fällt

Hier wird Aufgabe 1 grün. Zwei Dinge zugleich, weil sie dieselben Dateien anfassen: die Landmarke wandert ins Layout, und die drei Routen-Zustände entstehen.

**`not-found.tsx` schließt eine offene Flanke.** `ladeKatalog` ruft bei einem `DomainError` `notFound()` auf — und das landet heute auf Nexts weißer Standardseite, mitten in einem Portal, das sonst durchgehend `#0a0b0d` ist.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/layout.tsx`
- Ändern: **alle zwölf Stellen** unter `(schreibtisch)/`, die `styles.content` tragen — nicht nur die mit `<main>`
- **Nicht ändern:** `apps/web/app/portal/page.tsx` — behält sein `<main className={styles.content}>`, es liegt außerhalb der Route-Gruppe und hat kein Layout, das es für es tut
- Anlegen: `(schreibtisch)/loading.tsx`, `(schreibtisch)/error.tsx`, `(schreibtisch)/not-found.tsx`
- Anlegen: `apps/web/app/not-found.tsx`

**Schnittstellen:**
- Nutzt: `Seite`, `Zustand` aus Aufgabe 2 und 3
- Liefert: nichts für spätere Aufgaben; ab hier gilt, dass Seiten unter `(schreibtisch)` **kein `<main>`** rendern

- [ ] **Schritt 1: Die Landmarke ins Layout ziehen**

In `(schreibtisch)/layout.tsx`:

```tsx
<main className={styles.content}>{children}</main>
```

Und darunter fällt **jede** Hülle mit `styles.content` weg — auch die, die `<div>` statt `<main>` sind. Das sind zwölf Stellen in acht Dateien:

| Datei | Stellen | Element heute |
| --- | --- | --- |
| `(schreibtisch)/page.tsx` | 2 | `<main>` |
| `(schreibtisch)/leute/page.tsx` | 2 | `<main>` |
| `(schreibtisch)/einstellungen/page.tsx` | 3 | `<main>` |
| `(schreibtisch)/einstellungen/konto/page.tsx` | 1 | `<main>` |
| `(schreibtisch)/geraete/page.tsx` | 1 | `<div>` |
| `(schreibtisch)/tags/page.tsx` | 1 | `<div>` |
| `(schreibtisch)/modelle/page.tsx` | 1 | `<div>` |
| `(schreibtisch)/modelle/[modelId]/page.tsx` | 1 | `<div>` |

**Die vier `<div>`-Stellen sind der eigentliche Fallstrick.** Sie tragen keine Landmarke und fallen deshalb im Landmarkentest nicht auf — aber sie tragen `styles.content`, also `padding: 32px 40px 48px`. Bleiben sie stehen, während das Layout dieselbe Klasse bekommt, verschachtelt sich der Innenabstand in sich selbst: doppelter Rand auf vier Seiten, den **kein Test fängt**. Nur die Sichtprüfung.

Zum Nachzählen:

```bash
grep -rn "styles.content" apps/web/app --include=*.tsx
```

Danach darf davon genau eine Zeile übrig sein, die unter `(schreibtisch)` liegt — die im Layout. `portal/page.tsx` behält seine; sie liegt außerhalb der Gruppe.

- [ ] **Schritt 2: Laufen lassen — Aufgabe 1 muss grün werden**

```
pnpm exec playwright test bausteine.spec.ts
```

Erwartet: **PASS**. War der Lauf davor rot und ist jetzt grün, ist der Fehler geheilt und nicht wegdefiniert.

- [ ] **Schritt 3: Die drei Routen-Zustände schreiben**

`(schreibtisch)/loading.tsx` — Entscheidung 3 der Spec, Titel sofort, Rumpf still:

```tsx
import styles from "../../portal.module.css";

/**
 * "Laedt" heisst hier: der Bildschirm reagiert sofort, aber er erfindet
 * nichts.
 *
 * Keine Skelettzeilen. Designsystem Abschnitt 5 laesst das Skelett
 * ausschliesslich fuer Medien zu, und der Grund traegt auch am
 * Schreibtisch: die Zahl der Zeilen waere geraten, und eine geratene Zahl
 * ist eine Aussage ueber Daten, die noch niemand kennt. Der Titel dagegen
 * steht in der Route, nicht in der Datenbank -- er darf sofort da sein.
 */
export default function Laedt() {
  return <div className={styles.pageLead}>Lädt …</div>;
}
```

`(schreibtisch)/error.tsx` — muss `"use client"` sein, so verlangt es Next:

```tsx
"use client";

import { Zustand } from "../../bausteine/Zustand";

export default function Fehler({ reset }: { error: Error; reset: () => void }) {
  return (
    <Zustand
      art="fehler"
      titel="Diese Seite liess sich nicht laden."
      naechsterSchritt="Der Katalog ist davon nicht betroffen — über die Navigation links kommst du weiter."
      aktion={
        <button type="button" onClick={reset}>
          Noch einmal versuchen
        </button>
      }
    />
  );
}
```

**Die Fehlermeldung selbst erscheint nicht auf dem Schirm.** Sie kann eine Datenbankmeldung enthalten, und die gehört nicht vor einen Trainer. Der Satz sagt, was falsch ist und was trotzdem gilt — das ist die Regel, nicht der Stacktrace.

`(schreibtisch)/not-found.tsx` und `app/not-found.tsx` analog mit `Zustand art="leer"` und dem Wortlaut *„Diese Seite gibt es nicht."* / *„Vielleicht wurde das Gerät stillgelegt oder das Studio gewechselt."*

- [ ] **Schritt 4: Die volle Suite**

```
pnpm typecheck && pnpm test && pnpm test:e2e
```

Erwartet: typecheck grün, 90 Unit grün, 30 E2E grün. **Läuft ein E2E-Test rot: erst nachsehen, was auf Port 3000 lauscht.**

- [ ] **Schritt 5: Commit**

```bash
git add apps/web/app
git commit -m "fix(web): eine Hauptlandmarke je Seite, und notFound() landet nicht mehr im Weissen"
```

---

## Aufgabe 5: Tags als Referenzseite

Die erste gestaltete Seite. Sie ist mit Absicht **Tags**: sie hat keine Hauptaktion und damit die ungewöhnlichste Akzentzahl im ganzen Portal — **null**. Wer sie zuerst baut, kann die Regel nicht versehentlich als „eine je Seite" fest verdrahten.

> Canvas-Notiz `note-akzent`: *„Die Tags-Seite hat seit dieser Runde gar keine mehr. Sie legt nichts an; sie gibt Auskunft. Null ist so richtig wie eins."*

**Artboard:** `Tags.dc.html` — drei Abschnitte: *Lieferungen*, *Vergebene Geräte-Tags*, *Aushangschilder*. Wortlaut und Reihenfolge von dort, wörtlich.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/tags/page.tsx`
- Ändern: `e2e/bausteine.spec.ts`

**Schnittstellen:**
- Nutzt: `Seite`, `Abschnitt`, `Zeile`, `Zeilen`, `Zustand`, sowie `akzentflaechen`, `zuKleineBedienelemente` aus Aufgabe 1
- Liefert: das Muster, dem die Aufgaben 14–20 folgen

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

An `e2e/bausteine.spec.ts` anhängen:

```ts
import { akzentflaechen, zuKleineBedienelemente } from "./helpers/abnahme";
import { studioMitMitglied } from "./helpers/studio";

test("Die Tags-Seite traegt keine Akzentflaeche -- sie legt nichts an", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags");
  await page.goto(`/portal/${studioId}/tags`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `zu viele Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(0);
});

test("Ein Studio ohne Tags sagt, was zu tun ist, statt eine leere Liste zu zeigen", async ({
  page,
}) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags-leer");
  await page.goto(`/portal/${studioId}/tags`);

  await expect(page.getByText("Noch keine Lieferung")).toBeVisible();
  await expect(page.locator("[role=alert]")).toHaveCount(0);
});

test("Ein Mitglied sieht auf der Tags-Seite einen Satz, keinen Absturz", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "abnahme-tags-recht");
  await page.goto(`/portal/${studioId}/tags`);

  await expect(page.getByRole("heading", { name: "Tags" })).toBeVisible();
  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
});

test("Die Bedienelemente der Tags-Seite sind gross genug zum Treffen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "abnahme-tags-treffer");
  await page.goto(`/portal/${studioId}/tags`);

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu kleine Bedienelemente: ${zuKlein.join(", ")}`).toHaveLength(0);
});
```

**Die 40 im letzten Test ist kein Tippfehler**, sondern Befund 16, entschieden am 3. September: am Schreibtisch gelten 40 px für Nebenaktion und zerstörende Aktion, 44 px für Hauptaktion und Eingabefeld. Die „≥ 44 px" des Designsystems sind für die Halle hergeleitet — einhändig, im Halbdunkel. Am Schreibtisch liegt eine Maus. Die Tags-Seite trägt keine Hauptaktion, also ist 40 hier der richtige Prüfwert.

- [ ] **Schritt 2: Laufen lassen**

```
pnpm exec playwright test bausteine.spec.ts
```

Erwartet: **FAIL** auf mindestens dem Kein-Recht- und dem Leer-Test. Der Akzenttest kann zufällig grün sein — die heutige Seite hat keine Hauptaktion. Das ist kein Beweis, sondern Zufall, und deshalb steht er trotzdem hier.

- [ ] **Schritt 3: Die Seite auf Bausteine umbauen und nach Artboard gestalten**

`tags/page.tsx` auf `Seite`/`Abschnitt`/`Zeilen`/`Zeile` umstellen, mit den drei Abschnitten aus `Tags.dc.html`. Zu beachten:

- Der Kein-Recht-Fall braucht ein `try/catch` um die Tagabfrage, nach dem Muster in `leute/page.tsx:25` — `DomainError` mit `code === "unauthorized"` wird zu `<Zustand art="keinRecht" …>`, alles andere zu `art="fehler"`.
- Die Erklärsätze des Artboards sind **Inhalt, nicht Dekoration** und werden wörtlich übernommen, besonders der zum Vorrat: *„Der Gerätetag-Vorrat steht als Zahl. Ein vorrätiger Aufkleber lässt sich keinem Stück in der Packung zuordnen — 97 gleichlautende Zeilen wären keine Auskunft, sondern Lärm."*
- Datum ausgeschrieben (`Mi., 12. August 2026`), in der Studio-Zeitzone.
- *Sperren* ist eine zerstörende Aktion: `AktionsKnopf` mit `art="destructive"`, also `danger` als **Umriss ohne Fläche**.

- [ ] **Schritt 4: Laufen lassen**

```
pnpm exec playwright test bausteine.spec.ts
```

Erwartet: **PASS**, alle fünf.

- [ ] **Schritt 5: Sichtprüfung**

`run`-Skill, `/portal/<id>/tags` im Browser, Screenshot gegen `Tags.dc.html`. Abweichungen notieren — nicht wegsehen, nicht wegdiskutieren.

- [ ] **Schritt 6: Die volle Suite**

```
pnpm typecheck && pnpm test && pnpm test:integration && pnpm test:e2e
```

Erwartet: **91** Unit, **460 von 461** Integration, **35** E2E — 31 aus den Aufgaben 1 bis 4 plus die vier neuen dieser Aufgabe. Die Zahlen sind Richtwerte; bindend ist, dass kein zuvor grüner Test rot wird und die vier neuen grün sind.

- [ ] **Schritt 7: Commit**

```bash
git add apps/web/app/portal/[studioId]/\(schreibtisch\)/tags e2e/bausteine.spec.ts
git commit -m "feat(web): Tags gestaltet -- die Referenzseite, und sie traegt null Akzentflaechen"
```

---

# Abschnitt 1 — Einstieg

Sechs Bildschirme, heute mit **null** Gestaltung: rohe `<form>`, `<label>`, `<input>`, kein Stylesheet. Der Teil des Portals, der am weitesten von seinem Entwurf entfernt ist — und der einzige, den Phase 4 nie anfasst.

**Eine Regel bindet diesen ganzen Abschnitt:** die zugänglichen Namen bleiben, wie sie sind. `e2e/helpers/login.ts` füllt `getByLabel("E-Mail")` und `getByLabel("Passwort")` und klickt `getByRole("button", { name: "Anmelden" })`. **Acht Testdateien hängen daran** — sechs importieren `helpers/login` direkt (`auth`, `einstellungen`, `leute`, `login`, `onboarding`, `trainerportal`), zwei weitere über `helpers/studio`, das `anmelden()` aufruft (`einrichten`, `bausteine`). Ein umbenanntes Label ist keine Gestaltungsänderung, sondern ein Suitenbruch — und zwar in acht Dateien gleichzeitig, von denen sechs mit dem Einstieg nichts zu tun haben.

---

## Aufgabe 6: Die Einstieg-Hülle und Anmelden

**Artboard:** `Anmelden.dc.html`. Wortmarke „gymodo" oben links, Titel *Anmelden*, zwei Felder, Hauptaktion, darunter zwei Textlinks: *Passwort vergessen* und *Konto anlegen*.

**Dateien:**
- Anlegen: `apps/web/app/einstieg/Einstieg.tsx`
- Anlegen: `apps/web/app/einstieg/einstieg.module.css`
- Anlegen: `e2e/einstieg.spec.ts`
- Ändern: `apps/web/app/login/page.tsx`

**Schnittstellen:**
- Nutzt: `AKZENT`, `akzentflaechen`, `hauptlandmarken`, `zuKleineBedienelemente` aus Aufgabe 1
- Liefert:
  ```ts
  function Einstieg(props: {
    titel: string;
    vorspann?: React.ReactNode;
    children: React.ReactNode;
    fuss?: React.ReactNode;
  }): React.ReactElement;
  ```
  Rendert **genau ein** `<main>` — der Einstieg hat kein Layout, das es für ihn tut. Die Aufgaben 7–11 bauen darauf.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

`e2e/einstieg.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";

/**
 * Der Einstieg wird ohne Konto geprueft -- das ist sein Normalfall. Kein
 * studioMitTrainer, keine Anmeldung: wer hier steht, hat noch nichts.
 */
test("Die Anmeldeseite traegt eine Landmarke, eine Akzentflaeche und lesbare Namen", async ({
  page,
}) => {
  await page.goto("/login");

  expect(await hauptlandmarken(page)).toBe(1);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);

  // Die Namen, an denen acht Testdateien haengen. Sie sind ab hier
  // Schnittstelle, nicht Beschriftung.
  await expect(page.getByLabel("E-Mail")).toBeVisible();
  await expect(page.getByLabel("Passwort")).toBeVisible();
  await expect(page.getByRole("button", { name: "Anmelden" })).toBeVisible();

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu klein: ${zuKlein.join(", ")}`).toHaveLength(0);
});

test("Von der Anmeldung fuehren beide Wege weiter, die das Artboard zeichnet", async ({
  page,
}) => {
  await page.goto("/login");
  await page.getByRole("link", { name: "Konto anlegen" }).click();
  await expect(page).toHaveURL(/\/registrieren$/);

  await page.goto("/login");
  await page.getByRole("link", { name: "Passwort vergessen" }).click();
  await expect(page).toHaveURL(/\/passwort-vergessen$/);
});

test("Ein falsches Passwort meldet sich als Warnung, nicht als stiller Text", async ({ page }) => {
  await page.goto("/login");
  await page.getByLabel("E-Mail").fill("gibt-es-nicht@example.test");
  await page.getByLabel("Passwort").fill("falsch-falsch-falsch");
  await page.getByRole("button", { name: "Anmelden" }).click();

  await expect(page.getByRole("alert")).toBeVisible();
  await expect(page).toHaveURL(/\/login$/);
});
```

- [ ] **Schritt 2: Laufen lassen**

```
pnpm exec playwright test einstieg.spec.ts
```

Erwartet: **FAIL** — heute gibt es weder `<main>` noch eine Akzentfläche noch Links mit diesen Namen (die heutige Seite schreibt „Registrieren" und „Passwort vergessen?" mit Fragezeichen).

- [ ] **Schritt 3: Die Hülle schreiben**

`apps/web/app/einstieg/Einstieg.tsx`:

```tsx
import styles from "./einstieg.module.css";

/**
 * Die Huelle der sechs Einstiegsbildschirme: Wortmarke, zentrierte Karte,
 * 28 px Seitenrand.
 *
 * Getrennt von portal.module.css aus demselben Grund, aus dem
 * halle.module.css getrennt entstand: hier gibt es keine Rail, keinen
 * 1000-px-Inhaltsstrom und einen anderen Seitenrand. In portal.module.css
 * gequetscht braeuchte jede Regel eine Ausnahme, und die Ausnahmen waeren
 * die Mehrheit.
 *
 * Rendert das <main> selbst -- anders als die Bausteine des Schreibtischs,
 * denn hier gibt es kein Layout, das es tut.
 */
export function Einstieg({
  titel,
  vorspann,
  children,
  fuss,
}: {
  titel: string;
  vorspann?: React.ReactNode;
  children: React.ReactNode;
  fuss?: React.ReactNode;
}) {
  return (
    <main className={styles.seite}>
      <div className={styles.karte}>
        <span className={styles.marke}>gymodo</span>
        <h1 className={styles.titel}>{titel}</h1>
        {vorspann ? <p className={styles.vorspann}>{vorspann}</p> : null}
        {children}
        {fuss ? <div className={styles.fuss}>{fuss}</div> : null}
      </div>
    </main>
  );
}
```

`einstieg.module.css` nach `Anmelden.dc.html`: `.seite` zentriert die Karte im Bildschirm, `.karte` bekommt `padding: 28px`, `.marke` ist die Wortmarke, `.titel` folgt der Screentitel-Zeile des Designsystems (Versalien, Tracking negativ). Alle Farben als `var(--…)`.

- [ ] **Schritt 4: Die Anmeldeseite umbauen**

`login/page.tsx` auf `Einstieg` + `Feld` aus `Form.tsx` umstellen. Drei Punkte:

- Die Fehlermeldung bekommt `role="alert"`. Heute steht sie als stilles `<p>` da — ein Screenreader sagt sie nie an, und der Nutzer erfährt nicht, warum nichts passiert.
- Die Links heißen **wörtlich wie im Artboard**: *Passwort vergessen* (ohne Fragezeichen) und *Konto anlegen*. Der heutige Text „Kein Konto? Registrieren · Passwort vergessen?" fällt weg.
- Eine Akzentfläche: der Anmeldeknopf. Die beiden Links sind Text, keine Nebenaktionen.

- [ ] **Schritt 5: Laufen lassen**

```
pnpm exec playwright test einstieg.spec.ts
```

Erwartet: **PASS**, drei Tests.

- [ ] **Schritt 6: Die bestehenden Anmeldewege prüfen**

```
pnpm test:e2e
```

Erwartet: **38 grün** — 30 aus dem Bestand, 1 aus Aufgabe 1, 4 aus Aufgabe 5, 3 aus dieser. Richtwert; bindend ist, dass kein zuvor grüner Test rot wird.

**Wird `login.spec.ts` oder eine der acht Dateien mit `anmelden()` rot, ist ein zugänglicher Name gewandert** — dann zurück zum Wortlaut, nicht den Test anpassen. Das ist der wahrscheinlichste Weg, wie diese Aufgabe die Suite bricht, und er sieht beim ersten Hinsehen wie ein Fehler in einer ganz anderen Datei aus.

- [ ] **Schritt 7: Sichtprüfung und Commit**

Screenshot `/login` gegen `Anmelden.dc.html`.

```bash
git add apps/web/app/einstieg apps/web/app/login e2e/einstieg.spec.ts
git commit -m "feat(web): die Einstieg-Huelle, und Anmelden sieht aus wie sein Artboard"
```

---

## Aufgabe 7: Registrieren und Verifizieren

Zwei Artboards, **eine Route**. `registrieren/page.tsx` rendert heute schon zwei Schritte hintereinander im selben Dokument: erst das Konto, dann der Code aus der Mail. Das bleibt so — es ist ein Ablauf, kein Ortswechsel, und ein `/verifizieren` ohne eigenen Einstieg wäre eine Route, die man nicht aufrufen kann.

**Artboards:** `Registrieren.dc.html`, `Verifizieren.dc.html`.

**Befund 6 gilt hier:** `Verifizieren.dc.html` zeichnet einen Link *„Neuen Code anfordern"*. Diesen Weg gibt es im Code nicht. **Der Link wird nicht gebaut** — das wäre neues Verhalten, kein Aussehen. Er bleibt offener Punkt der Spec, Abschnitt 8.

**Dateien:**
- Ändern: `apps/web/app/registrieren/page.tsx`
- Ändern: `e2e/einstieg.spec.ts`

**Schnittstellen:**
- Nutzt: `Einstieg` aus Aufgabe 6, `registrieren`/`registrierungBestaetigen` aus `registrieren/actions.ts` (unverändert)
- Liefert: nichts für spätere Aufgaben

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

An `e2e/einstieg.spec.ts` anhängen:

```ts
test("Registrieren nennt die Passwortregel, bevor sie jemand verletzt", async ({ page }) => {
  await page.goto("/registrieren");

  expect(await hauptlandmarken(page)).toBe(1);
  expect(await akzentflaechen(page)).toHaveLength(1);

  // Zehn Zeichen sind seit dem 3. September der Mindestwert -- der Push der
  // Mailvorlagen hob minimum_password_length von 6 auf 10. Wer das erst
  // nach dem Absenden erfaehrt, tippt zweimal.
  await expect(page.getByText(/Mindestens zehn Zeichen/)).toBeVisible();
  await expect(page.getByRole("button", { name: "Konto anlegen" })).toBeVisible();
});

test("Ein zu kurzes Passwort sagt, was gilt -- nicht nur, dass etwas falsch ist", async ({
  page,
}) => {
  await page.goto("/registrieren");
  await page.getByLabel("E-Mail").fill(`kurz-${crypto.randomUUID()}@example.test`);
  await page.getByLabel("Passwort").fill("kurz");
  await page.getByRole("button", { name: "Konto anlegen" }).click();

  const meldung = page.getByRole("alert");
  await expect(meldung).toBeVisible();
  await expect(meldung).toContainText(/zehn|10/);
});
```

- [ ] **Schritt 2: Laufen lassen**

```
pnpm exec playwright test einstieg.spec.ts
```

Erwartet: **FAIL** auf beiden.

- [ ] **Schritt 3: Beide Schritte umbauen**

Der erste Schritt bekommt `Einstieg titel="Registrieren"`, zwei Felder und den Hinweis am Passwortfeld — wörtlich aus dem Artboard: *„Mindestens zehn Zeichen. Länge zählt mehr als Sonderzeichen."* Darunter der Satz aus dem Artboard: *„Ein Konto allein reicht nicht — du brauchst danach den Code deines Studios."*

**Dieser Satz stimmt für das Web nicht mehr** und wird ersetzt. Die Canvas-Notiz `note-einstieg` sagt es selbst: im Web wird man Mitarbeiter, nicht Mitglied, und Mitarbeiter fügt ein Studio unter *Leute → Mitarbeiter* hinzu. Der Satz lautet deshalb: *„Ein Konto allein reicht nicht — ein Studio muss dich danach als Mitarbeiter hinzufügen."* **Das ist Befund 17**, unten in der Befundliste nachzutragen.

Der zweite Schritt bekommt `Einstieg titel="Verifizieren"` und den Vorspann aus `Verifizieren.dc.html`, mit der echten Adresse eingesetzt: *„Wir haben einen Code an `<adresse>` geschickt. Er gilt eine Stunde."* Das Codefeld behält seinen Namen *Code aus der E-Mail*.

Fehlermeldungen beider Schritte bekommen `role="alert"`.

- [ ] **Schritt 4: Laufen lassen und Commit**

```
pnpm exec playwright test einstieg.spec.ts
```

Erwartet: **PASS**, fünf Tests. Danach Sichtprüfung gegen beide Artboards.

```bash
git add apps/web/app/registrieren e2e/einstieg.spec.ts
git commit -m "feat(web): Registrieren und Verifizieren gestaltet -- die Passwortregel steht vor dem Absenden"
```

---

## Aufgabe 8: Passwort vergessen und Passwort neu

Wieder zwei Artboards, eine Route, derselbe Grund wie in Aufgabe 7.

**Zwei Befunde treffen hier zusammen:**

- **Befund 4:** `PasswortVergessen.dc.html` zeichnet *„Link anfordern"*. Der Code schickt einen sechsstelligen Code, und `e2e/onboarding.spec.ts` liest ihn aus Mailpit. Der Code gewinnt — der Knopf heißt **„Code anfordern"**, wie er heute schon heißt.
- **Befund 5:** `PasswortNeu.dc.html` zeigt *Neues Passwort* und *Wiederholen*, aber **kein Codefeld**. Ohne den Code funktioniert der laufende Weg nicht; das Feld bleibt. Umgekehrt hat der Code heute **kein** *Wiederholen* — das kommt vom Artboard dazu und ist eine Verbesserung, keine Abweichung.

**Dateien:**
- Ändern: `apps/web/app/passwort-vergessen/page.tsx`
- Ändern: `apps/web/app/passwort-vergessen/actions.ts` — Gleichheitsprüfung der beiden Passwortfelder
- Ändern: `e2e/einstieg.spec.ts`

**Schnittstellen:**
- Nutzt: `Einstieg` aus Aufgabe 6
- Liefert: nichts für spätere Aufgaben
- **Ändert:** `passwortZuruecksetzen` liest zusätzlich `password2` aus dem `FormData`. `e2e/onboarding.spec.ts` füllt es ab jetzt mit — die Datei wird in diesem Schritt mitgeändert.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Passwort vergessen fordert einen Code an, keinen Link", async ({ page }) => {
  await page.goto("/passwort-vergessen");

  expect(await hauptlandmarken(page)).toBe(1);
  await expect(page.getByRole("button", { name: "Code anfordern" })).toBeVisible();

  // Der Satz aus dem Artboard: er sagt bewusst nicht, ob es das Konto gibt.
  await expect(page.getByText(/ist die Mail unterwegs/)).toBeVisible();
});

test("Zwei verschiedene neue Passwoerter werden abgelehnt, bevor eines gesetzt wird", async ({
  page,
}) => {
  const admin = adminClient();
  const email = `e2e-wiederholen-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  const angefordert = new Date();
  await page.goto("/passwort-vergessen");
  await page.getByLabel("E-Mail").fill(email);
  await page.getByRole("button", { name: "Code anfordern" }).click();

  const code = await latestOtpFor(email, angefordert);
  await page.getByLabel("Code aus der E-Mail").fill(code);
  await page.getByLabel("Neues Passwort").fill("passwort-eins-1234");
  await page.getByLabel("Wiederholen").fill("passwort-zwei-1234");
  await page.getByRole("button", { name: "Passwort setzen" }).click();

  const meldung = page.getByRole("alert");
  await expect(meldung).toBeVisible();
  await expect(meldung).toContainText(/stimmen nicht überein/);
  await expect(page).toHaveURL(/\/passwort-vergessen$/);
});
```

`E2E_PASSWORD` und `latestOtpFor` kommen aus `./helpers/login`. **`adminClient` gibt es dort noch nicht** — die Erzeugung des Service-Role-Clients steht heute wörtlich gleich in **sieben** Dateien: `helpers/studio.ts`, `auth`, `einstellungen`, `leute`, `login`, `tag-fallback`, `trainerportal`.

Zieh sie nach `helpers/login.ts` als `adminClient()` und lass die sieben Stellen sie von dort beziehen. **Das ist der Umbau mit dem größten Bruchrisiko in dieser Aufgabe** — sieben Dateien, von denen sechs mit dem Passwortpfad nichts zu tun haben. Wenn dir das zu viel für diese Aufgabe ist: leg `adminClient()` in `helpers/login.ts` an, benutz sie in deinen neuen Tests, und **lass die sieben Bestandsstellen unangetastet**. Dann ist der Umbau ein eigener Befund statt eines Nebenwegs, auf dem die Suite bricht.

- [ ] **Schritt 2: Laufen lassen**

Erwartet: **FAIL** — es gibt kein Feld *Wiederholen*.

- [ ] **Schritt 3: Umbauen**

Beide Schritte auf `Einstieg`. Der zweite bekommt das dritte Feld *Wiederholen* mit `type="password"`.

In `passwortZuruecksetzen` **vor** dem Aufruf an Supabase:

```ts
const passwort = String(formData.get("password") ?? "");
const wiederholung = String(formData.get("password2") ?? "");
if (passwort !== wiederholung) {
  return { error: "Die beiden Passwörter stimmen nicht überein." };
}
```

Die Prüfung steht **vor** dem Netzaufruf: ein Tippfehler in der Wiederholung soll nicht den Code verbrauchen. Ein verbrauchter Code bedeutet eine neue Mail, und der Nutzer weiß nicht, warum.

- [ ] **Schritt 4: `onboarding.spec.ts` mitziehen**

Der Test *„Nach dem Passwortwechsel steht ein Trainer im Portal"* füllt heute zwei Felder. Er bekommt eine Zeile:

```ts
await page.getByLabel("Wiederholen").fill("neues-passwort-1234");
```

**Das ist eine Verhaltensänderung, kein Testanpassen.** Der Weg hat ein Feld mehr, und der Test geht den Weg.

- [ ] **Schritt 5: Laufen lassen und Commit**

```
pnpm test:e2e
```

Erwartet: **43 grün** — 36 aus Abschnitt 0, 3 aus Aufgabe 6, 2 aus Aufgabe 7, 2 aus dieser. Richtwert; bindend ist, dass kein zuvor grüner Test rot wird. Danach Sichtprüfung gegen beide Artboards.

```bash
git add apps/web/app/passwort-vergessen e2e
git commit -m "feat(web): Passwort vergessen und neu gestaltet, mit Wiederholung vor dem Netzaufruf"
```

---

## Aufgabe 9: Studiowahl und der Zustand „kein Studio"

`/portal` ist der Einstieg ins Portal. Wer in genau einem Studio Trainer ist — der Normalfall — landet direkt dort und sieht die Seite nie. Sichtbar wird sie in zwei Fällen, und beide sind gezeichnet oder gestaltbar:

- **kein Studio:** das ist die **obere Hälfte** von `KeinStudio.dc.html` — *„Dein Konto steht. Ein Studio muss dich noch als Mitarbeiter hinzufügen."* Heute steht dort „Du pflegst noch keinen Katalog."
- **mehrere Studios:** ungezeichnet (**Befund 15**). Wird nach Bausteinen gestaltet, nicht nach Vorlage.

**Dateien:**
- Ändern: `apps/web/app/portal/page.tsx`
- Ändern: `e2e/einstieg.spec.ts`

**Schnittstellen:**
- Nutzt: `Einstieg` aus Aufgabe 6 für den Kein-Studio-Fall; `Seite`/`Abschnitt`/`Zeilen`/`Zeile` für die Studiowahl
- Liefert: nichts für spätere Aufgaben

**Warum zwei verschiedene Hüllen auf einer Route:** die beiden Fälle sind nicht zwei Zustände derselben Seite, sondern zwei Seiten. „Kein Studio" ist ein Einstiegsbildschirm — kein Kontext, keine Navigation, ein Satz. Die Studiowahl ist eine Liste im Portal. Sie in eine Hülle zu zwingen hieße, eine von beiden falsch zu rahmen.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Ein Konto ohne Studio erfaehrt, was fehlt und wer es beheben kann", async ({ page }) => {
  const admin = adminClient();
  const email = `e2e-ohne-studio-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await anmelden(page, email);
  await page.goto("/portal");

  await expect(page.getByRole("heading", { name: "Noch kein Studio" })).toBeVisible();
  await expect(page.getByText(/als Mitarbeiter hinzufügen/)).toBeVisible();
  // Der Weg heraus wird benannt, nicht verschwiegen.
  await expect(page.getByText(/Leute/)).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);
});
```

- [ ] **Schritt 2: Laufen lassen, umbauen, laufen lassen**

Erwartet erst **FAIL** (die Überschrift heißt heute „Trainerportal"), nach dem Umbau **PASS**.

Der Kein-Studio-Fall bekommt den Wortlaut aus dem Artboard, wörtlich: *„Dein Konto steht. Ein Studio muss dich noch als Mitarbeiter hinzufügen — danach steht hier das Portal."* und *„Wer im Studio schon dabei ist, findet dich über deine E-Mail-Adresse unter Leute → Mitarbeiter. Bis dahin gibt es hier nichts zu sehen — das ist keine Sperre, sondern die Wahrheit."*

**Die untere Hälfte des Artboards gehört nicht hierher.** *„Du wolltest trainieren?"* richtet sich an ein Mitglied, und ein Mitglied kommt nicht auf `/portal` — es kommt auf `/`. Der Block wandert in Aufgabe 11.

- [ ] **Schritt 3: Sichtprüfung und Commit**

```bash
git add apps/web/app/portal/page.tsx e2e/einstieg.spec.ts
git commit -m "feat(web): kein Studio sagt, wer es beheben kann -- und die Studiowahl bekommt eine Form"
```

---

# Abschnitt 2 — Die Wurzelseite

Der offene Punkt aus Fahrplan Abschnitt 6: *„Die Wurzelseite `/` ist ungestaltet — seit dem 3. September sieht Personal sie nicht mehr, alle übrigen Angemeldeten schon. Sie trägt das Beitrittsformular und stammt aus M0."*

Drei Zustände auf einer Route, und sie sind verschiedene Seiten:

| Wer | Was | Woher |
| --- | --- | --- |
| nicht angemeldet | Landeseite | `Start.dc.html` |
| angemeldet, Mitarbeiter | Weiterleitung auf `/portal` | steht schon, bleibt |
| angemeldet, kein Mitarbeiter | Mitgliedsbildschirm, mit Beitrittsformular wenn kein Studio | untere Hälfte von `KeinStudio.dc.html` |

---

## Aufgabe 10: Die Landeseite

**Artboard:** `Start.dc.html`. Wortmarke und *Anmelden* im Kopf, dann die Zeile *„Dein Studio, am Gerät erklärt."* über drei Zeilen gesetzt, ein Absatz, zwei Aktionen, ein Hinweis für Mitglieder, und ganz unten die Produktgrenze.

**Die Produktgrenze ist Pflichttext**, kein Kleingedrucktes — Designsystem §10 verlangt sie sichtbar. Wörtlich: *„gymodo misst nichts. Angezeigt wird ausschließlich, was Mitglieder selbst bestätigt haben. Einweisungsvideos und Einstellhinweise sind Inhalte des Studios, keine Trainings- oder Gesundheitsempfehlung von gymodo."*

**Dateien:**
- Ändern: `apps/web/app/page.tsx`
- Anlegen: `e2e/wurzel.spec.ts`
- Anlegen: `apps/web/app/einstieg/landeseite.module.css`

**Schnittstellen:**
- Nutzt: `hauptlandmarken`, `akzentflaechen` aus Aufgabe 1
- Liefert: nichts für spätere Aufgaben
- **Entfernt:** `data-testid="anonymous"` — der heutige Platzhalter *„Nicht angemeldet."*. Kein Test greift darauf zu (geprüft: nur `page.tsx` selbst nennt ihn).

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

`e2e/wurzel.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken } from "./helpers/abnahme";

/**
 * Die Wurzelseite ohne Konto. Bis zum 3. September stand hier "Nicht
 * angemeldet." und sonst nichts -- die erste Seite, die ein Mensch von
 * gymodo im Web sieht, war ein Satz auf schwarzem Grund.
 */
test("Wer ohne Konto auf die Wurzelseite kommt, findet beide Wege hinein", async ({ page }) => {
  await page.goto("/");

  expect(await hauptlandmarken(page)).toBe(1);

  // Genau eine Akzentflaeche: die Hauptaktion. "Konto anlegen" steht
  // daneben als Nebenaktion, nicht als zweiter Akzent -- zwei Flaechen
  // wuerden beide behaupten, DER Weg zu sein.
  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);

  await page.getByRole("link", { name: "Als Trainer anmelden" }).click();
  await expect(page).toHaveURL(/\/login$/);

  await page.goto("/");
  await page.getByRole("link", { name: "Konto anlegen" }).click();
  await expect(page).toHaveURL(/\/registrieren$/);
});

test("Die Landeseite nennt die Produktgrenze, ohne dass man danach sucht", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByText(/gymodo misst nichts/)).toBeVisible();
});

test("Sie sagt einem Mitglied, dass es im Web nichts zu tun hat", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByText(/im Web gibt es nichts für dich zu tun/)).toBeVisible();
});
```

- [ ] **Schritt 2: Laufen lassen, bauen, laufen lassen**

Erwartet erst **FAIL** (die Seite trägt heute keinen dieser Texte), nach dem Bau **PASS**.

Der anonyme Zweig von `page.tsx` rendert die Landeseite. Sie bekommt ein eigenes kleines Stylesheet, weil sie als einzige Seite des Projekts eine Satzzeile über drei Zeilen trägt — das ist Layout für genau einen Bildschirm und deshalb kein Baustein.

- [ ] **Schritt 3: Sichtprüfung und Commit**

Screenshot `/` ohne Sitzung gegen `Start.dc.html`.

```bash
git add apps/web/app/page.tsx apps/web/app/einstieg e2e/wurzel.spec.ts
git commit -m "feat(web): die Wurzelseite ist keine Sackgasse mehr -- Landeseite statt M0-Rauchprobe"
```

---

## Aufgabe 11: Der Mitgliedsbildschirm und das Beitrittsformular

**Entscheidung 1 der Spec gilt hier**, und sie weicht bewusst von der Canvas-Notiz ab:

> `note-einstieg`: *„Der Studio-Code steht hier ausdrücklich nicht mehr — er macht Mitglieder, und Mitglieder haben im Web nichts zu tun."*

Das Formular **bleibt**, gestaltet. Der Weg, der es ersetzen soll, ist die iOS-App, und die ist Phase 6 — `apps/` enthält nur `web`. Ein Weg wird nicht gestrichen, bevor sein Nachfolger existiert. Sonst gäbe es im ganzen Produkt keinen Beitrittsweg mehr, und `e2e/leute.spec.ts` verlöre den einzigen menschlichen Gang, mit dem es ein Mitglied erzeugt.

**Das ist Befund 9 und trägt einen Auslöser:** sobald die App den Beitritt trägt, fällt der Block hier weg.

**Artboard:** untere Hälfte von `KeinStudio.dc.html` — *„Du wolltest trainieren? Das Portal ist für Studios. Trainieren läuft in der App — dort trittst du deinem Studio bei, indem du den Aushang am Eingang oder den Aufkleber an einem Gerät scannst."*

**Dateien:**
- Ändern: `apps/web/app/page.tsx`
- Ändern: `apps/web/app/BeitrittsFormular.tsx`
- Ändern: `e2e/wurzel.spec.ts`

**Schnittstellen:**
- Nutzt: `Einstieg` aus Aufgabe 6, `beitreten` aus `app/actions.ts` (unverändert)
- **Bleibt unverändert:** `data-testid="beitritt-formular"`, `data-testid="studio-list"`, `data-testid="user-email"`, das Label *Studio-Code* und der Knopf *Beitreten*. **Sechs Tests in vier Dateien** hängen daran, nachgezählt: `auth.spec.ts` (Zeilen 25, 80, 106–110 — drei Tests), `login.spec.ts` (42–43), `leute.spec.ts` (50–52), `onboarding.spec.ts` (22, prüft die **Abwesenheit** von `user-email`). Eine Gestaltungsänderung, die sie bricht, ist keine.

`leute.spec.ts` ist der heikelste: er benutzt das Beitrittsformular nicht, um es zu prüfen, sondern um sich ein Mitglied zu bauen, das der Trainer danach hochstuft. Bricht das Formular, fällt ein Test über die **Rechteverwaltung** aus, und dort sucht niemand nach einer Änderung an der Wurzelseite.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
import { anmelden, adminClient, E2E_PASSWORD } from "./helpers/login";

test("Ein Mitglied ohne Studio bekommt den Beitrittsweg und die Wahrheit dazu", async ({
  page,
}) => {
  const admin = adminClient();
  const email = `e2e-wurzel-mitglied-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await anmelden(page, email);

  expect(await hauptlandmarken(page)).toBe(1);
  await expect(page.getByTestId("beitritt-formular")).toBeVisible();
  await expect(page.getByLabel("Studio-Code")).toBeVisible();

  // Der Satz aus dem Artboard: das Web ist nicht der Ort zum Trainieren.
  await expect(page.getByText(/Trainieren läuft in der App/)).toBeVisible();
});

test("Ein falscher Studio-Code meldet sich als Warnung", async ({ page }) => {
  const admin = adminClient();
  const email = `e2e-wurzel-code-${crypto.randomUUID()}@example.test`;
  const { error } = await admin.auth.admin.createUser({
    email,
    password: E2E_PASSWORD,
    email_confirm: true,
  });
  if (error) throw error;

  await anmelden(page, email);
  await page.getByLabel("Studio-Code").fill("GIBTESNICHT");
  await page.getByRole("button", { name: "Beitreten" }).click();

  // fehlermeldung() statt getByRole("alert"): Next legt einen leeren
  // Route-Announcer mit role="alert" ins Dokument, der Selektor ist damit
  // immer mehrdeutig -- und bricht genau im Fehlerfall ab.
  await expect(fehlermeldung(page)).toBeVisible();
});
```

- [ ] **Schritt 2: Laufen lassen, bauen, laufen lassen**

Der angemeldete Nicht-Mitarbeiter-Zweig von `page.tsx` bekommt `Einstieg titel="Noch kein Studio"` mit dem Artboard-Text; darunter das Beitrittsformular als Karte. Hat das Konto bereits ein Studio, steht statt des Formulars die Studioliste (`data-testid="studio-list"` bleibt) und derselbe Satz zur App.

`BeitrittsFormular.tsx` bekommt `Feld` aus `Form.tsx` und `role="alert"` an der Fehlermeldung.

**Ein Kommentar gehört über den Formularblock**, damit die Abweichung nicht später für ein Versehen gehalten wird:

```tsx
/*
 * Der Studio-Code steht hier gegen die Canvas-Notiz note-einstieg, die ihn
 * aus dem Web streichen will. Der Grund ist kein Widerspruch, sondern eine
 * Reihenfolge: den Beitritt soll die iOS-App tragen (Scan des Aushangs
 * oder des Aufklebers), und die ist Phase 6 -- apps/ enthaelt nur web.
 * Faellt das Formular vorher, gibt es im ganzen Produkt keinen
 * Beitrittsweg mehr.
 *
 * Auslöser fuer den Rueckbau ist die App, kein Datum.
 */
```

- [ ] **Schritt 3: Die volle Suite**

```
pnpm test:e2e
```

Bindend ist nicht eine Gesamtzahl, sondern: kein zuvor grüner Test wird rot. Besonders auf `auth.spec.ts`, `login.spec.ts`, `leute.spec.ts` und `onboarding.spec.ts` achten — alle vier gehen über diese Seite.

- [ ] **Schritt 4: Sichtprüfung und Commit**

```bash
git add apps/web/app e2e/wurzel.spec.ts
git commit -m "feat(web): der Mitgliedsbildschirm auf / -- Beitritt bleibt, solange die App fehlt"
```

---

# Abschnitt 3 — Rail und Zusammenlegung

**Ab hier ist nichts mehr rebase-neutral.** Phase 4 fasst dieselbe Rail und dieselbe Route-Gruppe an. Zwei Aufgaben, zwei Commits, ein zusammenhängender Block — wer sie über acht Commits verteilt, löst acht Konflikte statt zwei.

---

## Aufgabe 12: Die Rail wird feste Navigation

Heute listet die Rail **jedes Gerätemodell einzeln**. Das ist genau der Zustand, den Struktur-Spec §1 abschafft:

> Canvas-Notiz `note-rail`: *„Sie listete früher jedes Gerätemodell einzeln — bei fünfzig Geräten unbrauchbar. Objekte leben jetzt auf Listenseiten; die Rail zeigt sechs feste Bereiche, mit Zahlen, die den Blick lenken."*

**Artboard:** die Rail steht auf jedem Portal-Artboard identisch; `Main.dc.html` ist die Vorlage.

```
STUDIO        Überblick        (Kurse — noch nicht, siehe unten)
KATALOG       Geräte           Tags
VERWALTUNG    Leute            Einstellungen
```

Darunter, abgesetzt durch eine `line`-Kante: die E-Mail-Adresse und *Abmelden*.

**Der Kurse-Eintrag bleibt — er steht schon da.** Ursprünglich sah dieser Plan vor, ihn auszulassen, bis Aufgabe 22 die Seiten baut (Designsystem §11: *„Ein leerer Tab ist ein Versprechen ohne Gegenwert."*). **Am 4. September überholt:** Phase 4 ist in `master` gemergt, die Kurse-Routen existieren, und Phase 4 hat den Eintrag selbst in die Gruppe *Studio* gesetzt. Die Regel greift nicht mehr, weil das Versprechen eingelöst ist.

Übernimm ihn unverändert in die neue Rail, samt seiner Erkennung des aktiven Zustands über `pfad.startsWith(`${basis}/kurse`)` — die Kurse haben Unterrouten (`/kurse/vorlagen`, `/kurse/termin/…`), ein Gleichheitsvergleich würde die Zeile dort nicht markieren. Der Zusatz *„5 diese Woche"* aus dem Artboard braucht eine Zahl aus der Fachschicht; **bau ihn nicht auf Verdacht** — sieh nach, ob Phase 4 sie liefert, und melde es, wenn nicht.

**Die Rail braucht einen Kein-Recht-Fall.** Ihre Zahl *„24 Mitglieder · 4 Mitarbeiter"* kommt aus `listStudioMembers`, und das wirft für ein einfaches Mitglied `unauthorized`. Ohne Abfangen zerbricht die gemeinsame Navigation an der Rolle — auf jeder Seite gleichzeitig.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/Rail.tsx`
- Ändern: `apps/web/app/portal/[studioId]/catalog.ts` — `railZahlen` dazu
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/layout.tsx`
- Ändern: `apps/web/app/portal/portal.module.css` — Fußzeile
- Anlegen: `e2e/rail.spec.ts`

**Schnittstellen:**
- Nutzt: `ladeKatalog`, `erreichbarkeit` aus `catalog.ts`; `listStudioMembers`, `DomainError` aus `@fitretro/domain`; `abmelden` aus `portal/actions.ts`
- Liefert:
  ```ts
  type RailZahlen = {
    geraete: number;
    erreichbar: number;
    vorrat: number;
    /** null heisst "darf ich nicht wissen", nicht "keine". */
    mitglieder: number | null;
    mitarbeiter: number | null;
  };
  function railZahlen(studioId: string): Promise<RailZahlen>;
  ```
- **Bleibt unverändert:** `aria-label="Katalog"` an der Rail. `e2e/einrichten.spec.ts:532` und `e2e/onboarding.spec.ts:19` greifen darauf zu.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

`e2e/rail.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { hauptlandmarken } from "./helpers/abnahme";
import { studioMitMitglied, studioMitTrainer } from "./helpers/studio";

test("Die Rail zeigt sechs feste Bereiche in drei Gruppen, nicht jedes Modell", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "rail-fest");

  // Drei Modelle anlegen -- frueher waeren das drei Rail-Eintraege gewesen.
  for (const name of ["Latzug", "Beinpresse", "Brustpresse"]) {
    const { error } = await admin.from("equipment_models").insert({ studio_id: studioId, name });
    if (error) throw error;
  }

  await page.goto(`/portal/${studioId}`);
  const rail = page.getByRole("navigation", { name: "Katalog" });

  for (const eintrag of ["Überblick", "Geräte", "Tags", "Leute", "Einstellungen"]) {
    await expect(rail.getByRole("link", { name: new RegExp(eintrag) })).toBeVisible();
  }

  // Die Modelle stehen NICHT mehr in der Rail.
  await expect(rail.getByRole("link", { name: /Latzug/ })).toHaveCount(0);
  await expect(rail.getByRole("link", { name: /Modell anlegen/ })).toHaveCount(0);
});

test("Kurse steht in der Rail und bleibt auf seinen Unterrouten markiert", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "rail-kurse");
  const rail = page.getByRole("navigation", { name: "Katalog" });

  await page.goto(`/portal/${studioId}/kurse`);
  await expect(rail.getByRole("link", { name: /Kurse/ })).toHaveAttribute(
    "aria-current",
    "page",
  );

  // Die Kurse haben Unterrouten. Ein Gleichheitsvergleich auf den Pfad
  // wuerde die Zeile hier nicht mehr markieren -- der Trainer saehe nicht,
  // wo er ist.
  await page.goto(`/portal/${studioId}/kurse/vorlagen`);
  await expect(rail.getByRole("link", { name: /Kurse/ })).toHaveAttribute(
    "aria-current",
    "page",
  );
});

test("Die Rail traegt die Abmeldung und die eigene Adresse", async ({ page }) => {
  const { studioId, email } = await studioMitTrainer(page, "rail-fuss");
  await page.goto(`/portal/${studioId}`);

  const rail = page.getByRole("navigation", { name: "Katalog" });
  await expect(rail.getByText(email)).toBeVisible();
  await expect(rail.getByRole("button", { name: "Abmelden" })).toBeVisible();
});

test("Ein Mitglied bekommt eine Rail ohne Zahlen statt einer kaputten Seite", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "rail-recht");
  await page.goto(`/portal/${studioId}`);

  // Die Rail steht. Das ist der ganze Test: listStudioMembers wirft fuer
  // ein Mitglied "unauthorized", und ohne Abfangen faellt damit die
  // Navigation jeder Seite gleichzeitig aus.
  await expect(page.getByRole("navigation", { name: "Katalog" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Leute/ })).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);
});
```

- [ ] **Schritt 2: Laufen lassen**

```
pnpm exec playwright test rail.spec.ts
```

Erwartet: **FAIL** auf allen vier.

- [ ] **Schritt 3: `railZahlen` in `catalog.ts` schreiben**

```ts
/**
 * Die Zahlen der Rail an einer Stelle -- sie stehen auf jeder Seite und
 * duerfen deshalb nirgends eine Seite kosten.
 *
 * mitglieder/mitarbeiter sind `null`, wenn das Konto sie nicht sehen darf:
 * listStudioMembers wirft fuer ein einfaches Mitglied "unauthorized". Das
 * ist kein Fehler, sondern die Datenschutzgrenze -- und ohne dieses
 * Abfangen faellt die Navigation JEDER Seite gleichzeitig aus, nicht nur
 * die Zahl.
 *
 * `null` heisst "darf ich nicht wissen", nicht "keine". Die Rail zeigt
 * dann keine Zeile statt einer 0.
 */
export const railZahlen = cache(async (studioId: string): Promise<RailZahlen> => {
  const katalog = await ladeKatalog(studioId);
  const client = await createServerSupabaseClient();

  const summe = katalog.models.reduce(
    (stand, modell) => {
      const { geraete, erreichbar } = erreichbarkeit(modell);
      return { geraete: stand.geraete + geraete, erreichbar: stand.erreichbar + erreichbar };
    },
    { geraete: 0, erreichbar: 0 },
  );

  let mitglieder: number | null = null;
  let mitarbeiter: number | null = null;
  try {
    const leute = await listStudioMembers(client, studioId);
    mitglieder = leute.filter((person) => person.role === "member").length;
    mitarbeiter = leute.length - mitglieder;
  } catch (fehler) {
    if (!(fehler instanceof DomainError && fehler.code === "unauthorized")) throw fehler;
  }

  return {
    ...summe,
    vorrat: katalog.tags.filter((tag) => tag.status === "unassigned").length,
    mitglieder,
    mitarbeiter,
  };
});
```

**Nur `unauthorized` wird geschluckt.** Jeder andere Fehler fliegt weiter und landet in `error.tsx` — sonst versteckt die Rail eine kaputte Datenbank hinter einer fehlenden Zahl.

- [ ] **Schritt 4: Die Rail umbauen**

Drei Gruppen mit den Beschriftungen *Studio*, *Katalog*, *Verwaltung*; je Eintrag Titel und Zusatzzeile nach `Main.dc.html`:

| Eintrag | Zusatz | wenn null/leer |
| --- | --- | --- |
| Überblick | — | — |
| Geräte | `4 · 2 erreichbar` | `noch kein Gerät` |
| Tags | `97 vorrätig` | `keine vorrätig` |
| Leute | `24 Mitglieder · 4 Mitarbeiter` | **keine Zeile** |
| Einstellungen | — | — |

Die Fußzeile ist ein `<form action={abmelden}>` mit einem Textknopf, darüber die Adresse aus `supabase.auth.getUser()`. Der Akzent bleibt die 2-px-Kante der aktiven Zeile — **keine Fläche**, die gehört der Hauptaktion des Inhalts.

- [ ] **Schritt 5: Laufen lassen**

```
pnpm exec playwright test rail.spec.ts einrichten.spec.ts onboarding.spec.ts
```

Erwartet: **PASS**. `einrichten.spec.ts:528` prüft, dass jede Schreibtischseite die Rail trägt — dieser Test ist ab jetzt der Wächter über die Zusammenlegung.

- [ ] **Schritt 6: Sichtprüfung und Commit**

```bash
git add apps/web/app/portal e2e/rail.spec.ts
git commit -m "feat(web): die Rail wird feste Navigation -- sechs Bereiche, und sie zerbricht nicht an der Rolle"
```

---

## Aufgabe 13: Geräte und Modelle werden ein Bereich

Struktur-Spec, Entscheidung 5. Heute sind es zwei Routen mit zwei Bedeutungen; danach ist *Geräte* der Bereich und die Modellliste seine Startseite.

**Die flache Geräteliste entfällt — und kostet nichts.** Ihre beiden Aktionen, *Stilllegen* und *Wieder in Betrieb*, stehen bereits im Modell-Detail unter *Geräte im Raum* (`modelle/[modelId]/page.tsx`, Abschnitt 4). Die flache Liste war eine zweite Kopie derselben Aktionen an einem Ort, den kein Artboard zeichnet.

**Artboard:** `Geraete.dc.html` — Titel *Geräte*, Vorspann über den Unterschied Modell/Gerät, dann ein Abschnitt *Alle Gerätemodelle* mit der Hauptaktion *Modell anlegen* im Kopf.

**Die eine Akzentfläche ist *Modell anlegen*.** Canvas-Notiz `note-akzent`: *„Auf der Geräteseite — der zusammengelegten Liste der Modelle — gehört der Akzent dem Anlegen."*

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx` — **wird die Modellliste**
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/modelle/page.tsx` — **wird eine Weiterleitung**
- Ändern: `e2e/trainerportal.spec.ts`, `e2e/einrichten.spec.ts`
- Ändern: `e2e/rail.spec.ts`

**Schnittstellen:**
- Nutzt: `ladeKatalog`, `erreichbarkeit`; `Seite`, `Abschnitt`, `Zeilen`, `Zeile`, `Zustand`
- Liefert: `/portal/<id>/geraete` als Bereichsstartseite. Die Aufgaben 16–18 hängen ihre Reiter darunter.

**Warum `/modelle` weiterleitet statt zu verschwinden:** die Route steht in `trainerportal.spec.ts:129`, in `einrichten.spec.ts:536`, in drei Links im Überblick und vermutlich in Lesezeichen. Eine Weiterleitung kostet vier Zeilen und bricht nichts. Sie ist **dauerhaft**, kein Übergang — `/modelle` ist ab jetzt ein zweiter Name für denselben Ort.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

An `e2e/rail.spec.ts` anhängen:

```ts
test("Geräte ist der Bereich, und seine Startseite listet die Modelle", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "geraete-bereich");
  const { error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", manufacturer: "Technogym" });
  if (error) throw error;

  await page.goto(`/portal/${studioId}`);
  await page.getByRole("navigation", { name: "Katalog" }).getByRole("link", { name: /Geräte/ }).click();

  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete$`));
  await expect(page.getByRole("heading", { name: "Geräte" })).toBeVisible();
  await expect(page.getByRole("link", { name: /Latzug/ })).toBeVisible();
});

test("Der alte Weg /modelle fuehrt auf denselben Ort, statt ins Leere", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "geraete-alt");
  await page.goto(`/portal/${studioId}/modelle`);
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete$`));
});

test("Ein Studio ohne Modell sagt, womit man anfaengt", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "geraete-leer");
  await page.goto(`/portal/${studioId}/geraete`);

  await expect(page.getByText(/Noch kein Gerätemodell/)).toBeVisible();
  await expect(page.locator("[role=alert]")).toHaveCount(0);
});

test("Die Geräteseite traegt genau eine Akzentflaeche: das Anlegen", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "geraete-akzent");
  await page.goto(`/portal/${studioId}/geraete`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);
});
```

- [ ] **Schritt 2: Laufen lassen**

Erwartet: **FAIL** — `/geraete` zeigt heute Geräte, keine Modelle, und `/modelle` leitet nicht.

- [ ] **Schritt 3: Umbauen**

`geraete/page.tsx` bekommt den Inhalt der heutigen `modelle/page.tsx`, gestaltet nach `Geraete.dc.html`. Die Zusatzzeile je Modell steht dort wörtlich und ist dicht:

```
Technogym · 2 Geräte, 1 erreichbar · 2 Übungen, 1 mit Video · Foto · 2 Parameter
```

Fehlendes steht in `text-faint` als Tatsache, nicht als Mangel — `ohne Hersteller`, `noch kein Gerät`, `keine Übung`, `kein Foto, keine Parameter`. Die Regel steht schon im Kommentar über `.absent` in `portal.module.css` und gilt weiter.

`modelle/page.tsx` wird:

```tsx
import { redirect } from "next/navigation";

/**
 * Geraetemodelle und Geraete sind ein Bereich (Struktur-Spec, Entscheidung
 * 5). Die Liste lebt unter /geraete; dieser Pfad bleibt als zweiter Name
 * bestehen -- er steht in Tests, in drei Links des Ueberblicks und
 * vermutlich in Lesezeichen. Eine Weiterleitung kostet vier Zeilen und
 * bricht nichts.
 */
export default async function ModelleWeiterleitung({
  params,
}: {
  params: Promise<{ studioId: string }>;
}) {
  const { studioId } = await params;
  redirect(`/portal/${studioId}/geraete`);
}
```

- [ ] **Schritt 4: Die bestehenden Tests auf den neuen Weg ziehen**

`trainerportal.spec.ts:128–129` navigiert nach `/modelle` und erwartet die Modellliste — läuft über die Weiterleitung weiter, der Kommentar darüber („Der Katalog liegt seit dem Überblick unter /modelle") wird nachgezogen.

`trainerportal.spec.ts:187` navigiert nach `/geraete` und erwartet die **flache Liste**. Dieser Test prüft ab jetzt dasselbe an seinem neuen Ort: die Geräte eines Modells stehen im Modell-Detail. Der Weg dorthin ist ein Klick mehr — und das ist die Zusammenlegung, kein Verlust.

`einrichten.spec.ts:536` zählt `/modelle` **und** `/geraete` als Schreibtischseiten. Beide tragen weiter die Rail; die Liste bleibt unverändert.

- [ ] **Schritt 5: Die volle Suite**

```
pnpm typecheck && pnpm test && pnpm test:integration && pnpm test:e2e
```

Erwartet: **112 Unit** (85 Domain + 27 Web — Phase 4 hat die Zahl seit dem Rebase gehoben). Für Integration und E2E gilt keine Zielzahl mehr, sondern die Ursache: **jeder rote Integrationstest scheitert an `workout_sessions_completed_after_start`** (Uhrendrift im Container), und **kein zuvor grüner E2E-Test wird rot**.

**Lauf die E2E-Suite nicht als Ganzes** — die Maschine schießt sie beim Start wegen Speichermangels ab. Dateiweise mit `--workers=1`, und nur die betroffenen: `trainerportal.spec.ts`, `einrichten.spec.ts`, `rail.spec.ts`, `bausteine.spec.ts`.

- [ ] **Schritt 6: Sichtprüfung und Commit**

```bash
git add apps/web/app/portal e2e
git commit -m "feat(web): Geraete und Modelle werden ein Bereich -- die flache Liste war eine Kopie"
```

---

# Abschnitt 4 — Die Listen

Zwei Aufgaben. Tags ist in Aufgabe 5 schon fertig.

---

## Aufgabe 14: Der Überblick

Die dichteste Seite des Portals und die einzige mit Kennzahlen. Sie ist funktional vollständig — Kacheln, „Was noch fehlt", Meistgenutzt, Gemeldete Probleme, alle Zustände inklusive der Mindestzahl-Verdeckung. Was fehlt, ist die Form.

**Artboard:** `Main.dc.html`.

**Der Abschnitt *Diese Woche* aus dem Artboard wird nicht gebaut.** Er zeigt Kurstermine, und Kurse gibt es in Phase 5 nicht. Er kommt in Aufgabe 22 dazu.

**Diese Aufgabe löst zusätzlich Befund 19 auf: der Baustein `Produktgrenze`.** Der Satz „gymodo misst nichts …" steht an drei Stellen und überall in `text-faint` — einem Kontrast, den Designsystem §2 für Pflichttext ausdrücklich verbietet. Leg `apps/web/app/portal/bausteine/Produktgrenze.tsx` an: er trägt den Wortlaut **und** den Kontrast an einer Stelle, in `text-muted`. Der Überblick benutzt ihn hier, die Wurzelseite zieht nach, `/t/<token>` bleibt Aufgabe 21 (dort gilt die Member-Ebene, nicht `bausteine.module.css`).

Der Wortlaut ist je Ort verschieden — der Überblick sagt „Alles hier ist gezählt, was Mitglieder selbst bestätigt haben", die Landeseite die lange Fassung aus `Start.dc.html`. Der Baustein nimmt den Text deshalb als `children` und trägt nur Kontrast und Abstand. **Er erfindet keinen gemeinsamen Wortlaut**, den kein Artboard zeigt.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/page.tsx`
- Anlegen: `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `Seite`, `Abschnitt`, `Zeilen`, `Zeile`, `Kacheln`, `Kachel`, `Zustand`; `getStudioOverview`, `StudioOverview` aus `@fitretro/domain`
- Liefert: nichts für spätere Aufgaben

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

`e2e/schreibtisch.spec.ts`:

```ts
import { expect, test } from "@playwright/test";
import { akzentflaechen, hauptlandmarken, zuKleineBedienelemente } from "./helpers/abnahme";
import { studioMitMitglied, studioMitTrainer } from "./helpers/studio";

test("Ein frisches Studio zeigt keine vier Nullen, sondern einen Anfang", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-leer");
  await page.goto(`/portal/${studioId}`);

  // Designsystem 5: nie eine leere Statistik mit Nullen.
  await expect(page.getByText(/Noch nichts zu zählen/)).toBeVisible();
  await expect(page.getByText("Mitglieder aktiv")).toHaveCount(0);
});

test("Der Ueberblick nennt die Produktgrenze und die Datenschutzgrenze", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-grenzen");
  await page.goto(`/portal/${studioId}`);

  await expect(page.getByText(/gymodo misst nichts/)).toBeVisible();
});

test("Ein Mitglied sieht den Ueberblick nicht, aber auch keinen Absturz", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "ueberblick-recht");
  await page.goto(`/portal/${studioId}`);

  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
  await expect(page.getByText(/in der App, nicht hier/)).toBeVisible();
  expect(await hauptlandmarken(page)).toBe(1);
});

test("Der Ueberblick traegt hoechstens eine Akzentflaeche", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "ueberblick-akzent");
  await page.goto(`/portal/${studioId}`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen.length, `Akzentflaechen: ${flaechen.join(", ")}`).toBeLessThanOrEqual(1);
});
```

**`toBeLessThanOrEqual(1)` und nicht `toBe(1)`:** ein frisches Studio hat keine Hauptaktion — der Leer-Zustand nennt den nächsten Schritt als Text, und die Zeile „Noch kein Gerät angelegt" trägt eine **Neben**aktion. Null ist hier richtig, und ein Test, der eins erzwingt, würde eine Akzentfläche erfinden, wo keine hingehört.

- [ ] **Schritt 2: Laufen lassen, umbauen, laufen lassen**

Die bestehende Logik bleibt **vollständig erhalten** — sie ist richtig und mühsam erarbeitet: die Verdeckung unterhalb der Mindestzahl, der Strich statt der Null, der Fehlerfall der Summen neben einem funktionierenden Katalog. Nur die Hülle wechselt auf Bausteine, und die vier Kacheln bekommen die Form aus `Main.dc.html`.

Die vier Zusatzzeilen der Kacheln sind wörtlich: *Geräte erreichbar*, *Mitglieder aktiv*, *Sätze erfasst*, *Probleme gemeldet*.

- [ ] **Schritt 3: Sichtprüfung und Commit**

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/page.tsx" e2e/schreibtisch.spec.ts
git commit -m "feat(web): der Ueberblick gestaltet -- die Verdeckung bleibt, die Form kommt dazu"
```

---

## Aufgabe 15: Die Geräteliste abnehmen

Aufgabe 13 hat `/geraete` inhaltlich umgebaut. Diese Aufgabe nimmt sie gegen das Artboard ab und schließt die Zustände, die dabei noch offen sind.

**Warum getrennt von Aufgabe 13:** Aufgabe 13 ist ein Routen- und Bedeutungswechsel mit Folgen für vier Testdateien. Die Gestaltung im selben Commit hieße, einen Rebase-Konflikt über zweihundert Zeilen Formatierung zu lösen statt über zehn Zeilen Routing.

**Dateien:**
- Ändern: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/page.tsx`
- Ändern: `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: dieselben Bausteine wie Aufgabe 14
- Liefert: nichts für spätere Aufgaben

- [ ] **Schritt 1: Den Kein-Recht-Test schreiben**

```ts
test("Ein Mitglied sieht die Geräteliste nicht", async ({ page }) => {
  const { studioId } = await studioMitMitglied(page, "geraete-recht");
  await page.goto(`/portal/${studioId}/geraete`);

  await expect(page.getByRole("heading", { name: "Geräte" })).toBeVisible();
  await expect(page.getByText(/Trainern und Inhabern vorbehalten/)).toBeVisible();
});

test("Die Bedienelemente der Geräteliste sind gross genug", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "geraete-treffer");
  await page.goto(`/portal/${studioId}/geraete`);

  const zuKlein = await zuKleineBedienelemente(page, 40);
  expect(zuKlein, `zu klein: ${zuKlein.join(", ")}`).toHaveLength(0);
});
```

**Hinweis zum Kein-Recht-Fall:** `getStudioCatalog` wirft für ein Mitglied **nicht** `unauthorized` — RLS gibt ihm schlicht weniger Zeilen zurück. Wenn der Test rot bleibt, weil die Seite eine leere Liste statt des Satzes zeigt, ist das ein **Befund**, kein Testfehler: dann prüft die Seite die Rolle nicht, und der Unterschied zwischen „darf nicht" und „ist leer" fällt unter den Tisch. Er gehört dann in die Befundliste und wird über `railZahlen().mitglieder === null` entschieden — dieselbe Rolle, dieselbe Frage, schon beantwortet.

- [ ] **Schritt 2: Umbauen, Sichtprüfung gegen `Geraete.dc.html`, Commit**

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/geraete" e2e/schreibtisch.spec.ts
git commit -m "feat(web): die Geraeteliste abgenommen gegen ihr Artboard"
```

---

# Abschnitt 5 — Detail und Reiter

Fünf Aufgaben, acht Bildschirme. Die Reiterschicht ist der rote Faden: **ein Reiter je Bildschirm bedeutet ein Formular je Bildschirm**, und erst dadurch hält die Akzentregel wörtlich.

Die heutige Modellseite ist der Gegenbeweis — fünf Abschnitte mit fünf Formularen auf einem Schirm:

> Canvas-Notiz `note-akzent`: *„Die Modellseite zeigte früher fünf Akzentflächen gleichzeitig, eine je Formular. Reiter lösen das: immer nur ein Formular sichtbar, die Regel des Designsystems hält jetzt wörtlich."*

**`einstellungen/Reiter.tsx` gibt es bereits** — mit derselben Begründung im Kommentar. Er ist eine Client-Komponente, weil er `usePathname` benutzt. Der Baustein aus Aufgabe 3 nimmt `aktiv` als Eigenschaft und ist deshalb eine Server-Komponente: die Seite kennt ihre eigene Route, sie muss sie nicht im Browser erfragen. Aufgabe 20 ersetzt die lokale Fassung.

---

## Aufgabe 16: Die Reiterschicht am Modell und der Reiter Stammdaten

Die heutige `modelle/[modelId]/page.tsx` ist 371 Zeilen mit fünf Abschnitten. Sie zerfällt in vier Routen. Diese Aufgabe legt das Gerüst und den ersten Reiter.

**Artboard:** `Modell.dc.html` — Kopfzeile mit Rückweg *← Geräte*, Modellname, Untertitel *Technogym · Schritt 2,5 kg · ab 5,0 kg bis 100,0 kg*, dann die vier Reiter mit Zustand in der Beschriftung.

**Foto fällt in Stammdaten.** Das Artboard hat vier Reiter, die heutige Seite fünf Abschnitte — *Foto* ist keiner davon, es gehört zu den Stammdaten des Modells.

**Dateien:**
- Anlegen: `(schreibtisch)/geraete/[modelId]/layout.tsx` — Kopf und Reiterleiste
- Anlegen: `(schreibtisch)/geraete/[modelId]/page.tsx` — Stammdaten samt Foto
- Ändern: `(schreibtisch)/modelle/[modelId]/page.tsx` — **wird eine Weiterleitung**
- Ändern: `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `Reiter` aus Aufgabe 3; `ladeKatalog`; `modellSpeichern`, `fotoHochladen` aus `portal/actions.ts` (unverändert)
- Liefert: die vier Routen, auf die Aufgabe 17 und 18 bauen:
  - `/portal/<id>/geraete/<modelId>` — Stammdaten
  - `/portal/<id>/geraete/<modelId>/einstellungen`
  - `/portal/<id>/geraete/<modelId>/uebungen`
  - `/portal/<id>/geraete/<modelId>/instanzen` — *Einzelne Geräte*

**Warum `instanzen` und nicht `geraete`:** `/portal/<id>/geraete/<modelId>/geraete` liest sich wie ein Fehler und ist eine Falle beim Lesen von Logs. Der Reiter **heißt** in der Oberfläche *Einzelne Geräte* — der Pfad muss ihm nicht folgen.

**Achtung, Namenskollision:** unter `/geraete/` liegen ab jetzt sowohl die Modellliste (`page.tsx`) als auch die Modelldetails (`[modelId]/`). Das ist gewollt und die übliche Form; `[modelId]` fängt nur, was `page.tsx` nicht ist.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Das Modell zeigt vier Reiter, und jeder traegt seinen Zustand", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-reiter");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug", manufacturer: "Technogym" })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}`);

  const reiter = page.getByRole("navigation", { name: "Modell" });
  for (const name of ["Stammdaten", "Einstellungen", "Übungen", "Einzelne Geräte"]) {
    await expect(reiter.getByRole("link", { name: new RegExp(name) })).toBeVisible();
  }
  await expect(reiter.getByRole("link", { name: /Stammdaten/ })).toHaveAttribute(
    "aria-current",
    "page",
  );
});

test("Jeder Modellreiter traegt genau eine Akzentflaeche -- ein Formular je Bildschirm", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-akzent");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Beinpresse" })
    .select("id")
    .single();
  if (error) throw error;

  for (const reiter of ["", "/einstellungen", "/uebungen", "/instanzen"]) {
    await page.goto(`/portal/${studioId}/geraete/${modell.id}${reiter}`);
    const flaechen = await akzentflaechen(page);
    expect(
      flaechen.length,
      `Reiter "${reiter || "Stammdaten"}" traegt ${flaechen.length}: ${flaechen.join(", ")}`,
    ).toBeLessThanOrEqual(1);
  }
});

test("Der alte Modellpfad fuehrt auf den neuen", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-alt");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Brustpresse" })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/modelle/${modell.id}`);
  await expect(page).toHaveURL(new RegExp(`/portal/${studioId}/geraete/${modell.id}$`));
});
```

Der zweite Test ist der eigentliche Punkt dieses Abschnitts: **er ist auf der heutigen Seite fünffach rot** und wird durch die Reiter grün. Er läuft schon jetzt über alle vier Routen, obwohl drei davon erst in Aufgabe 17 und 18 entstehen — bis dahin scheitert er am 404, und das ist die richtige Farbe.

- [ ] **Schritt 2: Laufen lassen**

Erwartet: **FAIL**. Die Route gibt es nicht.

- [ ] **Schritt 3: Layout und Stammdaten bauen**

`layout.tsx` trägt Rückweg, Modellname, Untertitel und die Reiterleiste mit `name="Modell"`. Die Zustände in der Beschriftung kommen aus dem Katalog, wörtlich nach Artboard:

| Reiter | Zusatz |
| --- | --- |
| Stammdaten | — |
| Einstellungen | `2 Parameter` |
| Übungen | `2 · 1 mit Video` |
| Einzelne Geräte | `2 · 1 ohne Tag` |

`page.tsx` trägt Stammdaten **und Foto** in einem Formular — Name, Hersteller, Schrittweite, Minimum, Maximum, Fotofeld. Eine Akzentfläche: *Änderungen speichern*.

`modelle/[modelId]/page.tsx` wird eine Weiterleitung nach demselben Muster wie in Aufgabe 13.

- [ ] **Schritt 4: Sichtprüfung und Commit**

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)" e2e/schreibtisch.spec.ts
git commit -m "feat(web): das Modell bekommt vier Reiter -- ein Formular je Bildschirm"
```

---

## Aufgabe 17: Die Reiter Einstellungen und Übungen

Zwei Reiter, aus den Abschnitten 2 und 3 der heutigen Seite.

**Artboards:** `Modell.dc.html` für die Reiterleiste; die Inhalte selbst zeichnen `TelefonEinstellungen.dc.html` und `TelefonUebungen.dc.html` — in der Telefonfassung, aber mit demselben Wortlaut und derselben Reihenfolge.

**Die Reihenfolge der Übungen ist keine Kosmetik.** Canvas-Notiz `note-uebungen`: *„Übung 1 ist am Gerät die Vorauswahl des Mitglieds."* Der Umordnen-Weg der heutigen Seite bleibt erhalten.

**Dateien:**
- Anlegen: `(schreibtisch)/geraete/[modelId]/einstellungen/page.tsx`
- Anlegen: `(schreibtisch)/geraete/[modelId]/uebungen/page.tsx`
- Ändern: `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `layout.tsx` aus Aufgabe 16; `parameterAnlegen`, `parameterLoeschen`, `uebungAnhaengen`, `uebungLoesen`, `uebungUmordnen`, `videoHochladen` aus `portal/actions.ts` (unverändert)
- Liefert: nichts für spätere Aufgaben

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Ohne Einstellparameter sagt der Reiter, wofuer sie da sind", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-param-leer");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug" })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/einstellungen`);
  await expect(page.getByText(/Noch keine Einstellparameter/)).toBeVisible();
});

test("Ohne Uebung nennt der Reiter den naechsten Schritt", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-uebung-leer");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug" })
    .select("id")
    .single();
  if (error) throw error;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/uebungen`);
  await expect(page.getByText(/Noch keine Übung/)).toBeVisible();
});
```

- [ ] **Schritt 2: Bauen, Sichtprüfung, Commit**

Der Videoupload behält `VideoUpload.tsx` unverändert — er trägt die Warteschlange und den TUS-Fortschritt und ist nicht Gegenstand dieser Phase. **Sein Fortschrittsbalken ist Befund 11**: `.progressBar` hat `background: var(--accent)` und ist damit eine zweite Akzentfläche neben der Hauptaktion. Der Akzenttest aus Aufgabe 16 wird auf diesem Reiter deshalb **rot, sobald ein Upload läuft** — im Ruhezustand ist er grün, weil der Balken dann nicht gerendert wird. Die Entscheidung fällt in Aufgabe 21, nicht hier.

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/geraete" e2e/schreibtisch.spec.ts
git commit -m "feat(web): die Reiter Einstellungen und Uebungen"
```

---

## Aufgabe 18: Der Reiter Einzelne Geräte

Der vierte Reiter, aus Abschnitt 4 der heutigen Seite. Hier steht die Zählung, die Struktur-Spec §1 beschreibt.

**Artboard:** `Modell.dc.html`, Abschnitte *Anzahl im Studio* und *Geräte*.

**Verringern gibt es nicht.** Wörtlich aus dem Artboard: *„Erhöhen legt die fehlenden Geräte an — Nummer, Standort und Tag vergibst du danach am Gerät, mit dem Telefon. Verringern gibt es nicht: ein Gerät wird stillgelegt, einzeln, mit Namen."*

**Das Artboard ist hier unvollständig — Befund 7.** Es zeichnet je Gerät nur *Tag scannen* und *Tag ersetzen*, aber die Spec verlangt das Stilllegen, und im Code steht es bereits. **Der Code gewinnt:** die Zeile trägt beide Aktionen. Das Artboard wird nachgezogen, nicht der Code beschnitten.

**Dateien:**
- Anlegen: `(schreibtisch)/geraete/[modelId]/instanzen/page.tsx`
- Ändern: `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `layout.tsx` aus Aufgabe 16; `geraetAnlegen`, `geraetStilllegen`, `geraetWiederInBetrieb` aus `portal/actions.ts` (unverändert)
- Liefert: nichts für spätere Aufgaben

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Der Reiter Einzelne Geräte traegt das Stilllegen, auch wenn das Artboard es vergisst", async ({
  page,
}) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-instanzen");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug" })
    .select("id")
    .single();
  if (error) throw error;
  const { error: geraetFehler } = await admin
    .from("machines")
    .insert({ studio_id: studioId, equipment_model_id: modell.id, label: "12" });
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/instanzen`);

  await expect(page.getByRole("button", { name: "Stilllegen" })).toBeVisible();
  await expect(page.getByRole("link", { name: "Tag scannen" })).toBeVisible();
});

test("Ein stillgelegtes Geraet bleibt sichtbar und benannt", async ({ page }) => {
  const { studioId, admin } = await studioMitTrainer(page, "modell-stillgelegt");
  const { data: modell, error } = await admin
    .from("equipment_models")
    .insert({ studio_id: studioId, name: "Latzug" })
    .select("id")
    .single();
  if (error) throw error;
  const { error: geraetFehler } = await admin.from("machines").insert({
    studio_id: studioId,
    equipment_model_id: modell.id,
    label: "13",
    status: "inactive",
  });
  if (geraetFehler) throw geraetFehler;

  await page.goto(`/portal/${studioId}/geraete/${modell.id}/instanzen`);

  // Geraete werden stillgelegt, nie geloescht (Designsystem 10). Ein
  // verschwundenes Geraet naehme die Zuordnungshistorie mit.
  await expect(page.getByText("13")).toBeVisible();
  await expect(page.getByText("stillgelegt")).toBeVisible();
  await expect(page.getByRole("button", { name: "Wieder in Betrieb" })).toBeVisible();
});
```

- [ ] **Schritt 2: Bauen, Sichtprüfung, Commit**

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/geraete" e2e/schreibtisch.spec.ts
git commit -m "feat(web): der Reiter Einzelne Geraete -- mit dem Stilllegen, das im Artboard fehlt"
```

---

## Aufgabe 19: Leute — Mitglieder und Mitarbeiter

Zwei Reiter, zwei Routen. Heute gibt es **eine** Seite mit einer Liste.

> Struktur-Spec §2: *„Damit ist die Mitarbeiterliste die Rechteverwaltung und der heikelste Bildschirm des Portals. Sie braucht die entsprechende Sorgfalt: bestätigte Handlung beim Hochstufen, und niemand kann sich selbst die letzte Inhaberrolle entziehen."*

**Artboards:** `LeuteMitglieder.dc.html`, `LeuteMitarbeiter.dc.html`.

**Dateien:**
- Ändern: `(schreibtisch)/leute/page.tsx` — wird der Reiter *Mitglieder*
- Anlegen: `(schreibtisch)/leute/mitarbeiter/page.tsx`
- Ändern: `(schreibtisch)/leute/LeuteActions.tsx`
- Ändern: `e2e/leute.spec.ts`, `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `Reiter` aus Aufgabe 3; `listStudioMembers`; die Rollenaktionen aus `portal/actions.ts` (unverändert)
- Liefert: nichts für spätere Aufgaben
- **Bleibt unverändert:** die Zeilenstruktur, auf die `e2e/leute.spec.ts:58` mit `page.locator("li", { hasText: mitgliedEmail })` zugreift. `Zeile` rendert ein `<li>` — das passt, aber es ist zu prüfen und nicht anzunehmen.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Leute hat zwei Reiter, und beide nennen ihre Zahl", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "leute-reiter");
  await page.goto(`/portal/${studioId}/leute`);

  const reiter = page.getByRole("navigation", { name: "Leute" });
  await expect(reiter.getByRole("link", { name: /Mitglieder/ })).toBeVisible();
  await expect(reiter.getByRole("link", { name: /Mitarbeiter/ })).toBeVisible();
});

test("Die eigene Zeile traegt keinen Knopf, der die eigene Rolle nimmt", async ({ page }) => {
  const { studioId, email } = await studioMitTrainer(page, "leute-selbst");
  await page.goto(`/portal/${studioId}/leute/mitarbeiter`);

  const eigene = page.locator("li", { hasText: email });
  await expect(eigene).toBeVisible();
  await expect(eigene.getByText("Das bist du")).toBeVisible();
  await expect(eigene.getByRole("button", { name: /herabstufen/i })).toHaveCount(0);
});

test("Hochstufen sagt vorher, was es bedeutet", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "leute-hochstufen");
  await page.goto(`/portal/${studioId}/leute/mitarbeiter`);

  // Wortlaut aus LeuteMitarbeiter.dc.html.
  await expect(
    page.getByText(/Hochstufen gibt Zugriff auf den ganzen Katalog/),
  ).toBeVisible();
  await expect(page.getByText(/Der Studio-Code macht niemanden zum Trainer/)).toBeVisible();
});
```

- [ ] **Schritt 2: Bauen**

Der Reiter *Mitglieder* listet Rolle `member`, der Reiter *Mitarbeiter* die Rollen `owner` und `trainer` plus das Formular zum Hochstufen. Die eigene Zeile trägt *Das bist du* statt eines Knopfes.

**Der Fußsatz von `LeuteMitglieder.dc.html` ist überholt und wird ersetzt.** Er sagt, die Datenbank lasse Mitarbeiter noch an Trainingsdaten heran — das galt bis `0033`. Seit dem 2. September haben die vier Policies die Staff-Klausel verloren. Der neue Satz sagt, was jetzt gilt: *„Trainingsdaten eines Mitglieds sieht nur das Mitglied selbst. Das Portal legt eine Mitgliedschaft an und beendet sie, sonst nichts."* **Das ist Befund 18.**

- [ ] **Schritt 3: `leute.spec.ts` prüfen, Sichtprüfung, Commit**

```
pnpm exec playwright test leute.spec.ts schreibtisch.spec.ts
```

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/leute" e2e
git commit -m "feat(web): Leute bekommt zwei Reiter -- die Rechteverwaltung steht fuer sich"
```

---

## Aufgabe 20: Einstellungen — Studio und Konto

Die beiden Reiter gibt es schon als Routen; sie bekommen ihre Form und den gemeinsamen Baustein.

**Artboards:** `EinstellungenStudio.dc.html`, `EinstellungenKonto.dc.html`.

**Dateien:**
- Ändern: `(schreibtisch)/einstellungen/page.tsx`, `konto/page.tsx`
- Löschen: `(schreibtisch)/einstellungen/Reiter.tsx` — geht in `bausteine/Reiter.tsx` auf
- Ändern: `(schreibtisch)/einstellungen/EinstellungenActions.tsx`
- Ändern: `e2e/einstellungen.spec.ts`, `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `Reiter` aus Aufgabe 3; `getStudioSettings`, `updateStudioSettings`; `abmelden`, `passwortAendern`, `beitrittscodeErneuern`, `beitrittscodeAktivSetzen`
- Liefert: nichts für spätere Aufgaben
- **Achtung:** `bausteine/Reiter.tsx` braucht `aria-label="Einstellungen"` an dieser Stelle, sonst bricht, was heute darauf zugreift.

**Der Reiter *Studio* trägt drei Formulare** — Stammdaten, Stornofrist, Studio-Code. Das ist mehr als eines und damit ein Verstoß gegen „ein Formular je Bildschirm". Das Artboard zeichnet es trotzdem so, und der Grund trägt: die drei sind keine Alternativen, sondern drei Einstellungen desselben Studios, und ein vierter Reiter für die Stornofrist wäre Bürokratie. **Die Akzentfläche bekommt nur *Änderungen speichern*;** *Neuen Code erzeugen* ist eine Nebenaktion, *Kopieren* ebenfalls. Damit hält die Akzentregel, auch wenn die Formularregel hier nachgibt.

- [ ] **Schritt 1: Die fehlschlagenden Tests schreiben**

```ts
test("Einstellungen Studio traegt trotz dreier Formulare eine Akzentflaeche", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "einst-akzent");
  await page.goto(`/portal/${studioId}/einstellungen`);

  const flaechen = await akzentflaechen(page);
  expect(flaechen, `Akzentflaechen: ${flaechen.join(", ")}`).toHaveLength(1);
});

test("Der Studio-Code sagt, was ein neuer Code kostet", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "einst-code");
  await page.goto(`/portal/${studioId}/einstellungen`);

  // Wortlaut aus EinstellungenStudio.dc.html.
  await expect(page.getByText(/macht den alten sofort ungültig/)).toBeVisible();
  await expect(page.getByText(/Aushangschilder tragen keinen Code/)).toBeVisible();
});

test("Der Konto-Reiter traegt den Passwortwechsel mit Wiederholung", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "einst-konto");
  await page.goto(`/portal/${studioId}/einstellungen/konto`);

  await expect(page.getByLabel("Aktuelles Passwort")).toBeVisible();
  await expect(page.getByLabel("Neues Passwort")).toBeVisible();
  await expect(page.getByLabel("Wiederholen")).toBeVisible();
});
```

**Der dritte Test kann rot bleiben** — hat der heutige Passwortwechsel kein Wiederholungsfeld, ist das dieselbe Lücke wie in Aufgabe 8, und sie wird hier genauso geschlossen: Gleichheitsprüfung vor dem Netzaufruf.

- [ ] **Schritt 2: Bauen, `einstellungen.spec.ts` prüfen, Sichtprüfung, Commit**

```bash
git add "apps/web/app/portal/[studioId]/(schreibtisch)/einstellungen" apps/web/app/portal/bausteine e2e
git commit -m "feat(web): Einstellungen gestaltet, und der lokale Reiter geht im Baustein auf"
```

---

# Abschnitt 6 — Abgleich

## Aufgabe 21: Telefon und Fallback gegen ihre Artboards

**Hier wird nichts neu gebaut.** Die 16 `Telefon*`-Bildschirme sind in Phase 3 gebaut und gestaltet, `/t/<token>` trägt seit dem Medienplan `fallback.module.css` nach Member-Maßen. Diese Aufgabe liest, vergleicht und schreibt auf.

**Und sie fällt eine Entscheidung:** Befund 11, die Akzentregel gegen den Fortschrittsbalken.

**Dateien:**
- Ändern: `docs/superpowers/specs/2026-09-03-portal-frontend-design.md` — Befundliste
- Möglicherweise ändern: `apps/web/app/portal/portal.module.css` oder `halle.module.css` — je nach Entscheidung zu Befund 11
- Ändern: `e2e/schreibtisch.spec.ts`

**Schnittstellen:**
- Nutzt: `akzentflaechen`, `zuKleineBedienelemente`
- Liefert: eine entschiedene Akzentregel, gegen die Aufgabe 23 abnimmt

- [ ] **Schritt 1: Die 16 Telefonseiten abgleichen**

Je Artboard: Seite im Browser öffnen (`run`-Skill, 390 px breit), Screenshot, gegen `docs/superpowers/design/portal/Telefon<Name>.dc.html` halten. Abweichungen als Zeile notieren — **nicht beheben.** Phase 3 ist abgenommen; was hier auffällt, ist ein Befund für den nächsten Bauabschnitt, keine stille Nachbesserung.

Der Weg durch die Halle ist sechsschrittig; `Ablauf.dc.html` zeigt ihn ganz. Die elf Zustandskarten stehen in `TelefonZustaende.dc.html`.

- [ ] **Schritt 2: `/t/<token>` abgleichen**

Drei Zustände, alle mit `data-testid` versehen und in `tag-fallback.spec.ts` geprüft: `tag-unknown`, `tag-aushang`, und der Gerätefall. Für den Fallback gibt es **kein Artboard** im Portalsatz — er folgt den Member-Maßen. Geprüft wird gegen `2026-09-01-scan-beitritt-design.md`, nicht gegen ein Bild.

- [ ] **Schritt 3: Befund 11 entscheiden und festschreiben**

Der Fortschrittsbalken hat `background: var(--accent)`. Zwei Wege, und beide sind vertretbar:

- **Ausnahme benennen.** Der Balken ist keine Aktion, sondern eine Anzeige; die Regel schützt die Erkennbarkeit der *Hauptaktion*, und ein Balken konkurriert nicht mit ihr. Dann bekommt `akzentflaechen` einen Ausschluss für `.progressBar`, mit dem Grund im Kommentar.
- **Den Akzent abgeben.** Der Balken wird `text-muted` oder `surface-hover`. Kostet die Sichtbarkeit des Fortschritts im Halbdunkel — und der Upload läuft in der Halle.

**Empfehlung: Ausnahme benennen.** Designsystem §6 nennt den Balken ausdrücklich als eigenes Mittel (*„Resttimer als linearer Balken, kein Spinner. Er zeigt Restdauer, nicht Beschäftigung"*), und ein grauer Fortschritt im Keller ist schlechter lesbar als ein grüner. Die Regel wird dadurch nicht weicher, sondern genauer: **genau eine Akzent*aktion* je Bildschirm**, plus Anzeigen, die keine sind.

Die Entscheidung wandert als Satz in die Spec, Abschnitt 4, Punkt 5 — und in den Kommentar von `akzentflaechen`.

- [ ] **Schritt 4: Commit**

```bash
git add docs e2e apps
git commit -m "docs: Abgleich Telefon und Fallback, und die Akzentregel bekommt ihre Ausnahme"
```

---

# Abschnitt 7 — Kurse und Abschluss

## Aufgabe 22: Kurse — nach dem Rebase, oder der Vermerk

**Diese Aufgabe hat zwei Fassungen.** Welche gilt, entscheidet der Stand von Phase 4 zum Zeitpunkt der Ausführung — nicht die Absicht beim Planen.

- [ ] **Schritt 1: Nachsehen, ob Phase 4 in `master` steht**

```bash
git fetch origin
git log origin/master --oneline -15
git log origin/master --oneline -- apps/web/app/portal/\*/kurse
```

**Trägt `origin/master` die Kurse-Routen → Fassung A. Sonst → Fassung B.**

### Fassung A — Phase 4 ist gemergt

- [ ] **A1: Rebase**

```bash
git rebase origin/master
```

Erwartet werden Konflikte in `Rail.tsx`, `catalog.ts` und `(schreibtisch)/layout.tsx` — dieselben Dateien, die Aufgabe 12 angefasst hat. Das ist der Preis, der beim Schnitt eingeplant wurde: **zwei Konflikte statt acht**, weil die Rail in einem Commit steht.

- [ ] **A2: Die volle Suite auf dem neuen Stand**

```
pnpm typecheck && pnpm test && pnpm test:integration && pnpm test:e2e
```

Vor dem E2E-Lauf: **was lauscht auf Port 3000?** Und der erste Lauf nach einem Rebase hat ein kaltes `.next` — er zählt nicht.

- [ ] **A3: Den Kurse-Eintrag in die Rail nehmen**

Der Test aus Aufgabe 12 *„Kurse fehlt in der Rail, solange es die Seite nicht gibt"* wird hier **umgedreht**, nicht gelöscht:

```ts
test("Kurse steht in der Rail, seit es die Seite gibt", async ({ page }) => {
  const { studioId } = await studioMitTrainer(page, "rail-kurse");
  await page.goto(`/portal/${studioId}`);
  await expect(
    page.getByRole("navigation", { name: "Katalog" }).getByRole("link", { name: /Kurse/ }),
  ).toBeVisible();
});
```

- [ ] **A4: Die fünf Kurse-Bildschirme gestalten**

`Kurse.dc.html`, `Kursvorlagen.dc.html`, `Kursvorlage.dc.html`, `TerminAnlegen.dc.html`, `Termin.dc.html` — nach dem Muster der Aufgaben 14–20, mit denselben vier Zuständen und derselben Abnahme.

Dazu der Abschnitt *Diese Woche* im Überblick, der in Aufgabe 14 ausgelassen wurde.

**Ein Satz darf nicht in die Oberfläche:** die Nachrück-Benachrichtigung von der Warteliste. Designsystem §11 und Struktur-Spec §8 sind darin einig — *„Benachrichtigungen existieren nicht, und bis sie existieren darf der Satz nicht in die App."* Das gilt für das Portal genauso.

### Fassung B — Phase 4 ist nicht gemergt

- [ ] **B1: Nichts bauen**

Kein Kurse-Eintrag in der Rail, keine Kurse-Routen, kein *Diese Woche* im Überblick. Der Test aus Aufgabe 12 bleibt, wie er ist, und ist der Wächter darüber.

- [ ] **B2: In den Plan schreiben, was offen bleibt**

An das Ende dieses Plans, als eigener Abschnitt:

```markdown
## Was offen bleibt

**Abschnitt 7 ist nicht ausgeführt.** Phase 4 stand zum Zeitpunkt des
Abschlusses nicht in `master`; die Kurse-Routen gibt es nicht, und ohne
sie wäre ein Rail-Eintrag *Kurse* ein Versprechen ohne Gegenwert
(Designsystem §11).

Offen sind damit:

- Die fünf Kurse-Bildschirme: `Kurse.dc.html`, `Kursvorlagen.dc.html`,
  `Kursvorlage.dc.html`, `TerminAnlegen.dc.html`, `Termin.dc.html`.
- Der Rail-Eintrag *Kurse* in der Gruppe STUDIO, mit der Zahl
  „5 diese Woche". Der Test *„Kurse fehlt in der Rail"* in
  `e2e/rail.spec.ts` ist bis dahin richtig und wird dann umgedreht,
  nicht gelöscht.
- Der Abschnitt *Diese Woche* im Überblick (`Main.dc.html`).
- Der Rebase auf den gemergten Stand von Phase 4. Erwartete
  Konfliktstellen: `Rail.tsx`, `catalog.ts`,
  `(schreibtisch)/layout.tsx` — dieselben Dateien wie Aufgabe 12,
  bewusst in einem Commit gehalten.

**Der Satz, der auch dann nicht in die Oberfläche darf:** die
Nachrück-Benachrichtigung von der Warteliste. Push gibt es nicht,
E-Mail bräuchte den SMTP-Weg. Designsystem §11 und Struktur-Spec §8
sind darin einig.
```

- [ ] **B3: Fahrplan-Zeile entsprechend setzen**

In Aufgabe 23 wird Phase 5 dann als „✅ ohne Kurse" geführt, nicht als „✅". Ein halb erledigter Punkt, der als ganz erledigt dasteht, ist die teuerste Sorte Dokumentationsfehler — genau die, die Fahrplan Abschnitt 7 als „den Abstand zwischen Entwurf und Code" beschreibt.

---

## Aufgabe 23: Den Fahrplan nachziehen

Nach der Regel in Fahrplan Abschnitt 8: *„die Zeile in Abschnitt 3 auf ✅, den Bezugsstand in der Kopftabelle nachziehen, und erledigte Punkte in Abschnitt 6 streichen statt durchzustreichen."*

**Dateien:**
- Ändern: `docs/superpowers/plans/2026-09-01-gesamtfahrplan.md`

- [ ] **Schritt 1: Abschnitt 3, die Zeile**

```markdown
| ~~**Portal-Frontend nach den 39 Artboards**~~ | — | ✅ `2026-09-03-portal-frontend.md`, 23 Aufgaben | ✅ **3. September** |
```

Bei Fassung B: `✅ **ohne Kurse**` statt `✅`, mit dem Verweis auf *Was offen bleibt*.

- [ ] **Schritt 2: Die Kopftabelle**

Zeile für `phase5-portal-frontend` mit dem Merge-Commit und dem Inhalt: *„Bausteinschicht, Zustandsrouten, Einstieg, Wurzelseite, feste Rail, Geräte und Modelle zusammengelegt, neunzehn Bildschirme gestaltet — **keine Migration**"*.

- [ ] **Schritt 3: Abschnitt 6, streichen was erledigt ist**

**Gestrichen** — die Zeile verschwindet, sie wird nicht durchgestrichen:

- *„Die Wurzelseite `/` ist ungestaltet"* — erledigt in Aufgabe 10 und 11.

**Bleibt stehen, mit nachgezogener Begründung:**

- *„Ein verwaister Dev-Server auf Port 3000 verfälscht lokale E2E-Läufe still"* — unverändert gültig, in diesem Bauabschnitt zweimal bestätigt.
- *„`rls-workout-sessions` ist sporadisch rot"* — **die Beschreibung wird korrigiert.** Er ist auf dieser Maschine verlässlich rot, und die Ursache ist gemessen: die Containeruhr läuft der Node-Uhr 0,6 bis 1,1 s voraus. „Sporadisch" ist eine Vermutung; hier steht jetzt eine Messung.

**Neu aufzunehmen:**

- *„Das Beitrittsformular im Web wartet auf die iOS-App"* — Befund 9, mit dem Auslöser statt eines Datums.
- *„`Verifizieren` zeichnet einen Weg, den es nicht gibt"* — Befund 6, „Neuen Code anfordern".
Befund 16 gehört **nicht** in die offenen Punkte — er ist am 3. September entschieden. Stattdessen wird die Maßzeile in `2026-08-31-designplan-trainerportal.md`, Abschnitt *Global Constraints*, korrigiert: statt *„Trefferflächen ≥ 44 px; Hauptaktion 44 px hoch, Nebenaktion 40 px"* steht dort künftig *„Hauptaktion und Eingabefeld 44 px, Nebenaktion und zerstörende Aktion 40 px. Die ≥ 44 px des Designsystems gelten für die Halle, nicht für den Schreibtisch."*

- [ ] **Schritt 4: Commit**

```bash
git add docs/superpowers/plans/2026-09-01-gesamtfahrplan.md
git commit -m "docs: Phase 5 im Fahrplan -- die Wurzelseite faellt aus den offenen Punkten"
```

---

## Abnahme des ganzen Bauabschnitts

Bevor der Zweig zusammengeführt wird:

- [ ] `pnpm typecheck` — grün
- [ ] `pnpm test` — **90 grün** (85 Bestand + 5 aus Aufgabe 2)
- [ ] `pnpm test:integration` — **460 von 461**, und der eine rote ist `rls-workout-sessions › positiv: ein Mitglied beendet seine eigene Session`. Ist es ein anderer, ist es ein neuer Fehler
- [ ] `pnpm test:e2e` — grün, **zweiter Lauf**. Vorher: was lauscht auf Port 3000?
- [ ] `pnpm build` — grün
- [ ] Jeder der neunzehn Bildschirme einmal im Browser gegen sein Artboard gehalten
- [ ] Kein Farbliteral außerhalb von `globals.css`: `grep -rn "#[0-9a-fA-F]\{6\}" apps/web/app --include=*.css --include=*.tsx | grep -v globals.css` — erwartet: leer
- [ ] Keine neue `.sql`-Datei unter `supabase/migrations/` — Phase 5 braucht keine Migration
- [ ] Die Befundliste der Spec ist vollständig: Befunde 16, 17, 18 sind nachgetragen

### Wo jeder Befund landet

Damit sich nachrechnen lässt, dass keiner unterwegs verlorengeht:

| Befund | Was | Wo |
| --- | --- | --- |
| 1 | doppelte `<main>`-Landmarke | Aufgabe 1 findet ihn, Aufgabe 4 heilt ihn |
| 2 | `notFound()` auf weißer Seite | Aufgabe 4 |
| 3 | Rail zerbricht an der Rolle | Aufgabe 12 |
| 4 | „Link anfordern" statt Code | Aufgabe 8 |
| 5 | `PasswortNeu` ohne Codefeld | Aufgabe 8 |
| 6 | „Neuen Code anfordern" ohne Weg | **nicht gebaut** — Aufgabe 7 begründet es, bleibt offener Punkt |
| 7 | Stilllegen fehlt im Artboard | Aufgabe 18 — der Code gewinnt |
| 8 | flache Geräteliste ohne Artboard | Aufgabe 13 — entfällt, kostet nichts |
| 9 | Beitrittsformular gegen `note-einstieg` | Aufgabe 11, mit Auslöser im Kommentar |
| 10 | kein Kurse-Eintrag in der Rail | Aufgabe 12 setzt ihn aus, Aufgabe 22 dreht ihn um |
| 11 | `.progressBar` ist eine Akzentfläche | Aufgabe 17 stößt darauf, **Aufgabe 21 entscheidet** |
| 12 | Uhrendrift im Container | Globale Rahmenbedingungen; Aufgabe 23 korrigiert den Fahrplan |
| 13 | kaltes `.next` kostet zwei E2E | Globale Rahmenbedingungen |
| 14 | zweiter Abmelden-Ausgang | Aufgabe 12 — Absicht, beide Artboards zeigen ihn |
| 15 | `/portal` hat kein Artboard | Aufgabe 9 — nach Bausteinen statt nach Vorlage |
| 16 | Trefferflächen 44 gegen 40 | **entschieden**: 40 am Schreibtisch, 44 für die Hauptaktion. Aufgabe 1 hält den Wert als Parameter, damit die Halle ihren eigenen behält |
| 17 | Registrierungssatz stimmt fürs Web nicht | Aufgabe 7 |
| 18 | Fußsatz von `LeuteMitglieder` seit `0033` überholt | Aufgabe 19 |

### Die drei Befunde, die beim Planen dazukamen

Sie stehen hier, damit sie beim Nachtragen in die Spec nicht verlorengehen:

- **Befund 16 — die Global Constraints widersprachen sich bei den Trefferflächen.** Ein Satz sagte *„Trefferflächen ≥ 44 px; Hauptaktion 44 px hoch, **Nebenaktion 40 px**"*. **Entschieden am 3. September: 40 px gilt am Schreibtisch weiter**, 44 px für die Hauptaktion und Eingabefelder. Die Tests prüfen gegen 40; der Wert bleibt Parameter von `zuKleineBedienelemente`, damit die Hallenseiten mit ihrem eigenen, größeren Maß geprüft werden können.
- **Befund 17 — der Satz unter dem Registrierungsformular stimmt für das Web nicht.** `Registrieren.dc.html` sagt *„du brauchst danach den Code deines Studios"*; im Web wird man aber Mitarbeiter, nicht Mitglied. Ersetzt in Aufgabe 7.
- **Befund 18 — der Fußsatz von `LeuteMitglieder.dc.html` ist seit `0033` überholt.** Er sagt, die Datenbank lasse Mitarbeiter noch an Trainingsdaten heran. Seit dem 2. September haben die vier Policies die Staff-Klausel verloren. Ersetzt in Aufgabe 19.
