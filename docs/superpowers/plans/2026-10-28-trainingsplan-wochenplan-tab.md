# Trainingsplan als Wochenplan-Tab – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Tab „Kurse“ wird zum Tab „Plan“: ein Wochenkalender, in dem Kraft-Einheiten (A/B), feste Kurs-Tage und feste Cardio-Tage stehen. Das Onboarding fragt Kurs- und Cardio-Tage ab und zeigt daraus „Deine Woche“.

**Architecture:** Kurs-Tage, Cardio-Tage und die Wochentage der Kraft-Einheiten liegen im Trainingsprofil (neue Spalten). Der Server rechnet die Zahl der Kraft-Einheiten (`weekly_days` minus Kurs- und Cardio-Tage) und schlägt die Wochentage vor; die App rechnet nichts. Wochentage sind Erinnerungen, die Reihenfolge der Einheiten bleibt eine Folge (Spec F5). Cardio-Erledigung ist eine eigene kleine Tabelle. Die iOS-App baut den Plan-Tab aus dem bestehenden Kurse-Wochenkalender um.

**Tech Stack:** TypeScript (`packages/domain`, `apps/web` Route Handler, Vitest), Supabase/Postgres (RLS), SwiftUI (`apps/ios-member`, Swift Testing, XcodeGen).

**Spec:** Design-Leinwand https://claude.ai/artifact/ACMgzZ32CZoyG7FH1NXo1s (Screens 2a–2i), dazu `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` (Abschnitte 1, 2, F5). Wo die Leinwand und die Spec sich widersprechen, gilt die Leinwand für Aussehen und dieser Plan für Verhalten.

**Basis:** Von `origin/master` aus arbeiten (neuer Worktree, Branch `claude/trainingsplan-wochenplan`). Der aktuelle Branch `codex/sensor-luecken-2026-10-26` steht hinter master (Migrationen enden dort bei 0061, auf master bei 0068, Plan-Code fehlt).

## Entscheidungen

- **E1 Wochentage** sind ISO-Zahlen `1` (Mo) bis `7` (So), überall (SQL, TS, Swift). Die Woche beginnt Montag. Der Tag eines Termins wird in der Zeitzone des Studios bestimmt (`CourseWeek.timezone`).
- **E2 Speicherort:** vier neue Spalten in `training_profiles`: `kurs_tage smallint[]`, `cardio_tage smallint[]`, `cardio_arten text[]`, `kraft_tage smallint[]` (vorgeschlagen, vom Mitglied tauschbar), dazu `training_plans.wochenraster jsonb` (festgehaltenes Raster je Planversion). Alle `not null default '{}'`, damit Bestandsprofile und -pläne unverändert bleiben.
- **E3 Kraft-Einheiten je Woche** = `weekly_days − |kurs_tage ∪ cardio_tage|`, mindestens 1. Wird auf 1 angehoben, setzt der Generator den Grund `kraft_tage_auf_eins`. Die Struktur kommt weiter aus `strukturFuerTage`.
- **E4 Überschneidung:** Kurs- und Cardio-Tage dürfen sich nicht überschneiden (`validation_failed`). Ein Kraft-Tag auf einem Kurs- oder Cardio-Tag ist ebenfalls ungültig.
- **E5 Kurs-Termin** ist nur ein Wochentag. Namen und Uhrzeiten kommen aus den Anmeldungen (`KurseStore`). Keine Kurs-Art im Profil.
- **E6 Cardio-Arten:** `laufen`, `radfahren`, `schwimmen`, `wandern`, `anderes`. Umfang und Tempo sind ausdrücklich nicht Teil dieses Plans.
- **E7 Cardio abhaken:** Tabelle `cardio_checks(user_id, day)`, nur für heute oder vergangene Tage.
- **E8 Training-Tab** behält die Übungsliste der Einheit (dort wird trainiert), verliert aber die Überschrift „Nächstes Training“, die Home schon zeigt. Home bleibt der Ort für „Heute dran“ und die Woche.

## Global Constraints

