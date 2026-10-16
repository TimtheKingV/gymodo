# Muskelmodell in der Übungsbeschreibung – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Einweisung einer Übung zeigt unter dem Video ein Muskelmodell (vorne und hinten), auf dem die angesprochenen Muskeln in der Akzentfarbe leuchten.

**Architecture:**
- **Server:** `exercises.muscles` (jsonb) hält je Übung `[{key, name, role}]`. `catalog:import` schreibt es aus `catalog/gymtavo.json`. Bootstrap und Gerätekontext liefern es als `muscles` aus.
- **Geometrie:** Die vier SVGs aus dem Muskelmodell (Revision 4) liegen als Quelle im Repo. Ein Skript erzeugt daraus `muskelmodell.json` (Pfaddaten je Muskel und Ansicht), das die App bündelt. Die App zeichnet die Pfade nativ mit SwiftUI, ohne SVG-Bibliothek und ohne WebView.
- **Anzeige:** `MuskelKarte` färbt je Muskel nach Rolle ein. Hauptmuskeln nehmen `DesignSystem.Color.accent`, unterstützende Muskeln drei abgestufte Töne, alle übrigen ein dunkles Grau.

**Tech Stack:** Postgres-Migration, TypeScript-Domain (Zod, Vitest), Next.js-Portal-API, SwiftUI (Swift Testing), ein Node-Skript für den Pfadexport.

**Spec:** `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md` (Abschnitt „Zusatzdaten …`muscles`“, Zeile ~199) und `docs/superpowers/specs/2026-08-30-designsystem.md`. Die Katalog-Spec sagt dort „Tabellen dafür und eine App-Anzeige sind eine eigene spätere Etappe“ und „Muskelkarten kommen nicht ins Repo“. Task 1 passt beide Sätze an.

## Global Constraints

- **Muskelschlüssel** sind die aus `catalog/gymtavo.json` (`pectorals`, `deltoid_anterior`, …). Die SVGs führen sie als `data-muscle`.
- **Rollen:** `primary` oder `secondary`. Mindestens ein `primary` je Übung (prüft `katalog-datei.ts` schon).
- **JSON-Schlüssel (API, App):** `muscles: [{ key, name, role }]`. Fehlt das Feld (alter Server, gespeicherter Bootstrap), gilt `[]`.
- **Farben** (hex, aus dem abgenommenen Entwurf):
  - Hauptmuskel `#D4FF3F` = `DesignSystem.Color.accent`
  - unterstützend, nach Reihenfolge in der Übung: `#A8CC2A`, `#819B2A`, `#5E7220` (ab dem vierten bleibt es `#5E7220`)
  - nicht angesprochene Muskeln `#383D47`
  - Körperfläche `#1A1D22`, Körper- und Detaillinie `#3A404A`, Muskelkante `#14161A`
- **Linienstärken:** Körper 2,3 · Detail 1,1 · Muskelkante 3,2 (in SVG-Einheiten, skaliert mit der Karte).
- **Texte:** Überschrift „Beanspruchte Muskeln“ im Label-Stil (11 pt, Heavy, Versalien, Tracking 1,5). Rollen „Hauptmuskel“ und „Unterstützend“. Unter dem Modell „Vorderseite“ und „Rückseite“.
- **Das Modell ist schematisch.** Es zeigt weder Aktivierungsstärke noch EMG. Das steht als Hinweis im Quellcode neben der Karte, nicht in der Oberfläche.
- **Lizenz:** Die Vektorbasis steht unter MIT (Copyright (c) 2022 ELABBASSI Hicham). `LICENSE.txt` liegt neben den SVG-Quellen und der Hinweis im erzeugten JSON.
- **Fachliche Freigabe der Grafiken ist offen** (README Rev. 4). Vor einem Release in den Store muss sie vorliegen. Der Plan liefert, gibt aber nichts frei.
- **Kommentare** deutsch wie im Umfeld, Bezeichner deutsch.
- **Auslieferung in dieser Reihenfolge:** Migration 0056 und `catalog:import` → Web → App. Jeder Schritt ist für sich rückwärtskompatibel (additives Feld mit Default).
- **Migrationen und Import gegen ein nicht-lokales Ziel führt nur Tim nach Freigabe aus.** Der Plan endet für diese Schritte bei „bereit“.

