# Wochenplan ohne feste Tage – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Plan-Tab zeigt die Woche als Ziel „N× Kraft, M× Cardio (X min)“ mit Haken statt fester Tage; Kalender zeigt nur Geleistetes und gebuchte Kurse; Home und Serie folgen.

**Architecture:** Server: Migration 0072 (Profil-Zähler, `cardio_checks` mit `id`), Domain liefert `wochenziel` im Bootstrap, Serie zählt Cardio-Haken und Kurse mit, Generator nimmt `kraftProWoche` (1.4.0). App: eine reine Funktion `PlanWochenRechnung.berechne` ersetzt `PlanKalender` (Slots, verpasst, verschoben) und speist Plan-Tab, Monat und Home.

**Tech Stack:** TypeScript (pnpm/turbo, Vitest, zod), Supabase Postgres, Next.js API (`apps/web/app/api/v1`), SwiftUI iOS 26 (Swift Testing, xcodegen).

**Spec:** `docs/superpowers/specs/2026-11-11-wochenplan-ohne-tage-design.md` (lesen, bevor eine Aufgabe beginnt; §-Verweise unten zeigen dorthin).

## Global Constraints

- Woche Mo–So in der Zeitzone des Studios (`PlanKalenderKontext.zeitzone`, Server `zeitzoneDesStudios`).
- Kein „verpasst“, kein Übertrag, keine roten/gestrichelten Versäumnis-Marken – nirgends.
- Wording: „Kraft“ statt „Einheiten“ im Plan; Filter `Alle / Kraft / Kurse / Cardio`; Knopf „Woche anpassen“; Hinweis „Du legst fest, wie oft – nicht wann. Montag beginnt die Woche neu.“; offene Cardio-Karte Untertitel „zählt auch nach dem Krafttraining“.
- Wertebereiche: `kraft_pro_woche` 1–7 (null erlaubt), `cardio_pro_woche` 0–7 (Default 0), `cardio_minuten` 10–180 (Default 30; App-Zähler 10–90 in 5er-Schritten).
- `PLAN_REGEL_VERSION = "1.4.0"`.
- Tagesspalten `kurs_tage/cardio_tage/kraft_tage`, `training_plans.wochenraster` und die alten `PUT/DELETE ?day`-Wege bleiben funktionsfähig (alte App auf Prod).
- Prod-Migration und API-Deploy nur nach ausdrücklicher Freigabe durch Tim – nicht Teil dieses Plans.
- Debug-Build zeigt auf Prod: Simulatorprüfung nur mit Testkonto.
- Commits enden mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

**Befehle:**
- Domain: `pnpm --filter @fitretro/domain test -- <datei>`
- Integration (lokales Supabase, `supabase start`; bei I/O-Fehlern `colima restart`): `pnpm test:integration -- <datei>`
- Web-Typen: `pnpm --filter web typecheck` (bzw. `pnpm typecheck`)
- iOS: `cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite>` – immer die Zeile „Test run with N tests“ prüfen (falscher Filter meldet sonst Erfolg).

## Review Focus

1. **Montag 00:30 Studiozeit / Sonntag 23:30:** Ein Training So 23:30 gehört zur alten Woche, Mo 00:30 zur neuen – Haken und Marken springen genau dort (Test in Task 8).
2. **Zwei Trainings je 20 min Cardio bei Ziel 30 min:** kein Cardio-Haken; ein Training mit 2×15 min Cardio-Sätzen: ein Haken (Summe innerhalb einer Sitzung) (Task 8).
3. **Laufende, nicht beendete Sitzung:** kein Kraft-Haken, obwohl `erledigt[]` sie schon führt; nach Abschluss (auch Auto-Abschluss nach 4 h) Haken (Task 8).
4. **Profil ohne neue Felder (Bestandskonto, `kraft_pro_woche` null):** App zeigt das abgeleitete `wochenziel` vom Server, nie 0 Kraft-Karten (Tasks 4, 8).
5. **Vom Studio abgesagter Kurs / auf Warteliste:** erscheint weder als Kurs-Karte noch zählt er für die Serie (Tasks 5, 8).

---

### Task 1: Migration 0072 – Profil-Zähler und Cardio-Haken mit id

**Files:**
- Create: `supabase/migrations/0072_woche_ohne_tage.sql`
- Test: `tests/integration/plan-woche-ohne-tage.test.ts` (Muster: `tests/integration/plan-schreibwege.test.ts`)

**Interfaces:**
- Produces: Spalten `training_profiles.kraft_pro_woche smallint null`, `cardio_pro_woche smallint not null default 0`, `cardio_minuten smallint not null default 30`; `cardio_checks.id uuid` (PK), `cardio_checks.minuten smallint null`, Index `cardio_checks (user_id, day)`.

