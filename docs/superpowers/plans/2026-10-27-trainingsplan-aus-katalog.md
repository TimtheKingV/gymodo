# Trainingsplan aus dem Gymtavo-Katalog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Mitglied hat genau einen Trainingsplan, gebaut aus dem Gymtavo-Katalog und nutzbar ohne Studio (Freies Training); eine Position ist eine Übungsart, das Gewicht hängt an der Übung, und das Entfernen einer Übung fragt nach dem Grund und merkt ihn.

**Architecture:** Der Plan bleibt eine Zeile in `training_plans`, gehört aber immer dem Katalog-Studio (`studios.is_catalog`); damit passen Sessions, `record_session_plan` und `plan_gewichte` ohne Schemabruch (das Freie Training läuft schon dort). Eine Position nennt `exerciseId` und `modelId` (Katalog-Gerätemodell für Grenzen und Bild) statt `machineId`. Eine neue Tabelle `plan_merkliste` hält „nicht vorhanden“ (je Ort) und „gefällt mir nicht“ (je Mitglied). Server zuerst, dann iOS.

**Tech Stack:** Postgres/Supabase-Migrationen (ab `0066`), TypeScript in `packages/domain` (vitest) und `apps/web` (API), SwiftUI in `apps/ios-member` (Swift Testing, XcodeGen).

**Spec:** `docs/superpowers/specs/2026-10-27-trainingsplan-aus-katalog-design.md` (ersetzt F20 aus `2026-10-21-trainingsplan-design.md`). Hintergrund: `2026-10-25-trainingsplan-plangewichte-design.md`, Übergabe `docs/superpowers/plans/2026-10-27-trainingsplan-nach-etappe5-uebergabe.md`.

## Global Constraints

- Ein Plan je Mitglied, immer mit `studio_id` = Katalog-Studio; kein Studioplan, kein zweiter Plan (Spec, Entscheidung 1). Harter Wechsel: bestehende Pläne werden verworfen und neu erzeugt, kein Doppelformat.
- Eine Position ist eine Übungsart; welches Gerät das Mitglied nimmt, ist egal; fehlt die Übung im Studio, überspringt es sie (Entscheidung 2).
- Grund beim Entfernen: **nicht vorhanden** = am aktiven Ort nie wieder anbieten (Ort = Studio oder Freies Training = Katalog-Studio); **gefällt mir nicht** = nie mehr erste Wahl, nur optionale Alternative, gilt für das Mitglied überall; **belegt** = nur heute ersetzen, nichts merken (bestehender „nur heute“-Tausch). Die Merkliste sperrt Übungen (`exercise_id`), nie Modelle.
- Zielgewicht hängt an der Übung: Grenzen und Stufen vom Katalogmodell, nächster Wert aus dem letzten Satz dieser Übung an jedem Gerät, auch aus dem Freien Training (Sätze ohne `machine_id`).
- Ein Zähler für Einheiten und Anfängerübergang (8 Einheiten) über alle Sessions mit Plan, egal in welchem Studio.
- Regeln nur serverseitig (F15); die App filtert und zeigt nur.
- Jede Etappe einzeln auslieferbar, solange Prod bei `0065` steht: Datenbank und Server zuerst, dann App. Prod hat keinen Plan (27.10. geprüft, vor Beginn erneut prüfen).
- Prod-Aktionen (Migrationen ab `0066`, Deploy, Push, PR, Merge) nur mit ausdrücklicher Freigabe von Tim, jeweils einzeln. `supabase db push` geht gegen Prod nicht (Zeitstempel-Versionen 0057–0061); Migrationen dort per MCP `apply_migration`.
- Datenschutz: Beschwerden und Merkliste nie in Log, Testnotiz-Kontext oder Analyse; Beschwerden-Codes verlassen den Server nicht.
- Tests: `pnpm --filter @fitretro/domain test -- <datei>`, `pnpm test:integration -- <datei>` (Datenbank, einzeln laufen lassen), Swift: `cd apps/ios-member && xcodegen generate`, dann `xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,id=<ID>" test -only-testing:FitnessMemberTests/<Typname>` (ID über `xcrun simctl list devices available`, es gibt zwei „iPhone 17 Pro“; Filter ist der **Typname**, ein falscher Filter führt 0 Tests aus und meldet trotzdem „TEST SUCCEEDED“, immer die Zeile „Test run with N tests“ lesen).
- Debug-Build der App zeigt auf Prod: Tests nur mit Testkonto.

## Review Focus

- Mitglied ohne Studio bekommt Plan, nimmt ihn an und trainiert im Freien Training: Session, `record_session_plan`, Zielgewichte und Zähler funktionieren (Task 1, 4, 5, 7).
- „Nicht vorhanden“ in Studio A gilt nicht in Studio B und nicht im Freien Training (Task 2, 5, 8).
- „Gefällt mir nicht“ erscheint nie als erste Wahl im neuen Plan, bleibt aber als letzte Alternative wählbar; gibt es keine andere Übung des Bausteins, erscheint sie trotzdem statt eines Fehlers (Task 3, 5).
- Sätze derselben Übung an zwei Geräten, Sätze ohne Gerät und Sätze alter Studio-Sessions fließen in dasselbe Zielgewicht ein, ohne dass es springt (Task 4).
- Alter Studioplan oder Plan mit `machineId`-Positionen in der Datenbank: wird nicht mehr geliefert und blockiert die Neuerzeugung nicht (Task 1, 5).

