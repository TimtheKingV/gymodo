# Trainingsplan Etappe 3 – Plan im Studio (iOS) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Mitglied richtet in der App seinen Trainingsplan ein, sieht im Studio „heute dran“, hakt Übungen offline ab, tauscht Positionen und bekommt nach 8 Anfängereinheiten einen neuen Planvorschlag angeboten.

**Architecture:** Der Server bleibt Herr der Pläne: Alle Schreibwege auf `training_plans` laufen über `security definer`-Funktionen, die Übung und Gerät gegen das Studio prüfen (Migration 0062). Der Bootstrap liefert `member.trainingProfile` und `member.plans` (Plan, nächste Einheit, Zähler, Tauschkandidaten je Baustein; Beschwerden bleiben serverseitig gefiltert). Der Ablaufstatus (offen / erledigt / optional / getauscht) ist reine Logik in der App (`TrainingsplanAblauf`), rechnet offline und hängt als Momentaufnahme an jedem Satz-PUT; der Server speichert sie je Session (Migration 0063) und leitet daraus Einheitenzähler und „nächste Einheit“ ab. TypeScript und Swift prüfen dieselben Beispieldaten (`packages/domain/fixtures/plan-ablauf.json`).

**Tech Stack:** TypeScript/vitest (`packages/domain`, `tests/integration`), Next.js API (`apps/web`), Supabase-SQL, Swift 6 / SwiftUI / Swift Testing (`apps/ios-member`, XcodeGen).

**Spec:** `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` (Abschnitte 1, 5; F2, F5, F6, F17; dazu F14, F19, F20). Stand nach Etappe 2: `docs/superpowers/plans/2026-10-25-trainingsplan-etappe3-uebergabe.md`; Generator und Plan-Form: `docs/superpowers/plans/2026-10-24-trainingsplan-etappe2-profil-und-plan.md`. Screen-Entwürfe (von Tim freigegeben, 24.10.): https://claude.ai/artifact/CrdrrcB8qUoqK6FeKHeyQz, Nummern wie dort (1.1–1.5, 2.1–2.3, 3.1–3.3, 4.1–4.2).

## Etappen des Gesamtprojekts

