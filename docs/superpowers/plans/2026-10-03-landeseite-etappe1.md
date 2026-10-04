# Landeseite Etappe 1: Bausteine und `/` ohne Verkauf — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Wurzelseite `/` zeigt Besuchern ohne Sitzung eine Landeseite für Mitglieder (Held, Faktenzeile, Ohne/Mit, So geht's, CTA, Verlauf & Ziele, Fragen, Fuß, Kaufleiste „App laden“) statt der heutigen Trainer-Landung. Der angemeldete Zweig bleibt unverändert.

**Architecture:** Neue Bausteine unter `apps/web/app/landung/`, je Baustein eine `.tsx` mit eigenem CSS-Modul. Server Components, wo nichts reagiert. Client Components nur für Kaufleiste, Ohne/Mit, Held-Video und die Schritt-Indikatoren. Die beiden Zustandsautomaten (Kaufleiste, Ohne/Mit) sind reine Funktionen mit Vitest-Zustandstabellen. Die Komponenten verdrahten nur IntersectionObserver, Scroll und Timer dorthin. Alle Texte stehen in `landung/texte.ts`. `page.tsx` rendert im Zweig ohne Sitzung nur `<Startseite />`.

**Tech Stack:** Next.js 15 / React 19, CSS Modules, Vitest + @testing-library/react (jsdom), Playwright. Keine neue Abhängigkeit.

**Spec:** `docs/superpowers/specs/2026-10-03-landeseite-neu-gpath-referenz.md`. Maßgeblich sind §4 (Grundsätze), §5 (Texte für `/`), §7.2 mit 7.2.1/7.2.2 (Bausteine, Bewegung, Ohne/Mit), §7.3 (Kaufleiste), §7.6 (Tests) und §9 (Entscheidungen E1–E9). Dazu `docs/superpowers/specs/2026-08-30-designsystem.md` §2, §4, §6 und §10.

## Global Constraints

- **Umfang Etappe 1 (E1, E6, E7):** kein Verkauf, kein Formular, keine Warteliste, kein Sensor-Abschnitt, kein `VideoOverlay`, kein Kopfmenü, keine „Brücke zum Studio“. Die beiden letzten haben ohne `/studios` kein Ziel und kommen mit Etappe 2. Der Sensor erscheint nur als Antwort in den Fragen. Ohne/Mit steht ohne Hintergrundbild auf `--surface`: Die Überblendung „unscharf → scharf“ (7.2) braucht ein Foto und kommt mit den Medien (E6).
- **Marke (E8):** Wortmarke über `app/branding/GymtavoWordmark.tsx` (Bild, `alt="GYMTAVO"`). Im Fließtext „Gymtavo“, Versalien nur in der Wortmarke.
- **Produktgrenze auf `/`:** „Gymtavo misst nichts. Angezeigt wird ausschließlich, was du selbst bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.“ (§10, Du-Form, weil `/` jetzt Mitglieder anspricht). Farbe `--text-muted`, nie `--text-faint`.
- **Texte (§10):** Deutsch, Du-Form, keine Ausrufezeichen, kein Motivationston, „Vorschlag“ statt „Du solltest“. Jede Aussage ist im Code belegt (Belege in `texte.ts` als Kommentar).
- **Höchstens eine Akzentfläche (`--accent` als Hintergrund) im Viewport**, zu jeder Scrollposition (Spec §4.2). Der Ohne/Mit-Schalter ist im Zustand „Mit“ `--text`, nicht `--accent` (7.2.2).
- **Maße (§4):** Hauptaktion 64 px hoch, Radius 16. Trefferflächen ≥ 44 px. Seitenrand 20 px mobil.
- **Bewegung (7.2.1):** nur `transform`, `opacity`, `clip-path`. Kurven nur über die Tokens `--ease-out: cubic-bezier(0.23, 1, 0.32, 1)`, `--ease-in-out: cubic-bezier(0.77, 0, 0.175, 1)`, `--ease-drawer: cubic-bezier(0.32, 0.72, 0, 1)`. Was wiederholt ausgelöst wird, läuft als CSS-Transition an einem Datenattribut, keine Keyframes. reduced-motion wird nicht eigens behandelt: Die globale Regel in `globals.css` macht jeden Übergang zum Zustandswechsel (§6). Informationen bleiben trotzdem sichtbar. Hover nur unter `@media (hover: hover) and (pointer: fine)`.
- **`--kopf-hoehe: 62px`** (8 px Abstand oben + 54 px Pille). Eine CSS-Konstante auf `.startseite`, kein ResizeObserver.
- **Kein JS-Höhenschloss im Held:** `min-height: 100vh; min-height: 100svh`.
- **App-Store-Link:** `APP_STORE_URL` aus `apps/web/lib/appStore.ts`. Ohne `NEXT_PUBLIC_APP_STORE_URL` gilt `https://apps.apple.com/`, derselbe Platzhalter wie heute in `/t/[token]`.
- **Commits:** deutsch mit ae/oe/ue, ein Commit pro Aufgabe, Trailer exakt `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`, danach `git log -1 --format=%B` prüfen. Kommentare in TS/CSS geben einen Grund an und beschreiben nicht den Code.
- **Arbeitsort:** Worktree `.claude/worktrees/landeseite-neu`, Branch `claude/landeseite-neu`. Kein Push ohne Freigabe von Tim.

## Review Focus

1. **Zwei Akzentflächen gleichzeitig im Bild**, wenn die Kaufleiste über der CTA-Section oder am Hero-Knopf steht. Erwartet: nie mehr als eine. → `wurzel.spec.ts` prüft an fünf Scrollpositionen (Aufgabe 10), `kaufleiste.spec.ts` prüft „weicht der CTA“ (Aufgabe 11).
2. **Getippter Ohne/Mit-Zustand springt beim nächsten Scrollpixel zurück**, oder die Karte kommt von oben wieder ins Bild und zeigt noch „Mit“, obwohl die Sonde draußen ist. Erwartet: Der Tipp gilt, bis die Karte den Viewport verlässt, danach steht sie auf „Ohne“. → Zustandstabelle in Aufgabe 2, e2e in Aufgabe 10.
3. **Fokussierte Kaufleiste verschwindet unter `inert`**, wenn jemand per Tab hineingeht und dann mit Pfeiltasten runterscrollt. Erwartet: Sie bleibt sichtbar, solange der Fokus in ihr liegt. Versteckt ist sie nicht fokussierbar. → Aufgabe 1 (Tabelle), Aufgabe 11 (e2e).
4. **iOS-Gummiband und Flackern am Umkehrpunkt:** negative Scrollwerte oder Werte über dem Maximum, ±5-px-Zittern beim Impulsscrollen. Erwartet: kein Richtungswechsel unter 12 px am Stück. → Aufgabe 1.
5. **320 px Breite:** lange Pillen („Wie viele Wiederholungen?“), Wortmarke + „Anmelden“, Versal-H1. Erwartet: kein waagrechtes Scrollen auf der ganzen Seite. → `wurzel.spec.ts` (Aufgabe 10). Dazu JSON-LD mit `<` im Text (Ausbruch aus `<script>`) → Aufgabe 3.

---

## Dateiübersicht

| Datei | Verantwortung |
|---|---|
| `apps/web/app/globals.css` (ändern) | Kurven-Tokens `--ease-out`, `--ease-in-out`, `--ease-drawer` |
| `apps/web/lib/appStore.ts` | `APP_STORE_URL` |
| `apps/web/app/landung/kaufleiste.logik.ts` (+ `.test.ts`) | reiner Zustandsautomat der Kaufleiste |
| `apps/web/app/landung/ohnemit.logik.ts` (+ `.test.ts`) | Zustandsautomat Ohne/Mit, Pillenflug, Feed-Zeitplan und -Lage |
| `apps/web/app/landung/testhilfen.ts` | IntersectionObserver- und matchMedia-Attrappen für jsdom |
| `apps/web/app/landung/useMedienabfrage.ts` | `useMedienabfrage`, `useReduzierteBewegung` |
| `apps/web/app/landung/Aktion.module.css` | `.hauptaktion` (die eine Akzentfläche), von allen genutzt |
| `apps/web/app/landung/Laufband.tsx` + `.module.css` | ruhende Faktenzeile |
| `apps/web/app/landung/Fragen.tsx` + `.module.css` (+ `.test.tsx`) | `details/summary` + FAQPage-JSON-LD |
| `apps/web/app/landung/Fuss.tsx` + `.module.css` | Produktgrenze, Wege für Trainer |
| `apps/web/app/landung/Kopf.tsx` + `.module.css` | sticky Glas-Pille, Wortmarke, „Anmelden“ |
| `apps/web/app/landung/Held.tsx` + `.module.css` | Hero (Server) |
| `apps/web/app/landung/HeldVideo.tsx` (+ `.test.tsx`) | optionales Hero-Video (Client), Pause-Knopf |
| `apps/web/app/landung/OhneMit.tsx` + `.module.css` (+ `.test.tsx`) | die eine Inszenierung |
| `apps/web/app/landung/Schritte.tsx` + `.module.css` | „So geht's“, Scroll-Snap mobil |
| `apps/web/app/landung/SchritteIndikatoren.tsx` (+ `.test.tsx`) | Nummern-Indikatoren (Client) |
| `apps/web/app/landung/Kaufleiste.tsx` + `.module.css` (+ `.test.tsx`) | Leiste „App laden“ |
| `apps/web/app/landung/texte.ts` | alle Texte der Seite, mit Belegen |
| `apps/web/app/landung/Startseite.tsx` + `.module.css` | Komposition, CTA- und Verlauf-Section |
| `apps/web/public/landung/*.png` | drei App-Screenshots |
| `apps/web/app/page.tsx` (ändern) | Zweig ohne Sitzung → `<Startseite />` |
| `apps/web/app/einstieg/landeseite.module.css` (löschen) | ersetzt |
| `e2e/helpers/abnahme.ts` (ändern) | `akzentflaechen(page, { nurViewport })` |
| `e2e/wurzel.spec.ts` (ändern) | Tests ohne Sitzung neu |
| `e2e/landung.spec.ts` | Ohne/Mit im echten Browser |
| `e2e/kaufleiste.spec.ts` | Kaufleiste im echten Browser |

Testbefehle (aus der Worktree-Wurzel):
- Unit: `pnpm --filter @fitretro/web exec vitest run app/landung`
- e2e: `E2E_PORT=3007 pnpm test:e2e e2e/<datei>.spec.ts`. Lokales Supabase muss laufen (`pnpm supabase status`), `.env` liegt in der Worktree-Wurzel. Port 3007, weil parallele Sessions 3000 belegen können.

---

### Aufgabe 0: Auf den Stand des Branding-Branches bringen

Die Branding-Session (`.claude/worktrees/gymtavo-branding`) stellt in ihrer Aufgabe 4 gerade alle sichtbaren Web-Texte auf „Gymtavo“ um, darunter `apps/web/app/page.tsx` und `e2e/wurzel.spec.ts`, also genau die Dateien von Aufgabe 10. Dieser Plan setzt darauf auf.

- [ ] **Schritt 1: Prüfen, ob die Web-Texte committet sind**

```bash
git log --oneline master..feat/gymtavo-branding
git -C ../gymtavo-branding status --short
```
Erwartet: ein Commit für „Sichtbare Texte im Web“ (Aufgabe 4 des Branding-Plans), und `apps/web/app/page.tsx` taucht im Status nicht mehr als geändert auf. Wenn nicht: **anhalten und Tim fragen.** Die Aufgaben 1–9 hängen nicht an `page.tsx` und dürfen in dem Fall vorgezogen werden. Aufgabe 10 erst nach dem Rebase.

- [ ] **Schritt 2: Rebase und Grundzustand**

```bash
git rebase feat/gymtavo-branding     # oder master, falls der Branding-PR schon gemergt ist
pnpm install
pnpm --filter @fitretro/web exec vitest run
```
Erwartet: alle vorhandenen Unit-Tests grün. Ohne Commit, das ist nur der Ausgangspunkt.

---

### Aufgabe 1: Kurven-Tokens und Zustandsautomat der Kaufleiste

**Files:**
- Modify: `apps/web/app/globals.css` (im `:root`-Block hinter `--r-control`)
- Create: `apps/web/app/landung/kaufleiste.logik.ts`
- Test: `apps/web/app/landung/kaufleiste.logik.test.ts`

**Interfaces:**
- Produces: `type Richtung = "hoch" | "runter"`, `type KaufleistenZustand = { y: number; richtung: Richtung; wendeY: number; sichtbar: boolean }`, `type KaufleistenMessung = { y: number; maxY: number; ankerVorbei: boolean; schwelleY: number; verdeckt: boolean; fokusDrin: boolean }`, `const KAUFLEISTE_START: KaufleistenZustand`, `function naechsterZustand(vorher: KaufleistenZustand, m: KaufleistenMessung): KaufleistenZustand`, `const HYSTERESE_PX = 12`, `const NAHE_PX = 24`.

- [ ] **Schritt 1: Failing Test schreiben**

```ts
// apps/web/app/landung/kaufleiste.logik.test.ts
import { describe, expect, it } from "vitest";
import {
  KAUFLEISTE_START,
  naechsterZustand,
  type KaufleistenMessung,
  type KaufleistenZustand,
} from "./kaufleiste.logik";

const basis: KaufleistenMessung = {
  y: 0,
  maxY: 5000,
  ankerVorbei: false,
  schwelleY: 800,
  verdeckt: false,
  fokusDrin: false,
};

// Spielt eine Folge von Scrollpositionen durch, wie sie der rAF-Takt liefert.
function folge(ys: number[], m: Partial<KaufleistenMessung> = {}, start = KAUFLEISTE_START) {
  return ys.reduce<KaufleistenZustand>(
    (z, y) => naechsterZustand(z, { ...basis, ...m, y }),
    start,
  );
}

describe("naechsterZustand", () => {
  it("bleibt verborgen, solange der Hero-Knopf nicht vorbei ist", () => {
    expect(folge([100, 50]).sichtbar).toBe(false);
  });

  it("erscheint direkt hinter der Schwelle, auch beim Runterscrollen", () => {
    expect(folge([700, 810], { ankerVorbei: true }).sichtbar).toBe(true);
  });

  it("weicht beim Runterscrollen, sobald sie 24 px hinter der Schwelle ist", () => {
    expect(folge([700, 900, 1000], { ankerVorbei: true }).sichtbar).toBe(false);
  });

  it("kommt erst nach 12 px am Stueck nach oben zurueck", () => {
    const unten = folge([700, 900, 1400], { ankerVorbei: true });
    expect(folge([1392], { ankerVorbei: true }, unten).sichtbar).toBe(false);
    expect(folge([1392, 1388], { ankerVorbei: true }, unten).sichtbar).toBe(true);
  });

  it("flackert nicht bei Zittern unter der Hysterese", () => {
    const unten = folge([700, 900, 1400], { ankerVorbei: true });
    const z = folge([1395, 1400, 1395, 1400, 1394], { ankerVorbei: true }, unten);
    expect(z.richtung).toBe("runter");
    expect(z.sichtbar).toBe(false);
  });

  it("weicht jedem Verdecker, auch beim Hochscrollen", () => {
    const unten = folge([700, 900, 1400], { ankerVorbei: true });
    expect(folge([1300], { ankerVorbei: true, verdeckt: true }, unten).sichtbar).toBe(false);
  });

  it("bleibt stehen, solange der Fokus in ihr liegt", () => {
    expect(folge([700, 900, 1400], { ankerVorbei: true, fokusDrin: true }).sichtbar).toBe(true);
  });

  it("klemmt das iOS-Gummiband: negative Werte und Ueberhang kippen die Richtung nicht", () => {
    const oben = folge([0, -40]);
    expect(oben.y).toBe(0);
    expect(oben.richtung).toBe("runter");
    const ganzUnten = folge([4990, 5000, 5060, 5000], { ankerVorbei: true });
    expect(ganzUnten.y).toBe(5000);
    expect(ganzUnten.richtung).toBe("runter");
  });
});
```