---

### Task 1: Katalogplan in der Datenbank (Migration `0066_plan_aus_katalog.sql`)

**Files:**
- Create: `supabase/migrations/0066_plan_aus_katalog.sql`
- Test: `tests/integration/rls-plan-katalog.test.ts` (neu, Stil von `rls-plan-gewichte.test.ts`); anpassen: `tests/integration/plan-schreibwege.test.ts`, `tests/integration/session-plan.test.ts`

**Interfaces:**
- Consumes: `public.is_catalog_studio(uuid)` (0047), `training_plans` (0061), `create_training_plan`, `accept_training_plan`, `swap_training_plan_position`, `training_plan_pruefen` (0062/0065), `record_session_plan` (0063), `set_plan_gewichte`/`init_plan_gewichte` (0064).
- Produces:
  - `training_plan_pruefen(p_studio_id uuid, p_einheiten jsonb) returns void`: jede Position nennt `exerciseId` und `modelId`; `modelId` muss ein `equipment_models` des **Katalog-Studios** sein und die Übung über `equipment_model_exercises` tragen; `p_studio_id` muss das Katalog-Studio sein, sonst `plan_ungueltig`. Vergleich weiter als Text.
  - `create_training_plan(...)` und `accept_training_plan(uuid)`: erlaubt für das Katalog-Studio ohne Mitgliedschaft; jedes andere Studio → `plan_ungueltig`.
  - `swap_training_plan_position(p_plan_id uuid, p_einheit_key text, p_position_key text, p_exercise_id uuid, p_model_id uuid, p_vorgaben jsonb) returns training_plans`: die alte Signatur mit `p_machine_id` wird **entfernt**; sonst unverändert (Typ-Vorgaben wie 0065).
  - Policies `training_plans_insert_own`/`_update_own`: `is_studio_member(studio_id) or is_catalog_studio(studio_id)`.
  - `record_session_plan`, `set_plan_gewichte`, `init_plan_gewichte`: Bedingung `studio_id = v_session.studio_id` wird zu `public.is_catalog_studio(studio_id)` (der Plan gehört dem Katalog, die Session kann in jedem Studio laufen).
  - Bestehende Pläne anderer Studios werden `verworfen` (Status), `plan_gewichte` bleibt unberührt.

- [ ] **Step 1: Failing Integrationstest** `rls-plan-katalog.test.ts`, Fälle (jeweils mit Testmitglied ohne Studiomitgliedschaft):
  - `legt Plan fuer das Katalog-Studio an und nimmt ihn an`: `create_training_plan` mit Einheiten, deren Position `{exerciseId, modelId}` eines Katalogmodells nennt → `status 'vorschlag'`, `accept_training_plan` → `'aktiv'`.
  - `lehnt ein normales Studio ab`: `create_training_plan` mit `p_studio_id` eines Studios, in dem das Mitglied Mitglied ist → Fehler `plan_ungueltig`.
  - `lehnt Position mit machineId oder fremdem Modell ab`: Position ohne `modelId`, mit `machineId`, mit Modell eines normalen Studios → `plan_ungueltig`.
  - `swap tauscht ohne Mitgliedschaft`: neue Version aktiv, Position trägt das neue `modelId`; alte 6-Argument-Fassung mit `p_machine_id` ist nicht mehr aufrufbar (Fehler `PGRST202`).
  - `record_session_plan verknuepft eine Studio-Session mit dem Katalogplan` (Session in einem normalen Studio, `plan_id` = Katalogplan) → Erfolg.
- [ ] **Step 2: Test laufen lassen, muss fehlschlagen**
  Run: `pnpm test:integration -- rls-plan-katalog`
  Expected: FAIL (u. a. `kein_mitglied` / `plan_ungueltig` beim Katalog-Studio).
- [ ] **Step 3: Migration `0066` schreiben** nach den Signaturen oben; `create or replace` für bestehende Funktionen, `drop function ... swap_training_plan_position(uuid, text, text, uuid, uuid, jsonb)` vor der neuen (andere Parameternamen, gleiche Typen: Namensänderung braucht `drop`), `revoke`/`grant` wie in 0062/0065. Verwerfen: `update training_plans set status='verworfen' where studio_id not in (select id from studios where is_catalog) and status in ('vorschlag','aktiv')`.
- [ ] **Step 4: Anwenden und Test grün**
  Run: Migration lokal anwenden (wie in der Etappe-4-Übergabe beschrieben), dann `pnpm test:integration -- rls-plan-katalog` und zur Regression einzeln `pnpm test:integration -- plan-schreibwege`, `-- session-plan`, `-- rls-plan-gewichte`, `-- api-workout-sets`. Von Hand prüfen: ein vor der Migration angelegter Plan eines normalen Studios hat danach den Status `verworfen` (Ergebnis im Ledger).
  Expected: PASS. Die bestehenden Tests `plan-schreibwege` und `session-plan` nutzen Studiopläne und Geräte; sie sind in diesem Task auf Katalogpläne umzustellen (gleiche Fälle, `modelId` statt `machineId`, Katalog-Studio statt Studio). `api-workout-sets` „beendet die eigene Session“ ist als flackernd bekannt (dann Docker-Auth neu starten).