- Bedienoberfläche auf Deutsch, Texte wie in der Leinwand. Farben, Abstände, Schrift ausschließlich aus `DesignSystem` (`apps/ios-member/FitnessMember/DesignSystem/DesignSystem.swift`).
- Regeln laufen auf dem Server (`packages/domain`); die App zeigt nur an (Spec „Regeln laufen auf dem Server“).
- Neue Migration: nächste freie Nummer nach `0068` (Stand 28.10.2026: `0069`), bei Konflikt weiterzählen. **Prod-Migration, Deploy und Merge nur nach ausdrücklicher Freigabe von Tim**, jeweils einzeln.
- Das Debug-Build der iOS-App zeigt auf Prod: Simulatortests nur mit dem Testkonto.
- Swift: nach neuen Dateien `cd apps/ios-member && xcodegen generate`. Testfilter `-only-testing:FitnessMemberTests/<Typname>`; immer die Zeile „Test run with N tests“ prüfen (ein falscher Filter meldet trotzdem „TEST SUCCEEDED“). Simulator per ID (`xcrun simctl list devices available`).
- Kommentare im Stil des Codes: deutsch, erklären das Warum.

## Review Focus

- Weniger `weekly_days` als Kurs- plus Cardio-Tage (z. B. 2 Tage, 1 Kurs, 1 Cardio): Kraft bleibt 1, Grund `kraft_tage_auf_eins`, kein Fehler. (Task 1, 3)
- Bestandsprofil ohne neue Felder: Plan, Generator-Ausgabe und Vorschlag bleiben byte-gleich zu vorher. (Task 3)
- Mitglied ohne aktiven Plan, aber mit Kurs-Tagen: Plan-Tab zeigt Kurse und die Karte „Plan einrichten“, keine leeren A/B-Tage. (Task 6)
- Mitglied ohne Studio oder Studio ohne Kurse: Filter „Kurse“ und die Onboarding-Frage entfallen (Leinwand 2g). (Task 5, 6)
- Cardio für einen Tag in der Zukunft oder doppelt abhaken: Zukunft wird abgelehnt, doppelt ist idempotent. (Task 4)

---

## File Structure

| Datei | Verantwortung |
|---|---|
| `packages/domain/src/trainingsplan-woche.ts` (neu) | Reine Wochenlogik: Anzahl Kraft-Tage, Verteilung, Prüfung |
| `packages/domain/src/trainingsprofil.ts` | Profil um Wochenfelder erweitern |
| `packages/domain/src/trainingsplan-generator.ts`, `trainingsplan-regeln.ts` | `tage` aus Raster, Grund-Code, Regelversion |
| `packages/domain/src/cardio-checks.ts` (neu) | Cardio abhaken, lesen |
| `supabase/migrations/0069_wochenraster.sql`, `0070_cardio_checks.sql` (neu) | Schema |
| `apps/web/app/api/v1/me/cardio-checks/route.ts` (neu) | GET Bereich, PUT/DELETE Tag |
| `apps/ios-member/FitnessMember/Workout/PlanWoche.swift` (neu) | Reines Modell: Termine je Tag, Filter |
| `apps/ios-member/FitnessMember/Onboarding/PlanAntworten.swift`, `PlanSchritte.swift`, neu `PlanWochenSchritte.swift` | Onboarding-Schritte Kurse, Cardio, Deine Woche |
| `apps/ios-member/FitnessMember/Screens/Plan/` (neu): `PlanRootView.swift`, `PlanTagListe.swift`, `PlanEinheitView.swift`, `PlanEinplanenSheet.swift` | Plan-Tab |
| `apps/ios-member/FitnessMember/Navigation/MainTabView.swift` | Tab „Plan“ statt „Kurse“ |
| `apps/ios-member/FitnessMember/Screens/Home/HomeRootView.swift`, neu `HomeWocheKarte.swift` | Wochenkarte statt Plan-Karte |

---

### Task 1: Wochenlogik (rein)

**Files:**
- Create: `packages/domain/src/trainingsplan-woche.ts`
- Test: `packages/domain/src/trainingsplan-woche.test.ts`