- [ ] **Step 1: Failing integration tests** in `plan-woche-ohne-tage.test.ts`:
  - `befuellt kraft_pro_woche aus kraft_tage`: Profil mit `kraft_tage {2,5}` vor der Migration → nach Migration `kraft_pro_woche = 2`. (Umsetzung: Testdatenbank wird mit allen Migrationen aufgebaut; die Befüllung als eigene SQL-Funktion-freie `update`-Anweisung testen, indem der Test dieselbe `update`-Anweisung aus der Migrationsdatei erneut ausführt – Konstante `BEFUELLEN_SQL` aus der Datei lesen, zwischen den Markern `-- befuellen:start` / `-- befuellen:end`.)
  - `befuellt aus dem wochenraster des aktiven Plans, wenn kraft_tage leer`: aktiver Plan mit `wochenraster` mit 3 `kraft`-Einträgen → `3`.
  - `laesst kraft_pro_woche null ohne Quelle`.
  - `cardio_pro_woche = cardinality(cardio_tage)`; `cardio_minuten = 30`.
  - `cardio_checks erlaubt zwei Zeilen am selben Tag` (Insert als Mitglied, beide sichtbar, `id` gesetzt).
  - `kraft_pro_woche 0 und 8 werden abgelehnt`; `cardio_minuten 9 und 181 abgelehnt`.
  - `Mitglied liest eigene course_bookings mit course_sessions.starts_at/status` (Select mit `course_sessions!inner(starts_at,status)` liefert die eigene Buchung, keine fremde).
- [ ] **Step 2:** `pnpm test:integration -- plan-woche-ohne-tage` → FAIL (Spalten fehlen).
- [ ] **Step 3:** Migration schreiben. Reihenfolge: Spalten mit Checks; Befüllblock zwischen den Markern (Quelle: `cardinality(kraft_tage)` > 0, sonst `jsonb_array_length` der `kraft`-Einträge im `wochenraster` des Plans mit `status = 'aktiv'` desselben Users (bei mehreren Studios: größter Wert), sonst null); `cardio_checks`: `add column id uuid not null default gen_random_uuid()`, `drop constraint cardio_checks_pkey`, `add primary key (id)`, `create index on cardio_checks (user_id, day)`, `add column minuten smallint check (minuten between 1 and 600)`. Rechte wie 0071 (kein update). Falls der Course-Booking-Test rot bleibt, weil `course_sessions`-RLS den Join verhindert: Lesefunktion `my_course_starts(p_bis timestamptz) returns setof timestamptz` (security invoker reicht, wenn die Policies es erlauben; sonst definer mit `user_id = auth.uid()`), Rechte nur `authenticated`.
- [ ] **Step 4:** `pnpm test:integration -- plan-woche-ohne-tage` → PASS; außerdem `api-cardio-checks` und `api-training-profile` weiter grün.
- [ ] **Step 5:** Commit `feat(db): 0072 Wochenziel-Zaehler im Profil, Cardio-Haken mit id`.

### Task 2: Profil mit Zählern und `weekly_days`-Abgleich

**Files:**
- Modify: `packages/domain/src/trainingsprofil.ts`
- Test: `packages/domain/src/trainingsprofil.test.ts`, `tests/integration/api-training-profile.test.ts`

**Interfaces:**
- Produces: `TrainingProfile` erhält `kraftProWoche: number | null; cardioProWoche: number; cardioMinuten: number`. JSON (GET/PUT `me/training-profile`) gleiche Namen. `saveTrainingProfile` setzt bei gesendetem `kraftProWoche` das Ziel `weekly_days` auf `min(7, kraftProWoche + cardioProWoche)` über `setGoal`.

- [ ] **Step 1: Failing unit tests** (`trainingsprofil.test.ts`):
  - `pruefeTrainingsprofil` akzeptiert `{…basis, kraftProWoche: 2, cardioProWoche: 1, cardioMinuten: 30}` und liefert die Werte.
  - lehnt `kraftProWoche: 0`, `8`, `1.5`; `cardioProWoche: -1`, `8`; `cardioMinuten: 9`, `181` mit `validation_failed` ab.
  - fehlende neue Felder → `kraftProWoche: null, cardioProWoche: 0, cardioMinuten: 30`.
  - Tagesfelder ohne neue Felder laufen weiter durch `pruefeWoche` (bestehende Tests bleiben grün).
