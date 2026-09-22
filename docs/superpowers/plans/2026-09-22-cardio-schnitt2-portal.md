# Cardio Schnitt 2: Portal — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Trainer legt im Portal ein Laufband an: Kategorie Cardio, Belastung km/h mit Rastung 0–20 in 0,5-Schritten, Nebenbelastung Neigung in % (0–15, Schritt 0,5), und eine Übung „Dauerlauf" mit 15–20 Minuten. Ein Kraftgerät legt er genau wie heute an: Kategorie und Belastung stehen auf Kraft/kg, die Nebenbelastung auf „keine", das Rad zeigt dieselben Werte. Die Geräteliste lässt sich nach Kraft und Cardio filtern.

**Architecture:** Kein neuer Screen. Zwei Bausteine werden ersetzt: `ModellGewichtRad` → `ModellBelastungRad` (Kategorie, Belastungseinheit, Rad mit Wertelisten je Einheit, aufklappbare Nebenbelastung), `UebungRepsRad` → `UebungUmfangRad` (Umfangsart, Rad mit Wertelisten je Art; Minuten werden als Minuten gewählt und als Sekunden gespeichert). Das Lesen der Formularfelder liegt in einem Modul `formfelder.ts`, das beide Server-Action-Dateien teilen. Die Wertelisten kommen aus `einstellungVorschlaege.ts` und leiten ihre Startwerte aus `defaultLoadRange`/`defaultTargetRange` der Domain ab. Der Filter in der Geräteliste ist ein `Reiter` mit `?kategorie=`.

**Tech Stack:** Next.js Server Actions, React-Client-Bausteine, Vitest mit jsdom (`apps/web`), Playwright (nicht ausführbar in dieser Umgebung).

**Quelle:** `docs/superpowers/specs/2026-09-21-cardio-geraete-design.md`, Abschnitt 7; Schnitt 1 in `2026-09-22-cardio-schnitt1-datenmodell-domain.md`.

## Global Constraints

- **Rad-Beschriftungen bleiben eindeutig je Seite.** Die E2E-Tests finden ein Rad über `getByRole("listbox", { name })` im strikten Modus; ein zweites „Minimum" auf derselben Seite bräche sie. Die Nebenbelastung heißt deshalb „Nebenbelastung ab / bis / Schritt", und sie ist nur sichtbar, wenn eine Einheit gewählt ist.
- **Kraft-Vorgaben unverändert.** Kategorie Kraft, Belastung kg, Rad 0 / kein Anschlag / 2,5, Übung Wiederholungen 8–12. Die bestehenden E2E-Tests (`trainerportal`, `einrichten`, `schreibtisch`) laufen ohne Änderung durch; der Text „Schritt 2,5 kg · ab 5,0 kg bis 100,0 kg" bleibt zusammenhängend.
- **Eigene Auswahl (`Auswahl`), kein natives `<select>`** (Trainer-Feedback, Auswahl.tsx). Jede Auswahl trägt ein Label über `htmlFor`.
- **Kommentare ohne Umlaute, Nutzertexte mit.** Ein Commit je Task, Trailer wie in Schnitt 1.
- **Tests:** `pnpm -F @fitretro/web test` und `pnpm typecheck` grün vor jedem Commit. E2E ist in dieser Umgebung nicht ausführbar (Container-Registries gesperrt); die Zusicherung ersetzt ein Komponententest je Baustein plus der Hinweis im Abschnitt „Stand".

---

## Task 1: Wertelisten und Formularfelder

**Files:**
- Modify: `apps/web/app/portal/bausteine/einstellungVorschlaege.ts` (`belastungsWerte(unit)`, `umfangWerte(kind)`, Optionen für Kategorie, Einheit, Nebenbelastung, Umfangsart)
- Create: `apps/web/app/portal/formfelder.ts` (`belastungAusFormular`, `umfangAusFormular`)
- Create: `apps/web/app/portal/formfelder.test.ts`