- [ ] **Schritt 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/kaufleiste.logik.test.ts`
Expected: FAIL, „Failed to resolve import ./kaufleiste.logik“.

- [ ] **Schritt 3: Implementierung**

```ts
// apps/web/app/landung/kaufleiste.logik.ts
/**
 * Wann die Kaufleiste steht (Spec 7.3). Rein, damit die Zustandstabelle
 * ohne Browser pruefbar ist; Kaufleiste.tsx liefert nur Messungen.
 */
export type Richtung = "hoch" | "runter";

export type KaufleistenZustand = {
  y: number;
  richtung: Richtung;
  /** Umkehrpunkt: aeusserster Wert in der aktuellen Richtung. */
  wendeY: number;
  sichtbar: boolean;
};

export type KaufleistenMessung = {
  y: number;
  maxY: number;
  ankerVorbei: boolean;
  /** Dokument-y, an dem der Anker unter dem Kopf verschwand. */
  schwelleY: number;
  verdeckt: boolean;
  fokusDrin: boolean;
};

// Gpath wechselt bei 4 px je Frame. Bei 120 Hz und Impulsscrollen kippt das
// am Umkehrpunkt mehrmals; erst 12 px am Stueck sind eine Absicht.
export const HYSTERESE_PX = 12;
// Direkt hinter der Schwelle erscheint die Leiste auch beim Runterscrollen,
// sonst saehe man sie beim ersten Vorbeiscrollen nie.
export const NAHE_PX = 24;

export const KAUFLEISTE_START: KaufleistenZustand = {
  y: 0,
  richtung: "runter",
  wendeY: 0,
  sichtbar: false,
};

export function naechsterZustand(
  vorher: KaufleistenZustand,
  m: KaufleistenMessung,
): KaufleistenZustand {
  // Safari meldet beim Gummiband Werte ausserhalb des Dokuments; die
  // zaehlen nicht als Bewegung.
  const y = Math.min(Math.max(m.y, 0), Math.max(m.maxY, 0));
  let { richtung, wendeY } = vorher;
  const kandidat: Richtung | null = y > vorher.y ? "runter" : y < vorher.y ? "hoch" : null;
  if (kandidat === richtung) {
    wendeY = y;
  } else if (kandidat !== null && Math.abs(y - wendeY) >= HYSTERESE_PX) {
    richtung = kandidat;
    wendeY = y;
  }
  const sichtbar =
    m.ankerVorbei &&
    !m.verdeckt &&
    (m.fokusDrin || richtung === "hoch" || y - m.schwelleY < NAHE_PX);
  return { y, richtung, wendeY, sichtbar };
}
```

In `apps/web/app/globals.css` im `:root`-Block direkt hinter `--r-control: 10px;` einfügen:

```css
  /* Kurven der Landeseite (Spec 7.2.1). Als Tokens, damit kein Baustein
     eine eigene Naeherung erfindet; die Werte stammen aus der animate-
     Skill-Tabelle, nicht aus Gpath. */
  --ease-out: cubic-bezier(0.23, 1, 0.32, 1);
  --ease-in-out: cubic-bezier(0.77, 0, 0.175, 1);
  --ease-drawer: cubic-bezier(0.32, 0.72, 0, 1);
```

- [ ] **Schritt 4: Test laufen lassen, er muss bestehen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/kaufleiste.logik.test.ts`
Expected: PASS, 8 Tests.

- [ ] **Schritt 5: Commit**

```bash
git add apps/web/app/globals.css apps/web/app/landung/kaufleiste.logik.ts apps/web/app/landung/kaufleiste.logik.test.ts
git commit -m "feat(landung): Kurven-Tokens und Zustandsautomat der Kaufleiste

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 2: Zustandsautomat und Bewegungswerte für Ohne/Mit

**Files:**
- Create: `apps/web/app/landung/ohnemit.logik.ts`
- Test: `apps/web/app/landung/ohnemit.logik.test.ts`

**Interfaces:**
- Produces: `type OhneMitZustand = { mit: boolean; manuell: boolean }`, `type OhneMitEreignis = { art: "sonde"; schneidet: boolean } | { art: "tipp" } | { art: "karteWeg" }`, `const OHNE_MIT_START`, `function ohneMitZustand(v, e): OhneMitZustand`, `function pillenFlug(x: number, y: number, i: number): { sx: number; sy: number; r: number; verzoegerung: number }`, `function feedZeitplan(anzahl: number): number[]`, `function feedLage(abstand: number): { versatz: number; skala: number; deckkraft: number }`, `const RUECKFLUG_MS = 550`.

- [ ] **Schritt 1: Failing Test schreiben**

```ts
// apps/web/app/landung/ohnemit.logik.test.ts
import { describe, expect, it } from "vitest";
import {
  OHNE_MIT_START,
  feedLage,
  feedZeitplan,
  ohneMitZustand,
  pillenFlug,
  type OhneMitEreignis,
} from "./ohnemit.logik";

const ablauf = (...e: OhneMitEreignis[]) => e.reduce(ohneMitZustand, OHNE_MIT_START);

describe("ohneMitZustand", () => {
  it("folgt der Sonde in beide Richtungen", () => {
    expect(ablauf({ art: "sonde", schneidet: true }).mit).toBe(true);
    expect(ablauf({ art: "sonde", schneidet: true }, { art: "sonde", schneidet: false }).mit).toBe(false);
  });

  it("ein Tipp schaltet um und haelt gegen die Sonde", () => {
    const z = ablauf({ art: "sonde", schneidet: true }, { art: "tipp" }, { art: "sonde", schneidet: true });
    expect(z).toEqual({ mit: false, manuell: true });
  });

  it("verlaesst die Karte den Viewport, gilt wieder die Sonde, und die meldet draussen Ohne", () => {
    const z = ablauf({ art: "tipp" }, { art: "karteWeg" });
    expect(z).toEqual({ mit: false, manuell: false });
    expect(ohneMitZustand(z, { art: "sonde", schneidet: true }).mit).toBe(true);
  });
});

describe("pillenFlug", () => {
  it("fliegt weg von der Mitte", () => {
    const links = pillenFlug(20, 50, 0);
    expect(links.sx).toBeLessThan(0);
    expect(pillenFlug(80, 50, 0).sx).toBeGreaterThan(0);
    expect(pillenFlug(50, 10, 0).sy).toBeLessThan(0);
  });

  it("dreht abwechselnd zwischen 24 und 32 Grad und staffelt 15 ms", () => {
    const winkel = Array.from({ length: 10 }, (_, i) => pillenFlug(30, 30, i).r);
    for (const [i, r] of winkel.entries()) {
      expect(Math.abs(r)).toBeGreaterThanOrEqual(24);
      expect(Math.abs(r)).toBeLessThanOrEqual(32);
      expect(Math.sign(r)).toBe(i % 2 === 0 ? 1 : -1);
    }
    expect(pillenFlug(30, 30, 9).verzoegerung).toBe(135);
  });

  it("liefert in der Mitte keine NaN", () => {
    const m = pillenFlug(50, 50, 3);
    expect(Number.isFinite(m.sx) && Number.isFinite(m.sy)).toBe(true);
  });
});

describe("feedZeitplan", () => {
  it("ein Durchgang: 120 ms Anlauf, 1100 halten, 480 gleiten", () => {
    expect(feedZeitplan(4)).toEqual([1220, 2800, 4380]);
    expect(feedZeitplan(1)).toEqual([]);
  });
});

describe("feedLage", () => {
  it("aktueller Eintrag in Originalgroesse, Nachbarn klein und blass, Fernere unsichtbar", () => {
    expect(feedLage(0)).toEqual({ versatz: 0, skala: 1, deckkraft: 1 });
    expect(feedLage(1)).toEqual({ versatz: 1, skala: 0.55, deckkraft: 0.28 });
    expect(feedLage(-2).deckkraft).toBe(0);
    expect(feedLage(-2).versatz).toBe(-1.6);
  });
});
```

- [ ] **Schritt 2: Test laufen lassen, er muss scheitern**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/ohnemit.logik.test.ts`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 3: Implementierung**

```ts
// apps/web/app/landung/ohnemit.logik.ts
/**
 * Ohne/Mit, Modell "Schwelle" (Spec 7.2.2). Rein, damit die Tabelle der
 * Faelle ohne Browser laeuft; OhneMit.tsx meldet nur Ereignisse.
 */
export type OhneMitZustand = { mit: boolean; manuell: boolean };
export type OhneMitEreignis =
  | { art: "sonde"; schneidet: boolean }
  | { art: "tipp" }
  | { art: "karteWeg" };

export const OHNE_MIT_START: OhneMitZustand = { mit: false, manuell: false };

export function ohneMitZustand(v: OhneMitZustand, e: OhneMitEreignis): OhneMitZustand {
  switch (e.art) {
    case "sonde":
      // Nach einem Tipp kippte die Sonde den Zustand sonst beim naechsten
      // Scrollpixel zurueck.
      return v.manuell ? v : { mit: e.schneidet, manuell: false };
    case "tipp":
      return { mit: !v.mit, manuell: true };
    case "karteWeg":
      // Draussen schneidet die Sonde nie. Kaeme die Karte von oben zurueck,
      // meldete der Observer keinen Wechsel -- also hier schon auf Ohne.
      return OHNE_MIT_START;
  }
}

const FLUG_X_PX = 160;
const FLUG_Y_PX = 120;
const STAFFEL_MS = 15;

export function pillenFlug(x: number, y: number, i: number) {
  const dx = x - 50;
  const dy = y - 50;
  const laenge = Math.hypot(dx, dy) || 1;
  return {
    sx: Math.round((dx / laenge) * FLUG_X_PX),
    sy: Math.round((dy / laenge) * FLUG_Y_PX),
    r: (i % 2 === 0 ? 1 : -1) * (24 + ((i * 7) % 9)),
    verzoegerung: i * STAFFEL_MS,
  };
}

const FEED_ANLAUF_MS = 120;
const FEED_HALTEN_MS = 1100;
const FEED_GLEITEN_MS = 480;
/** So lange dauert der Rueckflug der Pillen; erst danach springt der Feed auf den Anfang. */
export const RUECKFLUG_MS = 550;

/** Zeitpunkte, zu denen der Feed auf Eintrag 1, 2, ... weiterspringt. Ein Durchgang. */
export function feedZeitplan(anzahl: number): number[] {
  return Array.from(
    { length: Math.max(anzahl - 1, 0) },
    (_, i) => FEED_ANLAUF_MS + FEED_HALTEN_MS + i * (FEED_HALTEN_MS + FEED_GLEITEN_MS),
  );
}

export function feedLage(abstand: number) {
  const a = Math.min(1, Math.abs(abstand));
  return {
    versatz: Math.max(-1.6, Math.min(1.6, abstand)),
    // Die Nachbarn werden kleiner, statt den aktuellen Eintrag zu
    // vergroessern: hochskalierter Text wird unscharf.
    skala: Math.round((1 - 0.45 * a) * 100) / 100,
    deckkraft: Math.abs(abstand) > 1.5 ? 0 : Math.round((1 - 0.72 * a) * 100) / 100,
  };
}
```

- [ ] **Schritt 4: Test laufen lassen, er muss bestehen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/ohnemit.logik.test.ts`
Expected: PASS.

- [ ] **Schritt 5: Commit**

```bash
git add apps/web/app/landung/ohnemit.logik.ts apps/web/app/landung/ohnemit.logik.test.ts
git commit -m "feat(landung): Zustandsautomat und Bewegungswerte fuer Ohne/Mit

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 3: Testhilfen, Faktenzeile, Fragen, Fuß

**Files:**
- Create: `apps/web/app/landung/testhilfen.ts`, `apps/web/lib/appStore.ts`, `apps/web/app/landung/Laufband.tsx`, `Laufband.module.css`, `Fragen.tsx`, `Fragen.module.css`, `Fuss.tsx`, `Fuss.module.css`
- Test: `apps/web/app/landung/Fragen.test.tsx`

**Interfaces:**
- Produces: `stubIntersectionObserver(): { melden(ziel: Element, teil: Partial<IntersectionObserverEntry>): void }`, `stubMatchMedia(treffer: (query: string) => boolean): void`, `APP_STORE_URL: string`, `<Laufband eintraege={readonly string[]} />`, `type Frage = { frage: string; antwort: string }`, `<Fragen id titel fragen />`, `<Fuss id produktgrenze />`.

- [ ] **Schritt 1: Testhilfen anlegen** (ohne eigenen Test, die Komponententests prüfen sie mit)

```ts
// apps/web/app/landung/testhilfen.ts
import { vi } from "vitest";

/**
 * jsdom kennt weder IntersectionObserver noch matchMedia. Die Attrappe
 * merkt sich jeden Observer, damit ein Test gezielt "Element X schneidet
 * jetzt" melden kann -- die Bausteine reagieren auf nichts anderes.
 */
export function stubIntersectionObserver() {
  const alle: FakeIO[] = [];
  class FakeIO {
    ziele = new Set<Element>();
    callback: IntersectionObserverCallback;
    optionen: IntersectionObserverInit | undefined;
    constructor(callback: IntersectionObserverCallback, optionen?: IntersectionObserverInit) {
      this.callback = callback;
      this.optionen = optionen;
      alle.push(this);
    }
    observe(el: Element) {
      this.ziele.add(el);
    }
    unobserve(el: Element) {
      this.ziele.delete(el);
    }
    disconnect() {
      this.ziele.clear();
    }
    takeRecords() {
      return [];
    }
  }
  vi.stubGlobal("IntersectionObserver", FakeIO);
  return {
    melden(ziel: Element, teil: Partial<IntersectionObserverEntry>) {
      for (const io of alle) {
        if (!io.ziele.has(ziel)) continue;
        const eintrag = {
          target: ziel,
          isIntersecting: false,
          boundingClientRect: ziel.getBoundingClientRect(),
          ...teil,
        } as IntersectionObserverEntry;
        io.callback([eintrag], io as unknown as IntersectionObserver);
      }
    },
  };
}

export function stubMatchMedia(treffer: (query: string) => boolean) {
  vi.stubGlobal("matchMedia", (query: string) => ({
    matches: treffer(query),
    media: query,
    onchange: null,
    addEventListener() {},
    removeEventListener() {},
    addListener() {},
    removeListener() {},
    dispatchEvent: () => false,
  }));
}
```

