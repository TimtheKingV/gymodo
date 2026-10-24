# Trainingsplan Etappe 1 – Voraussetzungen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Progression rechnet je Training statt je UTC-Kalendertag, ignoriert Aufwärmsätze und bekommt wieder eine Reserve – über eine einzige Frage am Ende jeder Übung.

**Architecture:** `toBlocks` gruppiert nach `session_id`; `workout_sets` bekommt eine Satzrolle (`arbeit`/`aufwaermen`), die Regel-Abfragen lesen nur Arbeitssätze. In iOS erscheint auf dem „Sätze geschafft“-Screen eine Reserve-Skala; die Antwort schickt den letzten Satz mit gleicher Kennung und `rir` erneut (idempotenter PUT). Der vorhandene Regelpfad `rir >= 1` in `progression.ts` greift damit wieder.

**Tech Stack:** TypeScript/vitest (`packages/domain`, `tests/integration`), Supabase-Migrationen (SQL), Next.js API (`apps/web`), SwiftUI/Swift Testing (`apps/ios-member`), xcodegen.

**Spec:** `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` (Abschnitte „Befunde, die vorher zu beheben sind“, 6 „Reserve-Abfrage“, 7 „Satzrolle“ und „Blöcke je Session“)

## Etappen des Gesamtprojekts

Dieses Dokument plant nur Etappe 1. Jede weitere Etappe bekommt einen eigenen Plan, wenn sie beginnt, weil sie auf den Erfahrungen der vorigen aufbaut.

| Etappe | Inhalt | Spec-Abschnitte |
|---|---|---|
| **1 – Voraussetzungen** (dieser Plan) | Blöcke je Session, Satzrolle, Reserve-Abfrage | Befunde, 6, 7 |
| 2 – Profil und Plan (Server) | Profilfelder, Einwilligung Beschwerden, Katalogfelder (Baustein, Typ, Bereiche, Planfreigabe), Plangenerator mit Zeitrechnung, Zielen, Fokus, Cardio, Planversionen, API | 1, 2, 3, 7, 8, F1, F9, F12, F14, F16, F19, F20 |
| 3 – Plan im Studio (iOS) | Screen-Design zuerst; Onboarding-Block „Dein Trainingsplan“, Planansicht, Ablaufstatus offline (F17), Tausch, Session ↔ Planeinheit | 1, 5, F2, F5, F6, F17 |
| 4 – Gewichte | Startschätzung, Übertragungskorrektur, Planziele in der Progression, grobe Stufen, Wiedereinstieg | 6, F4, F13, F18 |
| 5 – Erklärungen | „Warum dein Plan so aussieht“, Begründungssätze zu Vorschlägen | 4, F10 |

## Global Constraints

- Eigener Worktree unter `.claude/worktrees/` von `origin/master`; `.env` und `apps/ios-member/Config.xcconfig` hineinkopieren. Im Hauptverzeichnis arbeitet parallel `claude/mini-zirkel` – dort nichts auschecken oder ändern.
- **Erst beginnen, wenn `claude/mini-zirkel` nach master gemergt ist** (berührt `GeraetModel.swift`, `GeraetView.swift`, `TrainingRootView.swift`); sonst Task 4 auf dessen Stand rebasen.
- Migration heißt `0058_satzrolle.sql`. **Nicht auf Supabase-Prod anwenden ohne ausdrückliche Freigabe von Tim.**
- Nur eine Session baut iOS zur selben Zeit: vor jedem `xcodebuild` `pgrep -lx xcodebuild`. Nach neuen Swift-Dateien: `cd apps/ios-member && xcodegen generate`, `project.pbxproj` mitcommitten.
- Code-Kommentare ASCII (ae/oe/ue/ss) und nennen einen Grund; Markdown und UI-Texte mit echten Umlauten. Swift-Tests mit Swift Testing (`@Test`, `#expect`).
- Commits deutsch, Form `feat(domain): …` / `feat(ios): …` / `fix(…)` / `test(…)`, ein Commit je Task-Abschluss. Trailer exakt: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Altdaten bleiben unverändert gültig: alle bestehenden Sätze sind `arbeit`; `rir` bleibt nullable; `null` heißt „unbekannt“, nie 0.
- Freies Training verhält sich wie heute; die Reserve-Frage ist überspringbar und blockiert nichts.
- Nicht pushen, bis Tim es sagt.