**Interfaces:**
- Produces:
  - `type Wochentag = 1|2|3|4|5|6|7`
  - `kraftAnzahl(tage: number, kursTage: Wochentag[], cardioTage: Wochentag[]): { anzahl: number; angehoben: boolean }`
  - `verteileKraft(belegt: Wochentag[], anzahl: number): Wochentag[]` (aufsteigend, deterministisch)
  - `pruefeWoche(w: { kursTage: Wochentag[]; cardioTage: Wochentag[]; kraftTage: Wochentag[] }): void` (wirft `DomainError("validation_failed", …)`)

- [ ] **Step 1: Failing tests** mit diesen Werten: `kraftAnzahl(3,[1],[7])` → `{anzahl:1, angehoben:false}`; `kraftAnzahl(4,[1],[7])` → `{anzahl:2, angehoben:false}`; `kraftAnzahl(2,[1],[7])` → `{anzahl:1, angehoben:true}`; doppelte Tage zählen einmal (`kraftAnzahl(3,[1,1],[])` → 2). `verteileKraft([1,7],2)` → `[3,5]`; `verteileKraft([1,7],1)` → `[4]` (größte Lücke, Mitte, bei Gleichstand der frühere Tag); `verteileKraft([],3)` → `[1,3,5]`; `verteileKraft([1,2,3,4,5,6,7],1)` → `[]`. `pruefeWoche` wirft bei Kurs∩Cardio, Kraft∩Kurs, Kraft∩Cardio, Tag außerhalb 1–7, doppeltem Tag.
- [ ] **Step 2:** `pnpm --filter @fitretro/domain test -- trainingsplan-woche` → FAIL (Modul fehlt).
- [ ] **Step 3: Implement** die drei Funktionen. Verteilung: aus den freien Tagen greedy den Tag mit dem größten Mindestabstand zu allen belegten und schon gewählten Tagen, Woche zyklisch (So→Mo zählt als benachbart); Gleichstand → kleinerer Tag.
- [ ] **Step 4:** Tests laufen → PASS. `pnpm --filter @fitretro/domain typecheck`.
- [ ] **Step 5: Commit** `feat(domain): Wochenlogik fuer Kurs-, Cardio- und Kraft-Tage`

### Task 2: Profil-Spalten und Profil-API

**Files:**
- Create: `supabase/migrations/0069_wochenraster.sql`
- Modify: `packages/domain/src/trainingsprofil.ts` (`TrainingProfile`, `profilSchema`, `getTrainingProfile`, `saveTrainingProfile`)
- Test: `packages/domain/src/trainingsprofil.test.ts`, `tests/integration/api-training-profile.test.ts`

**Interfaces:**
- Consumes: `pruefeWoche` (Task 1)
- Produces: `TrainingProfile` bekommt `kursTage: Wochentag[]`, `cardioTage: Wochentag[]`, `cardioArten: CardioArt[]`, `kraftTage: Wochentag[]`; `CARDIO_ARTEN = ["laufen","radfahren","schwimmen","wandern","anderes"] as const` in `trainingsplan-typen.ts`. JSON-Felder der API: `kursTage`, `cardioTage`, `cardioArten`, `kraftTage`.

- [ ] **Step 1: Failing tests.** Domain: Profil ohne die neuen Felder wird weiter akzeptiert und liefert leere Listen; `cardioArten: ["joggen"]` → `validation_failed`; Überschneidung → `validation_failed`. Integration: PUT mit `kursTage:[1], cardioTage:[7], cardioArten:["laufen"], kraftTage:[3,5]`, danach GET liefert dieselben Werte; ein PUT ohne die Felder lässt gespeicherte Werte unverändert.
- [ ] **Step 2:** Tests laufen und scheitern.
- [ ] **Step 3: Migration** mit den vier Spalten (`smallint[] not null default '{}'`, `text[]` für Arten) und Check-Constraints: Werte in 1–7, `cardioArten <@` die fünf Schlüssel, Kurs und Cardio ohne gemeinsame Tage. Keine neue Policy nötig (bestehende `training_profiles`-Policies gelten).
- [ ] **Step 4: Domain** erweitern; fehlende Felder im PUT bedeuten „unverändert“ (Upsert nur mit gesendeten Spalten).
- [ ] **Step 5:** `supabase db reset` lokal (Docker/Colima läuft: bei I/O-Fehlern `colima restart`, `supabase stop --no-backup`, `start`), dann `pnpm test` und `pnpm test:integration -- api-training-profile` → PASS.
- [ ] **Step 6: Commit** `feat(plan): Wochenraster im Trainingsprofil`