- [ ] **Step 2: Failing integration tests** (`api-training-profile.test.ts`): PUT mit `kraftProWoche: 3, cardioProWoche: 1` → GET liefert beide; aktives `weekly_days`-Ziel ist `4`; PUT nur mit `minutes` lässt die Zähler unverändert; PUT mit `kraftProWoche: 6, cardioProWoche: 3` → Ziel `7`.
- [ ] **Step 3: Run** `pnpm --filter @fitretro/domain test -- trainingsprofil` und `pnpm test:integration -- api-training-profile` → FAIL.
- [ ] **Step 4: Implement:** Schema um drei optionale Felder (int, Bereiche wie Global Constraints); `getTrainingProfile` liest die drei Spalten; `saveTrainingProfile` merged wie die Tagesfelder (fehlend = unverändert), upsert nur gesendete Spalten; danach `setGoal(client, {kind: "weekly_days", targetValue})` wenn `kraftProWoche` gesendet.
- [ ] **Step 5:** beide Läufe PASS; `pnpm typecheck` grün.
- [ ] **Step 6:** Commit `feat(plan): Wochenziel als Zaehler im Trainingsprofil`.

### Task 3: Cardio-Haken mehrfach pro Tag (Domain + API)

**Files:**
- Modify: `packages/domain/src/cardio-checks.ts`, `apps/web/app/api/v1/me/cardio-checks/route.ts`
- Test: `packages/domain/src/cardio-checks.test.ts`, `tests/integration/api-cardio-checks.test.ts`

**Interfaces:**
- Produces (Domain): `type CardioCheck = { id: string; day: string; minuten: number | null }`; `addCardioCheck(client, userId, day: string, heute: string, minuten?: number): Promise<CardioCheck>`; `deleteCardioCheckById(client, userId, id: string): Promise<void>`; `listCardioCheckEintraege(client, userId, von, bis): Promise<CardioCheck[]>` (aufsteigend nach day, created_at). `setCardioCheck` (alt) legt nur an, wenn der Tag noch keine Zeile hat; `deleteCardioCheck` (alt) löscht alle Zeilen des Tags; `listCardioChecks` (alt) liefert eindeutige Tage.
- Produces (API): `GET ?from&to` → `{checks: CardioCheck[], days: string[]}`; `POST` Body `{day, minuten?}` → 201 `CardioCheck`; `DELETE ?id` → 204; `PUT ?day`/`DELETE ?day` wie bisher.

- [ ] **Step 1: Failing unit tests:** `addCardioCheck` lehnt Zukunftstag ab (wie `setCardioCheck`), lehnt `minuten: 0` und `601` ab; `deleteCardioCheckById` lehnt Nicht-UUID mit `validation_failed` ab.
- [ ] **Step 2: Failing integration tests:** zwei POST am selben Tag → GET `checks.length === 2`, `days` = `[tag]`; DELETE `?id` entfernt genau einen; altes PUT `?day` auf einen Tag mit vorhandenem Haken legt keinen zweiten an; altes DELETE `?day` entfernt beide; fremde id löschen → 204, eigene Zeile bleibt.
- [ ] **Step 3:** Läufe → FAIL.
- [ ] **Step 4:** Implementieren (Supabase `insert(...).select("id, day, minuten").single()`; altes `setCardioCheck` per Vorabprüfung `select id … limit 1` oder `insert … where not exists` über RPC-freie zwei Schritte – Rennen unkritisch).
- [ ] **Step 5:** PASS; Commit `feat(plan): mehrere Cardio-Haken pro Tag, Abhaken per id`.

### Task 4: `wochenziel` im Bootstrap

**Files:**
- Create: `packages/domain/src/wochenziel.ts`
- Modify: `packages/domain/src/bootstrap.ts` (Typ `member` + Zusammenbau um Zeile ~696), `packages/domain/src/index.ts` (Export)
- Test: `packages/domain/src/wochenziel.test.ts`, `tests/integration/domain-bootstrap.test.ts`

**Interfaces:**
- Produces: `type Wochenziel = { kraft: number; cardio: number; cardioMinuten: number }`; `berechneWochenziel(profil: TrainingProfile | null, weeklyDays: number | null, planTage: number | null): Wochenziel`; Bootstrap `member.wochenziel: Wochenziel`.

- [ ] **Step 1: Failing tests** (`wochenziel.test.ts`):
  - Profil `kraftProWoche 3, cardioProWoche 1, cardioMinuten 45` → `{kraft: 3, cardio: 1, cardioMinuten: 45}`.
  - `kraftProWoche null`, `planTage 4` → `kraft 4`; ohne Plan, `weeklyDays 2` → `2`; alles null → `2`; Profil null → `{kraft: 2 bzw. Fallback, cardio: 0, cardioMinuten: 30}`.
  - Ergebnis `kraft` immer 1…7 (planTage 9 → 7).
- [ ] **Step 2:** Integration (`domain-bootstrap.test.ts`): Bootstrap eines Mitglieds mit Profil `kraftProWoche 2, cardioProWoche 1` enthält `member.wochenziel = {kraft: 2, cardio: 1, cardioMinuten: 30}`.
- [ ] **Step 3:** FAIL → implementieren (`planTage` = `eingabe.tage` des ersten aktiven Plans aus `plans`, falls Zahl) → PASS.
- [ ] **Step 4:** Commit `feat(plan): Wochenziel im Bootstrap`.