- [ ] **Step 5: Commit**
  ```bash
  git add supabase/migrations/0066_plan_aus_katalog.sql tests/integration/rls-plan-katalog.test.ts
  git commit -m "feat(db): Trainingsplan gehoert dem Katalog-Studio (0066)"
  ```

---

### Task 2: Merkliste in der Datenbank (Migration `0067_plan_merkliste.sql`)

**Files:**
- Create: `supabase/migrations/0067_plan_merkliste.sql`
- Test: `tests/integration/rls-plan-merkliste.test.ts`

**Interfaces:**
- Consumes: `exercises`, `studios`, `studio_memberships`, `is_catalog_studio`, `is_studio_member` (Vorbild für Policies: `training_limits` in 0060).
- Produces: Tabelle `public.plan_merkliste (user_id uuid, exercise_id uuid, art text, studio_id uuid null, created_at timestamptz)`; `art in ('nicht_vorhanden','gefaellt_nicht')`; Check: `nicht_vorhanden` verlangt `studio_id` (Studio oder Katalog-Studio für das Freie Training), `gefaellt_nicht` verlangt `studio_id is null`; Unique `(user_id, exercise_id, art, coalesce(studio_id, '00000000-0000-0000-0000-000000000000'))`; RLS `force`, Policies „eigene Zeilen“ für select/insert/delete; Insert mit `studio_id` nur, wenn `is_studio_member(studio_id) or is_catalog_studio(studio_id)`; kein Update.

- [ ] **Step 1: Failing Test** `rls-plan-merkliste.test.ts`: `schreibt und liest eigene Zeilen`; `liest fremde Zeilen nicht`; `nicht_vorhanden ohne studio_id wird abgelehnt`; `gefaellt_nicht mit studio_id wird abgelehnt`; `nicht_vorhanden fuer fremdes Studio wird abgelehnt`; `nicht_vorhanden fuer das Katalog-Studio ist erlaubt` (Freies Training); `doppelte Zeile ergibt 23505`; `anon sieht nichts`.
- [ ] **Step 2: Test laufen lassen, muss fehlschlagen**
  Run: `pnpm test:integration -- rls-plan-merkliste`
  Expected: FAIL (Relation fehlt).