### Task 3: Generator nutzt das Raster

**Files:**
- Modify: `packages/domain/src/trainingsplan-regeln.ts` (`PLAN_REGEL_VERSION` → `"1.3.0"`), `packages/domain/src/trainingsplan-generator.ts`, `apps/web/app/api/v1/me/plans/route.ts`
- Test: `packages/domain/src/trainingsplan-generator.test.ts`, `tests/integration/api-plans.test.ts`

**Interfaces:**
- Consumes: `kraftAnzahl`, `verteileKraft` (Task 1), Profilfelder (Task 2)
- Produces: `GeneratorErgebnis.wochenraster: { tag: Wochentag; art: "kraft"|"kurs"|"cardio"; einheitKey?: string }[]` (nach Tag sortiert); Grund-Code `kraft_tage_auf_eins`. Der Plan-Endpunkt liefert `wochenraster` mit.

- [ ] **Step 1: Failing tests.** (a) Bestandseingabe ohne Raster ergibt exakt die bisherige Ausgabe (Fixture-Vergleich, bis auf `regelVersion`) und ein leeres `wochenraster` aus nur Kraft-Tagen nach `verteileKraft`. (b) 4 Tage, Kurs `[1]`, Cardio `[7]` → Struktur `gk_ab`, Raster `[1 kurs, 3 kraft A, 5 kraft B, 7 cardio]`. (c) 2 Tage, Kurs `[1]`, Cardio `[7]` → Struktur `gk_eine`, Grund `kraft_tage_auf_eins`. (d) Hat das Mitglied `kraftTage` im Profil gesetzt, gelten diese statt des Vorschlags, Einheiten A/B/… der Reihe nach.
- [ ] **Step 2:** scheitern lassen.
- [ ] **Step 3: Implement** `tage` im Generator aus `kraftAnzahl`; Raster bauen; Route reicht `kursTage`, `cardioTage`, `kraftTage` aus dem Profil an den Generator durch und speichert `wochenraster` in einer neuen Spalte `training_plans.wochenraster jsonb not null default '[]'` (in Migration `0069` aus Task 2 mit anlegen; Pläne sind stabil, F14, das Raster wird beim Erzeugen festgehalten und nie beim Lesen neu berechnet). Tauschen im Plan-Tab schreibt `training_profiles.kraft_tage`; der aktive Plan behält sein Raster, der nächste Vorschlag übernimmt die neuen Tage.
- [ ] **Step 4:** `pnpm test`, `pnpm test:integration -- api-plans` → PASS.
- [ ] **Step 5:** Swift-Gegenstück: `PlanWarumText` (`apps/ios-member/FitnessMember/Workout/PlanWarumText.swift`) um einen Satz zu `kraft_tage_auf_eins` ergänzen, `version` erhöhen, den festen Code-Test (`PlanWarumTextTests.generatorCodes`) um den neuen Code erweitern.
- [ ] **Step 6: Commit** `feat(plan): Generator plant um feste Kurs- und Cardio-Tage`

### Task 4: Cardio abhaken

**Files:**
- Create: `supabase/migrations/0070_cardio_checks.sql`, `packages/domain/src/cardio-checks.ts`, `apps/web/app/api/v1/me/cardio-checks/route.ts`
- Modify: `packages/domain/src/index.ts` (Export)
- Test: `packages/domain/src/cardio-checks.test.ts`, `tests/integration/api-cardio-checks.test.ts`