```ts
// apps/web/lib/appStore.ts
// Die App ist noch nicht im App Store (Stand 3. Oktober). Bis dahin zeigt
// der Link wie /t/[token] auf die Store-Startseite -- ein Ziel, das es gibt,
// statt eines toten Links.
export const APP_STORE_URL =
  process.env.NEXT_PUBLIC_APP_STORE_URL || "https://apps.apple.com/";
```

- [ ] **Schritt 2: Failing Test für Fragen**

```tsx
// apps/web/app/landung/Fragen.test.tsx
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
```

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/Fragen.test.tsx`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 3: Laufband, Fragen, Fuß implementieren**

```tsx
// apps/web/app/landung/Laufband.tsx
import styles from "./Laufband.module.css";

/**
 * Etappe 1 ruhend (E7): drei Fakten als umbrechende Zeile. Das Laufen
 * kommt erst mit Live-Zahlen (Etappe 3) -- Saetze, die vorbeiziehen, waeren
 * Bewegung ohne Zweck neben der einen Inszenierung (Ohne/Mit).
 */
export function Laufband({ eintraege }: { eintraege: readonly string[] }) {
  return (
    <section className={styles.laufband} aria-label="Kurz gesagt">
      <ul className={styles.liste}>
        {eintraege.map((e) => (
          <li key={e}>{e}</li>
        ))}
      </ul>
    </section>
  );
}
```

```css
/* apps/web/app/landung/Laufband.module.css */
.laufband {
  background: var(--surface);
  border-block: 1px solid var(--line);
  padding: var(--s20) 20px;
}

.liste {
  list-style: none;
  margin: 0 auto;
  padding: 0;
  max-width: 1080px;
  display: flex;
  flex-wrap: wrap;
  justify-content: center;
  gap: var(--s8) var(--s32);
  font-size: 15px;
  font-weight: 600;
  text-align: center;
}
```

```tsx
// apps/web/app/landung/Fragen.tsx
import styles from "./Fragen.module.css";

export type Frage = { frage: string; antwort: string };

/**
 * Natives details/summary: Tastatur, Screenreader und Suche-im-Text gibt es
 * damit gratis. Keine Hoehenanimation -- wie bei Gpath, und eine Antwort,
 * die man lesen will, soll nicht erst einfahren.
 */
export function Fragen({ id, titel, fragen }: { id: string; titel: string; fragen: readonly Frage[] }) {
  const ld = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    mainEntity: fragen.map((f) => ({
      "@type": "Question",
      name: f.frage,
      acceptedAnswer: { "@type": "Answer", text: f.antwort },
    })),
  };
  return (
    <section id={id} className={styles.abschnitt} aria-labelledby={`${id}-titel`}>
      <h2 id={`${id}-titel`} className={styles.titel}>
        {titel}
      </h2>
      <div className={styles.liste}>
        {fragen.map((f) => (
          <details key={f.frage} className={styles.frage}>
            <summary className={styles.kopf}>{f.frage}</summary>
            <p className={styles.antwort}>{f.antwort}</p>
          </details>
        ))}
      </div>
      <script
        type="application/ld+json"
        // JSON.stringify maskiert "<" nicht; ohne Ersatz beendete ein
        // "</script>" im Antworttext das Skript-Element.
        dangerouslySetInnerHTML={{ __html: JSON.stringify(ld).replace(/</g, "\\u003c") }}
      />
    </section>
  );
}
```

```css
/* apps/web/app/landung/Fragen.module.css */
.abschnitt {
  padding: var(--s48) 20px;
  max-width: 760px;
  margin: 0 auto;
}

.titel {
  font-size: 32px;
  line-height: 1.1;
  font-weight: 800;
  letter-spacing: -0.03em;
  margin: 0 0 var(--s24);
}

.liste {
  border-top: 1px solid var(--line);
}

.frage {
  border-bottom: 1px solid var(--line);
}

.kopf {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--s16);
  min-height: 56px;
  padding: var(--s12) 0;
  font-size: 17px;
  font-weight: 600;
  cursor: pointer;
  list-style: none;
}

.kopf::-webkit-details-marker {
  display: none;
}

/* Derselbe Pfeil wie .nochZuTunKopf im Portal: ein Zeichen, eine Bedeutung. */
.kopf::after {
  content: "";
  flex: none;
  width: 8px;
  height: 8px;
  border-right: 2px solid var(--text-muted);
  border-bottom: 2px solid var(--text-muted);
  transform: translateY(-2px) rotate(45deg);
  transition: transform 160ms ease-out;
}

.frage[open] > .kopf::after {
  transform: translateY(1px) rotate(-135deg);
}

.antwort {
  color: var(--text-muted);
  font-size: 16px;
  line-height: 1.55;
  margin: 0 0 var(--s16);
  max-width: 60ch;
}
```

```tsx
// apps/web/app/landung/Fuss.tsx
import Link from "next/link";
import styles from "./Fuss.module.css";

/**
 * Produktgrenze in text-muted (Designsystem 2 und 10, Befund 19) und die
 * Wege fuer Trainer, die frueher die Hauptaktion waren. Die Linknamen
 * unterscheiden sich vom "Anmelden" im Kopf, damit jeder Weg eindeutig
 * benannt ist.
 */
export function Fuss({ id, produktgrenze }: { id: string; produktgrenze: string }) {
  return (
    <footer id={id} className={styles.fuss}>
      <p className={styles.grenze}>{produktgrenze}</p>
      <nav aria-label="Für Trainer und Studios" className={styles.wege}>
        <span>Für Trainer und Studios:</span>
        <Link href="/login">Trainer-Anmeldung</Link>
        <Link href="/registrieren">Konto anlegen</Link>
      </nav>
    </footer>
  );
}
```

```css
/* apps/web/app/landung/Fuss.module.css */
.fuss {
  border-top: 1px solid var(--line);
  padding: var(--s32) 20px calc(var(--s32) + env(safe-area-inset-bottom));
  display: grid;
  gap: var(--s16);
}

.grenze {
  color: var(--text-muted);
  font-size: 13px;
  line-height: 1.45;
  max-width: 80ch;
  margin: 0;
}

.wege {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: var(--s8) var(--s16);
  font-size: 13px;
  color: var(--text-muted);
}

.wege a {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--text);
  font-weight: 600;
}
```

- [ ] **Schritt 4: Tests laufen lassen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung`
Expected: PASS (Fragen 3 Tests plus Aufgaben 1–2).

- [ ] **Schritt 5: Commit**

```bash
git add apps/web/lib/appStore.ts apps/web/app/landung/testhilfen.ts apps/web/app/landung/Laufband.* apps/web/app/landung/Fragen.* apps/web/app/landung/Fuss.*
git commit -m "feat(landung): Faktenzeile, Fragen mit JSON-LD und Fuss mit Produktgrenze

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 4: Gemeinsame Hauptaktion, Medienabfrage-Hook und Kopf

**Files:**
- Create: `apps/web/app/landung/Aktion.module.css`, `useMedienabfrage.ts`, `Kopf.tsx`, `Kopf.module.css`
- Test: `apps/web/app/landung/useMedienabfrage.test.tsx`

**Interfaces:**
- Produces: CSS-Klasse `hauptaktion` (in anderen Modulen per `composes: hauptaktion from "./Aktion.module.css";`), `useMedienabfrage(query: string): boolean` (Server-Snapshot `false`), `useReduzierteBewegung(): boolean`, `<Kopf />`.

- [ ] **Schritt 1: Failing Test**

```tsx
// apps/web/app/landung/useMedienabfrage.test.tsx
// @vitest-environment jsdom
import { cleanup, render, screen } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { stubMatchMedia } from "./testhilfen";
import { useReduzierteBewegung } from "./useMedienabfrage";

afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

function Anzeige() {
  return <p>{useReduzierteBewegung() ? "ruhig" : "bewegt"}</p>;
}

describe("useReduzierteBewegung", () => {
  it("liest prefers-reduced-motion", () => {
    stubMatchMedia((q) => q === "(prefers-reduced-motion: reduce)");
    render(<Anzeige />);
    expect(screen.getByText("ruhig")).toBeDefined();
  });

  it("ohne Wunsch bewegt", () => {
    stubMatchMedia(() => false);
    render(<Anzeige />);
    expect(screen.getByText("bewegt")).toBeDefined();
  });
});
```

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/useMedienabfrage.test.tsx`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 2: Implementierung**

```ts
// apps/web/app/landung/useMedienabfrage.ts
"use client";
import { useSyncExternalStore } from "react";

/**
 * useSyncExternalStore statt useEffect+useState: kein Zwischenrender mit
 * falschem Wert nach der Hydrierung. Der Server kennt kein Medium und
 * nimmt "trifft nicht zu" an -- dann rendert er die ruhige Fassung ohne
 * Video, die Client-Fassung kommt danach dazu.
 */
export function useMedienabfrage(query: string): boolean {
  return useSyncExternalStore(
    (melden) => {
      const liste = window.matchMedia(query);
      liste.addEventListener("change", melden);
      return () => liste.removeEventListener("change", melden);
    },
    () => window.matchMedia(query).matches,
    () => false,
  );
}

export function useReduzierteBewegung(): boolean {
  return useMedienabfrage("(prefers-reduced-motion: reduce)");
}
```

```css
/* apps/web/app/landung/Aktion.module.css */
/* Die Akzentflaeche der Landeseite (Designsystem 4: Hauptaktion 64 px,
   Radius 16). Held, CTA und Kaufleiste teilen sie; im Viewport steht immer
   hoechstens eine davon (Spec 4.2). */
.hauptaktion {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 64px;
  padding: 0 var(--s32);
  border-radius: 16px;
  background: var(--accent);
  color: var(--on-accent);
  font-weight: 700;
  font-size: 17px;
  text-decoration: none;
  transition:
    transform 120ms var(--ease-out),
    background-color 120ms ease;
}

/* Rueckmeldung beim Druck, nicht erst beim Loslassen. */
.hauptaktion:active {
  transform: scale(0.97);
  background: var(--accent-pressed);
}

@media (hover: hover) and (pointer: fine) {
  .hauptaktion:hover {
    background: var(--accent-pressed);
  }
}
```

```tsx
// apps/web/app/landung/Kopf.tsx
import Link from "next/link";
import { GymtavoWordmark } from "../branding/GymtavoWordmark";
import styles from "./Kopf.module.css";

/**
 * Sticky Glas-Pille (Spec 7.2). Etappe 1 ohne Menue: "Fuer Studios" hat bis
 * Etappe 2 kein Ziel, und ein Menue fuer einen einzigen Eintrag waere
 * Mechanik ohne Inhalt. "App laden" steht hier nicht -- als zweite
 * Akzentflaeche neben dem Hero-Knopf verletzte es Spec 4.2.
 */
export function Kopf() {
  return (
    <header className={styles.kopf}>
      <GymtavoWordmark />
      <Link href="/login" className={styles.anmelden}>
        Anmelden
      </Link>
    </header>
  );
}
```

```css
/* apps/web/app/landung/Kopf.module.css */
/* 54 px Pille, 8 px vom Rand: zusammen --kopf-hoehe (62 px) auf
   .startseite. Aendert sich eins davon, muss die Konstante mit. */
.kopf {
  position: sticky;
  top: var(--s8);
  z-index: 30;
  height: 54px;
  margin: var(--s8) var(--s16) 0;
  padding: 0 var(--s8) 0 var(--s16);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: var(--s16);
  border-radius: 16px;
  border: 1px solid var(--line);
  background: rgba(10, 11, 13, 0.72);
  -webkit-backdrop-filter: blur(22px) saturate(1.2);
  backdrop-filter: blur(22px) saturate(1.2);
}

/* Ohne Unschaerfe waere 72 % Deckkraft ueber Text unlesbar. */
@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .kopf {
    background: var(--surface);
  }
}

@media (prefers-reduced-transparency: reduce), (prefers-contrast: more) {
  .kopf {
    background: var(--surface);
    -webkit-backdrop-filter: none;
    backdrop-filter: none;
  }
}

/* Nebenaktion wie bisher .anmeldenKopf: Umriss, keine Akzentflaeche. */
.anmelden {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  height: 40px;
  padding: 0 var(--s16);
  border-radius: var(--r-control);
  background: var(--surface-raised);
  border: 1px solid var(--line);
  color: var(--text);
  font-weight: 600;
  flex-shrink: 0;
}

@media (hover: hover) and (pointer: fine) {
  .anmelden:hover {
    background: var(--surface-hover);
  }
}
```

- [ ] **Schritt 3: Tests laufen lassen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung`
Expected: PASS.

- [ ] **Schritt 4: Commit**

```bash
git add apps/web/app/landung/Aktion.module.css apps/web/app/landung/useMedienabfrage.* apps/web/app/landung/Kopf.*
git commit -m "feat(landung): Hauptaktion, Medienabfrage-Hook und Kopf als Glaspille

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 5: Held und optionales Held-Video

**Files:**
- Create: `apps/web/app/landung/Held.tsx`, `Held.module.css`, `HeldVideo.tsx`
- Test: `apps/web/app/landung/HeldVideo.test.tsx`

**Interfaces:**
- Consumes: `useMedienabfrage`, `useReduzierteBewegung` (Aufgabe 4), `hauptaktion` (Aufgabe 4), `stubIntersectionObserver`, `stubMatchMedia` (Aufgabe 3).
- Produces: `<Held titel vorspann aktion={{ href, text }} nebenlink={{ href, text }} bild={{ src, alt, width, height }} video?={{ src, poster }} />`. Der Hauptknopf trägt `id="held-aktion"`. `<HeldVideo src poster />`.

- [ ] **Schritt 1: Failing Test**