## Review Focus

1. **Zwei Trainings am selben Tag an derselben Übung** (morgens 40 kg, abends 45 kg): zwei Blöcke, der Vorschlag beruht auf dem Abendblock; heute verschmelzen sie und liefern `daten_uneindeutig` (Task 1).
2. **Training über Mitternacht UTC** (Start 00:30 Berliner Zeit = 22:30 UTC Vortag, Sätze bis 01:15): ein Block, nicht zwei (Task 1).
3. **Reserve beantwortet, während der letzte Satz noch offline in der Warteschlange liegt:** beide PUTs gehen in Reihenfolge raus, am Ende steht `rir` am Satz, `rep_events`/`volume_source` sind nicht überschrieben (Task 4).
4. **Antwort ändern** (erst 2, dann 3 getippt) oder „Weiß nicht“ nach einer Zahl: der zuletzt gewählte Wert gilt; „Weiß nicht“ setzt `rir` wieder auf `null` (Task 4).
5. **Aufwärmsatz mit weniger Gewicht vor drei gleichen Arbeitssätzen:** Vorschlag wie ohne Aufwärmsatz, nicht `daten_uneindeutig` (Task 2, 3).

---

### Task 1: Blöcke je Session statt je UTC-Tag

**Files:**
- Modify: `packages/domain/src/progression.ts` (`SatzZeile`, `BlockInput`, `toBlocks`)
- Modify: `packages/domain/src/machine-context.ts:406` (Select um `session_id`), `:512-545` (`cardioHistorie` je Session)
- Modify: `packages/domain/src/abschluss.ts:455` (Select um `session_id`)
- Modify: `packages/domain/src/progress.ts:~138` (Punkte je Session)
- Test: `packages/domain/src/progression.test.ts`, `tests/integration/domain-machine-context.test.ts`, `tests/integration/domain-progress.test.ts`

**Interfaces:**
- Produces: `SatzZeile` hat zusätzlich `session_id: string`. `BlockInput` hat zusätzlich `sessionId: string`; `performedOn` bleibt das UTC-Datum des **ersten** Satzes im Block (Anzeige unverändert). `toBlocks(rows)` liefert Blöcke in der Reihenfolge des ersten Auftretens einer Session in den absteigend sortierten Zeilen (neuester Block zuerst), Sätze im Block chronologisch.

- [ ] **Step 1: Failing tests** in `progression.test.ts`, `describe("toBlocks")`:
  - `trennt zwei Sessions am selben Tag`: Zeilen (absteigend) `s2 18:00 45kg`, `s2 17:58 45kg`, `s1 08:00 40kg` → 2 Blöcke, `blocks[0].sessionId === "s2"` mit 2 Sätzen, `blocks[1].sessionId === "s1"`.
  - `haelt eine Session ueber Mitternacht UTC zusammen`: `s1 2026-10-21T23:10Z`, `s1 2026-10-21T22:40Z` → 1 Block, `performedOn === "2026-10-21"`.
  - `suggestNextLoad nimmt den juengeren Block desselben Tages`: Block s2 3×12 bei 45 kg (rir null), Block s1 3×12 bei 40 kg → `reasonCode` ist **nicht** `daten_uneindeutig`, `inputs.currentLoad === 45`.
  - Bestehenden Test `liest secondary_load mit…` um `session_id` ergänzen.