| Etappe | Inhalt | Stand |
|---|---|---|
| 1 – Voraussetzungen | Blöcke je Session, Satzrolle, Reserve-Abfrage | gemergt, Prod bis 0058 |
| 2 – Profil und Plan (Server) | Katalogfelder, Profil, Beschwerden, Generator, Pläne, API | gemergt (#86), Prod bis 0061 |
| **3 – Plan im Studio (iOS)** (dieser Plan) | Onboarding-Block, Planansicht, Ablaufstatus, Tausch, Session ↔ Planeinheit, Einheitenzähler, Anfängerangebot | – |
| 4 – Gewichte | Startschätzung, Übertragung, Planziele in der Progression, Wiedereinstieg | – |
| 5 – Erklärungen | Texte zu den Begründungscodes („Warum so?“), Begründungen zu Vorschlägen | – |

**Bewusst nicht in Etappe 3:** Texte hinter „Warum so?“ und den Hinweisen im Schwerpunkt-Schritt (Etappe 5; der Link führt bis dahin zu einer Platzhalterseite mit den Begründungscodes), Aufwärmsatz-Vorbelegung in der App, späteres Ändern des Plans nach der Annahme außer Tausch und Anfängerangebot (kein Profil-Einstieg), Wochenvolumen-Prüfung, Änderung des Wochenkriteriums „4 Wochen“ (Anfängerübergang nur nach 8 Einheiten, Entscheidung Tim 24.10.).

## Entscheidungen mit Tim (24.10.)

- **Spaltenschutz:** Der Server schreibt Pläne per RPC (`security definer`); die Insert-/Update-Policies auf `training_plans` entfallen. Die RPCs prüfen Gerät und Übung gegen das Studio. Die App muss `exerciseId`/`machineId` nicht misstrauen.
- **Auffüllrolle:** Eigene Rolle `auffuellung` (Mehrgelenk vor Isolation), Regelversion 1.2.0.
- **Anfängerübergang:** Zähler (F5) plus Angebot nach 8 Einheiten; die App zeigt „Plan anpassen?“, Tim bestätigt einen neuen Vorschlag (F14).
- **Dauerhafter Tausch:** Server-Endpunkt legt sofort eine neue aktive Planversion an, kein Bestätigungsschritt.
- **Platzierung:** Plan im Training-Tab über „Gerät wählen“, dazu eine „Heute dran“-Zeile auf Home. Onboarding-Schritte hinter den Bestandsfragen und als Sheet für Bestandsnutzer. Optional-Zeile mit gestricheltem Kreis und Begründung. Zeilen-Antippen öffnet das Vorgaben-Sheet (Entwürfe 1.5/2.x, 24.10.).
- **Gestaltung:** Gewählte Chips und Segmente sind **weiß gefüllt** (`text` auf `onAccent`), nicht umrandet; eine Akzentfläche je Screen. Im Schwerpunkt-Schritt keine Erklärung. Alle Übungslisten (Plan, Tausch, Gerätezeile) tragen links das 56×56-pt-Vorschaubild wie die Geräteliste, der Status steht rechts.

## Meine Annahmen (bitte beim Lesen prüfen)

- **Erledigt** heißt: mindestens ein gespeicherter Satz der Übung in dieser Session (Cardio: ein Satz an einem beliebigen Cardiogerät). Aufwärmsätze gibt die App noch nicht als Rolle aus (nicht Etappe 3).
- **Tausch „nur heute“** ist Teil des Ablaufzustands (`getauscht`, Ersatzübung); „dauerhaft“ ändert nur die gewählte Einheit (z. B. A), nicht alle.
- **Neuer Nutzer:** Das Wurzel-Onboarding läuft *vor* dem Studiobeitritt, ein Plan braucht aber ein Studio (F20). Darum hat der Wurzel-Flow nur die drei Profilschritte 1.1–1.3 (speichert Profil und Beschwerden). Die Vorschau 1.4 erscheint, sobald ein Studio da ist, über die Karte 1.5 (Home) bzw. die Plankarte im Training-Tab.
- **Bootstrap-Name:** `member.plans` (Liste je Studio, wegen F20) statt `member.plan` aus der Übergabe. Beschwerden stehen nie im Bootstrap (Gesundheitsdaten); der Server filtert „meiden“ aus den Tauschkandidaten und sortiert „vorsichtig“ nach hinten, ohne es zu verraten.
- **Zähler offline:** Nach einer gezählten Einheit setzt die App lokal die nächste Einheit; der Server-Stand ersetzt das beim nächsten Bootstrap, sobald keine Schreibvorgänge mehr offen sind.
- **Hauptmuskeln aller Studioübungen (F17)** stehen schon im Bootstrap (`exercises[].muscles` an Geräten und Katalogtypen); kein neues Feld.

## Global Constraints

- Arbeit im Worktree `.claude/worktrees/trainingsplan-e3`, Branch `claude/trainingsplan-etappe3` (von `origin/master`). **Nicht pushen, bis Tim es sagt.**
- Migrationen ab `0062`: `0062_plan_schreibwege.sql`, `0063_session_plan.sql`. **Nicht auf Supabase-Prod anwenden ohne ausdrückliche Freigabe von Tim, und dann immer vor dem Merge des Codes.** Additiv, für den alten Code unschädlich (alte Apps senden kein `plan`). Die lokale Datenbank teilen mehrere Sessions: kein `supabase db reset` ohne Rückfrage; neue Migration mit `pnpm supabase migration up`.
- Lokale Umgebung: `colima start`, `pnpm supabase start`; im frischen Worktree `postgres-version storage-version storage-migration gotrue-version rest-version` aus `supabase/.temp/` des Hauptverzeichnisses nach `supabase/.temp/` kopieren (nicht die Prod-Verknüpfung). Integrationstests gezielt je Datei: `pnpm vitest run --config vitest.config.ts tests/integration/<datei>`. Typecheck wie die CI: `pnpm typecheck` im Root (prüft auch `tests/integration`), nicht nur `pnpm -r typecheck`. Vorbestehend rot: 3 Tests in `kurse-lesen.test.ts`, flackernd `api-workout-sets` „beendet die eigene Session“.
- iOS: nur eine Session baut zur selben Zeit, vor jedem `xcodebuild` `pgrep -lx xcodebuild`. Nach neuen Swift-Dateien `cd apps/ios-member && xcodegen generate`. Tests: `xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite> 2>&1 | grep -E "✘|error:|Test run with"`.
- Regeln nur serverseitig (F15); Ausnahme Ablaufstatus (F17), dort gilt der gemeinsame Testfallsatz. Plan und Status sind deutsch benannt wie im Bestand (`einheiten[].key`, `positionen[].key`, Status `offen|erledigt|optional|getauscht`).
- Konventionen: Code-Kommentare ASCII (ae/oe/ue/ss) und nennen einen Grund; Markdown, Fehlermeldungen und App-Texte mit echten Umlauten. Migrationen wie `0061`: deutscher Kopfkommentar, `force row level security`, Policies `<tabelle>_select_own`. API wie `apps/web/app/api/v1/me/plans/route.ts`. Swift: Namen, Kommentarstil und Designsystem-Tokens (`DesignSystem.Color/Spacing/Typography`) wie im Bestand; kein reines Schwarz, **genau eine Akzentfläche je Screen**, `warn` nur als Umriss, VoiceOver-Labels an jeder neuen Zeile.
- Commits deutsch, Form `feat(domain): …` / `feat(api): …` / `feat(db): …` / `feat(ios): …` / `test(…)`, ein Commit je Task. Trailer exakt (zwei Zeilen):
  `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`
  `Claude-Session: https://claude.ai/code/session_016S8cLkaCKkzB5v9v8YNRkJ`

## Review Focus

1. **Offline mit Plan, Reserve-Wiederholung:** Die Reserve-Frage sendet einen älteren Satz-Body erneut (`GeraetModel.reserveSetzen`). Dessen Plan-Momentaufnahme darf den neueren Stand nicht überschreiben: jede Momentaufnahme trägt einen aufsteigenden `stand`, der Server übernimmt nur einen höheren (Task 4, 9).
2. **Planversion wechselt in laufender Einheit** (Tausch „dauerhaft“, Annahme eines Vorschlags): die laufende Session bleibt an der Version, mit der sie gestartet ist; ihr Ablauf und ihre Zählung ändern sich nicht (Task 9, 12).
3. **Stillgelegtes Gerät / keine Alternativen / Plan eines verlassenen Studios:** Zeile zeigt eine andere Maschine derselben Übung, „Andere Übung“ entfällt ohne Kandidaten statt leer zu öffnen; ehemaliges Mitglied kann keinen Vorschlag annehmen und bekommt keinen Plan im Bootstrap (Task 2, 6, 11, 12).
4. **Freies Training und Ortswechsel:** Ohne Plan, an einem Gerät eines anderen Studios oder im Freien Training sendet `SetWrite` kein `plan`; Verhalten und Satzhistorie bleiben wie heute (Task 4, 9).
5. **Zählung der Einheit:** Eine Einheit nur mit Scannen/Verwerfen (keine erledigte oder optionale Position) zählt nicht; eine nie beendete, älter als 4 Stunden stillstehende Einheit zählt (Auto-Abschluss); ein verworfenes Training zählt nicht (Task 5, 6).

---

### Task 0: Arbeitsumgebung

**Files:** keine.

- [ ] **Step 1:** Im Worktree `.claude/worktrees/trainingsplan-e3` die fünf Versionsdateien aus `supabase/.temp/` des Hauptverzeichnisses kopieren, `pnpm install`, `colima start`, `pnpm supabase start`.
- [ ] **Step 2:** Ausgangslage grün prüfen: `pnpm typecheck`, `pnpm vitest run packages/domain`, `tests/integration/api-plans.test.ts` und `domain-trainingsplan.test.ts` einzeln. Erwartet: PASS.
- [ ] **Step 3:** Mit Tims ausdrücklichem OK (Rückfrage steht aus) den Worktree `trainingsplan-e2` und den Branch `claude/trainingsplan-etappe2` entfernen (`git worktree remove`, `git branch -d`); ohne OK nichts tun.

---

## Teil A – Server

### Task 1: Regelversion 1.2.0 – Auffüllrolle, Anzeigereihenfolge, Anfängerende

**Files:**
- Modify: `packages/domain/src/trainingsplan-generator.ts` (Rollen-Union :35, Auffüllschleife :177-190), `packages/domain/src/trainingsplan-regeln.ts` (`PLAN_REGEL_VERSION` :8, `zielprofil` :32), `packages/domain/src/trainingsplan.ts` (`PlanEingabe`)
- Test: `packages/domain/src/trainingsplan-generator.test.ts`, `packages/domain/src/trainingsplan-regeln.test.ts`

**Interfaces:**
- Produces: `PlanPosition.rolle: "pflicht" | "fokus" | "ergaenzung" | "auffuellung" | "cardio"`; `GeneratorEingabe.anfaengerBeendet?: boolean` (Default `false`, wird in `PlanEingabe` gespeichert); `zielprofil(ziel: Ziel, erfahrung: Erfahrung, anfaengerBeendet?: boolean): Zielprofil` – bei `erfahrung === "neu"` und `anfaengerBeendet === true` gilt das Profil von `"unregelmaessig"`; `PLAN_REGEL_VERSION = "1.2.0"`.
- Anzeigereihenfolge je Einheit (Schlüssel = Index danach): Mehrgelenk vor Isolation, darin Pflicht, Fokus, Auffüllung, Ergänzung (stabil), Cardio zuletzt.

- [ ] **Step 1: Failing tests.** Generator: `auffuellpositionen tragen die Rolle auffuellung` (60 min Ober/Unter, 4 Tage: mehr als Pflicht+Ergänzung → Rolle `auffuellung`, nie `ergaenzung`); `Mehrgelenk steht vor Isolation, Cardio zuletzt, keys sind 0..n-1 in Anzeigereihenfolge`; `anfaengerBeendet bei Erfahrung neu plant 3 Saetze Reserve [1,3] bei Muskelaufbau` und `ohne anfaengerBeendet bleibt neu bei 2 Saetzen, Reserve [3,4]`; `Regelversion ist 1.2.0`. Regeln: `zielprofil("muskelaufbau","neu",true)` gleich `zielprofil("muskelaufbau","unregelmaessig")`.
- [ ] **Step 2:** `pnpm vitest run packages/domain/src/trainingsplan-generator.test.ts packages/domain/src/trainingsplan-regeln.test.ts` → FAIL.
- [ ] **Step 3: Implement** die Änderungen am Generator (Auffüllschleife setzt `"auffuellung"`; nach der Auswahl stabil sortieren und Schlüssel neu vergeben), `zielprofil`, Version, `anfaengerBeendet` durch `generierePlan` an `zielprofil` reichen und in `PlanEingabe`/`eingabe` ablegen. Bestehende Tests, die Rolle `ergaenzung` für Auffüllung oder die alte Reihenfolge erwarten, anpassen.
- [ ] **Step 4:** Beide Dateien → PASS; `pnpm vitest run packages/domain` → PASS.
- [ ] **Step 5: Commit** `feat(domain): Planregeln 1.2.0 mit Auffüllrolle und Anfängerende`.

---

### Task 2: Pläne nur über RPC schreiben, Widerruf bereinigt alle Studios

**Files:**
- Create: `supabase/migrations/0062_plan_schreibwege.sql`
- Modify: `packages/domain/src/trainingsplan.ts` (`erzeugePlanVorschlag`, `acceptPlan`)
- Test: `tests/integration/domain-trainingsplan.test.ts`, `tests/integration/api-plans.test.ts`, neu `tests/integration/plan-schreibwege.test.ts`

**Interfaces:**
- Produces (SQL, alle `security definer`, `set search_path = public, pg_temp`, `revoke … from public; grant execute … to authenticated`, Prüfung `auth.uid() is not null`):
  - `create_training_plan(p_studio_id uuid, p_regel_version text, p_eingabe jsonb, p_struktur text, p_einheiten jsonb, p_gruende text[]) returns training_plans` – verlangt `is_studio_member(p_studio_id)`, ruft `training_plan_pruefen`, verwirft offene Vorschläge des Paars, vergibt `version`, fügt als `vorschlag` ein, alles in einer Transaktion (löst Übergabepunkt 5).
  - `accept_training_plan(p_plan_id uuid)` jetzt `security definer`, prüft zusätzlich `is_studio_member(studio_id)` (Übergabepunkt 4); Fehler `plan_nicht_annehmbar` (P0001) unverändert.
  - Hilfsfunktion `training_plan_pruefen(p_studio_id uuid, p_einheiten jsonb)`: jede Position (auch Cardio) muss ein `machineId` haben, das zu einem **aktiven** Gerät des Studios gehört, und ein `exerciseId`, das an dessen Modell (direkt über `equipment_model_exercises` oder über `catalog_model_id`) hängt; sonst `raise exception 'plan_ungueltig'` (P0001, Meldung unterscheidbar von `plan_nicht_annehmbar`).
  - Trigger `AFTER DELETE ON training_limits` (security definer): setzt in **allen** Plänen des Nutzers `eingabe.beschwerdenBeruecksichtigt = false` und entfernt `beschwerden_meiden`, `beschwerden_vorsichtig` aus `gruende` – auch in Studios, die das Mitglied verlassen hat (löst Übergabepunkt 3). Übungen bleiben.
  - Entfällt: `training_plans_insert_own`, `training_plans_update_own`. Es bleibt `training_plans_select_own`.
- Domain: `erzeugePlanVorschlag` und `acceptPlan` behalten ihre Signatur, rufen aber die RPCs; `plan_ungueltig` → `DomainError("validation_failed", …)`.

- [ ] **Step 1: Failing tests** `plan-schreibwege.test.ts` (Mitglied-Client wie in `api-plans.test.ts`): `direktes Insert in training_plans scheitert`; `direktes Update (status, einheiten) scheitert`; `create_training_plan mit Geraet eines fremden Studios wirft plan_ungueltig`; `… mit Uebung, die das Geraet nicht hat, wirft plan_ungueltig`; `… mit stillgelegtem Geraet wirft plan_ungueltig`; `accept eines Vorschlags im verlassenen Studio wirft Konflikt`; `Widerruf (DELETE training_limits) bereinigt auch den Plan in einem verlassenen Studio` (Gründe ohne `beschwerden_*`, Flag false, Positionen unverändert); `zwei parallele erzeugePlanVorschlag lassen genau einen Vorschlag stehen`. Bestehende Tests in `domain-trainingsplan.test.ts`/`api-plans.test.ts` dort anpassen, wo sie Zeilen direkt mit dem Mitglied-Client ändern (mit Service-Client).
- [ ] **Step 2:** `plan-schreibwege.test.ts` einzeln → FAIL.
- [ ] **Step 3: Migration 0062** schreiben (Kopfkommentar: warum RPC statt Spaltenschutz, Verweis auf Übergabe 2/3/4/5), lokal `pnpm supabase migration up`.
- [ ] **Step 4:** `trainingsplan.ts` auf die RPCs umstellen (einfügen/verwerfen/Version entfallen aus TS).
- [ ] **Step 5:** `plan-schreibwege.test.ts`, `domain-trainingsplan.test.ts`, `api-plans.test.ts` einzeln → PASS; `pnpm typecheck`.
- [ ] **Step 6: Commit** `feat(db): Pläne werden nur über geprüfte Funktionen geschrieben`.

---

### Task 3: Dauerhafter Tausch einer Planposition

**Files:**
- Modify: `supabase/migrations/0062_plan_schreibwege.sql`, `packages/domain/src/trainingsplan.ts`, `packages/domain/src/index.ts`
- Create: `apps/web/app/api/v1/me/plans/[id]/swap/route.ts`
- Test: `tests/integration/plan-schreibwege.test.ts`, `tests/integration/api-plans.test.ts`

**Interfaces:**
- Produces (SQL): `swap_training_plan_position(p_plan_id uuid, p_einheit_key text, p_position_key text, p_exercise_id uuid, p_machine_id uuid) returns training_plans` – nur für den **aktiven** Plan des Aufrufers und Studio-Mitglieder; neue Übung muss denselben `plan_baustein` wie die Position haben (`exercises.plan_baustein`), `training_plan_pruefen` bestehen und darf keinen Bereich aus `training_limits.areas = "meiden"` belasten (`plan_bereiche`); legt Version +1 mit Status `aktiv` an (alte → `ersetzt`), kopiert Eingabe, Gründe, Sätze, Wiederholungsbereich, Reserve, Pause der Position und setzt `exerciseId`, `machineId`, `hauptmuskeln` (primäre Muskeln aus `exercises.muscles`) neu. Fehler: `plan_nicht_annehmbar` (P0001) für fremd/nicht aktiv; `plan_ungueltig` sonst.
- Produces (Domain): `tauschePlanPosition(client, userId, planId, input: { einheitKey: string; positionKey: string; exerciseId: string; machineId: string }): Promise<TrainingPlan>`.
- Produces (API): `POST /api/v1/me/plans/[id]/swap`, Body wie `input` → 200 `TrainingPlan` (neue aktive Version); 401, 404 (Plan fremd), 409 (nicht aktiv), 422 (`validation_failed`).

- [ ] **Step 1: Failing tests:** `Tausch erzeugt Version +1, aktiv, alter Plan ersetzt, nur die gewaehlte Position aendert sich`; `anderer Baustein wird abgelehnt`; `Uebung mit gemiedenem Bereich wird abgelehnt`; `Geraet eines fremden Studios wird abgelehnt`; `Tausch auf nicht aktiven Plan: 409`; `API: 200 mit status aktiv und version +1`, `401 ohne Token`, `422 bei unbekanntem positionKey`.
- [ ] **Step 2:** Einzeln → FAIL.
- [ ] **Step 3:** Funktion in 0062 ergänzen (Migration ist noch lokal; Datei erweitern, `migration up` bzw. Funktion per `create or replace` einspielen), `tauschePlanPosition` und Route (Muster `accept/route.ts`).
- [ ] **Step 4:** Beide Testdateien → PASS; `pnpm typecheck`.
- [ ] **Step 5: Commit** `feat(api): Planposition dauerhaft tauschen`.

---

### Task 4: Session ↔ Planeinheit und Status je Position

**Files:**
- Create: `supabase/migrations/0063_session_plan.sql`
- Modify: `packages/domain/src/workout.ts` (`recordSetInputSchema` :81, `recordSet` :320)
- Test: `tests/integration/api-workout-sets.test.ts` (neu: `tests/integration/session-plan.test.ts`)

**Interfaces:**
- Produces (SQL): `workout_sessions` bekommt `plan_id uuid null references training_plans(id)`, `plan_einheit_key text null`, `plan_stand int not null default 0`; Check: `plan_id` und `plan_einheit_key` beide null oder beide gesetzt. Tabelle `session_plan_status(session_id uuid references workout_sessions(id) on delete cascade, position_key text, user_id uuid, status text check in ('offen','erledigt','optional','getauscht'), exercise_id uuid null references exercises(id), primary key (session_id, position_key))` mit nur `_select_own`. RPC `record_session_plan(p_session_id uuid, p_plan_id uuid, p_einheit_key text, p_stand int, p_positionen jsonb) returns void` (`security definer`): Session und Plan müssen dem Aufrufer gehören, `p_einheit_key` und jeder `key` müssen im Plan existieren, `exerciseId` der Ersatzübung muss existieren; setzt `plan_id`/`plan_einheit_key` nur, wenn noch null; übernimmt die Momentaufnahme (ersetzt alle Zeilen der Session) **nur wenn `p_stand` > `plan_stand`**; sonst still nichts.
- Produces (Domain): `recordSetInputSchema` bekommt optional `plan: { planId: uuid, einheitKey: string, stand: int ≥ 1, positionen: { key: string, status: "offen"|"erledigt"|"optional"|"getauscht", exerciseId?: uuid | null }[] }`; `recordSet` ruft nach dem Satz-Upsert `record_session_plan`, wenn `plan` gesetzt ist. Fehler der Funktion → `validation_failed`, der Satz bleibt gespeichert.

- [ ] **Step 1: Failing tests** (`session-plan.test.ts`, Plan + Session wie in `domain-trainingsplan.test.ts` aufgebaut): `erster Satz mit plan setzt plan_id, plan_einheit_key und die Statuszeilen`; `Satz ohne plan laesst alles wie bisher`; `aelterer stand ueberschreibt keinen neueren` (PUT stand 3, dann PUT stand 2 → Zeilen von 3); `Replay desselben PUT ist idempotent`; `plan eines anderen Nutzers wird abgelehnt, der Satz bleibt gespeichert`; `unbekannter positionKey: 422`; `Session loeschen entfernt die Statuszeilen`; `alte App (ohne plan) PUT unveraendert 200`.
- [ ] **Step 2:** Einzeln → FAIL.
- [ ] **Step 3:** Migration 0063 schreiben und lokal anwenden; Schema und `recordSet` erweitern.
- [ ] **Step 4:** `session-plan.test.ts` und `api-workout-sets.test.ts` einzeln → PASS; `pnpm vitest run packages/domain/src/workout.test.ts`; `pnpm typecheck`.
- [ ] **Step 5: Commit** `feat(db): Session trägt Planeinheit und Status je Position`.

---

### Task 5: Ablauflogik (TypeScript-Referenz) und gemeinsame Testfälle

**Files:**
- Create: `packages/domain/src/trainingsplan-ablauf.ts`, `packages/domain/fixtures/plan-ablauf.json`
- Modify: `packages/domain/src/index.ts`
- Test: `packages/domain/src/trainingsplan-ablauf.test.ts`

**Interfaces:**
- Produces:
  - `type PositionStatus = "offen" | "erledigt" | "optional" | "getauscht"`
  - `type AblaufPosition = { key: string; exerciseId: string; hauptmuskeln: string[]; cardio: boolean; status: PositionStatus; ersatzExerciseId: string | null }` (`hauptmuskeln` gilt für die **wirksame** Übung, bei Tausch die der Ersatzübung)
  - `type AblaufZustand = { positionen: AblaufPosition[]; ungeplanteGesehen: string[] }`
  - `type AblaufSatz = { exerciseId: string; hauptmuskeln: string[]; cardio: boolean }`
  - `ablaufNachSatz(z: AblaufZustand, satz: AblaufSatz): AblaufZustand` (rein, ändert `z` nicht)
  - `ablaufTauschen(z: AblaufZustand, positionKey: string, ersatz: { exerciseId: string; hauptmuskeln: string[] }): AblaufZustand` (nur Positionen `offen`/`getauscht`, nicht Cardio; sonst unverändert)
  - `einheitZaehlt(z: AblaufZustand): boolean` (mindestens eine Position `erledigt` oder `optional`)
  - `naechsteEinheitKey(einheitKeys: string[], zuletztGezaehlt: string | null): string` (Nachfolger in der Folge, nach der letzten wieder die erste; `null` oder unbekannter Schlüssel → erste)
- Regeln für `ablaufNachSatz` (Spec 5, F2, F19), in dieser Reihenfolge: (1) Wirksame Übung = `ersatzExerciseId ?? exerciseId`. Passt eine Position mit Status `offen`, `getauscht` oder `optional` zur Übung des Satzes (die erste in Planreihenfolge; bei Cardio: jede Cardio-Position, wenn `satz.cardio`), wird sie `erledigt`. (2) Sonst gilt der Satz als ungeplant, sofern keine Position (egal welcher Status) die Übung als wirksame Übung führt: Ist `satz.cardio` oder die Übung schon in `ungeplanteGesehen`, passiert nichts weiter; sonst wird sie vermerkt und **genau eine** Position mit Status `offen` oder `getauscht` (nicht Cardio) wird `optional` – die mit den meisten gemeinsamen Hauptmuskeln (mindestens 1), bei Gleichstand die zuerst im Plan. Cardio-Sätze berühren nie Kraftpositionen und umgekehrt.
- Fixture `plan-ablauf.json`: `{ "statusFaelle": [{ "name", "positionen": AblaufPosition[], "ungeplanteGesehen": string[], "saetze": AblaufSatz[], "tausche": [{ "positionKey", "exerciseId", "hauptmuskeln" }] (vor den Sätzen angewendet), "erwartet": [{ "key", "status", "ersatzExerciseId" }] }], "folgeFaelle": [{ "name", "einheitKeys", "zuletzt", "erwartet" }], "zaehlFaelle": [{ "name", "stati": PositionStatus[], "erwartet": boolean }] }`.

- [ ] **Step 1: Fixture und Test schreiben.** Fälle (Namen = Testnamen): `Satz an geplanter Uebung hakt ab`; `Reihenfolge ist egal`; `ungeplante Uebung macht genau die Position mit den meisten gemeinsamen Hauptmuskeln optional`; `Gleichstand: die zuerst im Plan`; `ohne gemeinsamen Hauptmuskel bleibt alles offen`; `zweiter Satz derselben ungeplanten Uebung macht keine weitere optional`; `optionale Position, danach doch gemacht, wird erledigt`; `Cardio-Satz an anderem Cardiogeraet erfuellt die Cardio-Position und laesst Kraft unberuehrt`; `Kraftsatz macht Cardio nie optional`; `Tausch: Satz mit Ersatzuebung erledigt die Position, Ersatz bleibt vermerkt`; `nach Tausch gilt die urspruengliche Uebung als ungeplant`; `bereits erledigte Position bleibt bei weiteren Saetzen erledigt`; Folge: `A -> B`, `B -> A`, `null -> A`, `unbekannt -> A`, `OK_A -> UK_A -> OK_B -> UK_B -> OK_A`, einzelne Einheit `A -> A`; Zählung: nur `offen`/`getauscht` → false, ein `optional` → true, ein `erledigt` → true. Der Test liest die Datei mit `readFileSync(new URL("../fixtures/plan-ablauf.json", import.meta.url))`.
- [ ] **Step 2:** `pnpm vitest run packages/domain/src/trainingsplan-ablauf.test.ts` → FAIL.
- [ ] **Step 3: Implement** die fünf Funktionen; `index.ts` exportiert sie.
- [ ] **Step 4:** → PASS; `pnpm typecheck`.
- [ ] **Step 5: Commit** `feat(domain): Ablaufstatus und Einheitenfolge mit gemeinsamen Testfällen`.

---

### Task 6: Bootstrap – Profil, Pläne, Zähler, Tauschkandidaten, Anfängerangebot

**Files:**
- Create: `packages/domain/src/trainingsplan-bootstrap.ts`
- Modify: `packages/domain/src/bootstrap.ts` (`Bootstrap.member` :37, Aufbau :636), `packages/domain/src/trainingsplan.ts` (`erzeugePlanVorschlag` nutzt den Zähler), `packages/domain/src/index.ts`
- Test: `packages/domain/src/trainingsplan-bootstrap.test.ts`, `tests/integration/domain-bootstrap.test.ts` (Ergänzung), `tests/integration/domain-trainingsplan.test.ts`

**Interfaces:**
- Consumes: `naechsteEinheitKey`, `einheitZaehlt` (Task 5), `ladeKandidaten`, `getTrainingProfile`, `getTrainingLimits`, `filtereKandidaten`/`istVorsichtig` (`trainingsplan-auswahl.ts`).
- Produces:
  - `type GezaehlteEinheit = { sessionId: string; einheitKey: string; startedAt: string }`; `gezaehlteEinheiten(sessions: { id: string; einheitKey: string; startedAt: string; completedAt: string | null; letzterSatzAm: string | null; zaehlt: boolean }[], jetzt: Date): GezaehlteEinheit[]` – aufsteigend nach `startedAt`; zählt, wenn `zaehlt` und (`completedAt` gesetzt **oder** letzter Satz älter als 4 h; keine Sätze und nicht beendet → nein).
  - `ladeGezaehlteEinheiten(client, userId, studioId, jetzt: Date): Promise<GezaehlteEinheit[]>` – liest Sessions mit `plan_id` des Paars (neueste 200), `session_plan_status`, letzte Satzzeit.
  - `type PlanFuerApp = { planId: string; studioId: string; version: number; regelVersion: string; struktur: string; einheiten: PlanEinheit[]; gruende: string[]; naechsteEinheitKey: string; zuletztEinheitKey: string | null; einheitenErledigt: number; anfaengerUebergang: boolean; alternativen: Partial<Record<Baustein, { exerciseId: string; machineId: string }[]>> }`.
  - `Bootstrap.member` bekommt `trainingProfile: TrainingProfile | null` und `plans: PlanFuerApp[]` (aktive Pläne nur der Studios, in denen der Nutzer Mitglied ist). `alternativen`: Kandidaten des Studios je Baustein ohne „meiden“, „vorsichtig“ hinten, Reihenfolge sonst wie `ladeKandidaten`; die Beschwerden selbst stehen nicht im Bootstrap.
  - `anfaengerUebergang = profil.experience === "neu" && einheitenErledigt >= 8 && eingabe.anfaengerBeendet !== true`.
  - `erzeugePlanVorschlag` setzt `anfaengerBeendet = profil.experience === "neu" && Zähler(Paar) >= 8`.

- [ ] **Step 1: Failing tests (Unit)** `gezaehlteEinheiten`: `beendete Einheit mit erledigter Position zaehlt`; `nie beendete, 5 h stillstehende zaehlt`; `laufende (letzter Satz vor 10 min) zaehlt nicht`; `Einheit ohne erledigte/optionale Position zaehlt nicht`; `Reihenfolge nach startedAt`. **Integration:** `Bootstrap enthaelt member.plans nur fuer Studios mit Mitgliedschaft`; `naechsteEinheitKey folgt der zuletzt gezaehlten Einheit`; `einheitenErledigt zaehlt ueber Planversionen desselben Paars`; `alternativen schliessen meiden-Uebungen aus und enthalten kein Beschwerdenfeld`; `anfaengerUebergang erst ab 8 Einheiten bei Erfahrung neu, nicht mehr nach Annahme eines Plans mit anfaengerBeendet`; `trainingProfile ist null ohne Profil`; `erzeugePlanVorschlag nach 8 Einheiten plant 3 Saetze`. `bootstrap.test.ts` anpassen, wo es die Antwortform vergleicht.
- [ ] **Step 2:** Unit-Test und `domain-bootstrap.test.ts` einzeln → FAIL.
- [ ] **Step 3: Implement** `trainingsplan-bootstrap.ts` (reine Funktion getrennt vom Laden), Anschluss in `getBootstrap`; Zähler in `erzeugePlanVorschlag`.
- [ ] **Step 4:** Testdateien einzeln → PASS; `pnpm vitest run packages/domain`; `pnpm typecheck`.
- [ ] **Step 5: Commit** `feat(api): Bootstrap liefert Trainingsprofil und Pläne mit Zähler`.

---

## Teil B – iOS

### Task 7: APIError, DTOs, APIClient

**Files:**
- Create: `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift`
- Modify: `Networking/APIError.swift` (`map` :91), `Networking/DTOs/ErrorEnvelope.swift`, `Networking/DTOs/BootstrapResponse.swift` (`Member` :4), `Networking/DTOs/WorkoutSet.swift` (`SetWrite`), `Networking/APIClient.swift`, das `BootstrapLoading`-Protokoll (:10) bei Bedarf
- Test: `FitnessMemberTests/APIClientTests.swift`, `FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces:
  - `APIError.profilUnvollstaendig(message: String, fehlt: [String])` und `APIError.planNichtMoeglich(message: String, baustein: String, grund: String)`; `istDauerhaft` → true, `servertext` → `message`. `ErrorEnvelope.Body.detail: JSONValue?`; `APIError.map(code: String, message: String, detail: JSONValue? = nil)`. Alle `switch` über `APIError` im Projekt vollständig halten.
  - `struct Trainingsplan: Decodable, Equatable, Sendable` (Felder wie `PlanFuerApp`), `TrainingsplanEinheit { key, positionen }`, `TrainingsplanPosition { key, baustein, rolle, exerciseId, machineId, typ, saetze, wdhVon, wdhBis, reserveVon, reserveBis, pauseSek, aufwaermsatz, dauerMin, hauptmuskeln }`, `Alternative { exerciseId, machineId }`; `BootstrapResponse.Member.trainingProfile: TrainingsplanProfil?` (`minutes`, `experience`, `focus`) und `plans: [Trainingsplan]` (beide fehlen in alten Antworten → `[]`/`nil`, Init-Vorgaben wie bei den anderen Feldern).
  - `SetWrite.plan: PlanMomentaufnahme?` (`planId`, `einheitKey`, `stand`, `positionen: [{ key, status, exerciseId }]`), nur codiert, wenn gesetzt; Warteschlangendatei von vor dem Update dekodiert weiter.
  - `APIClient`: `trainingProfile() async throws(APIError) -> TrainingsplanProfil?` (404 → nil), `putTrainingProfile(_:)`, `putTrainingLimits(areas: [String: String])` (sendet `{ einwilligung: true, areas }`), `deleteTrainingLimits()`, `trainingLimits() -> [String: String]?`, `createPlan(studioId:) -> Trainingsplan`, `acceptPlan(id:) -> Trainingsplan`, `swapPlanPosition(planId:einheitKey:positionKey:exerciseId:machineId:) -> Trainingsplan`.

- [ ] **Step 1: Failing tests:** `map erkennt profil_unvollstaendig und liest detail.fehlt`; `map erkennt plan_nicht_moeglich und liest baustein und grund`; `unbekannter Code bleibt .server`; `Bootstrap ohne trainingProfile/plans dekodiert (alte Antwort)`; `Bootstrap mit plans dekodiert Positionen und Alternativen` (Beispiel-JSON aus einer echten Antwort von Task 6); `SetWrite ohne plan codiert ohne Feld plan`; `SetWrite mit plan: Round-Trip`; `alte pending-writes.json (ohne plan) dekodiert`; APIClient: `createPlan 422 wird .planNichtMoeglich` (Muster der vorhandenen Tests mit gestubbter URLSession).
- [ ] **Step 2:** `pgrep -lx xcodebuild`, `xcodegen generate`, Tests `APIClientTests`, `DTOTests` → FAIL.
- [ ] **Step 3: Implement** Typen und Methoden (Pfade `/api/v1/me/training-profile`, `/training-limits`, `/plans`, `/plans/{id}/accept`, `/plans/{id}/swap`).
- [ ] **Step 4:** Beide Suiten → PASS; ganze Suite `FitnessMemberTests` einmal laufen lassen (Switch-Vollständigkeit).
- [ ] **Step 5: Commit** `feat(ios): Plan-DTOs, Fehlercodes und Endpunkte`.

---

### Task 8: Ablauflogik in Swift gegen dieselben Beispieldaten

**Files:**
- Create: `FitnessMember/Workout/TrainingsplanAblauf.swift`, `FitnessMemberTests/TrainingsplanAblaufTests.swift`
- Modify: `apps/ios-member/project.yml` (Testtarget: `../../packages/domain/fixtures/plan-ablauf.json` als Ressource, wie `Fixtures` dort deklariert sind)

**Interfaces:**
- Produces (spiegelt Task 5 1:1): `enum PositionStatus: String, Codable { case offen, erledigt, optional, getauscht }`; `struct AblaufPosition: Codable, Equatable { key, exerciseId, hauptmuskeln, cardio, status, ersatzExerciseId }`; `struct AblaufZustand: Codable, Equatable { positionen, ungeplanteGesehen }`; `struct AblaufSatz { exerciseId, hauptmuskeln, cardio }`; `enum TrainingsplanAblauf { static func nachSatz(_:_:) -> AblaufZustand; static func tauschen(_:positionKey:ersatz:) -> AblaufZustand; static func zaehlt(_:) -> Bool }`; `enum TrainingsplanFolge { static func naechsteEinheitKey(einheitKeys: [String], zuletzt: String?) -> String }`.

- [ ] **Step 1: Failing tests:** Ein Test je Fall der Fixture (`@Test(arguments:)` über die dekodierten `statusFaelle`, `folgeFaelle`, `zaehlFaelle`; Namen aus `name`), die Fixture kommt aus dem Bundle. Zusätzlich `Fixture enthaelt dieselben Fallnamen wie der TypeScript-Test` (Anzahl je Gruppe ≥ der in Task 5 genannten).
- [ ] **Step 2:** `xcodegen generate`; Suite → FAIL.
- [ ] **Step 3: Implement** die reine Logik, ohne Abhängigkeit von UI oder Store.
- [ ] **Step 4:** → PASS.
- [ ] **Step 5: Commit** `feat(ios): Ablaufstatus rechnet offline, gleiche Testfälle wie der Server`.

---

### Task 9: Ablauf-Speicher, Satzweg und Einheit beenden

**Files:**
- Create: `FitnessMember/Workout/TrainingsplanAblaufStore.swift`
- Modify: `Screens/Geraet/GeraetModel.swift` (Init :270, `satzSichern` :943), `Screens/Training/TrainingRootView.swift` (`beenden` :1552, Station-Aufbau :735-760), `Catalog/CatalogStore.swift` (Bootstrap-Neuladen), App-Wurzel, die `WorkoutSessionStore` erzeugt
- Test: `FitnessMemberTests/TrainingsplanAblaufStoreTests.swift`, `GeraetModelTests.swift`, `OrtswechselBeendenTests.swift`

**Interfaces:**
- Produces: `@MainActor @Observable final class TrainingsplanAblaufStore` (Datei `plan-ablauf.json` im Application-Support, Muster `SessionFileStore`):
  - `init(fileStore: …)`; `func vorbereiten(plan: Trainingsplan?, studioId: String?, jetzt: Date)` – wählt `naechsteEinheitKey` (mit lokalem Vorrang, siehe `einheitBeendet`) und baut den Zustand aus den Positionen, falls noch keiner für `(planId, einheitKey)` existiert; verwirft einen Zustand, der älter als 12 h oder von einer anderen Planversion ist, **sofern noch kein Satz gesendet wurde**; ein Zustand mit gebundener Session bleibt bei seiner Version (Review Focus 2).
  - `var zustand: AblaufZustand?`, `var planId`, `var einheitKey`, `var gebundeneSessionId: UUID?`
  - `func tauschen(positionKey: String, ersatz: (exerciseId: String, hauptmuskeln: [String]))` (heute)
  - `func nachSatz(sessionId: UUID, studioId: String?, satz: AblaufSatz) -> PlanMomentaufnahme?` – nil ohne Plan, im Freien Training oder bei Studio ≠ Studio des Plans (Review Focus 4); sonst neuer Zustand, `stand` +1, gebunden an `sessionId`
  - `func einheitBeendet()` – zählt der Zustand (`TrainingsplanAblauf.zaehlt`), merkt sich `lokalZuletzt = einheitKey` (bis zum nächsten Bootstrap bei leerer Warteschlange), danach Zustand leeren; zählt er nicht, nur leeren
  - `func nachBootstrap(offeneSchreibvorgaenge: Int)` – löscht `lokalZuletzt`, wenn nichts mehr offen ist
- `GeraetModel.satzSichern` ergänzt `body.plan = ablauf.nachSatz(…)` mit Hauptmuskeln der Übung aus dem Bootstrap (`role == primary`) und `istCardio`; die Reserve-Wiederholung (`reserveSetzen`) sendet ihren gespeicherten Body unverändert (also mit dessen älterem `stand`). `TrainingRootView.beenden()` ruft `einheitBeendet()`, bevor `sessions.beenden()` die Kennung zurückgibt, und verwirft den Zustand auch bei „Einheit verwerfen“ (zählt nicht).

- [ ] **Step 1: Failing tests (Store):** `vorbereiten waehlt die naechste Einheit aus dem Bootstrap`; `lokalZuletzt hat Vorrang bis nachBootstrap bei leerer Warteschlange`; `nachSatz haekt ab und erhoeht stand`; `ohne Plan, im Freien Training und in anderem Studio ist die Momentaufnahme nil`; `Zustand ueberlebt Neustart (Datei)`; `gebundene Session behaelt ihre Planversion, auch wenn ein neuer Plan im Bootstrap steht`; `einheitBeendet zaehlt nur mit erledigter oder optionaler Position`; `verwerfen zaehlt nicht`; `tauschen vor dem Start bleibt bis zum Satz erhalten`. **GeraetModel:** `Satz im Plan traegt plan im SetWrite`; `Satz ohne Plan traegt keins`; `Reserve-Wiederholung sendet den Body mit dem alten stand unveraendert`.
- [ ] **Step 2:** Suiten einzeln → FAIL.
- [ ] **Step 3: Implement** Store, Verdrahtung (Store wird wie `WorkoutSessionStore` in der Umgebung gehalten und an `GeraetModel` gereicht), `beenden`.
- [ ] **Step 4:** Drei Suiten → PASS; danach ganze Suite `FitnessMemberTests`.
- [ ] **Step 5: Commit** `feat(ios): Plan-Ablauf folgt den Sätzen und wandert mit dem Satz-PUT`.

---

### Task 10: Onboarding-Block (Entwürfe 1.1–1.5, 4.1, 4.2)

**Files:**
- Create: `FitnessMember/Onboarding/PlanSchritte.swift` (Views 1.1–1.4), `FitnessMember/Onboarding/PlanAntworten.swift`, `FitnessMember/Screens/Home/PlanEinrichtenKarte.swift` (1.5)
- Modify: `Onboarding/OnboardingAntworten.swift` (`OnboardingSchritt`, `schritte`), `Onboarding/OnboardingFlow.swift`, `Onboarding/OnboardingSchreiber.swift`, `Onboarding/OnboardingHinweis.swift`, `DesignSystem/Components/Chip.swift` (gefüllte Auswahl), `Screens/Home/HomeRootView.swift` (Karte)
- Test: `OnboardingAntwortenTests.swift`, `OnboardingSchreiberTests.swift`, `OnboardingHinweisTests.swift`, neu `PlanAntwortenTests.swift`

**Interfaces:**
- Produces:
  - `OnboardingSchritt` bekommt `planZeit, planSchwerpunkt, planBeschwerden, planVorschau`. `OnboardingFlow(…, umfang: OnboardingUmfang = .komplett)` mit `enum OnboardingUmfang { case komplett, nurPlan, nurVorschau }`; `OnboardingAntworten.schritte(umfang:, hatStudio:)`: `.komplett` = Bestand + `planZeit, planSchwerpunkt, planBeschwerden` (**ohne** Vorschau, solange `hatStudio == false`); `.nurPlan` = vier Plan-Schritte; `.nurVorschau` = nur 1.4 ohne Schrittzeile.
  - `struct PlanAntworten: Equatable { minuten: Int?; erfahrung: String?; schwerpunkt: [String]; beschwerden: [String: String]; einwilligung: Bool }` – Vorbelegung aus `Member.trainingProfile`; `schwerpunkt` höchstens 2 (drittes Tippen wirkungslos); `kannWeiter` je Schritt (Weiter bleibt aktiv, nur 1.3 ist gedämpft, wenn ein Bereich ≠ „nichts“ gewählt ist und die Einwilligung fehlt); Beschwerden werden nur mit `einwilligung == true` gesendet.
  - Schreibvorgänge (`OnboardingSchreibvorgang`): Profil `PUT training-profile` (fehlende Pflichtangaben `minutes`/`experience` → kein Aufruf, „Später“ lässt Rest unberührt), Beschwerden `PUT`/`DELETE training-limits` (alle „nichts“ ohne frühere Einwilligung: kein Aufruf).
  - Schritt 1.4: ruft `createPlan(studioId:)` beim Betreten, zeigt Einheiten-Tabs und Positionen mit Vorschaubild (Zeilen wie Task 11), „Plan übernehmen“ → `acceptPlan` → Bootstrap neu laden → Sheet schließt. `.profilUnvollstaendig` → Zustand 4.2 („Ergänzen“ springt zum ersten Bestandsschritt, der fehlt); `.planNichtMoeglich` → 4.1 mit Text je `grund` (`beschwerden`: „Mit deiner Angabe zu … bleibt für … keine Übung übrig“, Aktion „Beschwerden ändern“; `kein_geraet`: „Dein Studio hat dafür gerade kein aktives Gerät: …“ ohne Aktion außer „Später“). Bausteinnamen deutsch aus einer Tabelle `BausteinName.text(_:)`.
  - `Chip(text:isActive:)` zeigt aktiv als **weiße Füllung** (`DesignSystem.Color.text`, Schrift `onAccent`); gilt auch für die Segmente „Nichts · Vorsichtig · Meiden“. Bestehende Verwendungen (Ziel-Kacheln behalten ihren Akzentstrich; nur wo bisher `isActive` ein Akzentstrich war und der Entwurf Füllung zeigt, anpassen) per Snapshot-/Vorschau prüfen.
  - Karte 1.5 auf Home: erscheint, wenn `onboardingCompletedAt != nil`, ein Studio aktiv ist und `plans` für dieses Studio leer; Tippen öffnet `OnboardingFlow(umfang: trainingProfile == nil ? .nurPlan : .nurVorschau)` als Sheet; danach Bootstrap neu laden. Zweite Aktion ist Umriss (Home hat seine Akzentfläche).

- [ ] **Step 1: Failing tests:** `schritte komplett ohne Studio enthaelt 3 Plan-Schritte und keine Vorschau`; `schritte nurPlan hat vier`; `schwerpunkt begrenzt auf zwei`; `Beschwerden ohne Einwilligung werden nicht gesendet`; `Widerruf (Einwilligung entfernt) sendet DELETE`; `Vorbelegung aus trainingProfile`; `Schreiber: Profil-PUT nur mit minuten und erfahrung`; `Hinweistext fuer plan_nicht_moeglich nennt den Baustein deutsch`; `Hinweistext fuer profil_unvollstaendig nennt fehlende Angaben`; `Karte erscheint nur ohne Plan im aktiven Studio`.
- [ ] **Step 2:** `xcodegen generate`; Suiten einzeln → FAIL.
- [ ] **Step 3: Implement** Antworten/Schreiber/Hinweise (reine Logik zuerst), dann Views im Stil der vorhandenen `OnboardingScreen`-Schritte und die Karte.
- [ ] **Step 4:** Vier Suiten → PASS; Simulator-Durchlauf je Entwurf (1.1–1.5, 4.1, 4.2) mit Screenshots gegen den Entwurf prüfen (App starten, nicht nur Tests).
- [ ] **Step 5: Commit** `feat(ios): Onboarding-Block „Dein Trainingsplan“`.

---

### Task 11: Planansicht „heute dran“ (Entwürfe 2.1–2.3)

**Files:**
- Create: `Screens/Training/PlanKarte.swift`, `Screens/Training/PlanZeile.swift`, `Screens/Home/HeuteDranZeile.swift`, `Screens/Training/PlanWarumView.swift` (Platzhalter mit Gründen)
- Modify: `Screens/Training/TrainingRootView.swift` (`wurzel` :381), `Screens/Training/TrainingAbschlussView.swift`, `Screens/Home/HomeRootView.swift`
- Test: neu `FitnessMemberTests/PlanAnzeigeTests.swift`

**Interfaces:**
- Produces:
  - `enum PlanAnzeige` (reine Logik): `zeilen(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?, uebungen: [String: Uebungsname], geraete: …) -> [PlanZeilenModell]` mit `name`, `untertitel` („3 × 8–12 · Reserve 1–3“; Cardio „20 Min“; optional „Optional: <Übung> zählt für <Muskelgruppe>“; getauscht „Heute: <Ersatzübung>“), `status`, `vorschaubildModell` (Gerät der Position; ist es stillgelegt/entfernt: ein anderes aktives Gerät mit derselben Übung, sonst kein Bild), `zusaetzlichGemacht` (ungeplante Übungen der Session mit Satzzahl), `fortschritt` („3 von 7“, zählt erledigte und optionale), `restminutenText`.
  - `PlanKarte` über „Gerät wählen“ (Training-Tab, vor und während des Trainings, Entwurf 2.1/2.2): Kopf „HEUTE DRAN · Einheit A“, Meta „7 Übungen · ca. 63 Min“, Zeilen mit **Vorschaubild links, Status rechts** (offen Kreis, erledigt Haken, optional gestrichelter Kreis, getauscht ⇄), „Danach: Einheit B“, Link „Warum so?“. Ohne Plan im aktiven Studio: nichts (Tab wie heute). Die Akzentfläche bleibt „Gerät scannen“.
  - `HeuteDranZeile` auf Home (Einheit, Übungszahl, Tippen → Training-Tab).
  - Abschluss (2.3): Karte „Einheit A · 5 von 7 erledigt, 1 optional · Nächstes Mal ist Einheit B dran“; Anfängerangebot („Zeit, den Plan anzupassen?“ → `OnboardingFlow(umfang: .nurVorschau)` mit neuem Vorschlag) wenn `anfaengerUebergang`.
- Pause-Timer (F6): Der Resttimer nimmt bei Planübungen `pauseSek` der Position, sonst wie heute die Profil-Satzpause (`Rastwerte`/`Resttimer`) – Wert über `PlanAnzeige.pauseSek(fuer exerciseId:)` aus dem Ablaufzustand.

- [ ] **Step 1: Failing tests:** `Untertitel Mehrgelenk 3 x 8-12 mit Reserve`; `Cardio zeigt Minuten statt Saetze`; `optional nennt die ausloesende Uebung und Muskelgruppe`; `getauscht zeigt Heute: Ersatz`; `Fortschritt zaehlt erledigt plus optional`; `stillgelegtes Geraet: Bild vom anderen Geraet derselben Uebung`; `ohne Ersatzgeraet kein Bild, Zeile bleibt`; `zusaetzlich gemacht listet ungeplante Uebungen mit Satzzahl`; `Pause kommt aus der Planposition, sonst aus dem Profil`; `Plankarte entfaellt ohne Plan`.
- [ ] **Step 2:** `PlanAnzeigeTests` → FAIL.
- [ ] **Step 3: Implement** `PlanAnzeige` und die Views; Vorschaubild über das vorhandene `VorschauLader`/`Vorschaubild`; Zeilen mit VoiceOver-Label „<Übung>, <Status>, <Vorgabe>“.
- [ ] **Step 4:** Suite → PASS; Simulator: Entwürfe 2.1, 2.2, 2.3 nachstellen (Plan im Bootstrap, Sätze anlegen, ungeplante Übung, Beenden, Neustart-Test: Ablauf bleibt), Screenshots prüfen.
- [ ] **Step 5: Commit** `feat(ios): Plankarte „heute dran“ mit Ablaufstatus`.

---

### Task 12: Position-Sheet und Tausch (Entwürfe 3.1–3.3)

**Files:**
- Create: `Screens/Training/PlanPositionSheet.swift`, `Screens/Training/PlanTauschSheet.swift`
- Modify: `Screens/Training/PlanKarte.swift`, `Screens/Training/TrainingRootView.swift`
- Test: `FitnessMemberTests/PlanTauschTests.swift`

**Interfaces:**
- Consumes: `Trainingsplan.alternativen`, `TrainingsplanAblaufStore.tauschen`, `APIClient.swapPlanPosition`, `CatalogStore` (Bootstrap neu laden).
- Produces: `enum PlanTausch { static func kandidaten(position: TrainingsplanPosition, alternativen: [String: [Alternative]], belegt: Set<String>, uebungen: …) -> [TauschKandidat] }` (Kandidaten des Bausteins, ohne die aktuelle Übung und ohne Übungen, die schon in der Einheit stehen; Reihenfolge wie vom Server; je Kandidat Name, Gerät, Muskeln, Vorschaubild); `PlanPositionSheet` (Vorgabe-Tags „3 Sätze · 8–12 Wdh. · Pause 2:30 · Reserve 1–3“, „Andere Übung wählen“ **nur wenn Kandidaten da sind**, „Schließen“; keine Akzentfläche); `PlanTauschSheet` (Liste mit Thumbnail links, „Wählen“ je Zeile, Schalter „Dauerhaft im Plan ändern“; Schalter an → Bestätigungsschritt mit „Übernehmen“, ruft `swapPlanPosition`, danach Bootstrap neu laden; Schalter aus → `ablaufStore.tauschen` sofort). Nur offene Positionen (`offen`/`getauscht`) sind tauschbar; Cardio über dieselben Kandidaten des Bausteins `cardio`. Offline und „dauerhaft“: Schalter gesperrt mit Hinweis „Braucht Verbindung“, „nur heute“ geht offline. Läuft eine Session mit gebundener Planversion, ändert „dauerhaft“ nur die künftige Version (Review Focus 2).

- [ ] **Step 1: Failing tests:** `Kandidaten enthalten nur den Baustein, ohne aktuelle Uebung und ohne schon geplante`; `Reihenfolge des Servers bleibt`; `keine Kandidaten -> kein Knopf Andere Uebung`; `nur heute: Zustand getauscht, kein Netzwerkaufruf`; `dauerhaft: Aufruf mit Plan-, Einheits-, Positionsschluessel, danach Bootstrap neu`; `dauerhaft offline gesperrt`; `erledigte Position ist nicht tauschbar`; `Tausch waehrend laufender Einheit aendert deren Planversion nicht`.
- [ ] **Step 2:** → FAIL.
- [ ] **Step 3: Implement** Logik und Sheets (Stil `ZirkelUebungswahlSheet`/Drawer).
- [ ] **Step 4:** Suite → PASS; Simulator: 3.1–3.3 durchspielen, Screenshots prüfen.
- [ ] **Step 5: Commit** `feat(ios): Planposition heute oder dauerhaft tauschen`.

---

### Task 13: Abschluss und Übergabe

**Files:**
- Create: `docs/superpowers/plans/2026-10-24-trainingsplan-etappe4-uebergabe.md`
- Modify: Memory `project_trainingsplan-stand.md`

- [ ] **Step 1:** `pnpm typecheck`, `pnpm lint`, `pnpm vitest run packages/domain`, Integrationsdateien dieser Etappe einzeln (`plan-schreibwege`, `session-plan`, `domain-trainingsplan`, `api-plans`, `domain-bootstrap`, `api-workout-sets`), ganze Suite `FitnessMemberTests`, Release-Build (`xcodebuild … -configuration Release build`). Alles grün bis auf die bekannten Vorbefunde.
- [ ] **Step 2:** `superpowers:verification-before-completion`, dann `superpowers:requesting-code-review` über den Branch.
- [ ] **Step 3: Prod-Migrationen nur nach ausdrücklicher Freigabe von Tim**, Reihenfolge `0062`, `0063`, jeweils **vor** dem Merge; vorher `list_migrations` gegen Prod prüfen und eine frische lokale Datenbank einmal mit allen Migrationen aufbauen (nur nach Rückfrage, geteilte DB). Danach Merge nur nach Freigabe; nicht pushen ohne Tims Wort.
- [ ] **Step 4:** Übergabe für Etappe 4 schreiben (offene Punkte, Form von `member.plans` und `plan`-Momentaufnahme, was Etappe 4 an Gewichten/Progression anschließt, Textbausteine Etappe 5).
- [ ] **Step 5: Commit** `docs: Übergabe Trainingsplan Etappe 4`; Memory aktualisieren.

---

## Self-Review (Spec-Abdeckung)

- Abschnitt 1 (Onboarding-Block, Bestandsnutzer „Plan einrichten“, Einwilligung getrennt, Widerruf): Task 10, 2 (Widerruf serverseitig bereinigt). Neuer Nutzer ohne Studio: Annahme oben.
- Abschnitt 5 (heutige Einheit, Abhaken, Optional/F2, Tausch, Cardio F19, keine Rückfragen): Task 5, 8, 9, 11, 12; „Session ↔ Planeinheit“ Task 4.
- F5 (Einheit erledigt, Zähler): Task 5, 6, 9; F6 (Pause aus Planposition): Task 11; F17 (Ablaufstatus offline, gemeinsame Testfälle): Task 5, 8; F20 (Plan je Studio): Task 6, 10.
- Übergabe: Punkt 1 (APIError) Task 7; 2 (Spaltenschutz) Task 2; 3 (Widerruf) Task 2; 4 (Mitgliedschaft bei accept) Task 2; 5 (Transaktion) Task 2; 6 (Auffüllrolle) Task 1; 10 (Anfängerübergang/Zähler) Task 1, 6, 11; 13 (Bootstrap) Task 6. Offen gelassen: 7 (Cardio-Felder ohne Bedeutung, Cardio nimmt immer das erste Gerät), 8 (Fokus als Mehrgelenk ersetzt Isolation), 9 (Wochenvolumen), 11 (Textbausteine Etappe 5), 12 (Betrieb: `pnpm catalog:import` auf Prod ist laut Memory erledigt).
- Nicht abgedeckt, weil vom Design nicht verlangt: Plan ändern nach der Annahme außer Tausch/Anfängerangebot (kein Profil-Einstieg); „Warum so?“-Texte (Platzhalter).