### Task 5: Serie zählt Cardio-Haken und Kurse

**Files:**
- Modify: `packages/domain/src/sessions.ts` (`serienstand`, `getSessions`)
- Test: `packages/domain/src/serie.test.ts` (oder `sessions.test.ts`, wo `serienstand` heute getestet wird), `tests/integration/domain-sessions.test.ts`

**Interfaces:**
- Produces: `serienstand(startsAt: string[], jetzt: Date, zeitzone: string, weitereTage: string[] = []): Serienstand` – `weitereTage` sind Ortsdaten `YYYY-MM-DD`, behandelt wie Trainingstage. Kursbeginne gehen als Zeitpunkte in `startsAt` ein.

- [ ] **Step 1: Failing unit tests:**
  - Vorwoche nur Cardio-Haken (`weitereTage`), diese Woche Training → `weeks 2`.
  - Woche nur mit Kursbeginn (in `startsAt`) zählt.
  - `weitereTage` in der Zukunft verlängert nichts; `trainedDays` enthält Cardio-Tag dieser Woche.
- [ ] **Step 2: Failing integration test:** Mitglied mit Cardio-Haken letzte Woche, gebuchtem und begonnenem Kurs vorletzte Woche, Training diese Woche → `streak.weeks === 3`; zusätzlich ein vom Studio abgesagter Kurs (`course_sessions.status = 'cancelled'`) und eine Wartelisten-Buchung in einer leeren Woche davor verlängern nicht.
- [ ] **Step 3:** FAIL → implementieren: `getSessions` lädt (parallel) `cardio_checks.day` des Users (limit 2000, absteigend) und eigene Kursbeginne `course_bookings` `status = 'booked'` mit `course_sessions!inner(starts_at, status)` `status = 'planned'`, `starts_at <= now()` (limit 2000) – oder `my_course_starts` aus Task 1, falls dort nötig geworden. `streak` nutzt beide.
- [ ] **Step 4:** PASS; Commit `feat(serie): Cardio-Haken und Kurse halten die Serie`.

### Task 6: Generator 1.4.0 mit `kraftProWoche`

**Files:**
- Modify: `packages/domain/src/trainingsplan-generator.ts` (`GeneratorEingabe`, `planeKrafttage`, Raster-Bau ~361), `packages/domain/src/trainingsplan-regeln.ts:10`, `packages/domain/src/trainingsplan.ts` (`erzeugePlanVorschlag` ~120–190), `packages/domain/src/trainingsplan-generator.bestand.json`
- Test: `packages/domain/src/trainingsplan-generator.test.ts`, `packages/domain/src/trainingsplan-woche.test.ts`, `tests/integration/api-plans.test.ts`

**Interfaces:**
- Produces: `GeneratorEingabe.kraftProWoche?: number` (ersetzt `kursTage/cardioTage/kraftTage`); Struktur = `strukturFuerTage(kraftProWoche ?? tage)`; `wochenraster: []`; Grund `kraft_tage_auf_eins` entfällt.

- [ ] **Step 1: Failing tests:** `kraftProWoche 4, tage 6` → Struktur `ober_unter`; `kraftProWoche` fehlt, `tage 3` → `gk_ab`; `wochenraster` immer `[]`; `regelVersion === "1.4.0"`; Gründe enthalten nie `kraft_tage_auf_eins`. Integration: POST `me/plans` mit Profil `kraftProWoche 2` und `weekly_days 3` → `struktur` des 2-Tage-Falls.
- [ ] **Step 2:** FAIL → implementieren; `erzeugePlanVorschlag` übergibt `profil.kraftProWoche ?? undefined`, keine Tageslisten mehr. `planeKrafttage`, `kraftAnzahl`, `verteileKraft` löschen, wenn nichts sie mehr nutzt (`pruefeWoche` bleibt für das Profil); zugehörige Tests in `trainingsplan-woche.test.ts` mitlöschen, `pruefeWoche`-Tests bleiben.
- [ ] **Step 3:** Bestands-Snapshot neu schreiben (`pnpm --filter @fitretro/domain test -- trainingsplan-generator -u`), Diff prüfen: nur `regelVersion`, `wochenraster`, ggf. `kraft_tage_auf_eins` und Struktur der Fälle mit Kurs-/Cardio-Tagen dürfen sich ändern.
- [ ] **Step 4:** alle Domain-Tests PASS; Commit mit Begründung des Snapshots `feat(plan): Generator 1.4.0 plant nach Kraft pro Woche`.