- [ ] **Step 2:** `pnpm --filter @fitretro/domain test -- progression` → FAIL (`sessionId` undefined / ein Block).
- [ ] **Step 3:** `toBlocks` gruppiert über `row.session_id` (Map behält Einfügereihenfolge). Kommentar am Typ: warum Session statt Tag (zwei Trainings am Tag, Mitternacht UTC).
- [ ] **Step 4:** Aufrufer: `session_id` in die Selects von `machine-context.ts:406` und `abschluss.ts:455`. `cardioHistorie` gruppiert ebenfalls je `session_id` (dafür `session_id` in deren `SetRow`-Select). `progress.ts`: Schlüssel der Punkte ist `session_id`, `performedOn` = Tag des ersten Satzes; Typen dort entsprechend.
- [ ] **Step 5:** `pnpm --filter @fitretro/domain test` → PASS; `pnpm test:integration -- domain-machine-context domain-progress domain-complete-session` → PASS (lokales Supabase muss laufen: `pnpm supabase start`). Einen Integrationsfall in `domain-machine-context.test.ts` ergänzen: zwei Sessions am selben Tag ergeben zwei Einträge in `history`.
- [ ] **Step 6: Commit** `fix(domain): Bloecke je Training statt je UTC-Tag`

---

### Task 2: Satzrolle in Datenbank und Satz-API

**Files:**
- Create: `supabase/migrations/0058_satzrolle.sql`
- Modify: `packages/domain/src/workout.ts` (Schema `~:93`, Upsert `~:442`, Select `~:456`, `toRecordedSet`)
- Test: `tests/integration/domain-record-set.test.ts`, `tests/integration/api-workout-sets.test.ts`

**Interfaces:**
- Produces: Postgres-Enum `public.set_role` mit `'arbeit'`, `'aufwaermen'`; Spalte `workout_sets.set_role public.set_role not null default 'arbeit'`. Request-Feld `setRole: "arbeit" | "aufwaermen"` (optional, Default `"arbeit"`) im PUT `…/sets/[setId]`; Antwort `RecordedSet.setRole`.

- [ ] **Step 1: Failing tests** in `domain-record-set.test.ts`:
  - `speichert setRole aufwaermen`: `recordSet` mit `setRole: "aufwaermen"` → Zeile hat `set_role === "aufwaermen"`, Rückgabe `setRole === "aufwaermen"`.
  - `ohne setRole ist der Satz ein Arbeitssatz`.
  - `ein erneuter PUT ohne setRole setzt die Rolle zurueck auf arbeit` (dokumentiert: der PUT ersetzt den ganzen Satz, wie bei `rir`).
  - In `api-workout-sets.test.ts`: `setRole: "kuehl"` → 400 `validation_failed`.
- [ ] **Step 2:** `pnpm test:integration -- domain-record-set api-workout-sets` → FAIL.
- [ ] **Step 3:** Migration `0058_satzrolle.sql`: Enum und Spalte wie oben, `comment on column` mit Grund (Aufwärmsätze machen Blöcke uneindeutig; Progression und spätere Muskelbilanz lesen nur `arbeit`). Bestehende Zeilen bekommen über den Default `arbeit`. `pnpm supabase db reset` lokal.
- [ ] **Step 4:** `workout.ts`: `setRole: z.enum(["arbeit", "aufwaermen"]).default("arbeit")`, Upsert `set_role: input.setRole`, Select und `toRecordedSet` um `set_role`/`setRole`.
- [ ] **Step 5:** Tests → PASS; `pnpm --filter @fitretro/domain test` → PASS.
- [ ] **Step 6: Commit** `feat(domain): Satzrolle Arbeit/Aufwaermen (Migration 0058)`

---

### Task 3: Regeln lesen nur Arbeitssätze

**Files:**
- Modify: `packages/domain/src/machine-context.ts:406-410` (Filter), `packages/domain/src/abschluss.ts:452-458` (Filter), `packages/domain/src/progress.ts` (Filter in der Satzabfrage)
- Test: `tests/integration/domain-machine-context.test.ts`, `tests/integration/domain-complete-session.test.ts`