- [ ] **Step 3: Migration `0067` schreiben** (Tabelle, Checks, Index, RLS, Policies; `revoke all from anon`).
- [ ] **Step 4: Anwenden, Test grün**
  Run: Migration lokal anwenden, `pnpm test:integration -- rls-plan-merkliste`
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add supabase/migrations/0067_plan_merkliste.sql tests/integration/rls-plan-merkliste.test.ts
  git commit -m "feat(db): Merkliste fuer Planuebungen (0067)"
  ```

---

### Task 3: Kandidaten und Plan aus dem Katalog erzeugen

**Files:**
- Modify: `packages/domain/src/trainingsplan-auswahl.ts` (Typ `Kandidat`), `trainingsplan-generator.ts` (Typ `PlanPosition`), `trainingsplan-kandidaten.ts`, `trainingsplan.ts` (`erzeugePlanVorschlag`, `acceptPlan`, `tauschePlanPosition`, `PlanTausch`, `aktivePlaeneDerMitgliedschaften`, `aktiverPlanImStudio`, `listPlaene`)
- Test: `packages/domain/src/trainingsplan-generator.test.ts` (Auswahl-Fälle), `tests/integration/trainingsplan-kandidaten.test.ts`, `tests/integration/domain-trainingsplan.test.ts` (bestehende Dateien erweitern)

**Interfaces:**
- Consumes: Migration 0066/0067 (Task 1, 2); `uebungenMitKatalog` (`bootstrap.ts`).
- Produces:
  - `Kandidat = { exerciseId: string; modelId: string; baustein; typ; bereiche; hauptmuskeln }` (`machineId` entfällt); `PlanPosition.machineId` wird `modelId: string`.
  - `ladeKatalogStudioId(client): Promise<string>` (wirft `internal`, wenn es kein Katalog-Studio gibt).
  - `ladeKandidaten(client: SupabaseClient, merkliste: Merkliste): Promise<Kandidat[]>`: ein Kandidat je Übung mit Planfreigabe (`plan_baustein` und `plan_typ` gesetzt), `modelId` = das erste Katalogmodell der Übung nach `sort_order` (dann Modell-ID), sortiert nach `exerciseId` (Determinismus). Übungen mit `nicht_vorhanden` am Ort fallen weg; Übungen mit `gefaellt_nicht` bleiben, tragen aber `gefaelltNicht: true` und werden von `waehleKandidat`/`waehleFokus` nur gewählt, wenn es keine andere Übung des Bausteins gibt (wie „vorsichtig“ hinten).
  - `type Merkliste = { nichtVorhanden: string[]; gefaelltNicht: string[] }` (Übungs-IDs für den aktiven Ort bzw. überall) und `ladeMerkliste(client, userId, ortId: string): Promise<Merkliste>`.
  - `erzeugePlanVorschlag(client, userId, ortId?: string): Promise<TrainingPlan>`: `studio_id` des Plans ist immer das Katalog-Studio; `ortId` (Studio oder Katalog-Studio, Standard Katalog-Studio) bestimmt nur die Merkliste; ist `ortId` ein normales Studio, muss das Mitglied dort Mitglied sein (sonst `not_found`). Kein `requireMitglied` für das Katalog-Studio.
  - `ladeGezaehlteEinheiten(client, userId, jetzt)` (Parameter `studioId` entfällt, kein Filter nach Studio) und alle Aufrufer.
  - `aktiverKatalogPlan(client, userId): Promise<TrainingPlan | null>` ersetzt `aktivePlaeneDerMitgliedschaften` und `aktiverPlanImStudio` (nur Katalog-Studio, kein Filter über Mitgliedschaften).
  - `PlanTausch = { einheitKey; positionKey; exerciseId; modelId }`, RPC-Aufruf mit `p_model_id`.

- [ ] **Step 1: Failing Tests:**
  - `tests/integration/trainingsplan-kandidaten.test.ts` (Datenbank): `liefert einen Kandidaten je Uebung mit dem ersten Katalogmodell`; `laesst nicht_vorhanden am Ort weg`; `markiert gefaellt_nicht` (`gefaelltNicht: true`); `ohne Katalogmodelle: leere Liste`.
  - `trainingsplan-generator.test.ts` (rein): `waehleKandidat nimmt gefaelltNicht nur ohne Alternative`; `waehleFokus ebenso`; `nur gefaelltNicht-Kandidaten gelten fuer einen Pflichtbaustein als vorhanden` (kein `kein_geraet`).
  - `tests/integration/domain-trainingsplan.test.ts`: `erzeugt einen Plan ohne Mitgliedschaft im Katalog-Studio`; `Ort ohne Mitgliedschaft ergibt not_found`; `Positionen tragen modelId und kein machineId`; `aktiverKatalogPlan liefert hoechstens einen Plan`.
- [ ] **Step 2: Tests laufen lassen, müssen fehlschlagen**
  Run: `pnpm --filter @fitretro/domain test -- trainingsplan-generator` und `pnpm test:integration -- trainingsplan-kandidaten`, `-- domain-trainingsplan`
  Expected: FAIL (Typen/Funktionen fehlen).
- [ ] **Step 3: Implementieren** nach den Signaturen oben. Der Generator selbst bleibt unverändert außer dem Durchreichen von `modelId` statt `machineId` (Z. 39, 119, 277 in `trainingsplan-generator.ts`). `Kandidat.gefaelltNicht?: boolean` ist optional.
- [ ] **Step 4: Tests grün, dazu Typprüfung**
  Run: `pnpm --filter @fitretro/domain test && pnpm --filter @fitretro/domain typecheck` und die beiden Integrationstests aus Step 2
  Expected: PASS; Aufrufer in `apps/web` und `plangewichte.ts` melden Typfehler, die Task 4/5 beheben. In diesem Task nur die Dateien im Kopf anpassen und die Fehler der anderen im Ledger benennen.
- [ ] **Step 5: Commit**
  ```bash
  git add packages/domain/src
  git commit -m "feat(domain): Plan aus dem Katalog erzeugen, Merkliste-Filter"
  ```

---

### Task 4: Zielgewichte je Übung

**Files:**
- Modify: `packages/domain/src/plangewichte.ts` (`paarSchluessel`, `ladeGrenzen`, `ladeArbeitssaetze`, `ladeLetzteVor`, `aktualisierePlanGewichte`, `initialisierePlanGewichte`, `uebernehmePlanGewichte`, `ladeZielgewichte`, `zielFuerGeraet`, `ladeNachzuholende` in `trainingsplan-bootstrap.ts`)
- Test: `packages/domain/src/plangewichte.test.ts` und `plangewicht-start.test.ts` (erweitern), `tests/integration/domain-plangewichte.test.ts`

**Interfaces:**
- Consumes: `Position.modelId`, `Kandidat` (Task 3); Tabellen `workout_sets` (`machine_id` nullable, `exercise_id`), `equipment_models(load_step, load_min, load_max, load_start)`.
- Produces:
  - `uebungsSchluessel(exerciseId: string): string` ersetzt `paarSchluessel(machineId, exerciseId)`.
  - `ladeGrenzen(client, modelIds: string[]): Promise<Map<string, Grenzen>>` liest direkt `equipment_models` (Katalogmodelle), nicht mehr über `machines`; Modell ohne einstellbare Stufe (`load_step` nicht > 0) liefert kein Ziel (wie bisher bei Cardio).
  - Satzverlauf je Übung: Abfrage nach `exercise_id` ohne Filter auf `machine_id`, Sätze mit und ohne Gerät zählen; sonst unverändert (`set_role = 'arbeit'`, mit Last, Fenster 43 Tage, Seiten).
  - `zielFuerGeraet(...)` heißt `zielFuerPosition(zielgewichte, einheitKey, positionKey)`; `vorschlagAusZiel` nimmt die Grenzen des Positionsmodells.
  - Regelversion: rechnet die Regel gleich, bleibt `PLANGEWICHT_ALGO_VERSION`; ändern sich Startwerte (Fallback `load_start` des Katalogmodells, wenn kein Verlauf), `STARTSCHAETZUNG_VERSION` erhöhen und im Ledger vermerken.

- [ ] **Step 1: Failing Tests:**
  - `plangewichte.test.ts`: `rechnet aus Saetzen derselben Uebung an zwei Geraeten`; `zaehlt Saetze ohne Geraet`; `Grenzen kommen vom Katalogmodell der Position`; `Uebung ohne einstellbare Stufe hat kein Ziel`; `Gewicht springt nicht, wenn das letzte Gewicht aus einem anderen Geraet stammt` (Ziel bleibt die Folge aus `berechnePlanGewicht`, kein Sprung über `loadMax`/Stufen).
  - `plangewicht-start.test.ts`: `ohne Verlauf: Start aus load_start des Katalogmodells, gerundet auf die Stufe`.
  - `domain-plangewichte.test.ts`: `Satz im Freien Training (machine_id null) fuehrt zum Ziel der naechsten Einheit`.
- [ ] **Step 2: Tests laufen lassen, müssen fehlschlagen**
  Run: `pnpm --filter @fitretro/domain test -- plangewicht && pnpm test:integration -- domain-plangewichte`
  Expected: FAIL.
- [ ] **Step 3: Implementieren** nach den Signaturen; `machine_id`-Filter (Zeilen 203–208, 413–418, 709–714) und `Map`-Schlüssel (Z. 69) auf die Übung umstellen.
- [ ] **Step 4: Tests grün**
  Run: wie Step 2 plus `pnpm --filter @fitretro/domain test`
  Expected: PASS.
- [ ] **Step 5: Commit**
  ```bash
  git add packages/domain/src tests/integration/domain-plangewichte.test.ts
  git commit -m "feat(domain): Zielgewichte je Uebung statt je Geraet"
  ```

---

### Task 5: Bootstrap, API und Entfernen mit Grund

**Files:**
- Modify: `packages/domain/src/trainingsplan-bootstrap.ts` (`PlanAlternative`, `PlanFuerApp`, `alternativenJeBaustein`, `ladePlaeneFuerApp`, `ladeNachzuholende`), `packages/domain/src/bootstrap.ts` (Plan-Teil), `apps/web/app/api/v1/me/plans/route.ts`, `[id]/accept/route.ts`, `[id]/swap/route.ts`
- Test: `packages/domain/src/trainingsplan-bootstrap.test.ts`, `tests/integration/api-plans.test.ts` (Swap und Erzeugen über die Routen), `tests/integration/plan-schreibwege.test.ts`

**Interfaces:**
- Consumes: Task 3 (`aktiverKatalogPlan`, `ladeKandidaten`, `ladeMerkliste`, `ladeGezaehlteEinheiten`), Task 4 (`ladeZielgewichte`), Tabelle `plan_merkliste` (Task 2).
- Produces:
  - `PlanAlternative = { exerciseId: string; modelId: string }`.
  - `PlanFuerApp.studioId` ist die Katalog-Studio-ID; `member.plans` im Bootstrap enthält höchstens einen Plan; dazu `PlanFuerApp.merkliste: { nichtVorhanden: Record<string, string[]>; gefaelltNicht: string[] }` (je Ort die gesperrten Übungs-IDs; „gefällt mir nicht“ überall). Die Alternativen je Baustein kommen ohne Filter der Merkliste, aber mit „gefällt mir nicht“ am Ende der Liste und ohne `meiden`-Beschwerden; die App entfernt nur die Einträge `nichtVorhanden[aktiverOrt]` (reines Filtern, Task 6).
  - `POST /api/v1/me/plans` Body `{ studioId?: string }` (bedeutet Ort; fehlt er, Freies Training); `swap` Body `{ einheitKey, positionKey, exerciseId, modelId, grund?: "nicht_vorhanden" | "gefaellt_nicht", ortId?: string }`: bei `grund` wird nach erfolgreichem Tausch die **alte** Übung der Position in `plan_merkliste` eingetragen (`nicht_vorhanden` mit `studio_id = ortId` (fehlt: Katalog-Studio), `gefaellt_nicht` ohne Studio); Fehler beim Eintragen bricht den Tausch nicht ab (wie `ohneAbbruch`, protokolliert ohne Grund oder Übung im Text).
  - Kein Weg zum Zurücknehmen von Merklisteneinträgen (nicht im Spec, YAGNI).

- [ ] **Step 1: Failing Tests:**
  - `trainingsplan-bootstrap.test.ts`: `liefert hoechstens einen Plan mit Katalog-Studio-ID`; `Alternativen tragen modelId und haben gefaellt_nicht am Ende`; `Alternativen nennen keine Beschwerden-Bereiche`; `merkliste faltet nichtVorhanden je Ort`; `Zaehler zaehlt Sessions aus mehreren Studios`; `alter Plan mit machineId-Positionen wird nicht geliefert` (Status `verworfen` filtert ihn, Test mit Zeile des alten Formats und Status `aktiv` stellt sicher, dass der Bootstrap nicht wirft, sondern den Plan ausblendet: Positionen ohne `modelId` → Plan wird ausgelassen und protokolliert).
  - `api-plans.test.ts` (Routen, Datenbank): `swap mit grund nicht_vorhanden tauscht und merkt die alte Uebung am Ort`; `swap mit grund gefaellt_nicht merkt ohne Ort`; `swap ohne grund merkt nichts`; `Eintragsfehler bricht den Tausch nicht ab` (Merkliste per Policy unzugänglich gemacht oder Fake); `POST plans ohne studioId erzeugt im Freien Training`.
- [ ] **Step 2: Tests laufen lassen, müssen fehlschlagen**
  Run: `pnpm --filter @fitretro/domain test -- trainingsplan-bootstrap` und `pnpm test:integration -- api-plans`, `-- plan-schreibwege`
  Expected: FAIL.
- [ ] **Step 3: Implementieren** nach den Signaturen; `ladeNachzuholende` ohne Studiofilter; Routen bleiben dünn (Schema um `modelId`, `grund`, `ortId` erweitern, `machineId: uuid` entfällt).
- [ ] **Step 4: Gesamtlauf Server**
  Run: `pnpm --filter @fitretro/domain test && pnpm --filter @fitretro/web test && pnpm typecheck`
  Expected: PASS ohne Typfehler.
- [ ] **Step 5: Commit**
  ```bash
  git add packages/domain apps/web tests/integration
  git commit -m "feat(api): Katalogplan im Bootstrap, Entfernen mit Grund"
  ```

---

### Task 6: iOS – Plan ohne Studio sehen und einrichten

**Files:**
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift` (`Planposition.machineId` → `modelId`, `PlanAlternative`, `merkliste`), `Onboarding/PlanAntworten.swift` (`PlanEinrichten.zeigtKarte`), `Workout/PlanAnzeige.swift` (`plan(bootstrap:studioId:)`, `heute`, `bildmaschine`, `zielgewicht`), `Screens/Home/HomeRootView.swift:141`, `Screens/Training/PlanKarte.swift`, `Workout/TrainingsplanAblaufStore.swift` (und die persistierte Ablaufdatei), `Screens/Training/TrainingRootView.swift` (Stellen mit `activeStudioId` für den Plan)
- Test: `FitnessMemberTests/PlanAnzeigeTests.swift`, `PlanAntwortenTests.swift`, `TrainingsplanAblaufStoreTests.swift` (erweitern)