### Task 7: App – DTOs, APIClient, CardioChecksStore

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift` (`TrainingsplanProfil`), Bootstrap-DTO (Datei mit `struct BootstrapResponse`, `member`), `Networking/APIClient.swift:286-315`, `Workout/CardioChecksStore.swift`
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/Wochenziel.swift`
- Test: `FitnessMemberTests/DTOTests.swift`, `APIClientTests.swift`, neue Fälle in `PlanTabZustandTests.swift` entfallen später (Task 10)

**Interfaces:**
- Produces: `struct Wochenziel: Codable, Equatable, Sendable { let kraft: Int; let cardio: Int; let cardioMinuten: Int }`; `BootstrapResponse.Member.wochenziel: Wochenziel?` (decodeIfPresent); `TrainingsplanProfil` + `kraftProWoche: Int?`, `cardioProWoche: Int?`, `cardioMinuten: Int?` (encodeIfPresent); `struct CardioCheck: Codable, Equatable, Hashable, Sendable { let id: String; let day: String; let minuten: Int? }`; `APIClient.cardioChecks(from:to:) -> [CardioCheck]`, `addCardioCheck(day: String) -> CardioCheck`, `deleteCardioCheck(id: String)`; `CardioChecksStore.checks: [CardioCheck]` (statt `erledigt: Set<String>`), `abhaken(tagId:apiClient:) async -> String?`, `zuruecknehmen(id:apiClient:) async -> String?`, `laden` unverändert in der Signatur.

- [ ] **Step 1: Failing tests:** DTO dekodiert Profil mit/ohne neue Felder; kodiert ohne Tagesfelder, wenn nil; `Wochenziel` dekodiert; `CardioCheck`-Antwort `{checks:[…], days:[…]}` dekodiert; APIClient baut `POST me/cardio-checks` mit Body `{"day":"2026-11-10"}` und `DELETE me/cardio-checks?id=…` (Muster bestehender APIClient-Tests mit URLProtocol-Stub); `CardioChecksStore.zusammenfuehren` behält Einträge außerhalb des Bereichs.
- [ ] **Step 2:** `xcodegen generate` und Suites `DTOTests`, `APIClientTests` → FAIL.
- [ ] **Step 3:** Implementieren; Aufrufer von `erledigt`/`setzen` kompilierend halten (vorübergehend `erledigtTage: Set<String>` als berechnete Eigenschaft, entfällt in Task 13).
- [ ] **Step 4:** PASS; Commit `feat(ios): Wochenziel und Cardio-Haken mit id`.