**Interfaces:**
- Consumes: Spalte `workout_sets.set_role` (Task 2), `toBlocks` (Task 1).

- [ ] **Step 1: Failing tests:**
  - `domain-machine-context.test.ts` `ignoriert Aufwaermsaetze im Vorschlag`: eine Session mit 1×20 kg `aufwaermen` + 3×12 bei 40 kg `arbeit`, Vorsession 3×12 bei 40 kg → `suggestion.reasonCode !== "daten_uneindeutig"` und `suggestion.inputs.currentLoad === 40`; `history[0].volume` hat 3 Einträge.
  - `domain-complete-session.test.ts` `Abschlussvorschlag ignoriert Aufwaermsaetze`: gleiche Daten über `completeSession` → Vorschlag mit `currentLoad` 40.
- [ ] **Step 2:** Tests → FAIL (`daten_uneindeutig`).
- [ ] **Step 3:** In allen drei Abfragen `.eq("set_role", "arbeit")`; im Abschluss-Kommentar zu den 60 Zeilen je Block ergänzen, dass Aufwärmsätze nicht mitzählen. Den Kommentar in `progression.ts` über `withReserve` aktualisieren: Die App erfasst die Reserve wieder, einmal je Übung am letzten Satz (Trainingsplan-Spec Abschnitt 6).
- [ ] **Step 4:** Tests → PASS; komplette Domain- und Integrationstests grün.
- [ ] **Step 5: Commit** `feat(domain): Vorschlaege und Fortschritt nur aus Arbeitssaetzen`

---

### Task 4: Reserve-Abfrage am Ende einer Übung (iOS)

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/ReserveSkala.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift` (neue Methode, Kommentar an `rir: nil` `:172-178` anpassen)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (letzten Schreibvorgang merken, `reserveSetzen`)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`abschlussEntscheidung` `~:428`)
- Modify: `apps/ios-member/FitnessMember/Einstellungen.swift` (Merker „Reserve erklärt“)
- Test: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift`, `apps/ios-member/FitnessMemberTests/WorkoutSessionStoreTests.swift`

**Interfaces:**
- Consumes: PUT `…/sets/[setId]` mit `rir` (bestehend; der PUT ersetzt den ganzen Satz).
- Produces:
  - `enum Reserve: Equatable { case wert(Int) /* 0...5, 5 = "5+" */; case unbekannt }`
  - `WorkoutSessionStore.reserveSetzen(setId: UUID, rir: Double?)` – setzt `rir` am lokalen Satz der laufenden Session und speichert die Sessiondatei.
  - `GeraetModel.reserveSetzen(_ reserve: Reserve)` und `GeraetModel.reserve: Reserve?` (nil = noch nicht beantwortet; zurückgesetzt bei `uebungWechseln` und bei jedem neuen Satz).
  - `GeraetModel.zeigtReserveFrage: Bool` – true in Phase `.abschluss`, wenn nicht Cardio und `volumeKind == .reps`.
  - `ReserveSkala(auswahl: Reserve?, aendern: (Reserve) -> Void)`.

- [ ] **Step 1: Failing tests** in `GeraetModelTests.swift`:
  - `reserveSchicktLetztenSatzMitRirErneut`: drei Sätze sichern (Satzziel 3 → Phase `.abschluss`), `reserveSetzen(.wert(2))` → die Warteschlange enthält am Ende einen weiteren `PendingSetWrite` mit **derselben** `setId` wie der dritte Satz, `body.rir == 2`, und `volumeSource`, `volumeCounted`, `repEvents`, `performedAt` gleich dem ursprünglichen Body.
  - `fuenfPlusWirdFuenf`: `.wert(5)` → `body.rir == 5`.
  - `unbekanntNachZahlSetztNull`: erst `.wert(3)`, dann `.unbekannt` → letzter Write hat `rir == nil`; `.unbekannt` ohne vorherige Zahl erzeugt **keinen** Write.
  - `keineReserveFrageAmCardio`: Cardio-Station in `.abschluss` → `zeigtReserveFrage == false`.
  - `reserveWirdBeiNeuemSatzZurueckgesetzt`: `.wert(2)`, dann `weitererSatz()` und Satz sichern → `reserve == nil`.
  - In `WorkoutSessionStoreTests.swift` `reserveSetzenSchreibtInDieSessiondatei`: nach `reserveSetzen(setId:rir: 2)` liefert ein frisch geladener Store denselben Satz mit `rir == 2`.