```tsx
// apps/web/app/landung/HeldVideo.test.tsx
// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { HeldVideo } from "./HeldVideo";
import { stubIntersectionObserver, stubMatchMedia } from "./testhilfen";

const play = () => HTMLMediaElement.prototype.play;
const pause = () => HTMLMediaElement.prototype.pause;

beforeEach(() => {
  // jsdom implementiert keine Medienwiedergabe.
  vi.spyOn(HTMLMediaElement.prototype, "play").mockResolvedValue(undefined);
  vi.spyOn(HTMLMediaElement.prototype, "pause").mockImplementation(() => {});
});

afterEach(() => {
  cleanup();
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("HeldVideo", () => {
  it("bei reduzierter Bewegung kein Video -- das Poster im Held bleibt", () => {
    stubIntersectionObserver();
    stubMatchMedia((q) => q.includes("reduce") || q.includes("max-width"));
    const { container } = render(<HeldVideo src="/v.mp4" poster="/p.png" />);
    expect(container.querySelector("video")).toBeNull();
  });

  it("ab 990 px kein Video", () => {
    stubIntersectionObserver();
    stubMatchMedia(() => false);
    const { container } = render(<HeldVideo src="/v.mp4" poster="/p.png" />);
    expect(container.querySelector("video")).toBeNull();
  });

  it("spielt erst, wenn es sichtbar ist, und laesst sich anhalten (WCAG 2.2.2)", async () => {
    const io = stubIntersectionObserver();
    stubMatchMedia((q) => q.includes("max-width"));
    const { container } = render(<HeldVideo src="/v.mp4" poster="/p.png" />);
    const video = container.querySelector("video")!;
    expect(play()).not.toHaveBeenCalled();

    await act(async () => io.melden(video, { isIntersecting: true }));
    expect(play()).toHaveBeenCalledTimes(1);

    fireEvent.click(screen.getByRole("button", { name: "Video anhalten" }));
    expect(pause()).toHaveBeenCalled();
    expect(screen.getByRole("button", { name: "Video abspielen" })).toBeDefined();

    // Von Hand angehalten bleibt angehalten, auch wenn es wieder ins Bild kommt.
    await act(async () => io.melden(video, { isIntersecting: false }));
    await act(async () => io.melden(video, { isIntersecting: true }));
    expect(play()).toHaveBeenCalledTimes(1);
  });
});
```

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/HeldVideo.test.tsx`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 2: HeldVideo implementieren**

```tsx
// apps/web/app/landung/HeldVideo.tsx
"use client";
import { useEffect, useRef, useState } from "react";
import styles from "./Held.module.css";
import { useMedienabfrage, useReduzierteBewegung } from "./useMedienabfrage";

/**
 * Hochkant-Video nur mobil, nur ohne Bewegungsreduktion, nur im Bild
 * (Spec 7.2, Gpath). In Etappe 1 uebergibt niemand ein Video (E6); der
 * Baustein steht, damit das Video spaeter nur eine Prop ist.
 */
export function HeldVideo({ src, poster }: { src: string; poster: string }) {
  const reduziert = useReduzierteBewegung();
  const schmal = useMedienabfrage("(max-width: 989px)");
  const aktiv = schmal && !reduziert;
  const video = useRef<HTMLVideoElement>(null);
  const vonHandAngehalten = useRef(false);
  const imBild = useRef(false);
  const [laeuft, setLaeuft] = useState(false);

  useEffect(() => {
    const v = video.current;
    if (!aktiv || !v) return;
    const abspielen = () => {
      if (!imBild.current || vonHandAngehalten.current || document.hidden) return;
      v.play().then(
        () => setLaeuft(true),
        () => setLaeuft(false),
      );
    };
    const io = new IntersectionObserver(
      ([e]) => {
        imBild.current = e.isIntersecting;
        if (e.isIntersecting) abspielen();
        else {
          v.pause();
          setLaeuft(false);
        }
      },
      { threshold: 0.15 },
    );
    io.observe(v);
    // Safari haelt Videos im Hintergrund an; der Observer meldet beim
    // Zurueckkehren keinen Wechsel.
    document.addEventListener("visibilitychange", abspielen);
    window.addEventListener("pageshow", abspielen);
    return () => {
      io.disconnect();
      document.removeEventListener("visibilitychange", abspielen);
      window.removeEventListener("pageshow", abspielen);
    };
  }, [aktiv]);

  if (!aktiv) return null;

  const umschalten = () => {
    const v = video.current;
    if (!v) return;
    if (laeuft) {
      vonHandAngehalten.current = true;
      v.pause();
      setLaeuft(false);
    } else {
      vonHandAngehalten.current = false;
      v.play().then(() => setLaeuft(true));
    }
  };

  return (
    <div className={styles.video}>
      <video
        ref={video}
        src={src}
        poster={poster}
        muted
        loop
        playsInline
        preload="none"
        aria-hidden="true"
        tabIndex={-1}
      />
      <button
        type="button"
        className={styles.pause}
        onClick={umschalten}
        aria-label={laeuft ? "Video anhalten" : "Video abspielen"}
      >
        <span aria-hidden="true">{laeuft ? "❚❚" : "▶"}</span>
      </button>
    </div>
  );
}
```

- [ ] **Schritt 3: Held implementieren**

```tsx
// apps/web/app/landung/Held.tsx
import Image from "next/image";
import aktion from "./Aktion.module.css";
import styles from "./Held.module.css";
import { HeldVideo } from "./HeldVideo";

type Props = {
  titel: string;
  vorspann: string;
  aktion: { href: string; text: string };
  nebenlink: { href: string; text: string };
  bild: { src: string; alt: string; width: number; height: number };
  video?: { src: string; poster: string };
};

/**
 * Text oben, Bild in der Mitte, Knopf unten -- mobil die Gpath-Anordnung
 * (Spec 2). Keine Einblendanimation: die erste Ansicht steht sofort.
 */
export function Held({ titel, vorspann, aktion: haupt, nebenlink, bild, video }: Props) {
  return (
    <section className={styles.held} aria-labelledby="held-titel">
      <div className={styles.text}>
        <h1 id="held-titel" className={styles.titel}>
          {titel}
        </h1>
        <p className={styles.vorspann}>{vorspann}</p>
      </div>
      <div className={styles.bild}>
        <Image
          src={bild.src}
          alt={bild.alt}
          width={bild.width}
          height={bild.height}
          priority
          sizes="(min-width: 990px) 40vw, 90vw"
          className={styles.bildDatei}
        />
        {video ? <HeldVideo src={video.src} poster={video.poster} /> : null}
      </div>
      <div className={styles.aktionen}>
        <a id="held-aktion" href={haupt.href} className={`${aktion.hauptaktion} ${styles.knopf}`}>
          {haupt.text}
        </a>
        <a href={nebenlink.href} className={styles.nebenlink}>
          {nebenlink.text}
        </a>
      </div>
    </section>
  );
}
```

```css
/* apps/web/app/landung/Held.module.css */
/* svh statt Gpaths JS-Hoehenschloss: die kleine Viewporthoehe aendert sich
   beim Ein- und Ausfahren der Safari-Leiste nicht, der Held springt nicht. */
.held {
  position: relative;
  display: flex;
  flex-direction: column;
  min-height: 100vh;
  min-height: 100svh;
  margin-top: calc(-1 * var(--kopf-hoehe));
  padding: calc(var(--kopf-hoehe) + var(--s32)) 20px var(--s32);
  overflow: hidden;
}

.titel {
  font-size: clamp(44px, 13vw, 92px);
  line-height: 0.94;
  font-weight: 800;
  letter-spacing: -0.045em;
  text-transform: uppercase;
  text-wrap: balance;
  margin: 0;
  max-width: 12ch;
}

.vorspann {
  color: var(--text-muted);
  font-size: 17px;
  line-height: 1.5;
  margin: var(--s24) 0 0;
  max-width: 52ch;
}

.bild {
  position: relative;
  flex: 1;
  min-height: 220px;
  margin: var(--s24) 0;
  display: flex;
  justify-content: center;
}

.bildDatei {
  width: auto;
  height: 100%;
  max-height: 52svh;
  object-fit: contain;
  border-radius: 24px;
  border: 1px solid var(--line);
}

.aktionen {
  margin-top: auto;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--s12);
}

.knopf {
  min-width: min(320px, 100%);
}

.nebenlink {
  display: inline-flex;
  align-items: center;
  min-height: 44px;
  color: var(--text-muted);
  font-size: 15px;
}

@media (max-width: 480px) {
  .knopf {
    width: 100%;
  }
}

@media (min-width: 990px) {
  .held {
    display: grid;
    grid-template-columns: minmax(0, 1.3fr) minmax(0, 1fr);
    grid-template-areas:
      "text bild"
      "aktionen bild";
    align-content: center;
    column-gap: var(--s48);
    padding-inline: var(--s48);
  }
  .text {
    grid-area: text;
    align-self: end;
  }
  .aktionen {
    grid-area: aktionen;
    align-self: start;
    margin-top: var(--s40);
  }
  .bild {
    grid-area: bild;
    margin: 0;
    height: min(70svh, 720px);
  }
}

/* Video liegt ueber dem Poster derselben Groesse; es ersetzt das Bild
   nur, solange es laeuft oder angehalten ist. */
.video {
  position: absolute;
  inset: 0;
  display: flex;
  justify-content: center;
}

.video video {
  height: 100%;
  max-height: 52svh;
  width: auto;
  object-fit: contain;
  border-radius: 24px;
}

.pause {
  position: absolute;
  right: 0;
  bottom: 0;
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: 1px solid var(--line);
  background: rgba(20, 22, 26, 0.72);
  color: var(--text);
  font-size: 13px;
}
```

- [ ] **Schritt 4: Tests laufen lassen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung`
Expected: PASS.

- [ ] **Schritt 5: Commit**

```bash
git add apps/web/app/landung/Held.* apps/web/app/landung/HeldVideo.*
git commit -m "feat(landung): Held mit svh-Hoehe und optionalem Video mit Pause-Knopf

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 6: Ohne/Mit

**Files:**
- Create: `apps/web/app/landung/OhneMit.tsx`, `OhneMit.module.css`
- Test: `apps/web/app/landung/OhneMit.test.tsx`

**Interfaces:**
- Consumes: `ohneMitZustand`, `OHNE_MIT_START`, `pillenFlug`, `feedZeitplan`, `feedLage`, `RUECKFLUG_MS` (Aufgabe 2), `stubIntersectionObserver` (Aufgabe 3).
- Produces: `type Pille = { text: string; x: number; y: number }`, `<OhneMit titel marke ohne mit />`. Test-IDs `ohnemit-karte` und `ohnemit-sonde` (von `e2e/landung.spec.ts` genutzt).

- [ ] **Schritt 1: Failing Test**

```tsx
// apps/web/app/landung/OhneMit.test.tsx
// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { OhneMit } from "./OhneMit";
import { stubIntersectionObserver } from "./testhilfen";

let io: ReturnType<typeof stubIntersectionObserver>;
beforeEach(() => {
  io = stubIntersectionObserver();
});
afterEach(() => {
  cleanup();
  vi.useRealTimers();
  vi.unstubAllGlobals();
});

const props = {
  titel: "Weißt du noch?",
  marke: "Gymtavo",
  ohne: [
    { text: "Sitz 4 oder 5?", x: 26, y: 14 },
    { text: "Wo ist der Zettel?", x: 72, y: 44 },
  ],
  mit: ["Sitz 5 · Lehne 3", "Zuletzt 42,5 kg × 10", "Vorschlag +2,5 kg", "Einweisung ansehen"],
};

const schalter = () => screen.getByRole("switch", { name: "Mit Gymtavo" });

describe("OhneMit", () => {
  it("der Schalter ist ein echter switch und startet auf Ohne", () => {
    render(<OhneMit {...props} />);
    expect(schalter().tagName).toBe("BUTTON");
    expect(schalter().getAttribute("aria-checked")).toBe("false");
  });

  it("schaltet mit der Sonde", () => {
    render(<OhneMit {...props} />);
    act(() => io.melden(screen.getByTestId("ohnemit-sonde"), { isIntersecting: true }));
    expect(schalter().getAttribute("aria-checked")).toBe("true");
    expect(screen.getByTestId("ohnemit-karte").hasAttribute("data-mit")).toBe(true);
  });

  it("ein Tipp haelt gegen die Sonde, bis die Karte den Viewport verlaesst", () => {
    render(<OhneMit {...props} />);
    fireEvent.click(schalter());
    act(() => io.melden(screen.getByTestId("ohnemit-sonde"), { isIntersecting: false }));
    expect(schalter().getAttribute("aria-checked")).toBe("true");

    act(() => io.melden(screen.getByTestId("ohnemit-karte"), { isIntersecting: false }));
    expect(schalter().getAttribute("aria-checked")).toBe("false");
    act(() => io.melden(screen.getByTestId("ohnemit-sonde"), { isIntersecting: true }));
    expect(schalter().getAttribute("aria-checked")).toBe("true");
  });

  it("der Feed laeuft einen Durchgang und steht dann auf dem letzten Eintrag", () => {
    vi.useFakeTimers();
    render(<OhneMit {...props} />);
    fireEvent.click(schalter());
    const eintrag = (t: string) => screen.getByText(t);
    expect(eintrag("Sitz 5 · Lehne 3").style.getPropertyValue("--o")).toBe("0");
    act(() => vi.advanceTimersByTime(1220));
    expect(eintrag("Zuletzt 42,5 kg × 10").style.getPropertyValue("--o")).toBe("0");
    act(() => vi.advanceTimersByTime(10_000));
    expect(eintrag("Einweisung ansehen").style.getPropertyValue("--o")).toBe("0");
  });

  it("beide Listen stehen im Dokument -- der Vergleich ist der Inhalt", () => {
    render(<OhneMit {...props} />);
    expect(screen.getByRole("list", { name: "Ohne Gymtavo" })).toBeDefined();
    expect(screen.getByRole("list", { name: "Mit Gymtavo" })).toBeDefined();
  });
});
```

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/OhneMit.test.tsx`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 2: Implementierung**