**Interfaces:**
- Produces: `setCardioCheck(client, userId, day: string /* YYYY-MM-DD */, heute: string): Promise<void>` (idempotent, wirft `validation_failed` bei `day > heute`); `deleteCardioCheck(client, userId, day)`; `listCardioChecks(client, userId, von: string, bis: string): Promise<string[]>`. HTTP: `GET ?from=&to=` → `{ days: string[] }`, `PUT /…?day=`, `DELETE /…?day=`. Der Tag ist der Kalendertag des Mitglieds (die App sendet `day` und `heute` in der Studio-Zeitzone; der Server vertraut `day`, prüft nur Format und „nicht nach heute+1 UTC“ als Netz).

- [ ] **Step 1: Failing tests.** Doppeltes PUT ergibt eine Zeile; Zukunft → 400 `validation_failed`; DELETE eines fehlenden Tags → 204; fremde Zeilen sind per RLS unsichtbar (zweites Testkonto liest leer).
- [ ] **Step 2:** scheitern lassen.
- [ ] **Step 3: Migration** `cardio_checks(user_id uuid references auth.users on delete cascade, day date, created_at timestamptz default now(), primary key (user_id, day))`, RLS enable+force, Policies select/insert/delete nur eigene Zeilen (Muster `0060`).
- [ ] **Step 4: Implement** Domain und Route nach dem Muster von `training-profile/route.ts`.
- [ ] **Step 5:** Tests → PASS. **Step 6: Commit** `feat(plan): Cardio-Termine abhaken`