## Review Focus

- **Übung mit nur nicht darstellbaren Muskeln** (`deep_core`, in 11 Übungen): Die Karte zeigt kein leeres Modell, sondern die Legende ohne Bild oder gar nichts. Erwartet: kein Modell ohne Hervorhebung. Test in Task 5.
- **Unbekannter künftiger Muskelschlüssel** vom Server: Er bricht nichts und bleibt in der Legende, nur ohne Fläche. Test in Task 4 und 5.
- **Alter Server oder gespeicherter Bootstrap ohne `muscles`**: Decode gelingt, Karte entfällt. Test in Task 4.
- **Offline:** Die Einweisung zeigt die Karte aus dem Bootstrap, ohne Kontext. Test in Task 6.
- **Mehr als drei unterstützende Muskeln**: Der Farbverlauf bleibt am letzten Ton stehen, kein Absturz bei Index außerhalb. Test in Task 5.

---

### Task 1: Spezifikationen nachziehen

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md` (Abschnitt „Zusatzdaten“, `muscles`)
- Modify: `docs/superpowers/specs/2026-08-30-designsystem.md` (Tokens, neuer Abschnitt Muskelkarte)

**Interfaces:**
- Produces: die Farb- und Linienwerte aus „Global Constraints“ als Dokument, auf das `DesignSystem.swift` verweist.

- [ ] **Step 1: Katalog-Spec ändern.** Der Import schreibt `muscles` nach `exercises.muscles` (jsonb, `[{key,name,role}]`), Bootstrap und Kontext liefern sie, die App zeigt sie in der Einweisung. „Muskelkarten kommen nicht ins Repo“ wird zu: Die Vektorquellen liegen unter `assets/muskelmodell/`, die App zeichnet daraus nativ.
- [ ] **Step 2: Designsystem-Dokument** um die Muskelkarten-Tokens ergänzen (Farben, Linienstärken, Rollenstufen), wörtlich wie in „Global Constraints“.
- [ ] **Step 3: Commit** `docs(spec): Muskelmodell in der Einweisung`.

### Task 2: Migration `0056_exercise_muscles.sql`

**Files:**
- Create: `supabase/migrations/0056_exercise_muscles.sql`
- Test: `tests/integration/` (dort liegen die Migrationstests; Muster der Datei zu `0055` übernehmen)

**Interfaces:**
- Produces: Spalte `public.exercises.muscles jsonb not null default '[]'` mit Check, dass es ein Array ist.

- [ ] **Step 1: Failing test.** `exercises.muscles` ist nach der Migration ein leeres Array für eine bestehende Übung. Ein Objekt statt eines Arrays wird abgelehnt (`check (jsonb_typeof(muscles) = 'array')`).
- [ ] **Step 2: Test laufen lassen, Erwartung: FAIL** (Spalte fehlt). Befehl wie im Test-README, gegen die lokale Datenbank.
- [ ] **Step 3: Migration schreiben.** Eine `alter table … add column`-Zeile mit Check und einem Kommentar „(Katalog-Import schreibt, Spec Zusatzdaten)“.
- [ ] **Step 4: Test grün.** Außerdem `node scripts/smoke-migrations.mjs` (prüft Migrationen).
- [ ] **Step 5: Commit** `feat(db): 0056 exercises.muscles`.

### Task 3: Katalog-Import schreibt die Muskeln

**Files:**
- Modify: `packages/domain/src/katalog-plan.ts` (`UebungZeile`, `UEBUNG_FELDER`, Zeile ~235)
- Modify: `packages/domain/src/katalog-import.ts` (Ist-Select Zeile ~91, Upsert)
- Test: `packages/domain/src/katalog-plan.test.ts`

**Interfaces:**
- Consumes: `KatalogDatei.exercises[].muscles` (`{muscle, role}`) und `KatalogDatei.muscles` (`{key, name}`).
- Produces: `UebungZeile.muscles: { key: string; name: string; role: "primary" | "secondary" }[]`, in der Reihenfolge der Katalogdatei.

- [ ] **Step 1: Failing tests** in `katalog-plan.test.ts`: (a) Übung mit `muscles` ergibt eine Zeile mit `muscles: [{key:"pectorals", name:"Brust", role:"primary"}, …]`; (b) Ist-Stand ohne Muskeln und Datei mit Muskeln ist „geändert“ mit Feld `muscles`; (c) gleicher Inhalt ist „unverändert“, auch wenn Postgres die Schlüssel in anderer Reihenfolge liefert (Vergleich nach Inhalt, nicht nach Text).
- [ ] **Step 2: Tests laufen lassen, Erwartung FAIL.** `pnpm vitest run packages/domain/src/katalog-plan.test.ts`
- [ ] **Step 3: Umsetzen.** `UebungZeile` bekommt `muscles`, `UEBUNG_FELDER` nimmt `"muscles"` auf, der Vergleich nutzt für dieses Feld einen tiefen Vergleich. Der Ist-Select und der Upsert führen `muscles` mit. Die Namen kommen aus `k.muscles`.
- [ ] **Step 4: Tests grün,** dazu `katalog-datei.test.ts` und `pnpm typecheck`.
- [ ] **Step 5: Trockenlauf** `pnpm catalog:import --dry-run` gegen die lokale Datenbank. Erwartung: 162 Übungen „geändert“, Feld `muscles`. Gegen Produktion nur durch Tim.
- [ ] **Step 6: Commit** `feat(katalog): Import schreibt Muskeln je Übung`.

### Task 4: Bootstrap und Gerätekontext liefern `muscles`

**Files:**
- Modify: `packages/domain/src/bootstrap.ts` (Select Zeile ~418, Zeilentyp ~189–209)
- Modify: `packages/domain/src/machine-context.ts` (Select ~293, Typ ~230, Abbildung ~319)
- Test: `packages/domain/src/bootstrap.test.ts`, Test zu `machine-context` (gleicher Ordner)

**Interfaces:**
- Produces: In beiden Antworten trägt jede Übung `muscles: { key: string; name: string; role: "primary" | "secondary" }[]`, nie `null`, bei fehlender Spalte `[]`.

- [ ] **Step 1: Failing tests:** Bootstrap-Übung mit `muscles` in der Datenbankzeile erscheint unverändert in der Antwort. Eine Zeile ohne Wert (`null`/fehlend) ergibt `[]`. Gleiches im Gerätekontext.
- [ ] **Step 2: Erwartung FAIL.** `pnpm vitest run packages/domain/src/bootstrap.test.ts`
- [ ] **Step 3: Select-Strings und Abbildungen** um `muscles` erweitern, mit `?? []`. Die Zod-Form der Antwort (falls vorhanden) bekommt `muscles` mit Default `[]`.
- [ ] **Step 4: Tests grün,** dazu `pnpm typecheck` und die API-Tests unter `apps/web`.
- [ ] **Step 5: Commit** `feat(api): Bootstrap und Kontext liefern Muskeln`.

### Task 5: Geometrie und Zeichnen in der App

**Files:**
- Create: `assets/muskelmodell/` (die vier SVGs, `LICENSE.txt`, `README.md` der Revision 4)
- Create: `scripts/muskelmodell-json.mjs` (liest die SVGs, schreibt `muskelmodell.json`)
- Create: `apps/ios-member/FitnessMember/Resources/muskelmodell.json` (erzeugt, eingecheckt)
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/MuskelKarte.swift`
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/MuskelModell.swift` (Daten, Pfadparser, Farbwahl)
- Modify: `apps/ios-member/FitnessMember/DesignSystem/DesignSystem.swift` (Tokens), `apps/ios-member/project.yml` (Ressource), danach `xcodegen`
- Test: `apps/ios-member/FitnessMemberTests/MuskelModellTests.swift`

**Interfaces:**
- Produces (`MuskelModell.swift`):
  - `struct GeraetMuskel: Decodable, Hashable, Sendable { let key: String; let name: String; let role: Rolle }` mit `enum Rolle: String, Decodable { case primary, secondary }`.
  - `enum MuskelModell { static func pfad(_ d: String) -> Path }` – absolute Befehle `M`, `L`, `C`, `Z` (mehr kommen in den SVGs nicht vor).
  - `static func fuellung(fuer key: String, in muskeln: [GeraetMuskel]) -> Color?` – `nil` heißt „nicht angesprochen“.
  - `static func zeigtModell(_ muskeln: [GeraetMuskel]) -> Bool` – wahr, wenn mindestens ein Schlüssel eine Fläche im Modell hat.
- Produces (`MuskelKarte.swift`): `struct MuskelKarte: View { init(muskeln: [GeraetMuskel], geschlecht: Geschlecht?) }`.
- Das Skript legt je Ansicht ab: `viewBox`, Pfade `body`/`detail`, Muskelpfade `{ muscle, d, clip: [x,y,w,h]? }`. Die `clipPath`-Rechtecke der Schulter bleiben als `clip` erhalten, die App schneidet mit `Path.intersection`.

- [ ] **Step 1: Failing tests** in `MuskelModellTests.swift`:
  - `pfad("M 0,0 L 10,0 L 10,10 Z")` hat die Begrenzung `(0,0,10,10)`; ein `C`-Befehl endet am Zielpunkt.
  - `fuellung` für einen primären Muskel ist `DesignSystem.Color.accent`, für den ersten, zweiten, dritten und vierten unterstützenden `#A8CC2A`, `#819B2A`, `#5E7220`, `#5E7220` (**kein Absturz beim vierten**), für einen fehlenden `nil`.
  - `zeigtModell` ist falsch für `[deep_core]` und für `[]`, wahr für `[pectorals]`, wahr für `[deep_core, pectorals]`.
  - Jeder Muskelschlüssel aus `catalog/gymtavo.json`, der laut README darstellbar ist, hat eine Fläche in `muskelmodell.json` (Test liest beide Dateien aus dem Testbundle; erwartete Lücken: `deep_core`, `hip_flexors`, `neck`, `pelvic_floor`).
  - Ein unbekannter Schlüssel `zzz` in `muskeln` wirft nicht.