### Task 8: App – `PlanWochenRechnung` (Kern)

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/PlanWochenRechnung.swift`
- Test: `apps/ios-member/FitnessMemberTests/PlanWochenRechnungTests.swift`

**Interfaces:**
- Consumes: `Wochenziel`, `CardioCheck` (Task 7), `SessionSummary`, `ErledigteEinheit`, `CourseWeekSession`, `PlanFilter`.
- Produces:
```swift
enum WochenPhase: Equatable { case vergangen, laufend, kuenftig }
enum TagMarke: Equatable, Hashable { case kraft, cardio, kurs, kursGebucht }   // kursGebucht = gebucht, noch nicht begonnen
struct WochenKarte: Equatable, Identifiable {
    enum Art: Equatable { case kraft(einheitKey: String?), cardio, kurs(CourseWeekSession) }  // einheitKey nil = freies Training
    enum Quelle: Equatable { case sitzung(id: String), hand(checkId: String), keine }
    let id: String
    let art: Art
    let erledigtAm: Date?        // nil = offen
    let quelle: Quelle
    let istNaechste: Bool        // nur erste offene Kraft-Karte der laufenden Woche
    let minuten: Int?            // Trainingsdauer bzw. Cardio-Minuten
}
struct PlanWochenStand: Equatable {
    let phase: WochenPhase
    let karten: [WochenKarte]    // Reihenfolge: Kraft erledigt, Kraft offen, Cardio erledigt, Cardio offen, Kurse
    let marken: [Date: [TagMarke]]   // je startOfDay, sortiert kraft > kurs > kursGebucht > cardio
    let kraftErledigt: Int
    let cardioErledigt: Int
}
enum PlanWochenRechnung {
    static func berechne(
        wocheStart: Date, heute: Date, kalender: Calendar, ziel: Wochenziel,
        einheiten: [String], naechsteEinheitKey: String?,
        sitzungen: [SessionSummary], erledigt: [ErledigteEinheit],
        cardioChecks: [CardioCheck], kurse: [CourseWeekSession], filter: PlanFilter
    ) -> PlanWochenStand
}
```
Regeln: Spec §2 #1–#3, §3, §8. Kraft-Haken = Sitzung mit `completedAt != nil` in der Woche, die in `erledigt` steht oder einen Satz mit `cardio == nil` hat. Cardio automatisch = beendete Sitzung mit Σ `cardio.zeit` (Sekunden – in `Workout/Cardio.swift` bestätigen) ≥ `ziel.cardioMinuten * 60`, höchstens ein Haken je Sitzung, Tag = Ortsdatum `startedAt`. Kurs sichtbar = `ownStatus == "booked"` und `status != "cancelled"`; Marke `kurs` ab Beginn, vorher `kursGebucht`. Offene Karten nur in `.laufend`; `.kuenftig` zeigt nur Kurse. `filter` blendet Karten und Marken anderer Arten aus (`.alle` nichts).

- [ ] **Step 1: Failing tests** (Kalender Europe/Berlin, Woche ab Mo 9.11.2026, heute Di 10.11.):
  - `planEinheitUndFreiesTraining`: Ziel 2/0, Sitzung Mo mit `erledigt` A, Sitzung Di frei mit Kraftsatz → zwei erledigte Kraft-Karten (`einheitKey "A"`, `nil`), keine offene, `kraftErledigt 2`.
  - `zielUeberschritten`: Ziel 1, drei Trainings → drei erledigte, keine offene.
  - `offeneKartenFolgen`: Ziel 3, einheiten `[A,B]`, `naechsteEinheitKey "B"`, eins erledigt → offene Karten B, A; erste `istNaechste == true`, zweite `false`.
  - `laufendeSitzungGibtKeinenHaken`: `completedAt nil`, steht in `erledigt` → 0 erledigt, 2 offen.
  - `cardioNachKraft`: eine Sitzung mit Kraftsätzen + Cardio-Sätzen 20+12 min, Ziel Cardio 1×30 → Kraft- und Cardio-Haken aus derselben Sitzung.
  - `zweimalZwanzigMinutenReichenNicht`: zwei Sitzungen je 20 min Cardio → `cardioErledigt 0`.
  - `handHakenMehrfach`: zwei `CardioCheck` am Di, Ziel 1 → zwei erledigte Cardio-Karten (Quelle `.hand`), keine offene.
  - `nurCardioSitzungIstKeinKraft`: Sitzung nur Cardio-Sätze, nicht in `erledigt` → kein Kraft-Haken, ggf. Cardio.
  - `kursVorUndNachBeginn`: gebuchter Kurs Do 18:00 → Marke `.kursGebucht` am 12.; mit `heute` Do 19:00 → `.kurs`; Warteliste und abgesagt → keine Karte, keine Marke.
  - `wochenwechselMontagNacht`: Sitzung So 15.11. 23:30 Berlin zählt in Woche 9.–15.; Sitzung Mo 16.11. 00:30 nicht.
  - `vergangeneWocheOhneOffene`: `wocheStart` 2.11., Ziel 2, ein Training → genau eine Karte, `phase .vergangen`.
  - `kuenftigeWocheNurKurse`.
  - `filterKraft`: nur Kraft-Karten und `.kraft`-Marken.
  - `markenReihenfolge`: Tag mit Training und Kurs → `[.kraft, .kurs]`.
- [ ] **Step 2:** `xcodegen generate`; Suite `PlanWochenRechnungTests` → FAIL („Test run with 14 tests“ prüfen).
- [ ] **Step 3:** Implementieren (Ortsdaten über `kalender.startOfDay`, Zeitpunkte über `Zeitpunkt.parse`).
- [ ] **Step 4:** PASS; Commit `feat(ios): Wochenrechnung ohne feste Tage`.

### Task 9: App – Plan-Tab Woche und Monat

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Plan/PlanRootView.swift`, `Screens/Plan/PlanTagListe.swift` (wird zu den Wochenkarten), `Screens/Plan/PlanMonatsgitter.swift`, `Workout/PlanWoche.swift` (`PlanFilter.einheiten` → `.kraft`, Titel „Kraft“), `Screens/Plan/PlanKalenderKontext.swift`
- Create: `Screens/Plan/PlanWochenKarten.swift`, `Screens/Plan/PlanTagBlatt.swift`
- Test: `FitnessMemberTests/PlanWocheTests.swift` (Filter-Titel), neue `PlanWochenKartenTests.swift` (reine Text-Helfer)

**Interfaces:**
- Consumes: `PlanWochenRechnung.berechne` (Task 8), `CardioChecksStore.abhaken/zuruecknehmen` (Task 7), `member.wochenziel`.
- Produces: `PlanWochenKarten.untertitel(_ karte: WochenKarte, einheiten: [TrainingsplanEinheit], kalender: Calendar) -> String` (Texte nach Spec §3 Punkt 4: „erledigt Mo, 9. · 58 min“, „7 Übungen · ca. 63 min“, „nach Kraft B · 32 min“, „abgehakt Di, 10.“, „zählt auch nach dem Krafttraining“, „18:00 · gebucht“); `PlanKalenderKontext.stand(…) -> PlanWochenStand` als gemeinsamer Zusammenbau für Plan-Tab und Home (ersetzt `termine`).