```tsx
// apps/web/app/landung/OhneMit.tsx
"use client";
import { useEffect, useReducer, useRef, useState, type CSSProperties } from "react";
import {
  OHNE_MIT_START,
  RUECKFLUG_MS,
  feedLage,
  feedZeitplan,
  ohneMitZustand,
  pillenFlug,
} from "./ohnemit.logik";
import styles from "./OhneMit.module.css";

export type Pille = { text: string; x: number; y: number };

type Props = { titel: string; marke: string; ohne: readonly Pille[]; mit: readonly string[] };

/**
 * Die eine Inszenierung der Seite, Modell "Schwelle" (Spec 7.2.2). Die
 * Werte je Pille und Feed-Eintrag stehen am Element selbst, nicht als
 * Variable am Elternteil -- sonst rechnete jeder Wechsel die Stile aller
 * Kinder neu.
 */
export function OhneMit({ titel, marke, ohne, mit }: Props) {
  const karte = useRef<HTMLDivElement>(null);
  const sonde = useRef<HTMLSpanElement>(null);
  const [zustand, melden] = useReducer(ohneMitZustand, OHNE_MIT_START);
  const [feedIndex, setFeedIndex] = useState(0);

  useEffect(() => {
    const k = karte.current;
    const s = sonde.current;
    if (!k || !s) return;
    const sondeIO = new IntersectionObserver(
      ([e]) => melden({ art: "sonde", schneidet: e.isIntersecting }),
      { rootMargin: "0px 0px -42% 0px" },
    );
    const karteIO = new IntersectionObserver(([e]) => {
      if (!e.isIntersecting) melden({ art: "karteWeg" });
    });
    sondeIO.observe(s);
    karteIO.observe(k);
    return () => {
      sondeIO.disconnect();
      karteIO.disconnect();
    };
  }, []);

  useEffect(() => {
    if (!zustand.mit) {
      const t = setTimeout(() => setFeedIndex(0), RUECKFLUG_MS);
      return () => clearTimeout(t);
    }
    const timer = feedZeitplan(mit.length).map((ms, i) => setTimeout(() => setFeedIndex(i + 1), ms));
    return () => timer.forEach(clearTimeout);
  }, [zustand.mit, mit.length]);

  return (
    <section className={styles.abschnitt} aria-labelledby="ohnemit-titel">
      <div
        ref={karte}
        className={styles.karte}
        data-mit={zustand.mit ? "" : undefined}
        data-testid="ohnemit-karte"
      >
        <span ref={sonde} className={styles.sonde} aria-hidden="true" data-testid="ohnemit-sonde" />
        <div className={styles.kopf}>
          <h2 id="ohnemit-titel" className={styles.titel}>
            {titel}
          </h2>
          <div className={styles.schalterZeile}>
            <span className={styles.seiteOhne} aria-hidden="true">
              Ohne {marke}
            </span>
            <button
              type="button"
              role="switch"
              aria-checked={zustand.mit}
              aria-label={`Mit ${marke}`}
              className={styles.schalter}
              onClick={() => melden({ art: "tipp" })}
            >
              <span className={styles.knopf} />
            </button>
            <span className={styles.seiteMit} aria-hidden="true">
              Mit {marke}
            </span>
          </div>
          <p className={styles.hinweis}>Scroll, oder tipp auf den Schalter.</p>
        </div>
        <div className={styles.buehne}>
          <ul className={styles.pillen} aria-label={`Ohne ${marke}`}>
            {ohne.map((p, i) => {
              const f = pillenFlug(p.x, p.y, i);
              const stil = {
                left: `${p.x}%`,
                top: `${p.y}%`,
                "--sx": `${f.sx}px`,
                "--sy": `${f.sy}px`,
                "--r": `${f.r}deg`,
                "--d": `${f.verzoegerung}ms`,
              } as CSSProperties;
              return (
                <li key={p.text} className={styles.pille} style={stil}>
                  {p.text}
                </li>
              );
            })}
          </ul>
          <ol className={styles.feed} aria-label={`Mit ${marke}`}>
            {mit.map((text, i) => {
              const l = feedLage(i - feedIndex);
              const stil = { "--o": l.versatz, "--s": l.skala, "--a": l.deckkraft } as CSSProperties;
              return (
                <li key={text} style={stil}>
                  {text}
                </li>
              );
            })}
          </ol>
        </div>
      </div>
    </section>
  );
}
```

```css
/* apps/web/app/landung/OhneMit.module.css */
.abschnitt {
  padding: var(--s48) var(--s16);
}

.karte {
  position: relative;
  max-width: 640px;
  margin: 0 auto;
  border-radius: 24px;
  border: 1px solid var(--line);
  background: var(--surface);
  overflow: hidden;
}

/* 1-px-Sonde in der Kartenmitte; der Observer mit -42 % unten meldet sie,
   solange sie zwischen Oberkante und 58 % des Viewports steht. */
.sonde {
  position: absolute;
  left: 0;
  top: 50%;
  width: 1px;
  height: 1px;
  pointer-events: none;
}

.kopf {
  position: relative;
  z-index: 3;
  padding: var(--s24) 20px 0;
}

.titel {
  font-size: 28px;
  line-height: 1.08;
  font-weight: 800;
  letter-spacing: -0.03em;
  text-wrap: balance;
  margin: 0 0 var(--s16);
}

.schalterZeile {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: var(--s12);
  font-size: 15px;
  font-weight: 600;
}

.seiteOhne,
.seiteMit {
  color: var(--text-faint);
  transition: color 200ms ease;
}

.karte:not([data-mit]) .seiteOhne,
.karte[data-mit] .seiteMit {
  color: var(--text);
}

.schalter {
  position: relative;
  flex: none;
  width: 60px;
  height: 36px;
  padding: 0;
  border-radius: 999px;
  border: 1px solid var(--line);
  background: var(--surface-raised);
  cursor: pointer;
  transition:
    background-color 300ms ease,
    border-color 300ms ease;
}

/* 36 px Spur, 46 px Trefferflaeche (Designsystem 4: mindestens 44). */
.schalter::before {
  content: "";
  position: absolute;
  inset: -5px;
}

.knopf {
  position: absolute;
  top: 3px;
  left: 3px;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  background: var(--text-muted);
  transition:
    transform 300ms var(--ease-out),
    background-color 300ms ease;
}

/* "Mit" in --text, nicht --accent: der Akzent gehoert der Hauptaktion
   (Designsystem 2), und akzentflaechen() zaehlte die Spur sonst mit. */
.schalter[aria-checked="true"] {
  background: var(--text);
  border-color: var(--text);
}

.schalter[aria-checked="true"] .knopf {
  transform: translateX(24px);
  background: var(--bg);
}

.schalter:active .knopf {
  transform: scale(0.92);
}

.schalter[aria-checked="true"]:active .knopf {
  transform: translateX(24px) scale(0.92);
}

.hinweis {
  font-size: 13px;
  color: var(--text-muted);
  margin: var(--s8) 0 0;
}

.buehne {
  position: relative;
  height: 420px;
  margin-top: var(--s16);
}

.pillen {
  list-style: none;
  margin: 0;
  padding: 0;
  position: absolute;
  inset: 0;
  z-index: 2;
}

/* Transition, keine Keyframes: wer mitten im Flug zurueckscrollt, dreht
   die Bewegung vom aktuellen Wert aus um. Zurueck ohne Staffel. */
.pille {
  position: absolute;
  transform: translate(-50%, -50%);
  white-space: nowrap;
  max-width: calc(100% - 16px);
  overflow: hidden;
  text-overflow: ellipsis;
  font-size: 14px;
  font-weight: 600;
  padding: 9px 14px;
  border-radius: 999px;
  border: 1px solid var(--line);
  background: rgba(29, 32, 38, 0.86);
  transition:
    transform 550ms var(--ease-out),
    opacity 400ms var(--ease-out);
}

.karte[data-mit] .pille {
  transform: translate(calc(-50% + var(--sx)), calc(-50% + var(--sy))) scale(0.55) rotate(var(--r));
  opacity: 0;
  transition-delay: var(--d);
}

.feed {
  list-style: none;
  margin: 0;
  padding: 0;
  position: absolute;
  inset: 0;
  z-index: 2;
  display: grid;
  place-items: center;
  opacity: 0;
  transition: opacity 300ms var(--ease-out);
}

.karte[data-mit] .feed {
  opacity: 1;
  transition-delay: 120ms;
}

/* Gleiten auf der Flaeche, kein Ein- oder Austritt: ease-in-out. */
.feed li {
  grid-area: 1 / 1;
  white-space: nowrap;
  /* 26 px passten bei 320 px Breite nicht: "Zuletzt 42,5 kg × 10" wurde
     an der Karte abgeschnitten. */
  font-size: clamp(20px, 6.5vw, 26px);
  font-weight: 800;
  letter-spacing: -0.02em;
  padding: var(--s12) 20px;
  border-radius: 16px;
  background: rgba(10, 11, 13, 0.6);
  transform: translateY(calc(var(--o) * 3.9rem)) scale(var(--s));
  opacity: var(--a);
  transition:
    transform 480ms var(--ease-in-out),
    opacity 480ms var(--ease-in-out);
}

/* Designsystem 6: Zustandswechsel statt Bewegung, ohne Informationsverlust
   -- der Feed wird zur stillen Liste aller Eintraege. */
@media (prefers-reduced-motion: reduce) {
  .feed {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    gap: var(--s8);
  }
  .feed li {
    transform: none;
    opacity: 1;
    font-size: 20px;
  }
}
```

- [ ] **Schritt 3: Tests laufen lassen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung`
Expected: PASS.

- [ ] **Schritt 4: Commit**

```bash
git add apps/web/app/landung/OhneMit.*
git commit -m "feat(landung): Ohne/Mit mit Sonde, Tipp-Vorrang und einem Feed-Durchgang

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 7: So geht's mit Scroll-Snap und Indikatoren

**Files:**
- Create: `apps/web/app/landung/Schritte.tsx`, `Schritte.module.css`, `SchritteIndikatoren.tsx`
- Test: `apps/web/app/landung/SchritteIndikatoren.test.tsx`

**Interfaces:**
- Consumes: `useReduzierteBewegung` (Aufgabe 4), `stubIntersectionObserver`, `stubMatchMedia` (Aufgabe 3).
- Produces: `type Schritt = { titel: string; text: string; bild: { src: string; alt: string } }`, `<Schritte id titel schritte bildmasse={{ width, height }} />`, `<SchritteIndikatoren ids={string[]} titel={string[]} />`.

- [ ] **Schritt 1: Failing Test**

```tsx
// apps/web/app/landung/SchritteIndikatoren.test.tsx
// @vitest-environment jsdom
import { act, cleanup, fireEvent, render, screen } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { SchritteIndikatoren } from "./SchritteIndikatoren";
import { stubIntersectionObserver, stubMatchMedia } from "./testhilfen";

let io: ReturnType<typeof stubIntersectionObserver>;
const scrollIntoView = vi.fn();

beforeEach(() => {
  io = stubIntersectionObserver();
  Element.prototype.scrollIntoView = scrollIntoView;
  document.body.innerHTML = '<ol><li id="s-1"></li><li id="s-2"></li><li id="s-3"></li></ol>';
});
afterEach(() => {
  cleanup();
  scrollIntoView.mockReset();
  vi.unstubAllGlobals();
});

const ids = ["s-1", "s-2", "s-3"];
const titel = ["Tippen", "Trainieren", "Weiterkommen"];

describe("SchritteIndikatoren", () => {
  it("markiert die Folie, die zu 60 % sichtbar ist", () => {
    stubMatchMedia(() => false);
    render(<SchritteIndikatoren ids={ids} titel={titel} />);
    act(() => io.melden(document.getElementById("s-2")!, { isIntersecting: true }));
    expect(screen.getByRole("button", { name: "Schritt 2: Trainieren" }).getAttribute("aria-current")).toBe("step");
    expect(screen.getByRole("button", { name: "Schritt 1: Tippen" }).hasAttribute("aria-current")).toBe(false);
  });

  it("Tipp scrollt weich, bei reduzierter Bewegung sofort", () => {
    stubMatchMedia(() => false);
    render(<SchritteIndikatoren ids={ids} titel={titel} />);
    fireEvent.click(screen.getByRole("button", { name: "Schritt 3: Weiterkommen" }));
    expect(scrollIntoView).toHaveBeenLastCalledWith({ behavior: "smooth", block: "nearest", inline: "start" });
    cleanup();

    stubMatchMedia((q) => q.includes("reduce"));
    render(<SchritteIndikatoren ids={ids} titel={titel} />);
    fireEvent.click(screen.getByRole("button", { name: "Schritt 3: Weiterkommen" }));
    expect(scrollIntoView).toHaveBeenLastCalledWith({ behavior: "auto", block: "nearest", inline: "start" });
  });
});
```

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/SchritteIndikatoren.test.tsx`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 2: Implementierung**

```tsx
// apps/web/app/landung/SchritteIndikatoren.tsx
"use client";
import { useEffect, useState } from "react";
import styles from "./Schritte.module.css";
import { useReduzierteBewegung } from "./useMedienabfrage";

/**
 * Aktive Folie per Observer (threshold .6) statt Gpaths "Scroll-Ende +
 * 150 ms": kein Timer, und die Anzeige stimmt schon waehrend des Wischens.
 */
export function SchritteIndikatoren({ ids, titel }: { ids: readonly string[]; titel: readonly string[] }) {
  const [aktiv, setAktiv] = useState(0);
  const reduziert = useReduzierteBewegung();

  useEffect(() => {
    const folien = ids.map((id) => document.getElementById(id)).filter((el): el is HTMLElement => el !== null);
    const io = new IntersectionObserver(
      (eintraege) => {
        for (const e of eintraege) if (e.isIntersecting) setAktiv(ids.indexOf(e.target.id));
      },
      { root: folien[0]?.parentElement ?? null, threshold: 0.6 },
    );
    folien.forEach((f) => io.observe(f));
    return () => io.disconnect();
  }, [ids]);

  return (
    <div className={styles.indikatoren}>
      {ids.map((id, i) => (
        <button
          key={id}
          type="button"
          className={styles.indikator}
          aria-label={`Schritt ${i + 1}: ${titel[i]}`}
          aria-current={aktiv === i ? "step" : undefined}
          onClick={() =>
            document.getElementById(id)?.scrollIntoView({
              behavior: reduziert ? "auto" : "smooth",
              block: "nearest",
              inline: "start",
            })
          }
        >
          {i + 1}
        </button>
      ))}
    </div>
  );
}
```

```tsx
// apps/web/app/landung/Schritte.tsx
import Image from "next/image";
import styles from "./Schritte.module.css";
import { SchritteIndikatoren } from "./SchritteIndikatoren";

export type Schritt = { titel: string; text: string; bild: { src: string; alt: string } };

/**
 * Mobil ein Scroll-Snap-Slider wie auf Gpaths Produktseite, ab 750 px drei
 * Spalten. Keine eigene Animation: das native Scrollen bringt Impuls und
 * Einrasten mit.
 */
export function Schritte({
  id,
  titel,
  schritte,
  bildmasse,
}: {
  id: string;
  titel: string;
  schritte: readonly Schritt[];
  bildmasse: { width: number; height: number };
}) {
  const ids = schritte.map((_, i) => `${id}-${i + 1}`);
  return (
    <section id={id} className={styles.abschnitt} aria-labelledby={`${id}-titel`}>
      <h2 id={`${id}-titel`} className={styles.titel}>
        {titel}
      </h2>
      <ol className={styles.liste}>
        {schritte.map((s, i) => (
          <li key={s.titel} id={ids[i]} className={styles.schritt}>
            <div className={styles.bildRahmen}>
              <Image
                src={s.bild.src}
                alt={s.bild.alt}
                width={bildmasse.width}
                height={bildmasse.height}
                sizes="(min-width: 750px) 30vw, 80vw"
                className={styles.bildDatei}
              />
            </div>
            <p className={styles.nummer} aria-hidden="true">
              {i + 1}
            </p>
            <h3 className={styles.schrittTitel}>{s.titel}</h3>
            <p className={styles.text}>{s.text}</p>
          </li>
        ))}
      </ol>
      <SchritteIndikatoren ids={ids} titel={schritte.map((s) => s.titel)} />
    </section>
  );
}
```

```css
/* apps/web/app/landung/Schritte.module.css */
.abschnitt {
  background: var(--surface);
  padding: var(--s48) 0;
}

.titel {
  font-size: 32px;
  line-height: 1.1;
  font-weight: 800;
  letter-spacing: -0.03em;
  margin: 0 auto var(--s24);
  padding: 0 20px;
  max-width: 1080px;
}