- [ ] **Step 2: Erwartung FAIL** (Typen fehlen). `xcodebuild test -scheme FitnessMember -only-testing:FitnessMemberTests/MuskelModellTests …` (Zielgerät wie im Repo üblich, siehe `clean-disk`-Skill bei Platzmangel).
- [ ] **Step 3: SVG-Quellen und Skript.** Die vier SVGs und die Lizenz nach `assets/muskelmodell/` kopieren. `muskelmodell-json.mjs` schreibt `muskelmodell.json` deterministisch (feste Reihenfolge, Koordinaten unverändert). Lizenztext als Feld `lizenz` im JSON.
- [ ] **Step 4: `MuskelModell.swift`** nach den Signaturen oben. Die Stufenfarben als `DesignSystem.Color.muskelNachrangig: [Color]`, die übrigen als `muskelInaktiv`, `muskelHaut`, `muskelLinie`, `muskelKante`.
- [ ] **Step 5: `MuskelKarte`.** Karte im Stil der Kacheln der App (`surface`, 1 pt `line`, Radius `haupt`), Kopfzeile im Label-Stil, beide Ansichten nebeneinander in einem `Canvas`, darunter „Vorderseite/Rückseite“, darunter je Muskel eine Zeile mit Punkt, Name, Rolle. Das Canvas ist für VoiceOver verborgen. Stattdessen trägt die Karte ein Label „Beanspruchte Muskeln: Brust, Hauptmuskel; Trizeps, unterstützend“. `Geschlecht.weiblich` wählt das weibliche Modell, sonst das männliche. Fällt `zeigtModell` falsch aus, rendert die Karte nichts (`EmptyView`).
- [ ] **Step 6: Tests grün.** Dazu ein `#Preview` mit Brustpresse und eine Sichtprüfung im Simulator gegen den Entwurf (https://claude.ai/artifact/4ceCjDnvEUCEXG5FeKsiZ6).
- [ ] **Step 7: Commit** `feat(ios): Muskelkarte aus Pfaddaten`.

### Task 6: DTOs und Einweisung

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/BootstrapResponse.swift` (`Exercise`, ~163)
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/TagContextResponse.swift` (`Exercise`, ~54)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (neben `beschreibung`, ~308)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/EinweisungSchritt.swift` (nach `medien`, vor der Beschreibung)
- Test: `apps/ios-member/FitnessMemberTests/DTOTests.swift`, `GeraetModel`-Tests im selben Ordner

**Interfaces:**
- Consumes: `GeraetMuskel`, `MuskelKarte` aus Task 5.
- Produces: `GeraetModel.muskeln: [GeraetMuskel]` – aus dem Kontext, sonst aus dem Bootstrap, wie `beschreibung`.

- [ ] **Step 1: Failing tests:** (a) Bootstrap-JSON mit `muscles` dekodiert zu `Exercise.muscles`; (b) JSON **ohne** das Feld dekodiert zu `[]` (alter Server, gespeicherter Bootstrap); (c) `GeraetModel.muskeln` ohne Kontext (offline) liefert die Muskeln aus dem Bootstrap; (d) mit Kontext hat dessen Liste Vorrang.
- [ ] **Step 2: Erwartung FAIL.**
- [ ] **Step 3: DTOs** bekommen `var muscles: [GeraetMuskel] = []` mit Default wie `description`, damit bestehende memberwise-Aufrufe gültig bleiben. `GeraetModel.muskeln` spiegelt `beschreibung`.
- [ ] **Step 4: `EinweisungSchritt`** zeigt `MuskelKarte(muskeln: modell.muskeln, geschlecht: …)` zwischen `medien` und der Beschreibung. Das Geschlecht kommt aus dem Profil, falls es dort vorliegt, sonst `nil`. Spacing `s24` wie im Umfeld.
- [ ] **Step 5: Tests grün,** gesamte App-Testsuite und der UI-/Accessibility-Baumtest (`AccessibilityBaumTests`).
- [ ] **Step 6: Sichtprüfung im Simulator:** Brustpresse, Kniebeuge, eine `deep_core`-Übung (keine Karte), Flugmodus (Karte bleibt).
- [ ] **Step 7: Commit** `feat(ios): Muskelkarte in der Einweisung`.

---

## Self-Review

- **Spec-Abdeckung:** Daten (Task 2–4), Geometrie und Darstellung (Task 5), Einbau unter dem Video (Task 6), Dokumente (Task 1). Das Geschlecht des Modells ist in Task 5 und 6 angelegt, die Auswahl ist ein Nebenpfad: Gibt es im Profil kein Geschlecht, bleibt es männlich.
- **Typen:** `GeraetMuskel` (Task 5) wird in Task 6 unverändert genutzt. `muscles` heißt auf dem Server und im JSON überall gleich.
- **Offen für Tim:** Gelten die Rollenfarben auch für die weibliche Ansicht gleich (angenommen ja)? Soll `Geschlecht` aus dem Profil wirklich das Modell steuern, oder bleibt vorerst nur das männliche?
- **Nicht im Plan:** Die Karte auf der Satzseite, in der Übungsauswahl oder im Verlauf. Eigene Etappe, falls gewünscht.