- [ ] **Step 1: Failing tests:** `PlanFilter.allCases.map(\.titel) == ["Alle", "Kraft", "Kurse", "Cardio"]`; je Kartenart der Untertitel aus Spec §3 (Fälle wie oben, Kalender Berlin).
- [ ] **Step 2:** FAIL → Ansicht umbauen nach Leinwand „Gewählt · Kalender B + Karten A“: Kopf, KW-Zeile, Wochenstreifen mit `marken` (Akzentring + Symbol; heute weiß; `kursGebucht` gestrichelt; keine Zähler), „DIESE WOCHE“-Karten, „KURSE“, Knopf „Woche anpassen“. Tipp: erledigte Kraft/Cardio aus Sitzung → `SessionDetailView`; offene Kraft → `PlanEinheitView`; Hand-Haken „Rückgängig“; Tag im Streifen mit Marken → `PlanTagBlatt` (Sheet mit Sitzungen und Kursen des Tags). Monat: gleiche Marken, Legende Kraft/Kurs/Cardio ohne „verpasst“, darunter Inhalte des gewählten Tags. Wochenblättern wie heute.
- [ ] **Step 3:** PASS; App baut; Commit `feat(ios): Plan-Woche mit Haken statt Tagen`.

### Task 10: App – „Woche anpassen“

**Files:**
- Modify/rename: `Screens/Plan/PlanEinplanenSheet.swift` → `Screens/Plan/WocheAnpassenSheet.swift`; `PlanRootView.swift` (`profilSpeichern` ~313)
- Test: `FitnessMemberTests/PlanTabZustandTests.swift` (Abschnitt „Einplanen“ ersetzen), `EinheitNamenTests.swift:119` (Hinweis entfällt → Test anpassen/entfernen)

**Interfaces:**
- Produces: `struct WochenAuswahl: Equatable { var kraft: Int; var cardio: Int; var cardioMinuten: Int; var cardioArten: [String] }` mit `init(ziel: Wochenziel, profil: TrainingsplanProfil?)` und `func profil(aus alt: TrainingsplanProfil) -> TrainingsplanProfil` (setzt nur die drei Zähler und `cardioArten`, Tagesfelder nil); Grenzen `kraft 1...7`, `cardio 0...7`, `cardioMinuten 10...90` Schritt 5.

- [ ] **Step 1: Failing tests:** `WochenAuswahl(ziel: .init(kraft: 2, cardio: 1, cardioMinuten: 30), profil: nil).profil(aus: basis)` kodiert JSON mit `kraftProWoche 2, cardioProWoche 1, cardioMinuten 30` und ohne `kraftTage/kursTage/cardioTage`; Klemmen an den Grenzen (kraft 0 → 1, cardioMinuten 95 → 90, 33 → 35).
- [ ] **Step 2:** FAIL → Blatt mit drei Steppern, Cardio-Minuten nur bei cardio ≥ 1, Cardio-Arten wie heute, Hinweistext aus Global Constraints; Speichern → PUT, Bootstrap neu. `PlanWochentage` löschen.
- [ ] **Step 3:** PASS; Commit `feat(ios): Woche anpassen statt Tage einplanen`.

### Task 11: App – Home und Einheit-Seite

**Files:**
- Modify: `Screens/Home/HomeRootView.swift` (~85–95, 120–145, 330–381), `Screens/Home/HomeSerieView.swift`, `Verlauf/HomeSerie.swift` (`planMarken` ~137–160), `Screens/Home/NaechsteEinheitKarte.swift`, `Screens/Plan/PlanEinheitView.swift` (~45–80, 135–152), `DesignSystem/Components/ProfilKopf.swift:82`
- Test: `FitnessMemberTests/HomeSerieTests.swift` (~420–490), `HomeZeilenTests.swift`, `EinheitKarteModellTests.swift:124`

**Interfaces:**
- Produces: `HomeSerie.planMarken(_ marken: [Date: [TagMarke]], kalender: Calendar) -> [String: TagMarke]` (erste Marke je Tag); `HomeSerie.zielZeile(stand: PlanWochenStand, ziel: Wochenziel) -> String?` → „Kraft 1/2 · Cardio 0/1“ (ohne Cardio-Ziel nur „Kraft 1/2“; ohne Plan und ohne `wochenziel` nil → alte Zeile); `ProfilKopf.startKnopfText` entfällt (immer „Training starten“).