.liste {
  list-style: none;
  margin: 0;
  padding: 0 20px;
  display: flex;
  gap: var(--s16);
  overflow-x: auto;
  scroll-snap-type: x mandatory;
  scroll-padding-inline: 20px;
  overscroll-behavior-x: contain;
  scrollbar-width: none;
}

.liste::-webkit-scrollbar {
  display: none;
}

.schritt {
  flex: 0 0 82%;
  scroll-snap-align: start;
  background: var(--bg);
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: var(--s16);
}

/* Hochkant-Screenshots sind fast doppelt so hoch wie breit; gezeigt wird
   der obere Teil, dort steht das, worum es im Schritt geht. */
.bildRahmen {
  aspect-ratio: 3 / 4;
  overflow: hidden;
  border-radius: 12px;
  border: 1px solid var(--line);
}

.bildDatei {
  width: 100%;
  height: auto;
  display: block;
}

.nummer {
  margin: var(--s16) 0 0;
  font-size: 13px;
  font-weight: 700;
  color: var(--text-muted);
}

.schrittTitel {
  margin: var(--s4) 0 0;
  font-size: 22px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.text {
  margin: var(--s8) 0 0;
  color: var(--text-muted);
  font-size: 16px;
  line-height: 1.5;
}

.indikatoren {
  display: flex;
  justify-content: center;
  gap: var(--s8);
  margin-top: var(--s16);
}

.indikator {
  width: 44px;
  height: 44px;
  border-radius: 50%;
  border: 1px solid var(--line);
  background: transparent;
  color: var(--text-muted);
  font-weight: 700;
  transition:
    background-color 150ms ease,
    color 150ms ease;
}

.indikator[aria-current="step"] {
  background: var(--surface-raised);
  color: var(--text);
  border-color: var(--text-muted);
}

@media (min-width: 750px) {
  .liste {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    overflow: visible;
    max-width: 1080px;
    margin: 0 auto;
  }
  .indikatoren {
    display: none;
  }
}
```

- [ ] **Schritt 3: Tests laufen lassen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung`
Expected: PASS.

- [ ] **Schritt 4: Commit**

```bash
git add apps/web/app/landung/Schritte.* apps/web/app/landung/SchritteIndikatoren.*
git commit -m "feat(landung): So geht's als Scroll-Snap mit Nummern-Indikatoren

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 8: Kaufleiste

**Files:**
- Create: `apps/web/app/landung/Kaufleiste.tsx`, `Kaufleiste.module.css`
- Test: `apps/web/app/landung/Kaufleiste.test.tsx`

**Interfaces:**
- Consumes: `naechsterZustand`, `KAUFLEISTE_START`, `KaufleistenZustand` (Aufgabe 1), `hauptaktion` (Aufgabe 4), `stubIntersectionObserver` (Aufgabe 3).
- Produces: `<Kaufleiste anker={string} verdecker={readonly string[]} titel={string} merkmale={readonly string[]} aktion={{ href: string; text: string }} />`. Gerendert als `<aside aria-label="Schnellzugriff">`, sichtbar mit `data-sichtbar`, versteckt mit `inert` + `aria-hidden="true"`. Liest `--kopf-hoehe` vom eigenen Element (geerbt von `.startseite`).

- [ ] **Schritt 1: Failing Test**

```tsx
// apps/web/app/landung/Kaufleiste.test.tsx
// @vitest-environment jsdom
import { act, cleanup, render } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { Kaufleiste } from "./Kaufleiste";
import { stubIntersectionObserver } from "./testhilfen";

let io: ReturnType<typeof stubIntersectionObserver>;

function scrollen(y: number) {
  Object.defineProperty(window, "scrollY", { value: y, configurable: true });
  window.dispatchEvent(new Event("scroll"));
}

beforeEach(() => {
  io = stubIntersectionObserver();
  vi.stubGlobal("requestAnimationFrame", (cb: FrameRequestCallback) => {
    cb(0);
    return 1;
  });
  vi.stubGlobal("cancelAnimationFrame", () => {});
  document.body.innerHTML = '<a id="held-aktion"></a><footer id="fuss"></footer>';
  Object.defineProperty(document.documentElement, "scrollHeight", { value: 5000, configurable: true });
  scrollen(0);
});
afterEach(() => {
  cleanup();
  vi.unstubAllGlobals();
});

const leiste = () => document.querySelector("aside")!;

function zeigen() {
  render(
    <Kaufleiste
      anker="held-aktion"
      verdecker={["fuss"]}
      titel="Gymtavo"
      merkmale={["Tap am Gerät", "Deine Werte", "Für iPhone"]}
      aktion={{ href: "https://apps.apple.com/", text: "App laden" }}
    />,
    { container: document.body.appendChild(document.createElement("div")) },
  );
}

describe("Kaufleiste", () => {
  it("startet versteckt: inert und aria-hidden, nicht nur unsichtbar", () => {
    zeigen();
    expect(leiste().hasAttribute("inert")).toBe(true);
    expect(leiste().getAttribute("aria-hidden")).toBe("true");
    expect(leiste().hasAttribute("data-sichtbar")).toBe(false);
  });

  it("erscheint, sobald der Hero-Knopf oben raus ist", () => {
    zeigen();
    act(() => {
      scrollen(820);
      io.melden(document.getElementById("held-aktion")!, {
        isIntersecting: false,
        boundingClientRect: { top: -40, bottom: -10 } as DOMRectReadOnly,
      });
    });
    expect(leiste().hasAttribute("data-sichtbar")).toBe(true);
    expect(leiste().hasAttribute("inert")).toBe(false);
    expect(leiste().getAttribute("aria-hidden")).toBeNull();
  });

  it("weicht dem Fuss", () => {
    zeigen();
    act(() => {
      scrollen(820);
      io.melden(document.getElementById("held-aktion")!, {
        isIntersecting: false,
        boundingClientRect: { top: -40, bottom: -10 } as DOMRectReadOnly,
      });
      io.melden(document.getElementById("fuss")!, { isIntersecting: true });
    });
    expect(leiste().hasAttribute("data-sichtbar")).toBe(false);
  });
});
```

Run: `pnpm --filter @fitretro/web exec vitest run app/landung/Kaufleiste.test.tsx`
Expected: FAIL, Import nicht auflösbar.

- [ ] **Schritt 2: Implementierung**

```tsx
// apps/web/app/landung/Kaufleiste.tsx
"use client";
import { useEffect, useRef, useState } from "react";
import { KAUFLEISTE_START, naechsterZustand, type KaufleistenZustand } from "./kaufleiste.logik";
import styles from "./Kaufleiste.module.css";

type Props = {
  anker: string;
  verdecker: readonly string[];
  titel: string;
  merkmale: readonly string[];
  aktion: { href: string; text: string };
};

/**
 * Spec 7.3. Observer statt Messung in jedem Frame fuer Anker und
 * Verdecker; nur die Scrollrichtung braucht den Scroll-Listener, rAF-
 * gedrosselt. Die Entscheidung trifft naechsterZustand().
 */
export function Kaufleiste({ anker, verdecker, titel, merkmale, aktion }: Props) {
  const leiste = useRef<HTMLElement>(null);
  const [zustand, setZustand] = useState<KaufleistenZustand>(KAUFLEISTE_START);
  const verdeckerSchluessel = verdecker.join(",");

  useEffect(() => {
    const el = leiste.current;
    const ankerEl = document.getElementById(anker);
    if (!el || !ankerEl) return;
    const kopfHoehe = parseFloat(getComputedStyle(el).getPropertyValue("--kopf-hoehe")) || 0;
    const lage = { ankerVorbei: false, schwelleY: 0, fokusDrin: false };
    const sichtbareVerdecker = new Set<Element>();
    let raf = 0;

    const messen = () => {
      raf = 0;
      setZustand((vorher) =>
        naechsterZustand(vorher, {
          y: window.scrollY,
          maxY: document.documentElement.scrollHeight - window.innerHeight,
          ankerVorbei: lage.ankerVorbei,
          schwelleY: lage.schwelleY,
          verdeckt: sichtbareVerdecker.size > 0,
          fokusDrin: lage.fokusDrin,
        }),
      );
    };
    const anfordern = () => {
      if (!raf) raf = requestAnimationFrame(messen);
    };

    const ankerIO = new IntersectionObserver(
      ([e]) => {
        lage.ankerVorbei = !e.isIntersecting && e.boundingClientRect.top < kopfHoehe;
        lage.schwelleY = e.boundingClientRect.bottom + window.scrollY - kopfHoehe;
        anfordern();
      },
      // Unter dem Kopf ist der Knopf schon nicht mehr zu sehen.
      { rootMargin: `-${kopfHoehe}px 0px 0px 0px` },
    );
    ankerIO.observe(ankerEl);

    const verdeckerIO = new IntersectionObserver(
      (eintraege) => {
        for (const e of eintraege) {
          if (e.isIntersecting) sichtbareVerdecker.add(e.target);
          else sichtbareVerdecker.delete(e.target);
        }
        anfordern();
      },
      { threshold: 0.15 },
    );
    for (const id of verdeckerSchluessel.split(",")) {
      const v = document.getElementById(id);
      if (v) verdeckerIO.observe(v);
    }

    // Laege der Fokus in einer Leiste, die inert wird, waere er verloren.
    const fokus = () => {
      lage.fokusDrin = el.contains(document.activeElement);
      anfordern();
    };
    el.addEventListener("focusin", fokus);
    el.addEventListener("focusout", fokus);
    window.addEventListener("scroll", anfordern, { passive: true });

    return () => {
      ankerIO.disconnect();
      verdeckerIO.disconnect();
      el.removeEventListener("focusin", fokus);
      el.removeEventListener("focusout", fokus);
      window.removeEventListener("scroll", anfordern);
      if (raf) cancelAnimationFrame(raf);
    };
  }, [anker, verdeckerSchluessel]);

  const versteckt = !zustand.sichtbar;
  return (
    <aside
      ref={leiste}
      aria-label="Schnellzugriff"
      className={styles.leiste}
      data-sichtbar={zustand.sichtbar ? "" : undefined}
      inert={versteckt}
      aria-hidden={versteckt ? "true" : undefined}
    >
      <div className={styles.text}>
        <p className={styles.titel}>{titel}</p>
        <p className={styles.merkmale}>{merkmale.join(" · ")}</p>
      </div>
      <a href={aktion.href} className={styles.aktion}>
        {aktion.text}
      </a>
    </aside>
  );
}
```

```css
/* apps/web/app/landung/Kaufleiste.module.css */
/* Versteckt liegt die Leiste ganz unter dem Rand: eigene Hoehe plus Abstand
   plus Safe Area -- Gpaths 110 % reicht dafuer nicht. Eine Transition fuer
   alle Wechsel, keine Erst-Einblendung als Keyframe (Spec 7.3): Keyframes
   fangen bei Unterbrechung von vorn an. */
.leiste {
  position: fixed;
  z-index: 40;
  left: 1.2rem;
  right: 1.2rem;
  bottom: calc(1.2rem + env(safe-area-inset-bottom));
  max-width: 42rem;
  margin-inline: auto;
  display: flex;
  align-items: center;
  gap: var(--s12);
  padding: var(--s8) var(--s8) var(--s8) var(--s16);
  border-radius: 20px;
  border: 1px solid var(--line);
  background: rgba(20, 22, 26, 0.72);
  -webkit-backdrop-filter: blur(20px);
  backdrop-filter: blur(20px);
  transform: translateY(calc(100% + 1.2rem + env(safe-area-inset-bottom)));
  transition: transform 200ms var(--ease-drawer);
}

.leiste[data-sichtbar] {
  transform: translateY(0);
  transition-duration: 240ms;
}

@supports not ((backdrop-filter: blur(1px)) or (-webkit-backdrop-filter: blur(1px))) {
  .leiste {
    background: var(--surface);
  }
}

@media (prefers-reduced-transparency: reduce), (prefers-contrast: more) {
  .leiste {
    background: var(--surface);
    -webkit-backdrop-filter: none;
    backdrop-filter: none;
  }
}

@media (min-width: 990px) {
  .leiste {
    max-width: 44rem;
    bottom: calc(1.6rem + env(safe-area-inset-bottom));
    transform: translateY(calc(100% + 1.6rem + env(safe-area-inset-bottom)));
  }
  .leiste[data-sichtbar] {
    transform: translateY(0);
  }
}

.text {
  flex: 1;
  min-width: 0;
}

.titel {
  margin: 0;
  font-size: 15px;
  font-weight: 700;
}

.merkmale {
  margin: 2px 0 0;
  font-size: 12px;
  color: var(--text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

/* Dieselbe Akzentflaeche wie der Hero-Knopf, kompakter: die Leiste ist
   eine Wiederholung der Hauptaktion, kein eigener Ort. 52 px bleiben
   ueber der Trefferflaeche (Designsystem 4). */
.aktion {
  composes: hauptaktion from "./Aktion.module.css";
  flex: none;
  height: 52px;
  padding: 0 20px;
  font-size: 16px;
  border-radius: 14px;
}
```

- [ ] **Schritt 3: Tests laufen lassen**

Run: `pnpm --filter @fitretro/web exec vitest run app/landung`
Expected: PASS.

- [ ] **Schritt 4: Commit**

```bash
git add apps/web/app/landung/Kaufleiste.*
git commit -m "feat(landung): Kaufleiste mit Verdeckern, Fokus-Halt und inert im versteckten Zustand

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 9: App-Screenshots

**Files:**
- Create: `apps/web/public/landung/tippen.png`, `geraet.png`, `verlauf.png`

Diese Aufgabe braucht den Simulator. Laut Worktree-Regel darf immer nur eine Session gleichzeitig bauen. Vorher `df -h /System/Volumes/Data` prüfen, es müssen mehr als 3 GB frei sein. Belegt eine andere Session den Simulator, zuerst Aufgabe 10 bis Schritt 2 vorziehen, die Tests dürfen dort rot bleiben.

- [ ] **Schritt 1: App gegen das lokale Backend starten.** Vorgehen wie in der Notiz zum Simulator-Sichtcheck: App-Build mit `SUPABASE_URL=http://127.0.0.1:54321`, `SUPABASE_ANON_KEY=<aus pnpm supabase status>` und `API_BASE_URL=http://127.0.0.1:3007/api/v1` als xcodebuild-Settings, Web-Dev-Server auf Port 3007, ein Testkonto mit Studio, einem Gerät samt Einstellwerten und drei bestätigten Sätzen.

- [ ] **Schritt 2: Statusleiste festlegen und drei Bilder aufnehmen.** Tim navigiert im Simulator, der Agent nimmt auf:

```bash
xcrun simctl status_bar booted override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4
xcrun simctl io booted screenshot apps/web/public/landung/tippen.png    # Scan-Fenster offen
xcrun simctl io booted screenshot apps/web/public/landung/geraet.png    # Geraete-Screen mit Werten
xcrun simctl io booted screenshot apps/web/public/landung/verlauf.png   # Verlauf eines Geraets
```

- [ ] **Schritt 3: Auf 750 px Breite verkleinern und Maße notieren**

```bash
for f in apps/web/public/landung/*.png; do sips --resampleWidth 750 "$f" >/dev/null; sips -g pixelWidth -g pixelHeight "$f"; done
```
Erwartet: alle drei 750 px breit und gleich hoch (iPhone 17 Pro: 1630). Die Höhe geht in Aufgabe 10 als `BILD` in `Startseite.tsx`. Prüfen, dass auf keinem Bild eine echte Mailadresse steht, nur das Testkonto.

- [ ] **Schritt 4: Commit**

```bash
git add apps/web/public/landung
git commit -m "feat(landung): drei App-Screenshots fuer Held und So geht's

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 10: Startseite zusammensetzen, `/` umstellen, `wurzel.spec` neu

**Files:**
- Create: `apps/web/app/landung/Startseite.tsx`, `Startseite.module.css`, `e2e/landung.spec.ts`
- Create: `apps/web/app/landung/texte.ts`
- Modify: `apps/web/app/page.tsx` (Zweig `if (!user)`), `e2e/helpers/abnahme.ts:42-54`, `e2e/wurzel.spec.ts`
- Delete: `apps/web/app/einstieg/landeseite.module.css`

**Interfaces:**
- Consumes: alles aus den Aufgaben 1–9.
- Produces: `<Startseite />`, `akzentflaechen(page, { nurViewport?: boolean })`. Ids auf der Seite: `held-aktion`, `so-gehts`, `landung-cta`, `fragen`, `landung-fuss`.

- [ ] **Schritt 1: Helfer erweitern** (`e2e/helpers/abnahme.ts`, Funktion `akzentflaechen` ersetzen)

```ts
export async function akzentflaechen(
  page: Page,
  { nurViewport = false }: { nurViewport?: boolean } = {},
): Promise<string[]> {
  return await page.evaluate(
    ({ akzent, nurViewport }) => {
      const treffer: string[] = [];
      for (const el of Array.from(document.querySelectorAll<HTMLElement>("*"))) {
        if (getComputedStyle(el).backgroundColor !== akzent) continue;
        const kasten = el.getBoundingClientRect();
        if (kasten.width === 0 || kasten.height === 0) continue;
        // Spec 4.2 der Landeseite: eine lange Seite hat mehrere Kaufmomente,
        // die Regel gilt je Bildschirm. Die versteckte Kaufleiste liegt per
        // transform unter dem Rand und faellt damit heraus.
        if (
          nurViewport &&
          (kasten.bottom <= 0 || kasten.top >= innerHeight || kasten.right <= 0 || kasten.left >= innerWidth)
        )
          continue;
        const text = (el.textContent ?? "").trim().slice(0, 40);
        treffer.push(`${el.tagName.toLowerCase()}${text ? ` "${text}"` : ""}`);
      }
      return treffer;
    },
    { akzent: AKZENT, nurViewport },
  );
}
```

- [ ] **Schritt 2: Rote e2e-Tests schreiben**

In `e2e/wurzel.spec.ts` die Tests zur Seite ohne Konto ersetzen, also alle vor dem Kommentarblock „Der angemeldete Nicht-Mitarbeiter-Zweig“ sowie „Die Produktgrenze der Landeseite steht in text-muted“. Den Kommentar über dem ersten Test fortschreiben. Die Tests für angemeldete Konten und die Wortmarken-/320-px-Tests am Ende bleiben, wie die Branding-Session sie hinterlassen hat. Import erweitern um `akzentflaechen` (schon da). Neu oben:

```ts
/**
 * Die Wurzelseite ohne Konto. Bis zum 3. September stand hier "Nicht
 * angemeldet.", danach eine Landung fuer Trainer; seit Etappe 1 der neuen
 * Landeseite (Spec 2026-10-03) ist sie fuer Mitglieder da. Trainer finden
 * ihren Weg im Kopf und im Fuss.
 */
test("Ohne Konto: eine Hauptlandmarke und der Weg zur App", async ({ page }) => {
  await page.goto("/");
  expect(await hauptlandmarken(page)).toBe(1);
  await expect(page.getByRole("heading", { level: 1, name: "Nie wieder raten am Gerät." })).toBeVisible();
  const app = page.locator("#held-aktion");
  await expect(app).toHaveText("App laden");
  await expect(app).toHaveAttribute("href", /^https:\/\/apps\.apple\.com\//);
});

test("Hoechstens eine Akzentflaeche im Bild, an jeder Stelle der Seite", async ({ page }) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto("/");
  const pruefen = async (wo: string) => {
    const f = await akzentflaechen(page, { nurViewport: true });
    expect(f.length, `${wo}: ${f.join(", ")}`).toBeLessThanOrEqual(1);
  };
  expect(await akzentflaechen(page, { nurViewport: true })).toHaveLength(1);
  for (const id of ["so-gehts", "landung-cta", "fragen", "landung-fuss"]) {
    await page.locator(`#${id}`).scrollIntoViewIfNeeded();
    // Kaufleiste: 240 ms Transition plus ein Frame.
    await page.waitForTimeout(400);
    await pruefen(id);
  }
});

test("Trainer kommen weiter zu Anmeldung und Konto", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("banner").getByRole("link", { name: "Anmelden", exact: true }).click();
  await expect(page).toHaveURL(/\/login$/);
  await page.goto("/");
  await page.getByRole("contentinfo").getByRole("link", { name: "Konto anlegen" }).click();
  await expect(page).toHaveURL(/\/registrieren$/);
});

/**
 * Befund 19 gilt weiter: die Produktgrenze steht sichtbar und in
 * text-muted, nicht in text-faint (Designsystem 2 und 10).
 */
test("Die Produktgrenze steht im Fuss, in text-muted", async ({ page }) => {
  await page.goto("/");
  const satz = page.getByRole("contentinfo").getByText(/Gymtavo misst nichts/);
  await satz.scrollIntoViewIfNeeded();
  await expect(satz).toBeVisible();
  expect(await satz.evaluate((el) => getComputedStyle(el).color)).toBe("rgb(155, 163, 175)");
});

test("Auf 320 px laeuft die ganze Landeseite nicht ueber", async ({ page }) => {
  await page.setViewportSize({ width: 320, height: 640 });
  await page.goto("/");
  for (const y of [0, 900, 1800, 100_000]) {
    await page.evaluate((y) => window.scrollTo(0, y), y);
    const ueberlauf = await page.evaluate(
      () => document.documentElement.scrollWidth - document.documentElement.clientWidth,
    );
    expect(ueberlauf, `bei y=${y}`).toBe(0);
  }
});
```

Dazu `e2e/landung.spec.ts`:

```ts
import { expect, test, type Page } from "@playwright/test";

/** Kartenmitte auf einen Anteil der Viewporthoehe scrollen. */
async function karteAuf(page: Page, anteil: number) {
  await page.getByTestId("ohnemit-karte").evaluate((el, anteil) => {
    const r = el.getBoundingClientRect();
    window.scrollTo(0, window.scrollY + r.top + r.height / 2 - window.innerHeight * anteil);
  }, anteil);
}

test.use({ viewport: { width: 390, height: 844 } });

test("Ohne/Mit schaltet beim Scrollen in beide Richtungen", async ({ page }) => {
  await page.goto("/");
  const schalter = page.getByRole("switch", { name: "Mit Gymtavo" });
  await expect(schalter).toHaveAttribute("aria-checked", "false");
  await karteAuf(page, 0.3);
  await expect(schalter).toHaveAttribute("aria-checked", "true");
  await page.evaluate(() => window.scrollTo(0, 0));
  await karteAuf(page, 0.8);
  await expect(schalter).toHaveAttribute("aria-checked", "false");
});

test("Ein Tipp haelt, bis die Karte den Bildschirm verlaesst", async ({ page }) => {
  await page.goto("/");
  const schalter = page.getByRole("switch", { name: "Mit Gymtavo" });
  await karteAuf(page, 0.8);
  await schalter.click();
  await expect(schalter).toHaveAttribute("aria-checked", "true");
  await karteAuf(page, 0.75);
  await page.waitForTimeout(200);
  await expect(schalter).toHaveAttribute("aria-checked", "true");
  await page.evaluate(() => window.scrollTo(0, 0));
  await expect(schalter).toHaveAttribute("aria-checked", "false");
});

test("Mit reduzierter Bewegung steht der Feed als Liste da", async ({ page }) => {
  await page.emulateMedia({ reducedMotion: "reduce" });
  await page.goto("/");
  await karteAuf(page, 0.3);
  const feed = page.getByRole("list", { name: "Mit Gymtavo" });
  for (const text of ["Sitz 5 · Lehne 3", "Zuletzt 42,5 kg × 10", "Vorschlag +2,5 kg", "Einweisung ansehen"]) {
    await expect(feed.getByText(text)).toBeInViewport();
  }
});
```

Run: `E2E_PORT=3007 pnpm test:e2e e2e/wurzel.spec.ts e2e/landung.spec.ts`
Expected: Die neuen Tests ohne Konto und alle in `landung.spec.ts` FAIL (alte Seite). Die Tests mit Konto bleiben grün.

- [ ] **Schritt 3: Texte anlegen** (importiert die Typen `Pille`, `Schritt`, `Frage` aus den Aufgaben 3, 6 und 7)

```ts
// apps/web/app/landung/texte.ts
/**
 * Alle Texte der Landeseite an einer Stelle (Spec 5, Designsystem 10).
 * Jede Aussage ueber das Produkt traegt ihren Beleg im Kommentar -- die
 * Seite verspricht nichts, was die App nicht tut.
 */
import type { Frage } from "./Fragen";
import type { Pille } from "./OhneMit";
import type { Schritt } from "./Schritte";

export const MARKE = "Gymtavo";

export const HELD = {
  titel: "Nie wieder raten am Gerät.",
  // Beleg: Geraete-Screen der App zeigt Einstellwerte, letzte Saetze und
  // Einweisungsvideos des Studios (designsystem.md 7, t/[token]/page.tsx).
  vorspann:
    "Halte dein iPhone an das Gerät. Du siehst deine Einstellung, deine letzten Sätze und die Einweisung deines Studios.",
  aktion: "App laden",
  nebenlink: "Wie das funktioniert",
  bild: {
    src: "/landung/geraet.png",
    alt: "Der Geräte-Screen der App mit Einstellwerten und den letzten Sätzen",
  },
} as const;

// Belege: "Einweisung auch ohne App" -- t/[token]/page.tsx zeigt Videos
// oeffentlich, Fussnote "funktioniert auf jedem Geraet und ohne App".
// "an jedem Geraet mit Tag" -- Einstellwerte haengen am Geraet (Spec M1).
export const FAKTEN = [
  "Ein Tap statt Zettel",
  "Einweisung auch ohne App",
  "Deine Werte an jedem Gerät mit Tag",
] as const;

// Positionen in Prozent der Buehne (mobil gemessen im Prototyp vom 3.10.).
export const OHNE_MIT: { titel: string; ohne: readonly Pille[]; mit: readonly string[] } = {
  titel: "Weißt du noch, wie du das Gerät eingestellt hast?",
  ohne: [
    { text: "Wie viele Wiederholungen?", x: 56, y: 6 },
    { text: "Sitz 4 oder 5?", x: 26, y: 14 },
    { text: "Letztes Mal 40 oder 45 kg?", x: 58, y: 24 },
    { text: "Wie ging die Übung?", x: 30, y: 36 },
    { text: "Wo ist der Zettel?", x: 72, y: 44 },
    { text: "3 oder 4 Sätze?", x: 24, y: 54 },
    { text: "Lehne verstellt?", x: 66, y: 62 },
    { text: "Trainer gerade frei?", x: 36, y: 72 },
    { text: "Notizen-App?", x: 76, y: 80 },
    { text: "Griff oben oder unten?", x: 40, y: 88 },
  ],
  // Beleg "Vorschlag +2,5 kg": Zahlformat.swift / designsystem.md 10.
  mit: ["Sitz 5 · Lehne 3", "Zuletzt 42,5 kg × 10", "Vorschlag +2,5 kg", "Einweisung ansehen"],
};

export const SCHRITTE_TITEL = "So geht's";
export const SCHRITTE: readonly Schritt[] = [
  {
    titel: "Tippen",
    text: "Halte dein iPhone an den Tag am Gerät.",
    bild: { src: "/landung/tippen.png", alt: "Das Scan-Fenster der App mit NFC und QR-Code" },
  },
  {
    titel: "Trainieren",
    text: "Deine Einstellung steht schon da. Du bestätigst nur deine Sätze.",
    bild: { src: "/landung/geraet.png", alt: "Der Geräte-Screen mit Einstellwerten und Satzrad" },
  },
  {
    // Beleg: Verlauf/ und Verlauf/HomeZiele.swift in der App.
    titel: "Weiterkommen",
    text: "Verlauf und Ziele zeigen dir, wo du stehst.",
    bild: { src: "/landung/verlauf.png", alt: "Der Verlauf eines Geräts mit den letzten Trainings" },
  },
];

export const CTA = {
  titel: "Probier es am nächsten Gerät.",
  // E3: kostenlos fuer Mitglieder, das Studio zahlt.
  text: "Die App ist kostenlos. Du brauchst nur ein Studio, das Gymtavo nutzt.",
  aktion: "App laden",
} as const;

export const VERLAUF = {
  titel: "Dein Fortschritt, ohne Rechnerei.",
  karten: [
    {
      titel: "Jedes Gerät mit Verlauf",
      text: "Was du an einem Gerät bestätigt hast, steht beim nächsten Mal wieder da.",
    },
    {
      titel: "Ziele, die du selbst setzt",
      text: "Du legst fest, worauf du hinarbeitest, und siehst, wo du stehst.",
    },
    {
      // Beleg: Kurse seit Phase 4 (designsystem.md 11), Text wie t/[token].
      titel: "Kurse am selben Ort",
      text: "Wochenplan, Anmeldung und Warteliste deines Studios in derselben App.",
    },
  ],
} as const;

export const PRODUKTGRENZE =
  "Gymtavo misst nichts. Angezeigt wird ausschließlich, was du selbst bestätigt hast. Einweisungsvideos und Einstellhinweise sind Inhalte deines Studios, keine Trainings- oder Gesundheitsempfehlung von Gymtavo.";

// "Wo liegen meine Daten?" fehlt bewusst, bis die Antwort belegt ist (Spec 5, [pruefen]).
export const FRAGEN: readonly Frage[] = [
  { frage: "Kostet die App etwas?", antwort: "Nein. Die App ist kostenlos, dein Studio nutzt Gymtavo." },
  {
    frage: "Brauche ich ein Studio mit Gymtavo?",
    antwort:
      "Ja. Einstellwerte und Einweisungen kommen von deinem Studio. Ist es noch nicht dabei, frag an der Theke nach.",
  },
  {
    frage: "Gibt es Gymtavo für Android?",
    antwort:
      "Die App gibt es zurzeit nur für iPhone. Die Einweisung am Gerät öffnet sich aber auf jedem Handy, auch ohne App.",
  },
  { frage: "Was misst Gymtavo?", antwort: PRODUKTGRENZE },
  {
    // E1: Sensor nur als Antwort, ohne Termin und ohne Formular.
    frage: "Wann kommt der Sensor?",
    antwort: "Er ist in Entwicklung. Einen Termin nennen wir erst, wenn er feststeht.",
  },
];

export const KAUFLEISTE = {
  titel: MARKE,
  merkmale: ["Tap am Gerät", "Deine Werte", "Für iPhone"],
  aktion: "App laden",
} as const;
```

- [ ] **Schritt 4: Startseite**

```tsx
// apps/web/app/landung/Startseite.tsx
import { APP_STORE_URL } from "@/lib/appStore";
import aktion from "./Aktion.module.css";
import { Fragen } from "./Fragen";
import { Fuss } from "./Fuss";
import { Held } from "./Held";
import { Kaufleiste } from "./Kaufleiste";
import { Kopf } from "./Kopf";
import { Laufband } from "./Laufband";
import { OhneMit } from "./OhneMit";
import { Schritte } from "./Schritte";
import styles from "./Startseite.module.css";
import {
  CTA,
  FAKTEN,
  FRAGEN,
  HELD,
  KAUFLEISTE,
  MARKE,
  OHNE_MIT,
  PRODUKTGRENZE,
  SCHRITTE,
  SCHRITTE_TITEL,
  VERLAUF,
} from "./texte";

// Masse der Screenshots aus Aufgabe 9 (750 px breit).
const BILD = { width: 750, height: 1630 };

/**
 * Reihenfolge nach Gpath (Spec 1.1): Problem, Beweis, Problem erlebbar,
 * Muehelosigkeit, Kauf, Zusatznutzen, Einwaende. Flaechen wechseln bg und
 * surface (E2). Ohne Verkauf, ohne Sensor, ohne Studio-Bruecke (Etappe 1).
 */
export function Startseite() {
  return (
    <div className={styles.startseite}>
      <Kopf />
      <main>
        <Held
          titel={HELD.titel}
          vorspann={HELD.vorspann}
          aktion={{ href: APP_STORE_URL, text: HELD.aktion }}
          nebenlink={{ href: "#so-gehts", text: HELD.nebenlink }}
          bild={{ ...HELD.bild, ...BILD }}
        />
        <Laufband eintraege={FAKTEN} />
        <OhneMit titel={OHNE_MIT.titel} marke={MARKE} ohne={OHNE_MIT.ohne} mit={OHNE_MIT.mit} />
        <Schritte id="so-gehts" titel={SCHRITTE_TITEL} schritte={SCHRITTE} bildmasse={BILD} />
        <section id="landung-cta" className={styles.cta} aria-labelledby="landung-cta-titel">
          <h2 id="landung-cta-titel" className={styles.ctaTitel}>
            {CTA.titel}
          </h2>
          <p className={styles.ctaText}>{CTA.text}</p>
          <a href={APP_STORE_URL} className={aktion.hauptaktion}>
            {CTA.aktion}
          </a>
        </section>
        <section className={styles.verlauf} aria-labelledby="verlauf-titel">
          <h2 id="verlauf-titel" className={styles.abschnittTitel}>
            {VERLAUF.titel}
          </h2>
          <ul className={styles.karten}>
            {VERLAUF.karten.map((k) => (
              <li key={k.titel} className={styles.karte}>
                <h3 className={styles.karteTitel}>{k.titel}</h3>
                <p className={styles.karteText}>{k.text}</p>
              </li>
            ))}
          </ul>
        </section>
        <Fragen id="fragen" titel="Fragen" fragen={FRAGEN} />
      </main>
      <Fuss id="landung-fuss" produktgrenze={PRODUKTGRENZE} />
      <Kaufleiste
        anker="held-aktion"
        verdecker={["landung-cta", "landung-fuss"]}
        titel={KAUFLEISTE.titel}
        merkmale={KAUFLEISTE.merkmale}
        aktion={{ href: APP_STORE_URL, text: KAUFLEISTE.aktion }}
      />
    </div>
  );
}
```

Wenn die Screenshots aus Aufgabe 9 eine andere Höhe haben, `BILD.height` auf den gemessenen Wert setzen.

```css
/* apps/web/app/landung/Startseite.module.css */
/* Die Landeseite ist weder Einstieg noch Schreibtisch (frueher
   einstieg/landeseite.module.css): eigener Satz, eigene Bausteine unter
   landung/. --kopf-hoehe = 8 px Abstand + 54 px Pille (Kopf.module.css);
   Held und Kaufleiste rechnen damit. */
.startseite {
  --kopf-hoehe: 62px;
  min-height: 100dvh;
  background: var(--bg);
}

/* Sprungziele landen unter dem Kopf, nicht hinter ihm. */
.startseite section[id] {
  scroll-margin-top: var(--kopf-hoehe);
}

.cta {
  padding: var(--s48) 20px;
  max-width: 760px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: var(--s16);
}

.ctaTitel,
.abschnittTitel {
  font-size: 32px;
  line-height: 1.1;
  font-weight: 800;
  letter-spacing: -0.03em;
  margin: 0;
}

.ctaText {
  color: var(--text-muted);
  font-size: 17px;
  line-height: 1.5;
  margin: 0 0 var(--s8);
}

.verlauf {
  background: var(--surface);
  padding: var(--s48) 20px;
}

.verlauf > * {
  max-width: 1080px;
  margin-inline: auto;
}

.karten {
  list-style: none;
  padding: 0;
  margin-top: var(--s24);
  display: grid;
  gap: var(--s16);
}

.karte {
  background: var(--bg);
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: var(--s20);
}

.karteTitel {
  margin: 0;
  font-size: 20px;
  font-weight: 800;
  letter-spacing: -0.02em;
}

.karteText {
  margin: var(--s8) 0 0;
  color: var(--text-muted);
  font-size: 16px;
  line-height: 1.5;
}

@media (max-width: 480px) {
  .cta > a {
    width: 100%;
  }
}

@media (min-width: 750px) {
  .karten {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }
}
```

- [ ] **Schritt 5: `page.tsx` umstellen.** Den ganzen `if (!user) { return ( <div className={styles.bildschirm}> … </div> ); }`-Block ersetzen durch:

```tsx
  // Ohne Sitzung: die Landeseite fuer Mitglieder (Spec 2026-10-03, Etappe 1).
  // Bis dahin stand hier die Trainer-Landung aus Start.dc.html mit dem Satz
  // "im Web gibt es nichts fuer dich zu tun" -- der faellt weg, weil die
  // Seite jetzt Mitglieder anspricht. Trainer finden Anmelden im Kopf.
  if (!user) return <Startseite />;
```

Den Kommentarblock „Bis zum 3. September stand hier nur …“ darüber entfernen, weil der neue Kommentar ihn ersetzt. Imports: `import { Startseite } from "./landung/Startseite";` dazu. `Link`, `GymtavoWordmark` und `styles from "./einstieg/landeseite.module.css"` entfernen, falls sie danach unbenutzt sind (`pnpm typecheck` meldet sie nicht, also mit `grep -n "Link\|GymtavoWordmark\|styles\." apps/web/app/page.tsx` prüfen). Dann `git rm apps/web/app/einstieg/landeseite.module.css` und vorher mit `grep -rn "landeseite.module" apps/web` sicherstellen, dass niemand sonst sie importiert.

- [ ] **Schritt 6: Unit-Tests, Typen, e2e**

```bash
pnpm --filter @fitretro/web exec vitest run
pnpm typecheck
E2E_PORT=3007 pnpm test:e2e e2e/wurzel.spec.ts e2e/landung.spec.ts e2e/einstieg.spec.ts
```
Expected: alles PASS. Wenn „Hoechstens eine Akzentflaeche“ an `landung-cta` scheitert: Die Kaufleiste weicht der CTA nicht. Dann den Verdecker-IO in `Kaufleiste.tsx` prüfen, nicht den Test lockern.

- [ ] **Schritt 7: Commit**

```bash
git add apps/web/app/landung apps/web/app/page.tsx e2e/helpers/abnahme.ts e2e/wurzel.spec.ts e2e/landung.spec.ts
git commit -m "feat(landung): / ohne Sitzung zeigt die neue Landeseite fuer Mitglieder

Startseite aus den Bausteinen, Texte mit Belegen, akzentflaechen je
Viewport, wurzel.spec fuer die Seite ohne Konto neu und landung.spec fuer
Ohne/Mit. Die alte Trainer-Landung und ihr Stylesheet entfallen.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 11: Kaufleiste im echten Browser

**Files:**
- Create: `e2e/kaufleiste.spec.ts`

**Interfaces:**
- Consumes: Seite aus Aufgabe 10, Ids `held-aktion`, `landung-cta`, `landung-fuss`.

- [ ] **Schritt 1: Test schreiben**

```ts
// e2e/kaufleiste.spec.ts
import { expect, test, type Page } from "@playwright/test";

/**
 * Spec 7.3 und 7.6. Die Zustandstabelle prueft kaufleiste.logik.test.ts;
 * hier geht es darum, dass Observer, Scroll und CSS im echten Browser
 * dasselbe tun.
 */
test.use({ viewport: { width: 390, height: 844 } });

// Per Locator statt getByRole: versteckt ist die Leiste aria-hidden und
// faellt damit aus dem Rollenbaum.
const leiste = (page: Page) => page.locator('aside[aria-label="Schnellzugriff"]');

async function nach(page: Page, y: number) {
  await page.evaluate((y) => window.scrollTo(0, y), y);
}

async function ankerUnterkante(page: Page) {
  return await page.locator("#held-aktion").evaluate((el) => el.getBoundingClientRect().bottom + window.scrollY);
}

test("versteckt beim Laden, erscheint hinter dem Hero-Knopf", async ({ page }) => {
  await page.goto("/");
  await expect(leiste(page)).toHaveAttribute("aria-hidden", "true");
  await expect(leiste(page)).not.toBeInViewport();
  await nach(page, (await ankerUnterkante(page)) - 62 + 10);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
  await expect(leiste(page)).toBeInViewport();
});

test("weicht beim Runterscrollen, kommt beim Hochscrollen", async ({ page }) => {
  await page.goto("/");
  const start = (await ankerUnterkante(page)) - 62 + 10;
  await nach(page, start);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
  await nach(page, start + 600);
  await expect(leiste(page)).not.toHaveAttribute("data-sichtbar", "");
  await nach(page, start + 500);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
});

test("weicht der CTA-Section und dem Fuss, auch beim Hochscrollen", async ({ page }) => {
  await page.goto("/");
  await nach(page, 100_000);
  await page.waitForTimeout(100);
  await page.evaluate(() => window.scrollBy(0, -40));
  await expect(leiste(page)).not.toHaveAttribute("data-sichtbar", "");

  const cta = await page.locator("#landung-cta").evaluate((el) => el.getBoundingClientRect().top + window.scrollY);
  await nach(page, cta + 200);
  await page.waitForTimeout(100);
  await nach(page, cta - 200);
  await expect(leiste(page)).not.toHaveAttribute("data-sichtbar", "");
});

test("versteckt nicht fokussierbar, sichtbar fokussierbar", async ({ page }) => {
  await page.goto("/");
  const link = leiste(page).getByRole("link", { name: "App laden", includeHidden: true });
  await link.focus();
  await expect(link).not.toBeFocused();

  await nach(page, (await ankerUnterkante(page)) - 62 + 10);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
  await link.focus();
  await expect(link).toBeFocused();

  // Der Fokus haelt die Leiste, auch wenn jetzt nach unten gescrollt wird.
  await page.evaluate(() => window.scrollBy(0, 600));
  await page.waitForTimeout(300);
  await expect(leiste(page)).toHaveAttribute("data-sichtbar", "");
});
```

- [ ] **Schritt 2: Laufen lassen**

Run: `E2E_PORT=3007 pnpm test:e2e e2e/kaufleiste.spec.ts`
Expected: PASS. Ein Fehlschlag heißt: Die Verdrahtung in `Kaufleiste.tsx` weicht von der Logik ab. Dort beheben.

- [ ] **Schritt 3: Commit**

```bash
git add e2e/kaufleiste.spec.ts
git commit -m "test(landung): Kaufleiste im Browser -- Anker, Richtung, Verdecker, Fokus

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
git log -1 --format=%B
```

---

### Aufgabe 12: Gesamtprüfung, Sichtprüfung, Spec fortschreiben

- [ ] **Schritt 1: Kompletter Testsatz** (Notiz zu den Commit-Konventionen)

```bash
pnpm typecheck
pnpm test
pnpm test:integration
E2E_PORT=3007 pnpm test:e2e
```
Expected: alles grün. Die iOS-Tests (`xcodebuild test …`) nur laufen lassen, wenn `git diff --stat feat/gymtavo-branding...HEAD -- apps/ios-member` etwas zeigt. Sonst im Bericht festhalten, dass sie entfallen und warum.

- [ ] **Schritt 2: Bewegung prüfen.** Den Skill `review-animations` auf den Diff von `apps/web/app/landung/` anwenden. Befunde mit Schwere „block“ beheben (eigener Commit `fix(landung): …`), den Rest an Tim berichten.

- [ ] **Schritt 3: Sichtprüfung im Browser** (`pnpm --filter @fitretro/web dev -p 3007`, Claude in Chrome oder Tims Browser, 390 × 844 und 1440 × 900):
  - Held: Text oben, Bild, Knopf unten, nichts springt beim Scrollen an.
  - Ohne/Mit: Pillen fliegen gestaffelt nach außen und kommen mitten im Flug sauber zurück. Einmal mit DevTools-Animationen auf 10 % abspielen.
  - Kaufleiste: Glas lesbar, Einblenden fühlt sich nicht träge an.
  - `prefers-reduced-motion` per DevTools emulieren: keine Bewegung, keine Information fehlt.
  - Safe Area: auf einem echten iPhone (Vercel-Preview) liegt die Kaufleiste über dem Home-Indikator. Chromium kann `env(safe-area-inset-bottom)` nicht emulieren, deshalb steht das nicht im e2e.

- [ ] **Schritt 4: Spec fortschreiben.** In `docs/superpowers/specs/2026-10-03-landeseite-neu-gpath-referenz.md` unter 7.7/1 „umgesetzt am …“ mit Verweis auf diesen Plan eintragen. Commit `docs(landeseite): Etappe 1 als umgesetzt vermerken`.

- [ ] **Schritt 5: Bericht an Tim.** Testergebnisse mit Zahlen, offene Punkte: App-Store-URL (`NEXT_PUBLIC_APP_STORE_URL` fehlt), Impressum/Datenschutz (Etappe 2, § 5 DDG), Videos (E6). Kein Push, kein PR ohne Freigabe.
