# Follow-along-Flows Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Mitglied startet in der App einen Follow-along-Flow (Zeitintervalle mit Timer), der aus einem ausgewerteten YouTube-Kurs entstanden ist, und der Abschluss wird gespeichert.

**Architecture:** Drei neue Tabellen (`flows`, `flow_steps`, `flow_runs`) mit RLS nach dem Muster von `workout_sessions`/`cardio_checks`, Domain-Funktionen und zwei API-Routen im bestehenden `/api/v1/me/*`-Stil, ein Importwerkzeug in `tools/flow-import` (Transkript bereinigen, Entwurf prüfen, idempotentes Seed-SQL erzeugen) und ein iOS-Teil mit reiner Zeitmaschine (`FlowAblauf`), Store mit Offline-Cache und drei Screens im Training-Tab.

**Tech Stack:** Supabase/Postgres, TypeScript (`packages/domain`, Next.js-Routen in `apps/web`, Vitest), Swift 6/SwiftUI (`apps/ios-member`), `yt-dlp`, `tsx`.

**Spec:** `docs/superpowers/specs/2026-11-26-follow-along-flows-design.md`

## Global Constraints

- Arbeitsbasis ist `origin/master`, nicht der aktuelle Zweig `codex/sensor-luecken-2026-10-26` (der liegt hinter master). Neuer Zweig/Worktree `feature/follow-along-flows` ab `origin/master`.
- Migration: nächste freie Nummer auf master (Stand 26.11.: `0078`; vor dem Anlegen mit `git ls-tree origin/master supabase/migrations/` prüfen).
- Code-Kommentare, Bezeichner in SQL/TS/Swift ohne Umlaute (`ue`, `ae`), Oberflächentexte mit Umlauten und auf Deutsch.
- Keine Texte, Namen oder Bilder des Trainers übernehmen. Beschreibungen der Schritte sind eigene Formulierungen, höchstens ein Satz.
- Die Quelle (`source_url`, `source_channel`) wird nur gespeichert, in v1 **nicht** in der App angezeigt.
- Mitglieder lesen Flows ihres Studios und schreiben nur eigene `flow_runs`. Flows entstehen nur über das Importwerkzeug.
- Auf Supabase-Prod wird eine Migration oder ein Seed nur nach ausdrücklicher Freigabe durch Tim im Chat angewendet (Task 10).
- Gesamtdauer eines Flows = Summe aller `work_s` + `rest_s`; der letzte Schritt hat `rest_s = 0`.

**Annahmen aus dem Entwurf (Tim kann sie ändern):** Einstieg im Training-Tab; Flows gelten pro Studio; keine Sprachansagen in v1; Quelle nicht sichtbar.

## Review Focus

1. **Dasselbe `flow_run` wird zweimal gesendet** (schlechtes Netz, Wiederholung): genau eine Zeile, zweite Antwort ebenfalls 204.
2. **Flow ohne Schritte, Schritt mit `work_s <= 0` oder negativer Pause:** Seed-Werkzeug und Datenbank lehnen ab.
3. **Mitglied eines anderen Studios** sieht keine Flows und kann keinen Run auf einen fremden Flow schreiben (404).
4. **App im Hintergrund oder Bildschirm gesperrt mitten im Flow:** die Restzeit stimmt beim Zurückkommen, weil sie aus der Uhrzeit berechnet wird und nicht aus gezählten Ticks.
5. **Abbrechen im Warm-up, im Countdown oder im letzten Schritt:** Countdown speichert nichts, sonst `aborted` mit richtigem `last_step`; Pause und Fortsetzen verschieben die Zeitpunkte nicht.

---

## Dateistruktur