- [ ] **Step 2:** `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FitnessMemberTests/GeraetModelTests -only-testing:FitnessMemberTests/WorkoutSessionStoreTests` → FAIL (Symbole fehlen).
- [ ] **Step 3:** `WorkoutSessionStore.reserveSetzen` und in `GeraetModel` den zuletzt eingereihten `PendingSetWrite` merken (`private var letzterWrite`); `reserveSetzen` kopiert ihn, setzt `body.rir` (`Double`), ruft `sessions.reserveSetzen` und `enqueue`. Gleicher Wert wie zuletzt gesendet → kein neuer Write.
- [ ] **Step 4:** Tests → PASS.
- [ ] **Step 5: UI.** `ReserveSkala`: Frage „Wie viele Wiederholungen wären im letzten Satz noch drin gewesen?“, eine Zeile mit `0`, `1`, `2`, `3`, `4`, `5+` und darunter ein Textknopf „Weiß nicht“. Ziele mindestens 44 pt; VoiceOver liest „Reserve 2 Wiederholungen, ausgewählt“. In `abschlussEntscheidung` ersetzt die Skala den `FertigRing`, wenn `zeigtReserveFrage`; die Knöpfe „Nächste Übung“ / „Weiterer Satz“ bleiben unten und unverändert, nichts wartet auf eine Antwort. Beim allerersten Erscheinen (Merker in `Einstellungen`, Schlüssel `reserveErklaert`) steht unter der Frage einmalig: „Gemeint sind saubere Wiederholungen mit demselben Gewicht, ohne Pause.“ Testnotiz-Kennung `geraet.reserve`. Neue Datei → `xcodegen generate`.
- [ ] **Step 6:** Komplette iOS-Tests: `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16'` → grün. Im Simulator einmal durchspielen: 3 Sätze, Skala erscheint, `2` tippen, „Nächste Übung“; ohne Antwort weiter geht ebenfalls.
- [ ] **Step 7: Commit** `feat(ios): Reserve-Frage am Ende jeder Uebung`

---

## Bewusst nicht in Etappe 1

- **Einen Satz in der App als Aufwärmsatz markieren.** Server und Regeln können es nach Task 2/3; die Bedienung gehört ins Screen-Design von Etappe 3 (dort ist der Aufwärmsatz der Planübung vorbelegt). Bis dahin senden iOS-Sätze keine `setRole` und sind Arbeitssätze.
- Muskelbilanz/Häufigkeit in iOS (`Haeufigkeit.swift`) auf Arbeitssätze umstellen – mit der Satzbilanz in Etappe 2.
- Reserve beim vorzeitigen „Übung abschließen“ aus der Eingabe heraus: dort keine Frage (bleibt `null`). Wer vor dem Satzziel aufhört, hat meist einen Grund, der nichts mit Reserve zu tun hat.

## Hinweis zur Vorgeschichte

Die Reserve-Eingabe je Satz wurde am 11.09. bewusst entfernt (`52a421a`, „Reserve raus“), weil sie jeden Satz verlangsamte. Diese Etappe bringt sie nicht pro Satz zurück, sondern als **eine** überspringbare Frage pro Übung auf dem Screen, der ohnehin wartet (Tims Entscheidung 6 in der Spec).