### Task 5: iOS – Modelle und Wochenmodell

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift` (`wochenraster`), `Verlauf/TrainingsProfil.swift` bzw. `TrainingsplanProfil` (vier neue Felder), `Networking/DTOs/ProfilWrite.swift`, API-Client um Cardio-Checks
- Create: `apps/ios-member/FitnessMember/Workout/PlanWoche.swift`
- Test: `apps/ios-member/FitnessMemberTests/PlanWocheTests.swift`

**Interfaces:**
- Produces:
  - `enum PlanTermin: Equatable { case einheit(key: String, erledigt: Bool); case kurs(titel: String, beginn: Date, angemeldet: Bool); case cardio(arten: [String], erledigt: Bool) }`
  - `enum PlanFilter: CaseIterable { case alle, einheiten, kurse, cardio; var titel: String }`
  - `PlanWoche.termine(tage: [Date], kalender: Calendar, raster: [Rasterplatz], kurse: [CourseWeekSession], cardioErledigt: Set<String>, einheitenErledigt: Set<String>, filter: PlanFilter) -> [Date: [PlanTermin]]` (Schlüssel = `startOfDay`)
  - `PlanWoche.sichtbareFilter(hatPlan: Bool, hatKurse: Bool, hatCardio: Bool) -> [PlanFilter]`

- [ ] **Step 1: Failing tests** (Swift Testing, feste `Calendar` mit `Europe/Berlin`, Woche 26.10.–1.11.2026): Raster `[1 kurs, 3 kraft A, 5 kraft B, 7 cardio]` ergibt je Tag genau einen Termin, Montag zeigt den angemeldeten Kurs dieses Tags (Titel aus der Sitzung), Mittwoch `einheit("A", erledigt:false)`; Filter `.kurse` lässt nur Kurs-Termine, aber zeigt auch nicht gebuchte Kurse als `kurs(angemeldet:false)`; `sichtbareFilter(hatPlan:false, hatKurse:true, hatCardio:false)` → `[.alle, .kurse]`; ohne Kurse und ohne Cardio → `[]` (Leinwand 2g: keine Filter).
- [ ] **Step 2:** `xcodegen generate`, Test mit `-only-testing:FitnessMemberTests/PlanWocheTests` → FAIL.
- [ ] **Step 3: Implement** DTO-Felder (Decodable mit `decodeIfPresent`, damit ältere Serverantworten weiter lesbar bleiben) und `PlanWoche`.
- [ ] **Step 4:** Test → PASS („Test run with N tests“ prüfen); Gesamtsuite grün. **Step 5: Commit** `feat(ios): Wochenmodell fuer den Plan-Tab`

### Task 6: iOS – Plan-Tab

**Files:**
- Create: `Screens/Plan/PlanRootView.swift`, `PlanTagListe.swift`, `PlanEinheitView.swift`, `PlanEinplanenSheet.swift`
- Modify: `Navigation/MainTabView.swift` (Tab 2: `Label("Plan", systemImage: "calendar")`, `kursePfad` → `planPfad`, Route um `.einheit(key:)` erweitern; `KursRoute` bleibt für Kurs-Details), `Screens/Kurse/KurseWochenView.swift` (Wochenstreifen und Ladelogik als wiederverwendbare Teile herauslösen statt kopieren)
- Test: `FitnessMemberTests/PlanTabZustandTests.swift`

**Interfaces:**
- Consumes: `PlanWoche`, `PlanFilter` (Task 5), `KurseStore`, Cardio-Check-Client
- Produces: `PlanTabZustand` (reiner Zustand: gewählter Tag, Filter, Vorauswahl „heute“) mit `static func vorauswahl(tage: [Date], heute: Date, kalender: Calendar) -> Date`.

- [ ] **Step 1: Failing tests:** Vorauswahl ist heute, wenn heute in der Woche liegt, sonst Montag; gewählter Filter, der nicht mehr sichtbar ist (Kurse verschwinden), fällt auf `.alle` zurück (wie `KurseAnsicht.geltend`).
- [ ] **Step 2:** scheitern lassen, **Step 3:** `PlanTabZustand` und Views nach Leinwand 2a/2e/2f/2g/2i bauen: Wochenstreifen mit Punkt (Einheit gefüllt), Ring (Kurs), Raute (Cardio) plus Legende; Tagesliste; Karte „Als nächstes“ (zwei nächste Termine) wenn der Tag leer ist; Einheit antippen → `PlanEinheitView` (Übungsliste aus `Trainingsplan.einheiten`, „Training starten“ wie bisher über `PlanStart`); Cardio-Karte mit „Als erledigt markieren“ (nur heute/vergangen); `PlanEinplanenSheet` ändert `kraftTage`/`kursTage`/`cardioTage` über das Profil-PUT und lädt den Bootstrap neu. Ohne aktiven Plan: Kurse wie bisher plus Karte `PlanEinrichtenKarte`.
- [ ] **Step 4:** Tests grün, App im Simulator (Testkonto) durchklicken: alle fünf Zustände aus der Leinwand (Tag mit Einheit, Kurs-Filter, ohne Studio, Sonntag mit Cardio, Einplanen). **Step 5: Commit** `feat(ios): Plan-Tab statt Kurse-Tab`

### Task 7: iOS – Onboarding Kurse, Cardio, Deine Woche

**Files:**
- Modify: `Onboarding/PlanAntworten.swift` (`kursTage`, `cardioTage`, `cardioArten`, `kraftTage` + Umschalter), `Onboarding/OnboardingFlow.swift` (Schritte 5–7, Zähler „von 8“), `Onboarding/PlanVorschau.swift` (Vorschau zeigt das Raster)
- Create: `Onboarding/PlanWochenSchritte.swift` (`PlanKursSchritt`, `PlanCardioSchritt`, `PlanWochenSchritt`)
- Test: `FitnessMemberTests/PlanAntwortenTests.swift`

**Interfaces:**
- Consumes: Profil-PUT (Task 2), Plan-Antwort mit `wochenraster` (Task 3)
- Produces: `PlanAntworten.kursTage: [Int]`, `cardioTage: [Int]`, `cardioArten: [String]`; `mutating func tagUmschalten(_ tag: Int, fuer art: Wochenart)`; `var kursFrageSichtbar(hatStudioMitKursen: Bool) -> Bool`.

- [ ] **Step 1: Failing tests:** Ein Tag, der bei Kurs gewählt ist, wird beim Cardio-Umschalten abgelehnt (Überschneidung, E4); „Nein, nur freies Training“ leert Tage und Arten; „Weiter“ ist gesperrt, solange „Ja“ gewählt ist, aber kein Tag oder (bei Cardio) keine Art; `kursFrageSichtbar(hatStudioMitKursen:false)` → `false` und der Flow überspringt den Schritt (Schrittzähler passt sich an).
- [ ] **Step 2:** scheitern lassen; **Step 3:** Schritte nach Leinwand 2c, 2c2, 2c3 bauen (Tage als 7er-Raster, Zugänglichkeit: Tage als Schalter mit Label „Montag, ausgewählt“); „Deine Woche“ zeigt das vom Server gelieferte Raster, „Tauschen“ tauscht zwei Kraft-Tage und schreibt `kraftTage`. Rechenbeispiel-Hinweis aus der Leinwand nur anzeigen, wenn der Server `kraft_tage_auf_eins` oder die Zahl der Einheiten bestätigt hat, nicht in der App rechnen.
- [ ] **Step 4:** Tests → PASS; Flow im Simulator mit Testkonto (frisches Onboarding) durchspielen. **Step 5: Commit** `feat(ios): Onboarding fragt Kurs- und Cardio-Tage`

### Task 8: iOS – Home ohne Doppelung

**Files:**
- Create: `Screens/Home/HomeWocheKarte.swift`
- Modify: `Screens/Home/HomeRootView.swift`, `Screens/Training/PlanKarte.swift` (Überschrift „Nächstes Training“ entfällt, E8)
- Test: `FitnessMemberTests/HomeWocheKarteTests.swift`

**Interfaces:**
- Produces: `HomeWoche.zeilen(raster:erledigt:heute:kalender:) -> [HomeWochenfeld]` mit `HomeWochenfeld { tag: Int; art: Wochenart; label: String; istHeute: Bool; erledigt: Bool }`, `HomeWoche.zusammenfassung(...) -> String` („1 von 4 Terminen erledigt“).

- [ ] **Step 1: Failing tests** für Raster `[1 kurs, 3 A, 5 B, 7 cardio]` an einem Mittwoch: Felder Mo–So, Mittwoch ist „heute“, Montag `erledigt` wenn eine Anmeldung/Teilnahme vorliegt, Zusammenfassung stimmt. **Step 2–4:** bauen nach Leinwand 2d; die Karte führt in den Plan-Tab (`beiPlanZeigen`, analog `beiTrainingZeigen`); „Als nächstes“ führt zur Einheit/Cardio. **Step 5: Commit** `feat(ios): Home zeigt die Woche statt doppeltem Plan-Einstieg`

### Task 9: Abschluss und Freigaben

- [ ] **Step 1:** `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `pnpm smoke:migrations`; Swift-Gesamtsuite. Alles grün, sonst nicht weiter.
- [ ] **Step 2:** Uebergabe-Dokument aktualisieren (`docs/superpowers/plans/2026-10-28-trainingsplan-wochenplan-uebergabe.md`): was fertig ist, was offen (Cardio-Umfang/Tempo, Kurs-Art im Plan, Strava/Health), Prod-Stand.
- [ ] **Step 3: Freigaben bei Tim einholen, einzeln:** (a) PR öffnen/pushen, (b) Prod-Migrationen 0069 und 0070 per MCP `apply_migration`, (c) API-Deploy, (d) Merge. Ohne Antwort nichts davon tun.

---

## Self-Review

- **Spec-Abdeckung:** Leinwand 2a (Task 5, 6), 2b (6), 2c/2c2/2c3 (7), 2d (8), 2e (6), 2f (6), 2g (5, 6), 2i (4, 6). Cardio ohne Umfang/Tempo wie gewünscht.
- **Typen:** `Wochentag` (TS) ↔ `Int` 1–7 (Swift) ↔ `smallint[]` (SQL); `wochenraster`-Feldnamen in Task 3 und Task 5 gleich (`tag`, `art`, `einheitKey`).
- **Offene Punkte für Tim (nicht blockierend):** E8 (Training-Tab behält die Übungsliste), E4 (Kurs- und Cardio-Tag dürfen nicht zusammenfallen), E5 (Kurs nur als Wochentag).