- [x] **Step 1:** Wertelisten je Einheit mit Startwerten aus `defaultLoadRange`; für `kg` exakt die bisherigen Listen und Startwerte.
- [x] **Step 2:** `formfelder.ts`: liest `category` (Vorgabe kraft), `loadUnit` (Vorgabe kg), Rad-Werte, `secondaryUnit` („" → keine Nebenbelastung, dann alle vier null), `volumeKind` (Vorgabe reps) und rechnet Minuten in Sekunden um. Tests dafür mit `FormData`.
- [x] **Step 3:** Commit `feat(portal): Wertelisten je Belastungseinheit und Umfangsart`.

## Task 2: `ModellBelastungRad`

**Files:**
- Create: `apps/web/app/portal/bausteine/ModellBelastungRad.tsx`, `ModellBelastungRad.test.tsx`
- Delete: `apps/web/app/portal/bausteine/ModellGewichtRad.tsx`
- Modify: `ModellAnlegenFormular.tsx`, `ModellNeuFormular.tsx`, `StammdatenFormular.tsx`, `portal/actions.ts`, `einrichten/actions.ts`

- [x] **Step 1:** Baustein: Auswahl „Kategorie", Auswahl „Belastung", Rad (`key={loadUnit}`, damit ein Einheitenwechsel die Startwerte der neuen Einheit lädt), Auswahl „Nebenbelastung" mit „keine", darunter bei Wahl das zweite Rad. Startwerte aus den Props (Stammdaten) oder den Vorgaben.
- [x] **Step 2:** Test: Vorgabe ist Kraft/kg mit den alten Werten; Wechsel auf km/h zeigt 0,5 als Schritt; Nebenbelastung „keine" rendert kein zweites Rad, „%" schon; versteckte Felder tragen die Namen.
- [x] **Step 3:** Formulare und Actions umstellen (`belastungAusFormular`).
- [x] **Step 4:** Commit `feat(portal): Modellformular mit Kategorie, Belastungseinheit und Nebenbelastung`.

## Task 3: `UebungUmfangRad`

**Files:**
- Create: `apps/web/app/portal/bausteine/UebungUmfangRad.tsx`, `UebungUmfangRad.test.tsx`
- Delete: `apps/web/app/portal/bausteine/UebungRepsRad.tsx`
- Modify: `UebungFormular.tsx`, `UebungSheet.tsx`, `portal/actions.ts`, `einrichten/actions.ts`

- [x] **Step 1:** Baustein: Auswahl „Umfang" (Wiederholungen / Minuten / Meter), Rad mit zwei Spalten, Beschriftung je Art („Wiederholungen ab" / „bis" wie bisher; „Minuten ab"; „Meter ab").
- [x] **Step 2:** Test: Vorgabe Wiederholungen 8–12; Minuten zeigt 15–20; versteckte Felder heißen `targetMin`/`targetMax`/`volumeKind`.
- [x] **Step 3:** Formulare und Actions (`umfangAusFormular`).
- [x] **Step 4:** Commit `feat(portal): Uebungsformular mit Umfangsart`.

## Task 4: Anzeige und Filter

**Files:**
- Modify: `(schreibtisch)/geraete/page.tsx` (Filter über `searchParams.kategorie`, Kategorie in der Zeile), `(schreibtisch)/geraete/[modelId]/layout.tsx` (Kategorie und Nebenbelastung im Vorspann), `einrichten/modell/page.tsx` (Kategorie im Meta)

- [x] **Step 1:** Filter als `Reiter` „Alle / Kraft / Cardio" oberhalb der Liste; ohne Parameter „Alle".
- [x] **Step 2:** Vorspann des Modells: „Cardio · Technogym · Schritt 0,5 km/h · ab 0,0 km/h bis 20,0 km/h · Neigung 0,0–15,0 %, Schritt 0,5 %".
- [x] **Step 3:** Commit `feat(portal): Kategorie in Liste, Filter und Modellkopf`.

## Task 5: Plan- und Spec-Stand

- [x] Abschnitt „Stand" hier, Verweis in der Spec (Abschnitt 14).

## Stand nach der Umsetzung (22. September)

- Web-Unit-Tests: 106 grün (vorher 95), neu `formfelder` (8), `ModellBelastungRad` (4), `UebungUmfangRad` (3). `pnpm typecheck` grün.
- **Nicht ausgeführt:** `pnpm test:integration` und `pnpm test:e2e`. In der Cloud-Umgebung dieser Session lässt sich Docker zwar starten, aber die Netzwerkrichtlinie weist die Image-Downloads aller drei Registries (Docker Hub, ECR, GHCR) mit 403 ab; ohne Images kein `supabase start`. Beides gehört in den ersten lokalen Lauf: `supabase db reset && pnpm test:integration && pnpm test:e2e`. Die bestehenden E2E-Schritte wurden gegen die geänderten Texte und Rad-Beschriftungen gegengelesen (Substring-Matches, Beschriftungen unverändert).
- Deploy-Hinweis aus Schnitt 1 gilt weiter: Datenbank, API und Portal gehen zusammen mit Schnitt 3 (iOS) live.

## Was dieser Schnitt NICHT tut

- Keine iOS-Änderung (Schnitt 3).
- Kein neues Artboard; die Auswahlfelder folgen `EinstellungFormular` (Art-Auswahl).
- Keine E2E-Erweiterung für den Cardio-Pfad, weil sie hier nicht ausführbar wäre. Sie gehört in den ersten Lauf mit lokalem Supabase.