- [ ] **Step 1: Failing tests:** `zielZeile` für (1/2, 0/1) → „Kraft 1/2 · Cardio 0/1“; (2/2, cardio 0) → „Kraft 2/2“; `planMarken` nimmt `.kraft` vor `.kurs`; kein Fall erzeugt eine Marke für einen Tag ohne Geleistetes/Kurs.
- [ ] **Step 2:** FAIL → Home: Streifen-Marken aus `PlanKalenderKontext.stand` der laufenden Woche; Zeile unter der Serie aus `zielZeile`; „Nächste Einheit“ = `naechsteEinheitKey` (bzw. `PlanAnzeige.heute`), „Training starten“ immer; `TrainingstageFestlegenZeile` löschen; Cardio-Haken der Woche weiter laden (auch ohne Plan, wenn `wochenziel.cardio > 0`). `PlanEinheitView`: Überzeile ohne geplanten Tag, Start nur für die nächste Einheit, Text „Training starten“.
- [ ] **Step 3:** PASS; Commit `feat(ios): Home zeigt Wochenziel als Haken`.

### Task 12: App – Onboarding ohne Tage

**Files:**
- Modify: `Onboarding/PlanWochenSchritte.swift`, `Onboarding/PlanAntworten.swift` (~220–270), Onboarding-Ablauf (Schrittliste, Datei per `grep -rn PlanWochenSchritte`)
- Test: `FitnessMemberTests/PlanAntwortenTests.swift`, `OnboardingAntwortenTests.swift`, `OnboardingSchreiberTests.swift`

**Interfaces:**
- Consumes: `WochenAuswahl` (Task 10).
- Produces: `PlanAntworten.woche: WochenAuswahl` statt Tageslisten; `PlanAntworten.zusammenfassung -> String` = „2× Kraft · 1× Cardio 30 min · Kurse nach Buchung“ (Cardio-Teil entfällt bei 0).

- [ ] **Step 1: Failing tests:** Schrittfolge enthält keinen Kurstage-Schritt mehr; Cardio-Schritt schreibt `cardioProWoche/cardioMinuten/cardioArten`; Zusammenfassung wie oben; geschriebenes Profil ohne Tagesfelder; `kraft_tage_auf_eins`-Anzeige (`PlanWochenSchritte.swift:368`) entfällt.
- [ ] **Step 2:** FAIL → umbauen (Tauschen von Tagen löschen) → PASS.
- [ ] **Step 3:** Commit `feat(ios): Onboarding fragt wie oft statt wann`.

### Task 13: Aufräumen und Gesamtprüfung

**Files:**
- Delete: `Workout/PlanKalender.swift`, `FitnessMemberTests/PlanKalenderTests.swift`; aus `PlanKalenderKontext.swift` `termine/geplanterTag/istGeplanterTag/fenster`; aus `PlanTabZustand.swift` `anzeigeRaster/hatKrafttage`; zugehörige Fälle in `PlanTabZustandTests`, `PlanKalenderKontextTests`, `PlanWocheTests`; `CardioChecksStore.erledigtTage`; `PlanTagMarke.Art.verpasst`.
- Modify: `Workout/PlanWarumText.swift` (Satz `kraft_tage_auf_eins` bleibt für alte Pläne – nicht löschen).

- [ ] **Step 1:** `grep -rn "verpasst\|PlanKalender\.\|anzeigeRaster\|istGeplanterTag\|Einheiten\"" apps/ios-member/FitnessMember` → nur noch erlaubte Treffer (PlanWarumText, unrelated).
- [ ] **Step 2:** `xcodegen generate`; volle iOS-Testsuite (`-only-testing:FitnessMemberTests`) → alle grün, Anzahl notieren.
- [ ] **Step 3:** `pnpm test`, `pnpm typecheck`, `pnpm lint`, `pnpm test:integration` → grün.
- [ ] **Step 4:** Simulator (Testkonto, Debug-Build zeigt auf Prod – deshalb erst nach Freigabe/Deploy sinnvoll; bis dahin gegen lokales Supabase, falls die App dafür konfigurierbar ist, sonst Prüfung als offen vermerken): Plan-Woche, Monat, Woche anpassen, Abhaken/Rückgängig, Home. Screenshots in den PR.
- [ ] **Step 5:** Commit `chore(ios): feste Plan-Tage entfernt`.

### Task 14: PR und Paketliste

- [ ] **Step 1:** Push `claude/p2-wochenplan-logik`, PR gegen `master`: Zusammenfassung, Testläufe mit Zahlen, Hinweis „0072 und API-Deploy brauchen Freigabe“, offene Simulatorprüfung. Endet mit `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.
- [ ] **Step 2:** Im Haupt-Checkout `docs/superpowers/plans/2026-11-10-testnotizen-pakete.md` Statuszeile P2: „PR offen, wartet auf Freigabe“ + Branch/PR; P3/P4: „kann starten (P2 im PR)“.