**Interfaces:**
- Consumes: Bootstrap-Form aus Task 5 (`plans` ≤ 1, `modelId`, `merkliste`).
- Produces:
  - `PlanEinrichten.zeigtKarte(member:) -> Bool` (Parameter `studioId` entfällt): Onboarding abgeschlossen und `member.plans.isEmpty`.
  - `PlanAnzeige.plan(bootstrap: BootstrapResponse?) -> Trainingsplan?` (Parameter `studioId` entfällt): der eine Plan mit Einheiten, in jedem Ort sichtbar, auch im Freien Training.
  - `TrainingsplanAblaufStore`: der Zustand hängt am Plan, nicht an einer Studio-ID. Persistierte Dateien mit `studioId` bleiben lesbar (Feld wird ignoriert); ein Ablauf eines alten Plans mit anderer `planId` wird verworfen wie heute bei fremdem Plan.
  - Position ohne Gerät: Bild über das Katalogmodell (`modelId`), kein Studio-Gerät.

- [ ] **Step 1: Failing Tests:** `PlanAnzeigeTests`: `zeigt den Plan im Freien Training`; `zeigt den Plan in einem Studio ohne eigene Planzeile`; `Planposition liest modelId`; `Zielgewicht wird ueber den Positionsschluessel gefunden`. `PlanAntwortenTests`: `Karte erscheint im Freien Training ohne Plan`; `Karte erscheint nicht mit Plan`; `Karte erscheint nicht vor dem Onboarding`. `TrainingsplanAblaufStoreTests`: `liest eine alte Datei mit studioId`; `verwirft den Ablauf eines anderen Plans`.
- [ ] **Step 2: Tests laufen lassen, müssen fehlschlagen**
  Run: `cd apps/ios-member && xcodegen generate && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,id=<ID>" test -only-testing:FitnessMemberTests/PlanAnzeigeTests -only-testing:FitnessMemberTests/PlanAntwortenTests -only-testing:FitnessMemberTests/TrainingsplanAblaufStoreTests`
  Expected: Build-Fehler bzw. FAIL.