| Datei | Verantwortung |
|---|---|
| `supabase/migrations/0078_follow_along_flows.sql` | Tabellen, RLS, Rechte |
| `packages/domain/src/flows.ts` (+ `flows.test.ts`) | Typen, Dauer, Run-Prüfung, Lesen/Schreiben |
| `apps/web/app/api/v1/me/flows/route.ts` | GET Flows des Mitglieds |
| `apps/web/app/api/v1/me/flow-runs/[runId]/route.ts` | PUT Run (idempotent) |
| `tools/flow-import/` | Transkript bereinigen, Entwurf prüfen, Seed-SQL, Testflow-JSON |
| `apps/ios-member/FitnessMember/Networking/DTOs/Flow.swift` | DTOs |
| `apps/ios-member/FitnessMember/Flows/FlowAblauf.swift` | reine Zeitmaschine |
| `apps/ios-member/FitnessMember/Flows/FlowStore.swift` | Laden, Cache, offene Runs |
| `apps/ios-member/FitnessMember/Screens/Flows/*.swift` | Liste, Detail, Lauf |

---

### Task 1: Migration und RLS

**Files:**
- Create: `supabase/migrations/0078_follow_along_flows.sql`
- Test: `tests/integration/db-flows.test.ts` (Muster: `tests/integration/api-kurse.test.ts` für Studio und Mitgliedschaft, `helpers/clients.ts`)

**Interfaces:**
- Produces: Tabellen `public.flows(id uuid pk default gen_random_uuid(), studio_id uuid not null → studios on delete cascade, key text not null, titel text not null, beschreibung text, level text null check in ('einsteiger','mittel','fortgeschritten'), source_url text, source_channel text, created_at timestamptz not null default now(), unique (studio_id, key))`, `public.flow_steps(flow_id uuid → flows on delete cascade, position int check >= 1, name text not null, beschreibung text, work_s int not null check > 0, rest_s int not null check >= 0, is_warmup boolean not null default false, primary key (flow_id, position))`, `public.flow_runs(id uuid primary key` ohne Default`, flow_id → flows on delete cascade, user_id → auth.users on delete cascade, studio_id → studios, started_at timestamptz not null, ended_at timestamptz not null, last_step int not null check >= 1, outcome text not null check in ('finished','aborted'), constraint ended_after_start check (ended_at >= started_at))`.

- [ ] **Step 1: Failing test** `db-flows.test.ts` mit diesen Fällen: (a) Mitglied von Studio A liest Flow und Schritte von A, Mitglied von Studio B sieht 0 Zeilen; (b) `authenticated` kann nicht in `flows`/`flow_steps` einfügen oder ändern (Fehler); (c) Mitglied schreibt eigenen `flow_run` mit gültigem Flow seines Studios; zweites Insert derselben `id` per `upsert(..., { ignoreDuplicates: true })` ergibt weiterhin eine Zeile; (d) Insert eines Runs mit fremdem `user_id` oder fremdem Studio scheitert; (e) `work_s = 0` und `position = 0` scheitern am Check.
- [ ] **Step 2:** `pnpm vitest run --config vitest.config.ts tests/integration/db-flows.test.ts` → FAIL ("relation public.flows does not exist").
- [ ] **Step 3: Migration schreiben** wie oben. RLS an allen drei Tabellen enable + force. Policies: `flows_select` und `flow_steps_select` (über `exists` auf `flows`) mit `public.is_studio_member(studio_id)`; `flow_runs_select_own` (`user_id = (select auth.uid())`), `flow_runs_insert_own` (`user_id = (select auth.uid())` und `is_studio_member(studio_id)` und der Flow gehört zu diesem Studio). Rechte nach dem Muster von `0071_cardio_checks.sql`: `revoke all` von `anon`/`public`, auf `authenticated` für `flows`/`flow_steps` nur `select`, für `flow_runs` nur `select, insert`.
- [ ] **Step 4:** Migration lokal anwenden (`pnpm supabase db reset` oder wie in `scripts/smoke-migrations.mjs`), Test erneut laufen lassen → PASS. Zusätzlich `pnpm smoke:migrations`.
- [ ] **Step 5: Commit** `feat(flows): Tabellen und RLS fuer Follow-along-Flows`

### Task 2: Domain-Funktionen

**Files:**
- Create: `packages/domain/src/flows.ts`, `packages/domain/src/flows.test.ts`
- Modify: `packages/domain/src/index.ts` (Export, wie bei `cardio-checks`)