- [ ] **Step 3: Implementieren** nach den Signaturen. Die Bootstrap-JSON-Fixtures der Tests (`PlanAnzeigeTests.plan(...)`) auf `modelId` umstellen.
- [ ] **Step 4: Tests und ganze Suite grün**
  Run: Befehl aus Step 2, danach ohne `-only-testing`
  Expected: `Test run with N tests ... passed`, `** TEST SUCCEEDED **`.
- [ ] **Step 5: Commit**
  ```bash
  git add apps/ios-member
  git commit -m "feat(ios): Plan ohne Studio sehen und einrichten"
  ```

---

### Task 7: iOS – Position starten und überspringen ohne festes Gerät

**Files:**
- Modify: `Screens/Training/PlanZeile.swift`, `Screens/Training/PlanKarte.swift`, `Screens/Training/TrainingRootView.swift` (Start einer Planposition, Geräteauswahl), `Workout/ScanEntscheidung.swift`, `Screens/Geraet/GeraetModel.swift`, `Workout/PlanAnzeige.swift` (Fortschritt, „gemacht“ über `exerciseId`)
- Test: `FitnessMemberTests/PlanAnzeigeTests.swift`, `PlanTauschTests.swift` (erweitern); für `ScanEntscheidung` den vorhandenen Testtyp suchen (`grep -rl ScanEntscheidung apps/ios-member/FitnessMemberTests`, derzeit `ScanBeitrittTests.swift`), sonst eine neue Datei `ScanEntscheidungTests.swift` anlegen

**Interfaces:**
- Consumes: Task 6; `GeraeteAuswahl` listet im Freien Training alle Katalogtypen, im Studio die Geräte des Studios; Satz trägt `exerciseId` und `equipmentModelId` bzw. `machineId`.
- Produces:
  - Tippen auf eine Planzeile öffnet die Geräteauswahl, gefiltert auf Modelle/Geräte, die die Übung der Position anbieten (Katalogmodell oder ein Studiogerät mit gleichem `catalog_model_id`).
  - Eine Position gilt als gemacht, wenn ein Satz dieser `exerciseId` in der Session liegt, egal an welchem Gerät (Spec Abschnitt 5); „Überspringen“ ist das bestehende Nicht-Machen, der Fortschritt zählt es nicht als erledigt.

- [ ] **Step 1: Failing Tests:** `PlanAnzeigeTests`: `Position ist erledigt durch einen Satz derselben Uebung an einem anderen Geraet`; `Position bleibt offen ohne Satz der Uebung`. `Scan-Entscheidung`: `Scan eines Studiogeraets, das die Uebung anbietet, startet die Position`; `Scan eines Geraets ohne die Uebung bietet die Alternative aus der Planeinheit an` (bestehendes Verhalten bleibt). Dazu ein Test, der die Auswahlliste für eine Position auf die passenden Modelle beschränkt (Name nach dem Typ, den der Implementierer anlegt, im Ledger notiert).
- [ ] **Step 2: Tests laufen lassen, müssen fehlschlagen**
  Run: wie Task 6 Step 2 mit den Typnamen `PlanAnzeigeTests`, `PlanTauschTests` und dem Scan-Testtyp
  Expected: FAIL.
- [ ] **Step 3: Implementieren** (Umfang laut Interfaces; Details der View-Anbindung wählt der Implementierer innerhalb der vorhandenen Muster in `TrainingRootView.swift`).
- [ ] **Step 4: Tests und ganze Suite grün** (Befehl wie Task 6 Step 4).
- [ ] **Step 5: Manuelle Sichtprüfung** mit Testkonto im Simulator: Freies Training, Plan ansehen, Position antippen, Satz machen, Fortschritt springt auf erledigt. Ergebnis im Ledger oder an Tim melden.
- [ ] **Step 6: Commit**
  ```bash
  git add apps/ios-member
  git commit -m "feat(ios): Planposition ohne festes Geraet starten"
  ```

---

### Task 8: iOS – Entfernen mit Grund und Alternative

**Files:**
- Modify: `Workout/PlanTausch.swift`, `Screens/Training/PlanPositionSheet.swift` (und das Tausch-Sheet), `Networking/APIClient.swift` (Swap-Aufruf mit `modelId`, `grund`, `ortId`), `Workout/PlanAnzeige.swift` (Alternativen filtern)
- Test: `FitnessMemberTests/PlanTauschTests.swift`, `APIClientTests` (Stil des vorhandenen Swap-Tests)