**Interfaces:**
- Produces:
  - `type FlowSchritt = { position: number; name: string; beschreibung: string | null; workS: number; restS: number; istWarmup: boolean }`
  - `type Flow = { id: string; studioId: string; key: string; titel: string; beschreibung: string | null; level: "einsteiger" | "mittel" | "fortgeschritten" | null; schritte: FlowSchritt[]; dauerS: number }`
  - `type FlowRunEingabe = { id: string; flowId: string; startedAt: string; endedAt: string; lastStep: number; outcome: "finished" | "aborted" }`
  - `flowDauerS(schritte: Pick<FlowSchritt, "workS" | "restS">[]): number`
  - `pruefeFlowRun(run: FlowRunEingabe, schrittAnzahl: number): FlowRunEingabe` (wirft `DomainError("validation_failed", …)`)
  - `listFlows(client: SupabaseClient): Promise<Flow[]>` (Schritte nach `position` sortiert, Flows nach `titel`)
  - `recordFlowRun(client: SupabaseClient, userId: string, run: FlowRunEingabe): Promise<void>` (idempotent, 404-Fall als `DomainError("not_found", …)`; Fehlercodes in `errors.ts` nachsehen und den vorhandenen für „nicht gefunden" nehmen)

- [ ] **Step 1: Failing tests** in `flows.test.ts`: `flowDauerS([{workS:40,restS:20},{workS:40,restS:0}])` = 100; `pruefeFlowRun` lehnt ab: `lastStep` 0, `lastStep` > Schrittzahl, `endedAt` vor `startedAt`, `outcome: "finished"` mit `lastStep` ≠ Schrittzahl, keine UUID als `id`; akzeptiert `aborted` mit `lastStep` 3 von 20.
- [ ] **Step 2:** `pnpm --filter @fitretro/domain exec vitest run src/flows.test.ts` → FAIL.
- [ ] **Step 3: Implementieren.** Reine Funktionen zuerst; `listFlows` mit einer Abfrage `flows` + eingebetteten `flow_steps`; `recordFlowRun` lädt die Schrittzahl des Flows (nicht sichtbar → `not_found`), prüft, dann `upsert` mit `ignoreDuplicates: true`; `studio_id` des Runs kommt aus dem Flow.
- [ ] **Step 4:** Test → PASS, `pnpm typecheck`.
- [ ] **Step 5: Commit** `feat(flows): Domain-Funktionen fuer Flows und Runs`

### Task 3: API-Routen

**Files:**
- Create: `apps/web/app/api/v1/me/flows/route.ts`, `apps/web/app/api/v1/me/flow-runs/[runId]/route.ts`
- Test: `tests/integration/api-flows.test.ts` (Muster: `api-cardio-checks.test.ts`, `bearerFuer`)

**Interfaces:**
- Consumes: `listFlows`, `recordFlowRun`, `requireUserId`, `errorResponse`, `fromDomainError`, `bearerClientFrom` (wie in `cardio-checks/route.ts`).
- Produces: `GET /api/v1/me/flows` → `200 { flows: Flow[] }`, Header `cache-control: private, no-store`; `PUT /api/v1/me/flow-runs/{runId}` Body `{flowId, startedAt, endedAt, lastStep, outcome}` → `204`; `401` ohne Token, `422` (`validation_failed`) bei ungültigem Body, `404` bei unbekanntem/fremdem Flow.

- [ ] **Step 1: Failing tests:** 401 ohne Token (beide); GET liefert den Flow des eigenen Studios mit sortierten Schritten und `dauerS`; ein Nutzer ohne Mitgliedschaft bekommt `flows: []`; PUT zweimal mit gleicher `runId` → beide 204, eine Zeile in `flow_runs`; PUT mit fremdem Flow → 404; PUT mit `lastStep: 0` → 422; `runId` ohne UUID-Form → 422.
- [ ] **Step 2:** `pnpm vitest run --config vitest.config.ts tests/integration/api-flows.test.ts` → FAIL.
- [ ] **Step 3: Routen schreiben** im Stil von `cardio-checks/route.ts` (`dynamic = "force-dynamic"`, JSON-Rumpf prüfen, Typen der Felder prüfen).
- [ ] **Step 4:** Test → PASS; `pnpm typecheck`.
- [ ] **Step 5: Commit** `feat(flows): API fuer Flows und Run-Abschluss`

### Task 4: Importwerkzeug – Transkript und Entwurfsprüfung

**Files:**
- Create: `tools/flow-import/transkript.ts`, `tools/flow-import/entwurf.ts`, `tools/flow-import/entwurf.test.ts`, `tools/flow-import/transkript.test.ts`
- Modify: `vitest.config.ts` (nur falls `tools/**` nicht in `include` steht), `package.json` (Script `"flow:transkript": "tsx tools/flow-import/transkript.ts"`)

**Interfaces:**
- Produces:
  - `bereinigeVtt(vtt: string): string[]` → Zeilen `"m:ss Text"`; `<…>`-Tags und aufeinanderfolgende identische Zeilen werden entfernt, Platzhalter wie `[Musik]` bleiben stehen.
  - `type FlowEntwurf = { key: string; titel: string; beschreibung: string | null; level: "einsteiger" | "mittel" | "fortgeschritten" | null; quelle: { url: string; kanal: string }; schritte: { name: string; beschreibung: string | null; workS: number; restS: number; istWarmup: boolean; unsicher?: boolean }[] }`
  - `pruefeFlowEntwurf(e: unknown): FlowEntwurf` (wirft bei: keine Schritte, `workS <= 0`, `restS < 0`, leerer Name, `key` nicht `^[a-z0-9-]+$`, letzter Schritt mit `restS ≠ 0`)
- CLI `pnpm flow:transkript <youtube-url> <ausgabeordner>`: ruft `yt-dlp --skip-download --write-auto-subs --write-subs --sub-langs "de.*" --no-playlist` auf und schreibt `transkript.txt` mit `bereinigeVtt`. Bei HTTP 429 klare Fehlermeldung, kein Wiederholen in Schleife.

- [ ] **Step 1: Failing tests:** `bereinigeVtt` mit einem kleinen VTT-Ausschnitt (doppelte Rollzeilen, `<c>`-Tags, Zeitstempel `00:01:07.000 -->`) ergibt `["1:07 …"]` ohne Duplikate; `pruefeFlowEntwurf` wirft in den fünf genannten Fällen und akzeptiert einen gültigen Entwurf.
- [ ] **Step 2:** `pnpm vitest run tools/flow-import` → FAIL.
- [ ] **Step 3: Implementieren.** Die Logik von `bereinigeVtt` entspricht dem Skript aus dem Probelauf (Zeitstempel aus `HH:MM:SS.mmm -->`, Tags raus, aufeinanderfolgende Duplikate raus).
- [ ] **Step 4:** Tests → PASS.
- [ ] **Step 5: Commit** `feat(flows): Importwerkzeug fuer Transkript und Entwurfspruefung`

### Task 5: Seed-SQL erzeugen und Testflow

**Files:**
- Create: `tools/flow-import/flow-sql.ts`, `tools/flow-import/flow-sql.test.ts`, `tools/flow-import/flows/hiit-20-min.json`
- Modify: `package.json` (Script `"flow:sql": "tsx tools/flow-import/flow-sql.ts"`)

**Interfaces:**
- Consumes: `FlowEntwurf`, `pruefeFlowEntwurf` (Task 4).
- Produces: `flowZuSql(e: FlowEntwurf, studioId: string): string` – idempotent (`insert … on conflict (studio_id, key) do update`, Schritte werden für diesen Flow gelöscht und neu geschrieben, alles in einer Transaktion), wirft solange ein Schritt `unsicher: true` hat. `studioId` muss UUID sein, SQL-Strings werden mit verdoppelten Hochkommata maskiert. CLI: `pnpm flow:sql <flow.json> --studio <uuid>` schreibt SQL auf stdout.

- [ ] **Step 1: Failing tests:** `flowZuSql` enthält je Schritt ein Insert mit `position` ab 1; ein Name mit Hochkomma (`Farmer's`) wird maskiert; mit `unsicher: true` wirft es; ungültige Studio-ID wirft; zweimal erzeugen ergibt identischen Text. Test für die Datei: `hiit-20-min.json` besteht `pruefeFlowEntwurf`, hat 20 Schritte, genau 3 mit `istWarmup`, `flowDauerS`-Summe 1180 (20 × 40 + 19 × 20), und genau zwei Schritte (Nr. 7 Squat-Pulse, Nr. 14 Weitsprung) mit `unsicher: true`.
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: Implementieren** `flowZuSql`; **`hiit-20-min.json` schreiben** mit `key: "hiit-20-min"`, `titel: "HIIT 20 Minuten"`, `level: "mittel"`, Quelle `https://www.youtube.com/watch?v=dS4uUM5UfOA` / Kanal `Sascha Huber`. Schritte in dieser Reihenfolge, je `workS: 40`, `restS: 20` (letzter `0`), Warm-up die ersten drei: High Kicks, Slow Burpees, Jumping Jacks, Toe Touches + Jackknifes, Mini Scissor Kicks, Burpees mit Oberschenkel-Berührung, Squat-Pulse (`unsicher`), Plank, Swimmer, Russian Twist, Lunge + Kick, Liegestütze, Leg Drop & Pull, Weitsprung mit Bodenberührung (`unsicher`), Squat mit Händen zum Boden, Plank mit Knie zur Brust, Flutter Kicks, Skater Jumps, Crunch-Halten, Burpees mit Streckung. Jede `beschreibung` selbst formuliert, ein Satz, nicht aus dem Transkript.
- [ ] **Step 4:** Test → PASS. `pnpm flow:sql tools/flow-import/flows/hiit-20-min.json --studio <uuid>` muss wegen `unsicher` mit klarer Meldung abbrechen.
- [ ] **Step 5: Commit** `feat(flows): Seed-SQL-Erzeugung und Testflow HIIT 20 Minuten`

### Task 6: iOS – DTOs und Zeitmaschine

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/Flow.swift`, `apps/ios-member/FitnessMember/Flows/FlowAblauf.swift`
- Test: `apps/ios-member/FitnessMemberTests/FlowAblaufTests.swift`, `…/FlowDTOTests.swift` (Stil von `AblaufListeTests.swift`)

**Interfaces:**
- Produces:
  - `struct FlowSchritt: Codable, Equatable, Identifiable { position, name, beschreibung: String?, workS: Int, restS: Int, istWarmup: Bool }`, `struct Flow: Codable, Equatable, Identifiable { id, studioId, key, titel, beschreibung: String?, level: String?, schritte: [FlowSchritt], dauerS: Int }`, `struct FlowRunEingabe: Codable, Equatable { id, flowId, startedAt, endedAt, lastStep: Int, outcome: String }` (Feldnamen wie die JSON-Antwort aus Task 3; ISO-8601-Strings).
  - `enum FlowZustand: Equatable { case countdown(restS: Int); case arbeit(schritt: Int, restS: Int); case pause(naechster: Int, restS: Int); case fertig }` (`schritt`/`naechster` 0-basiert).
  - `struct FlowAblauf { static let countdownS = 3; init(schritte: [FlowSchritt]); func zustand(nachS vergangen: Double) -> FlowZustand; var gesamtS: Int }` – `restS` ist aufgerundet; Schritte mit `restS == 0` haben keine Pause.

- [ ] **Step 1: Failing tests** mit 3 Schritten (40/20, 40/20, 40/0): `zustand(0)` = `.countdown(3)`; `2.1` = `.countdown(1)`; `3.0` = `.arbeit(0, 40)`; `42.9` = `.arbeit(0, 1)`; `43.0` = `.pause(naechster: 1, restS: 20)`; `63.0` = `.arbeit(1, 40)`; `123.0` = `.arbeit(2, 40)`; `163.0` = `.fertig` (3 + 160); `gesamtS` = 160; negative Eingabe verhält sich wie 0. DTO-Test: JSON-Beispiel aus Task 3 dekodiert zu `Flow` mit 20 Schritten.
- [ ] **Step 2:** `xcodebuild test -project apps/ios-member/FitnessMember.xcodeproj -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:FitnessMemberTests/FlowAblaufTests` → FAIL. (Falls das Xcode-Projekt aus `project.yml` erzeugt wird: vorher `xcodegen generate` im Ordner `apps/ios-member`.)
- [ ] **Step 3: Implementieren.** `zustand` rechnet über kumulierte Grenzen, keine Tick-Zähler.
- [ ] **Step 4:** Tests → PASS.
- [ ] **Step 5: Commit** `feat(flows): iOS-DTOs und Zeitmaschine fuer Follow-along`

### Task 7: iOS – Store mit Cache und offenen Runs

**Files:**
- Create: `apps/ios-member/FitnessMember/Flows/FlowStore.swift`
- Test: `apps/ios-member/FitnessMemberTests/FlowStoreTests.swift`
- Vorlage lesen: `Kurse/KurseStore.swift`, `Kurse/KurseFileStore.swift`, `docs/superpowers/specs/2026-10-15-offline-stabilitaet-design.md`

**Interfaces:**
- Consumes: `APIClient` (Aufruf-Muster aus `KurseStore`), DTOs aus Task 6.
- Produces: `@Observable final class FlowStore { init(apiClient: APIClient, dateiStore: …); var flows: [Flow]; func laden() async; func runAbschliessen(_ run: FlowRunEingabe) async; func offeneRunsSenden() async }` – `laden()` zeigt erst den Cache (Datei `flows.json`) und ersetzt ihn bei Erfolg; offene Runs liegen in `flow-runs-offen.json`, `PUT /me/flow-runs/{id}` ist idempotent, daher darf jeder Start sie erneut senden.

- [ ] **Step 1: Failing tests** mit gefälschtem APIClient und Dateistore wie in den Kurse-Tests: Laden ohne Netz zeigt zuvor gecachte Flows; `runAbschliessen` bei Netzfehler lässt den Run in der offenen Liste, ein späteres `offeneRunsSenden()` sendet ihn und leert die Liste; derselbe Run zweimal gesendet erzeugt keine zweite Liste.
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: Implementieren** nach dem Muster der Kurse.
- [ ] **Step 4:** Tests → PASS.
- [ ] **Step 5: Commit** `feat(flows): FlowStore mit Cache und offenen Runs`

### Task 8: iOS – Screens und Einstieg

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Flows/FlowListeView.swift`, `FlowDetailView.swift`, `FlowLaufView.swift`, `apps/ios-member/FitnessMember/Flows/FlowLauf.swift` (`@Observable`-Zustand des Laufs)
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (Zeile/Karte „Flows", die `FlowListeView` pusht)
- Test: `apps/ios-member/FitnessMemberTests/FlowLaufTests.swift`

**Interfaces:**
- Consumes: `FlowAblauf`, `FlowStore`, `FlowRunEingabe`.
- Produces: `@Observable final class FlowLauf { init(flow: Flow, jetzt: @escaping () -> Date); func starten(); func pausieren(); func fortsetzen(); func abbrechen() -> FlowRunEingabe?; var zustand: FlowZustand; func abgeschlossenerRun() -> FlowRunEingabe? }` – verstrichene Zeit = `jetzt() − start − pausiert`. `abbrechen()` liefert `nil` im Countdown, sonst `outcome: "aborted"` mit `lastStep` = laufender Schritt (1-basiert, in der Pause der gerade beendete).

- [ ] **Step 1: Failing tests** für `FlowLauf` mit steuerbarer Uhr: Start, nach 5 s `.arbeit(0, …)`; 10 s Pause, dann Fortsetzen: Restzeit unverändert; Abbrechen bei 1 s → `nil`; Abbrechen in Schritt 3 → `aborted`, `lastStep == 3`; nach Ablauf aller Schritte `abgeschlossenerRun()` mit `finished` und `lastStep == schritte.count`; Uhr springt 5 min vor (App im Hintergrund) → `.fertig`, kein Absturz.
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3: `FlowLauf` implementieren**, dann Views: Liste (Titel, Dauer in Minuten, Schrittzahl, Level), Detail (Schrittliste, „Starten"), Lauf (Countdown 3-2-1, Arbeitsphase mit Name, Beschreibung, Ring mit Restzeit und „Als Nächstes: …", Pause mit großer nächster Übung, Fertig mit Dauer und Schrittzahl, Haptik beim Phasenwechsel, `UIApplication.shared.isIdleTimerDisabled` an/aus, Pause- und Abbrechen-Knopf mit Rückfrage). Ende ruft `FlowStore.runAbschliessen`. Aufbau aus `Screens/Training/PausenScreen.swift` und dem Designsystem (`docs/superpowers/specs/2026-08-30-designsystem.md`) übernehmen. Der Timer der View liest nur `FlowLauf.zustand` (z. B. `TimelineView(.periodic(from:by:0.25))`).
- [ ] **Step 4:** Tests → PASS; App im Simulator bauen (`xcodebuild build`, danach Kontrolle in Task 9).
- [ ] **Step 5: Commit** `feat(flows): Screens und Einstieg im Training-Tab`

### Task 9: Gesamtprobe lokal

- [ ] **Step 1:** Lokale Supabase starten, Migration angewendet, Studio und Testmitglied vorhanden. Aus `hiit-20-min.json` für die Probe eine Kopie ohne `unsicher`-Flags erzeugen (nur lokal, nicht committen), `pnpm flow:sql … --studio <lokale-studio-id>` und das SQL lokal ausführen.
- [ ] **Step 2:** Web-API lokal starten, iOS-App im Simulator gegen den lokalen Server starten, den Flow komplett durchlaufen lassen (Beschleunigung per Debug-Uhr ist nicht nötig; Abbruch in Schritt 3 und vollständiger Lauf je einmal), danach in `flow_runs` prüfen: je eine Zeile, `finished` bzw. `aborted` mit `last_step = 3`. Screenshots von Liste, Arbeit, Pause und Fertig ansehen.
- [ ] **Step 3:** `pnpm test`, `pnpm test:integration`, `pnpm typecheck` und der komplette iOS-Testlauf grün. Ergebnis im Chat berichten, auch Fehlschläge.

### Task 10: Auf Prod bringen (nur nach Freigabe)

- [ ] **Step 1:** Tim im Chat um Freigabe bitten: Migration `0078`, Seed des Flows in das gewünschte Studio, API-Deploy (Vercel). Namen der zwei unsicheren Schritte (Squat-Pulse, Weitsprung mit Bodenberührung) von Tim bestätigen lassen, danach `unsicher` entfernen.
- [ ] **Step 2 (nur bei „Ja"):** Migration über den Supabase-Connector anwenden, Seed-SQL ausführen, `list_tables` bzw. eine Zählabfrage prüfen, API deployen.
- [ ] **Step 3:** Memory-Eintrag zum Projektstand schreiben (neue Datei `project_follow-along-flows.md`, Index in `MEMORY.md`).

---

## Selbstkontrolle

- **Spec-Abdeckung:** Datenmodell (Task 1), Importweg (Tasks 4, 5), App-Ablauf mit Countdown, Arbeit, Pause, Fertig, Abbruch (Tasks 6, 8), Offline-Laden (Task 7), Tracking mit `flow_runs` (Tasks 1–3, 7), Einstieg im Training-Tab (Task 8), Prod nur mit Freigabe (Task 10). Nicht-Ziele (Katalog, Sensorik, Plan, Trainerportal) kommen nirgends vor.
- **Abweichung vom Spec:** `duration_s` wird nicht gespeichert (Task 2, `flowDauerS`); Spec ist angepasst.
- **Offen für Tim:** Quelle sichtbar?, Einstieg im Training-Tab, Sprachansagen später, die zwei „mittel sicheren" Übungsnamen.