**Interfaces:**
- Consumes: `PlanFuerApp.alternativen` und `merkliste` (Task 5); `CatalogStore.ort`/`activeStudioId` für den aktiven Ort (Freies Training = Katalog-Studio-ID aus `bootstrap.catalog.studioId`).
- Produces:
  - `PlanTausch.kandidaten(position:, plan:, ort:) -> [Alternative]`: Alternativen des Bausteins ohne die aktuelle Übung, ohne `merkliste.nichtVorhanden[ortKey]`, Reihenfolge wie vom Server (gefällt-mir-nicht am Ende), `ortKey` = Studio-ID oder Katalog-Studio-ID.
  - Ablauf „Übung entfernen“: Sheet mit den drei Gründen. **Belegt** ersetzt nur für heute (bestehender Pfad, kein Serveraufruf, nichts gemerkt). **Nicht vorhanden** und **Gefällt mir nicht** rufen den dauerhaften Tausch mit `grund` und `ortId` (aktiver Ort) auf. Gibt es im Baustein keine Alternative, bietet das Sheet nur „Überspringen“ an (nichts wird gemerkt, kein Serveraufruf); der Grund wird nur zusammen mit einem Tausch gespeichert.

- [ ] **Step 1: Failing Tests:** `PlanTauschTests`: `Kandidaten ohne die aktuelle Uebung`; `Kandidaten ohne nichtVorhanden des aktiven Ortes`; `nichtVorhanden eines anderen Ortes bleibt sichtbar`; `Freies Training nutzt die Katalog-Studio-ID als Ort`; `gefaellt_nicht steht am Ende`; `belegt ruft keinen Server`. API-Test: `Swap sendet grund, modelId und ortId`.
- [ ] **Step 2: Tests laufen lassen, müssen fehlschlagen**
  Run: wie Task 6 Step 2 mit `PlanTauschTests`
  Expected: FAIL.
- [ ] **Step 3: Implementieren** nach den Signaturen; Texte der drei Gründe: „Belegt“, „Gibt es hier nicht“, „Gefällt mir nicht“ (Entwurf, Tim liest vor dem Merge).
- [ ] **Step 4: Tests und ganze Suite grün** (Befehl wie Task 6 Step 4).
- [ ] **Step 5: Manuelle Sichtprüfung** mit Testkonto: im Freien Training „Gibt es hier nicht“ → Übung kommt dort nicht mehr als Alternative; in einem Studio bleibt sie sichtbar.
- [ ] **Step 6: Commit**
  ```bash
  git add apps/ios-member
  git commit -m "feat(ios): Uebung entfernen mit Grund und Alternative"
  ```

---

### Task 9: Texte, Übergabe, Abschluss

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/PlanWarumText.swift` (Sätze mit „dein Studio“), `FitnessMemberTests/PlanWarumTextTests.swift`, `docs/superpowers/plans/2026-10-27-trainingsplan-nach-etappe5-uebergabe.md` (Stand, F20 ersetzt, offene Punkte)

**Interfaces:**
- Consumes: Gründe aus dem Generator (`zeit_budget_nicht_ausgeschoepft`, `abnehmen_kein_cardio_geraet` u. a.).
- Produces: `PlanWarumText.version` erhöht; Sätze ohne „dein Studio“. Ist ein Grund im Katalogplan nicht mehr erreichbar (z. B. fehlendes Cardio-Gerät, weil der Katalog Cardio hat), bleibt der Satz im Code, damit ältere Server-Codes lesbar bleiben.

- [ ] **Step 1: Failing Test:** `PlanWarumTextTests`: `kein Satz nennt dein Studio` (über `generatorCodes`).
- [ ] **Step 2: Test laufen lassen, muss fehlschlagen**
  Run: Befehl wie Task 6 Step 2 mit `PlanWarumTextTests`
  Expected: FAIL (zwei Sätze nennen das Studio).
- [ ] **Step 3: Sätze umformulieren, `version` auf `1.2.0`.** Vorschlag: „Der Katalog hat nicht genug passende Übungen für die ganze Zeit. Einige Trainings sind deshalb kürzer als angegeben.“; `abnehmen_kein_cardio_geraet`: „Im Katalog gibt es dafür kein Cardio-Gerät, deshalb ist kein Cardio eingeplant.“
- [ ] **Step 4: Gesamtlauf** (Domain, Web, Swift) wie in Task 5 Step 4 und Task 6 Step 4.
  Expected: alles PASS.
- [ ] **Step 5: Übergabe aktualisieren** und committen.
  ```bash
  git add apps/ios-member docs
  git commit -m "feat(ios): Warum-so-Texte ohne Studiobezug, Uebergabe"
  ```
- [ ] **Step 6: Auslieferung (nur mit Freigabe von Tim, jeweils einzeln):** Migrationen `0066` und `0067` auf Prod (MCP `apply_migration`), API-Deploy, danach App-Build auf das Testgerät. Reihenfolge einhalten: erst Datenbank, dann API, dann App.

---

## Nicht Teil dieses Plans

- Studiospezifische Pläne, Gerätezuordnung, Startcoach, Wochenvolumen-Prüfung und die übrigen offenen Punkte der Übergabe.
- Zurücknehmen von Merklisteneinträgen in der App (nur falls Task 8 es braucht, siehe Ruling in Task 5).
