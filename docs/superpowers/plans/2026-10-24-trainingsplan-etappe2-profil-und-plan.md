# Trainingsplan Etappe 2 – Profil und Plangenerator (Server) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Server speichert Trainingsprofil und Beschwerden eines Mitglieds und erzeugt daraus deterministisch einen Trainingsplan für ein Studio, den das Mitglied per API abruft und bestätigt.

**Architecture:** Der Katalog markiert ca. 30 Übungen als Planübungen (`plan`: Baustein, Typ, belastete Bereiche). Ein reiner Generator in `packages/domain` bekommt Profil, Beschwerden und Kandidaten (aktive Geräte des Studios × Planübungen) und liefert Einheiten, Positionen, geschätzte Minuten und Begründungscodes; die Zeitrechnung ist eine versionierte Konstantentabelle. Pläne liegen als versionierte Zeilen in `training_plans` (Einheiten als jsonb, höchstens ein aktiver Plan je Mitglied und Studio); `POST` erzeugt einen Vorschlag, `accept` macht ihn atomar aktiv.

**Tech Stack:** TypeScript/vitest (`packages/domain`, `tests/integration`), Zod (Katalog-Validator), Supabase-Migrationen (SQL), Next.js API (`apps/web`).

**Spec:** `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` (Abschnitte 1, 2, 3, 7, 8; F1, F9, F12, F14, F16, F19, F20). Vorarbeit und Code-Karte: `docs/superpowers/plans/2026-10-24-trainingsplan-etappe2-uebergabe.md`.

## Etappen des Gesamtprojekts

| Etappe | Inhalt | Stand |
|---|---|---|
| 1 – Voraussetzungen | Blöcke je Session, Satzrolle, Reserve-Abfrage | gemergt (PR #83), Migration 0058 auf Prod |
| **2 – Profil und Plan (Server)** (dieser Plan) | Katalogfelder und -daten, Profil, Beschwerden, Generator, Plan-Speicherung, API | – |
| 3 – Plan im Studio (iOS) | Onboarding-Block, Planansicht, Ablaufstatus (F17), Tausch, Session ↔ Planeinheit, Einheitenzähler (F5) | – |
| 4 – Gewichte | Startschätzung, Übertragung, Planziele in der Progression, Wiedereinstieg | – |
| 5 – Erklärungen | Texte zu den Begründungscodes, Begründungen zu Vorschlägen | – |

**Bewusst nicht in Etappe 2:** Anfängerübergang nach 8 Einheiten (braucht den Einheitenzähler, Etappe 3; Pläne für „neu“ werden in Phase 1 erzeugt), Planpositionen als eigene Tabelle (Etappe 3 verweist auf `(plan_id, einheit_key, position_key)` im jsonb), `member.plan` im Bootstrap, Sessions ↔ Planeinheit, Vorschlagsprotokoll-Erweiterung, Textbausteine (nur Codes).

## Entscheidungen mit Tim (24.10.)

- Alle Strukturen der Spec werden gebaut (Ober/Unter bei 4 Tagen, A/B/C bei 5–6).
- Erfahrung „neu“: Phase 1 fest (2 Sätze, Reserve 3–4); Übergang kommt mit dem Einheitenzähler.
- Katalogwerte befüllt Claude konservativ, Tim gibt sie im PR frei; `plan` vorhanden = für Pläne freigegeben.

## Global Constraints

- Arbeit im Worktree `.claude/worktrees/trainingsplan-e2` auf Branch `claude/trainingsplan-etappe2`. Lokale Testumgebung: `colima start`, dann `pnpm supabase start`; im frischen Worktree `postgres-version storage-version storage-migration gotrue-version rest-version` aus `supabase/.temp/` des Hauptverzeichnisses kopieren (nicht die Prod-Verknüpfung). Integrationstests gezielt je Datei bzw. `--no-file-parallelism`; bei Timeouts `pnpm supabase stop && pnpm supabase start`. Vorbestehend rot: 3 Tests in `kurse-lesen.test.ts`, flackernd `api-workout-sets` „beendet die eigene Session“.
- Migrationen heißen `0059_plan_katalogfelder.sql`, `0060_trainingsprofil.sql`, `0061_trainingsplaene.sql`. **Nicht auf Supabase-Prod anwenden ohne ausdrückliche Freigabe von Tim, und dann immer vor dem Merge des Codes.** Migrationen sind additiv und für den alten Code unschädlich.
- Konventionen für Migrationen wie `0043_member_goals.sql`: deutscher Kopfkommentar, `force row level security`, Policies `<tabelle>_select_own/_insert_own/_update_own/_delete_own` mit `user_id = (select auth.uid())`, keine Tabellen-Grants. API wie `apps/web/app/api/v1/me/measurements/route.ts` (`bearerClientFrom`, `errorResponse`/`fromDomainError`; 401/404/409/422/500; GET mit `cache-control: private, no-store`).
- Neue Dateien heißen `trainingsplan-*.ts` (`katalog-plan.ts`/`planeImport` ist der Katalog-Importplan, nicht verwechseln). Domain-Funktionen exportieren über `packages/domain/src/index.ts`.
- Regeln nur serverseitig in `packages/domain` (F15). Generator ist rein (kein DB-Zugriff, keine Uhr, kein Zufall): gleiche Eingabe → gleicher Plan.
- Planregel-Version `PLAN_REGEL_VERSION = "1.0.0"` (in `trainingsplan-regeln.ts`), wird am Plan gespeichert.
- Zeitvorgaben v1 (Spec Abschnitt 2): Aufwärmen 5 min (bei 30 min entfällt es), Satz 45 s (0,75 min), Pause Mehrgelenk 2,5 min / Isolation 1,5 min (zwischen den Sätzen), Aufwärmsatz 1,5 min je Mehrgelenkübung, Gerät wechseln 1,5 min je Übung, Cardio nur Abnehmen: ≥ 60 min → 20, 45 → 10, 30 → 0. Budgetüberschreitung höchstens 5 %.
- Zielprofile (Spec Abschnitt 3): Muskelaufbau Mehrgelenk 8–12 / Isolation 10–15 Wdh., 3 Sätze, Reserve 1–3; Fitness 10–15 Wdh., 2 Sätze, Reserve 2–3; Abnehmen 10–15 Wdh., 3 Sätze (bei knapper Zeit 2), Reserve 2–3; Erfahrung „neu“ überschreibt: 2 Sätze, Reserve 3–4. `get_stronger` wird wie Muskelaufbau geplant (F1), `stay_fit` = Fitness, `lose_weight` = Abnehmen.
- Beschwerden sind Gesundheitsdaten (DSGVO Art. 9): eigene Tabelle, `consent_at` not null, Einwilligung zurückziehen = Zeile löschen; kein Freitext; Geschlecht, Alter, Größe, Gewicht fließen **nicht** in den Plan (F7).
- Code-Kommentare ASCII (ae/oe/ue/ss) und nennen einen Grund; Markdown und fachliche Texte mit echten Umlauten. Fehlermeldungen der API deutsch wie im Bestand.
- Commits deutsch, Form `feat(domain): …` / `feat(api): …` / `feat(db): …` / `feat(katalog): …` / `test(…)`, ein Commit je Task. Trailer exakt: `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Nicht pushen, bis Tim es sagt.

## Review Focus

1. **Studio ohne passendes Gerät für einen Pflichtbaustein** (z. B. keine Druckmaschine aktiv): kein stiller Plan ohne Pflichtbaustein, sondern Fehler `plan_nicht_moeglich` mit dem fehlenden Baustein; API antwortet 422 (Task 5, 7).
2. **„meiden“ schließt alle Kandidaten eines Pflichtbausteins aus** (Knie meiden, Studio hat nur Beinpresse und Beinstrecker): nie eine gemiedene Übung planen; stattdessen `plan_nicht_moeglich`. „vorsichtig“ sortiert nur nach hinten, schließt nie aus (Task 5).
3. **Nur 1 Kandidat in einem Baustein bei A/B-Wechsel:** beide Einheiten bekommen dieselbe Übung, kein Fehler (Task 5).
4. **Studio ohne Cardiogerät, Ziel Abnehmen:** kein Cardio-Block, die Zeit geht an Kraftübungen, Code `abnehmen_kein_cardio_geraet` (Task 5).
5. **Zwei Vorschläge, dann Annahme des älteren:** alter Vorschlag ist nach neuem POST `verworfen`, `accept` darauf → 409; zwei parallele `accept` führen nie zu zwei aktiven Plänen (Task 7).
6. **Beschwerden-Einwilligung zurückgezogen, danach neuer Plan:** der Generator sieht keine Bereiche; bestehende Pläne bleiben unverändert (Task 3, 7).
7. **`weekly_days` = 7 oder fehlendes Ziel/Tage:** 7 wird wie 6 geplant; fehlen Ziel oder Tage, antwortet die API 422 `profil_unvollstaendig` statt zu raten (Task 7).

---

### Task 1: Katalogfeld `plan` (Validator, Import, Spalten)

**Files:**
- Create: `packages/domain/src/trainingsplan-typen.ts`, `supabase/migrations/0059_plan_katalogfelder.sql`
- Modify: `packages/domain/src/katalog-datei.ts` (`uebungSchema` :104-125, `querPruefen` :247), `packages/domain/src/katalog-plan.ts` (`UebungZeile` :46, `UEBUNG_FELDER` :138, Mapping :250-259), `packages/domain/src/katalog-import.ts` (Select :91), `packages/domain/src/index.ts`
- Test: `packages/domain/src/katalog-datei.test.ts`, `packages/domain/src/katalog-plan.test.ts`, `tests/integration/katalog-import.test.ts`

**Interfaces:**
- Produces (`trainingsplan-typen.ts`, von allen Folgetasks genutzt):
  - `BAUSTEINE = ["beine_knie","beine_huefte","druecken","ziehen","schulter","arme","rumpf","beine_ergaenzung","cardio"] as const`, `type Baustein`
  - `PLAN_TYPEN = ["mehrgelenk","isolation"] as const`, `type PlanTyp`
  - `BEREICHE = ["knie","huefte","unterer_ruecken","schulter","ellenbogen_handgelenk"] as const`, `type Bereich`
  - `FOKUS_BEREICHE = ["brust","ruecken","schultern","arme","po","beine","bauch"] as const`, `type FokusBereich`
  - `ERFAHRUNG = ["neu","unregelmaessig","regelmaessig"] as const`, `type Erfahrung`
  - `MINUTEN = [30,45,60,75,90] as const`, `type Minuten`
  - `PFLICHT_BAUSTEINE = ["beine_knie","beine_huefte","druecken","ziehen"]`
  - `type PlanFeld = { baustein: Baustein; typ: PlanTyp; bereiche: Bereich[] }`
- Katalog-JSON: optionales Objekt `plan: { baustein, typ, bereiche? }` an der Übung (`bereiche` default `[]`), `.strict()`. Spalten an `exercises`: `plan_baustein text null`, `plan_typ text null`, `plan_bereiche text[] not null default '{}'`; Check: `plan_baustein` und `plan_typ` sind beide null oder beide gesetzt, Werte aus den Listen. Vorhanden = für Pläne freigegeben.

- [ ] **Step 1: Failing tests.** `katalog-datei.test.ts`: `akzeptiert eine Uebung mit plan` (Baustein `druecken`, Typ `mehrgelenk`, Bereiche `["schulter"]`), `lehnt unbekannten Baustein ab`, `lehnt plan ohne typ ab`, `lehnt unbekannte Felder in plan ab`, `Uebung ohne plan bleibt gueltig`. `katalog-plan.test.ts`: `uebertraegt plan_* in die Zeile` und `plan entfernt im Katalog setzt die Spalten auf null` (Änderungserkennung über `UEBUNG_FELDER`). `tests/integration/katalog-import.test.ts`: Import mit Planfeld schreibt `plan_baustein/plan_typ/plan_bereiche`; zweiter Import ohne Änderung ist ein No-op.
- [ ] **Step 2: Run** `pnpm vitest run packages/domain/src/katalog-datei.test.ts packages/domain/src/katalog-plan.test.ts` → FAIL (Feld unbekannt).
- [ ] **Step 3: Implement** `trainingsplan-typen.ts` wie oben; `uebungSchema` um `plan` erweitern (zod-Enums aus den Konstanten); `UebungZeile`/`UEBUNG_FELDER`/Mapping/Select um die drei Spalten; Fixture `katalog-testdaten.ts:46` bleibt gültig, weil `plan` optional ist.
- [ ] **Step 4: Migration `0059_plan_katalogfelder.sql`** (`alter table exercises add column …`, Check-Constraints). Lokal anwenden: `pnpm supabase db reset` oder `pnpm supabase migration up`.
- [ ] **Step 5: Run** die drei Testdateien (Integration: `pnpm vitest run tests/integration/katalog-import.test.ts`) → PASS.
- [ ] **Step 6: Commit** `feat(katalog): Übungen tragen Baustein, Typ und belastete Bereiche für Pläne`.

---

### Task 2: Katalogdaten für ca. 30 Planübungen + Cardio

**Files:**
- Modify: `catalog/gymtavo.json`
- Test: `packages/domain/src/gymtavo-katalog.test.ts`

**Interfaces:**
- Consumes: `plan`-Feld und Konstanten aus Task 1.
- Produces: im echten Katalog tragen mindestens 2 Übungen je Baustein ein `plan`-Objekt (Pflichtbausteine mindestens 2, damit A/B wechseln kann); Cardio-Übungen (`cardio_treadmill_walk`, `cardio_upright_bike`, `cardio_elliptical`, `cardio_rower` u. a.) sind Baustein `cardio`, Typ `isolation`, ohne Bereiche.

- [ ] **Step 1: Failing test** in `gymtavo-katalog.test.ts`: `jeder Pflichtbaustein hat mindestens zwei Planuebungen` (je `PFLICHT_BAUSTEINE`), `jeder uebrige Baustein hat mindestens eine`, `Planuebungen haben mindestens einen primaeren Muskel` (aus `muscles[].role`), `Mehrgelenk-Bausteine druecken, ziehen, beine_knie sind nie als isolation eingetragen`.
- [ ] **Step 2: Run** `pnpm vitest run packages/domain/src/gymtavo-katalog.test.ts` → FAIL.
- [ ] **Step 3: Katalogwerte setzen.** Kandidaten aus Spec Abschnitt 2 (`leg_press_45`, `leg_press_horizontal`, `hack`/`belt squat`, `hip_thrust_machine`, `leg_curl_seated`, `leg_curl_prone`, `chest_press_*`, `incline_chest_press`, `shoulder_press_machine`, `row_machine_*`, `cable_row_*`, `lat_pulldown_*`, `high_row_machine`, `lateral_raise_machine`, `cable_lateral_raise`, `preacher_curl_machine`, `triceps_extension_machine`, `ab_crunch_machine`, `cable_crunch_kneeling`, `back_extension`, `leg_extension_machine`, Waden) gegen die tatsächlichen Keys in `gymtavo.json` abgleichen; nur existierende Keys belegen. Bereiche konservativ: im Zweifel den Bereich eintragen (Beinpresse/Beinstrecker/Hack → `knie`; Hip Thrust, Rückenstrecker → `huefte`, `unterer_ruecken`; Schulterdrücken, Schrägbankpresse → `schulter`; Rudern/Latzug → `schulter`; Curls/Trizeps → `ellenbogen_handgelenk`; Back Extension, Rumpfübungen mit Beugung → `unterer_ruecken`). `review` bleibt `draft`.
- [ ] **Step 4: Run** Test aus Step 1 und `pnpm catalog:validate` (bzw. den vorhandenen Validator-Befehl in `package.json`) → PASS.
- [ ] **Step 5: Commit** `feat(katalog): Planübungen mit Baustein, Typ und Bereichen (zur Freigabe durch Tim)`. Im PR-Text die Tabelle Übung → Baustein/Typ/Bereiche auflisten, damit Tim sie dort freigibt.

---

### Task 3: Trainingsprofil und Beschwerden

**Files:**
- Create: `supabase/migrations/0060_trainingsprofil.sql`, `packages/domain/src/trainingsprofil.ts`, `apps/web/app/api/v1/me/training-profile/route.ts`, `apps/web/app/api/v1/me/training-limits/route.ts`
- Modify: `packages/domain/src/index.ts`; falls es einen Datenexport/eine Kontolöschung mit Tabellenliste gibt (`grep -rn "member_goals" packages apps/web --include=*.ts`), die beiden Tabellen dort ergänzen
- Test: `packages/domain/src/trainingsprofil.test.ts`, `tests/integration/api-training-profile.test.ts`, `tests/integration/api-training-limits.test.ts`

**Interfaces:**
- Consumes: `MINUTEN`, `ERFAHRUNG`, `FOKUS_BEREICHE`, `BEREICHE` (Task 1).
- Produces:
  - Tabelle `training_profiles(user_id uuid pk → auth.users on delete cascade, minutes int check in (30,45,60,75,90), experience text check in (neu, unregelmaessig, regelmaessig), focus text[] not null default '{}' check cardinality ≤ 2 und Werte aus `FOKUS_BEREICHE`, updated_at)`.
  - Tabelle `training_limits(user_id pk, consent_at timestamptz not null, areas jsonb not null, updated_at)`; `areas` hat Schlüssel aus `BEREICHE`, Werte `"meiden" | "vorsichtig"`.
  - `type TrainingProfile = { minutes: Minuten; experience: Erfahrung; focus: FokusBereich[] }`; `type TrainingLimits = { consentAt: string; areas: Partial<Record<Bereich, "meiden" | "vorsichtig">> }`.
  - `getTrainingProfile(client, userId): Promise<TrainingProfile | null>`, `saveTrainingProfile(client, userId, input: unknown): Promise<TrainingProfile>` (validiert, wirft `ValidationError` aus `errors.ts`; Duplikate in `focus` werden abgelehnt), `getTrainingLimits(client, userId): Promise<TrainingLimits | null>`, `saveTrainingLimits(client, userId, input: unknown, now: Date): Promise<TrainingLimits>` (Eingabe `{ einwilligung: true, areas }`, `einwilligung !== true` → `ValidationError`; `consent_at` = `now`), `deleteTrainingLimits(client, userId): Promise<void>`.
  - API: `GET|PUT /api/v1/me/training-profile` (404 bei GET ohne Profil), `GET|PUT|DELETE /api/v1/me/training-limits` (DELETE idempotent → 204).

- [ ] **Step 1: Failing tests (Domain)** `trainingsprofil.test.ts` (reine Validierung): `lehnt Minuten 50 ab`, `lehnt drei Fokusbereiche ab`, `lehnt doppelten Fokus ab`, `akzeptiert leeren Fokus`, `lehnt Beschwerden ohne einwilligung ab`, `lehnt unbekannten Bereich und unbekannte Stufe ab`, `leere areas mit einwilligung sind erlaubt`.
- [ ] **Step 2: Failing tests (Integration)** `api-training-profile.test.ts` / `api-training-limits.test.ts` (Muster `api-goals.test.ts`, Route-Handler direkt): 401 ohne Token; PUT → GET gibt dasselbe zurück; zweites PUT überschreibt; 422 bei ungültigen Werten; ein zweiter Nutzer sieht die Daten nicht (RLS); `limits` DELETE entfernt, GET danach 404; `consent_at` ist gesetzt und nicht vom Client steuerbar.
- [ ] **Step 3: Run** → FAIL.
- [ ] **Step 4: Migration `0060`** mit beiden Tabellen und den vier Policies je Tabelle; lokal anwenden.
- [ ] **Step 5: Implement** `trainingsprofil.ts` (zod-Validierung, `upsert` auf `user_id`) und die zwei Routen (Muster `measurements/route.ts`); Export in `index.ts`.
- [ ] **Step 6: Run** `pnpm vitest run packages/domain/src/trainingsprofil.test.ts` und die zwei Integrationsdateien einzeln → PASS.
- [ ] **Step 7: Commit** `feat(api): Trainingsprofil und Beschwerden mit Einwilligung`.

---

### Task 4: Regeln und Zeitrechnung

**Files:**
- Create: `packages/domain/src/trainingsplan-regeln.ts`, `packages/domain/src/trainingsplan-zeit.ts`
- Modify: `packages/domain/src/index.ts`
- Test: `packages/domain/src/trainingsplan-zeit.test.ts`, `packages/domain/src/trainingsplan-regeln.test.ts`

**Interfaces:**
- Consumes: Typen aus Task 1.
- Produces (`trainingsplan-regeln.ts`):
  - `PLAN_REGEL_VERSION = "1.0.0"`
  - `type Ziel = "muskelaufbau" | "fitness" | "abnehmen"`; `zielAusTrainingGoal(goal: string | null): Ziel | null` (`build_muscle`, `get_stronger` → muskelaufbau; `stay_fit` → fitness; `lose_weight` → abnehmen; sonst null)
  - `type Zielprofil = { saetze: 2 | 3; wdh: { mehrgelenk: [number, number]; isolation: [number, number] }; reserve: [number, number] }`; `zielprofil(ziel: Ziel, erfahrung: Erfahrung): Zielprofil` (Werte aus Global Constraints; „neu“ → 2 Sätze, Reserve [3,4])
  - `type Struktur = { key: "gk_eine" | "gk_ab" | "gk_abc" | "ober_unter"; einheiten: { key: string; bausteine: { pflicht: Baustein[]; ergaenzung: Baustein[] } }[] }`; `strukturFuerTage(tage: number): Struktur` (≤1 → eine GK-Einheit `A`; 2–3 → `A`,`B`; 4 → `OK_A`,`UK_A`,`OK_B`,`UK_B` mit Oberkörper = Pflicht `druecken`,`ziehen`, Ergänzung `schulter`,`arme`; Unterkörper = Pflicht `beine_knie`,`beine_huefte`, Ergänzung `beine_ergaenzung`,`rumpf`; ≥ 5 → `A`,`B`,`C`; Tage > 6 werden wie 6 behandelt). GK-Einheiten: Pflicht = `PFLICHT_BAUSTEINE`, Ergänzung = `schulter`,`rumpf`,`arme`,`beine_ergaenzung` (in dieser Reihenfolge).
  - `FOKUS_MUSKELN: Record<FokusBereich, string[]>` mit Katalog-Muskelkeys: brust `pectorals`; ruecken `lats`,`upper_back`; schultern `deltoid_lateral`,`deltoid_anterior`,`deltoid_posterior`; arme `biceps`,`triceps`; po `glutes`; beine `quads`,`hamstrings`,`calves`; bauch `abs`,`obliques`.
- Produces (`trainingsplan-zeit.ts`): Konstanten `ZEIT` (`aufwaermenMin: 5`, `satzMin: 0.75`, `pauseMin: {mehrgelenk: 2.5, isolation: 1.5}`, `aufwaermsatzMin: 1.5`, `einstellenMin: 1.5`, `toleranz: 0.05`), `cardioMinuten(minuten: Minuten): 0 | 10 | 20` (30 → 0, 45 → 10, ≥ 60 → 20), `uebungMinuten(typ: PlanTyp, saetze: number): number` (= `einstellenMin + saetze*satzMin + (saetze-1)*pause + (typ==="mehrgelenk" ? aufwaermsatzMin : 0)`), `aufwaermenMinuten(minuten: Minuten): number` (30 → 0, sonst 5), `pauseSekunden(typ: PlanTyp): number` (150 / 90).

- [ ] **Step 1: Failing tests Zeit:** `uebungMinuten("mehrgelenk", 3) === 10.25`, `("isolation", 3) === 6.75`, `("mehrgelenk", 2) === 7`, `("isolation", 2) === 4.5`; `cardioMinuten`: 30→0, 45→10, 60→20, 75→20, 90→20; `aufwaermenMinuten(30) === 0`, `(45) === 5`.
- [ ] **Step 2: Failing tests Regeln:** `zielAusTrainingGoal("get_stronger") === "muskelaufbau"`, `("lose_weight") === "abnehmen"`, `(null) === null`, `("xyz") === null`; `zielprofil("muskelaufbau","regelmaessig")` → 3 Sätze, Wdh. MG [8,12], Iso [10,15], Reserve [1,3]; `zielprofil("fitness","neu")` → 2 Sätze, Reserve [3,4]; `zielprofil("abnehmen","unregelmaessig")` → 3 Sätze, Reserve [2,3]; `strukturFuerTage`: 1 → 1 Einheit `A`; 3 → `A,B`; 4 → `OK_A,UK_A,OK_B,UK_B`; 5 und 6 → `A,B,C`; 7 → wie 6; jeder GK-Einheit enthält alle `PFLICHT_BAUSTEINE`; jeder Fokusbereich hat mindestens einen Muskelkey.
- [ ] **Step 3: Run** `pnpm vitest run packages/domain/src/trainingsplan-zeit.test.ts packages/domain/src/trainingsplan-regeln.test.ts` → FAIL.
- [ ] **Step 4: Implement** beide Dateien; reine Funktionen und `as const`-Tabellen, kein I/O. Kommentar an `ZEIT`: Vorgaben v1, später mit gemessenen Dauern (Pausensumme) nachjustieren.
- [ ] **Step 5: Run** → PASS.
- [ ] **Step 6: Commit** `feat(domain): Planregeln und Zeitrechnung v1`.

---

### Task 5: Plangenerator

**Files:**
- Create: `packages/domain/src/trainingsplan-generator.ts`
- Modify: `packages/domain/src/index.ts`
- Test: `packages/domain/src/trainingsplan-generator.test.ts`

**Interfaces:**
- Consumes: Typen (Task 1), `strukturFuerTage`, `zielprofil`, `FOKUS_MUSKELN`, `PLAN_REGEL_VERSION` (Task 4), `ZEIT`/`uebungMinuten`/`cardioMinuten`/`aufwaermenMinuten`/`pauseSekunden` (Task 4).
- Produces:
  - `type Kandidat = { exerciseId: string; machineId: string; baustein: Baustein; typ: PlanTyp; bereiche: Bereich[]; hauptmuskeln: string[] }` (Reihenfolge der Liste ist die Auswahlreihenfolge; Aufrufer sortiert nach `exerciseId`, dann `machineId` für Determinismus)
  - `type GeneratorEingabe = { ziel: Ziel; tage: number; minuten: Minuten; fokus: FokusBereich[]; erfahrung: Erfahrung; beschwerden: Partial<Record<Bereich, "meiden" | "vorsichtig">>; kandidaten: Kandidat[] }`
  - `type PlanPosition = { key: string; baustein: Baustein; rolle: "pflicht" | "fokus" | "ergaenzung" | "cardio"; exerciseId: string; machineId: string; typ: PlanTyp; saetze: number; wdhVon: number | null; wdhBis: number | null; reserveVon: number; reserveBis: number; pauseSek: number; aufwaermsatz: boolean; dauerMin: number | null; hauptmuskeln: string[] }` (`key` = Index in der Einheit als String; Cardio: `wdh*` null, `dauerMin` gesetzt, `saetze` 1, `pauseSek` 0)
  - `type PlanEinheit = { key: string; positionen: PlanPosition[]; geschaetzteMinuten: number }`
  - `type GeneratorErgebnis = { regelVersion: string; struktur: Struktur["key"]; einheiten: PlanEinheit[]; gruende: string[] }`
  - `generierePlan(eingabe: GeneratorEingabe): GeneratorErgebnis`; wirft `PlanNichtMoeglichError` (in `errors.ts` neben den anderen Domänenfehlern, `.baustein: Baustein`, `.grund: "kein_geraet" | "beschwerden"`).
- Ablauf je Einheit (Algorithmus, den die Tests festlegen):
  1. Budget = `minuten − aufwaermenMinuten − Cardio`; Cardio nur bei Ziel Abnehmen **und** vorhandenem Cardio-Kandidaten, sonst 0.
  2. Kandidaten je Baustein: „meiden“-Bereiche (Schnittmenge mit `bereiche`) ausgeschlossen; „vorsichtig“ stabil nach hinten sortiert. Variation: Einheit mit Index `i` nimmt je Baustein Kandidat `i mod n`; bei n = 1 immer derselbe. Ein Pflichtbaustein ohne Kandidat → `PlanNichtMoeglichError` (`kein_geraet`, wenn schon vor dem Beschwerdenfilter leer, sonst `beschwerden`).
  3. Pflichtpositionen mit Ziel-Satzzahl; passt die Summe nicht in `budget × 1,05`, werden alle Sätze auf 2 gesenkt (Gründe `zeit_saetze_reduziert`). Pflichtbausteine entfallen nie, auch wenn 2 Sätze noch zu lang sind.
  4. Verbleibende Zeit füllen: zuerst je Fokusbereich (bis 2, in Eingabereihenfolge) eine Übung der Einheit, deren `hauptmuskeln` einen Muskel aus `FOKUS_MUSKELN[bereich]` enthalten, die noch nicht in der Einheit steht und deren Baustein Pflicht oder Ergänzung dieser Einheit ist; sie hat Rolle `fokus` und nimmt den Platz der nächsten Ergänzung ein (F9, Gesamtzeit bleibt gleich). Gibt es in der Einheit keinen passenden Kandidaten, entfällt der Fokus dort; passt Pflicht + Fokus nicht ins Budget, entfällt der zweite Fokus (`fokus_zweiter_entfallen`). Danach Ergänzungsbausteine in der Reihenfolge aus `strukturFuerTage`, solange `Summe + uebungMinuten ≤ budget × 1,05` gilt.
  5. Aufwärmsatz (`aufwaermsatz: true`) bei jeder Mehrgelenkübung. Cardio-Position am Ende der Einheit mit `dauerMin = cardioMinuten`.
  6. `geschaetzteMinuten` = Aufwärmen + Summe `uebungMinuten` + Cardio.
- Gründe (Codes, Reihenfolge stabil, ohne Duplikate): `struktur_ganzkoerper_eine_einheit | struktur_ganzkoerper_ab | struktur_ganzkoerper_abc | struktur_ober_unter`, `zeit_uebungen`, `zeit_saetze_reduziert`, `zeit_ergaenzung_entfallen`, `zeit_aufwaermen_entfallen` (bei 30 min), `fokus_<bereich>` je berücksichtigtem Fokus, `fokus_zweiter_entfallen`, `abnehmen_cardio_zone`, `abnehmen_cardio_gekuerzt` (< 20 min), `abnehmen_kein_cardio_geraet`, `abnehmen_alltag` (Hinweis Alltagsbewegung/Ernährung), `bauch_kein_fettabbau` (Abnehmen + Fokus `bauch`), `anfaenger_reserve` (Erfahrung „neu“), `beschwerden_meiden`, `beschwerden_vorsichtig`.

- [ ] **Step 1: Failing tests** `trainingsplan-generator.test.ts` mit einem Testkatalog (je Baustein 2 Kandidaten, Mehrgelenk/Isolation passend zur Spec, ein Cardio-Kandidat):
  - `60 min Muskelaufbau regelmaessig, 3 Tage: 7 Positionen je Einheit (4 Pflicht, 3 Ergaenzungen), geschaetzteMinuten 62.75` (Testkatalog: beine_huefte und alle Ergaenzungen Isolation; 5 + 3×10,25 + 4×6,75; Obergrenze 63).
  - `30 min Muskelaufbau: 5 Positionen mit 2 Saetzen, kein allgemeines Aufwaermen, Minuten ≤ 31.5` und Gründe enthalten `zeit_aufwaermen_entfallen`, `zeit_saetze_reduziert`.
  - `45 min Fitness: 2 Saetze, Reserve [2,3]`.
  - `Abnehmen 60 min: letzte Position ist Cardio mit dauerMin 20, Minuten ≤ 63`; `45 min: dauerMin 10`, Code `abnehmen_cardio_gekuerzt`; `30 min: kein Cardio`.
  - `Abnehmen ohne Cardio-Kandidat: kein Cardio, Code abnehmen_kein_cardio_geraet, mehr Kraftuebungen als mit Cardio`.
  - `Erfahrung neu: alle Positionen 2 Saetze, Reserve [3,4], Code anfaenger_reserve`.
  - `A und B waehlen verschiedene Uebungen je Pflichtbaustein, wenn mindestens 2 Kandidaten`; `bei einem Kandidaten gleiche Uebung, kein Fehler`.
  - `4 Tage: vier Einheiten OK_A, UK_A, OK_B, UK_B; Oberkoerper enthaelt nur druecken/ziehen/schulter/arme`.
  - `Fokus po: jede Einheit mit passendem Kandidaten enthaelt genau eine Fokusposition, Zahl der Positionen gleich wie ohne Fokus`; `Fokus bauch + Abnehmen: Code bauch_kein_fettabbau`; `zwei Fokusse, Zeit reicht nur fuer einen: fokus_zweiter_entfallen`.
  - `meiden knie: keine Position hat bereich knie; vorsichtig knie: Kandidat mit knie steht hinten, wird aber gewaehlt, wenn er der einzige ist`.
  - `Pflichtbaustein ohne Kandidat wirft PlanNichtMoeglichError(kein_geraet)`; `alle Kandidaten eines Pflichtbausteins gemieden wirft PlanNichtMoeglichError(beschwerden)`.
  - `Determinismus: zweimal dieselbe Eingabe, tiefes Gleichheitsergebnis`; `Geschlecht/Alter sind kein Eingabefeld` (Typ-Test genügt: `GeneratorEingabe` enthält nur die oben genannten Felder).
- [ ] **Step 2: Run** `pnpm vitest run packages/domain/src/trainingsplan-generator.test.ts` → FAIL.
- [ ] **Step 3: Implement** `generierePlan` in `trainingsplan-generator.ts` nach dem Ablauf oben; Hilfsfunktionen privat in derselben Datei halten, solange sie unter ca. 300 Zeilen bleibt, sonst Auswahl (`waehleKandidaten`) nach `trainingsplan-auswahl.ts`. `PlanNichtMoeglichError` in `errors.ts`.
- [ ] **Step 4: Run** → PASS; dazu `pnpm --filter @gymtavo/domain typecheck` (bzw. den im Repo üblichen Typecheck-Befehl).
- [ ] **Step 5: Commit** `feat(domain): Plangenerator mit Zeitrechnung, Zielen, Fokus und Cardio`.

---

### Task 6: Kandidaten aus dem Studio laden

**Files:**
- Create: `packages/domain/src/trainingsplan-kandidaten.ts`
- Modify: `packages/domain/src/index.ts`; ggf. `packages/domain/src/bootstrap.ts` / `machine-context.ts`, falls `uebungenMitKatalog` bzw. `uebungenZusammenfuehren` exportiert werden müssen (nicht duplizieren)
- Test: `tests/integration/trainingsplan-kandidaten.test.ts`

**Interfaces:**
- Consumes: `Kandidat` (Task 5), `uebungenMitKatalog` (`bootstrap.ts:248`), `cardioGeraeteLaden`/`istCardioModell` (`cardio-geraete.ts:17, :70`).
- Produces: `ladeKandidaten(client: SupabaseClient, studioId: string): Promise<Kandidat[]>` – Kandidaten sind alle Übungen **mit** `plan_baustein` an aktiven Geräten (`machines.status = 'active'`) des Studios, eigene und Katalogübungen des Gerätetyps zusammengeführt wie in `getBootstrap`; `hauptmuskeln` = Keys der Muskeln mit `role = "primary"`; Cardio-Kandidaten aus Cardiogeräten (Baustein `cardio`). Sortiert nach `exerciseId`, dann `machineId`. Eine Übung an mehreren Geräten ergibt je Gerät einen Kandidaten.

- [ ] **Step 1: Failing test** (eigene Typen/Übungen unter `GYMTAVO` anlegen, wie die Katalog-Integrationstests; der echte Katalog ist nicht geladen, „enthält“ prüfen): `liefert nur aktive Geraete des Studios` (inaktives Gerät und Gerät eines zweiten Studios fehlen), `ignoriert Uebungen ohne plan`, `fuehrt Katalog- und eigene Uebungen zusammen`, `hauptmuskeln enthaelt nur primary`, `Cardiogeraet liefert Kandidat mit baustein cardio`, `Reihenfolge ist deterministisch`.
- [ ] **Step 2: Run** `pnpm vitest run tests/integration/trainingsplan-kandidaten.test.ts` → FAIL.
- [ ] **Step 3: Implement** `ladeKandidaten`: Geräte des Studios (aktiv) → Modelle → Übungen über die vorhandene Zusammenführung; nicht neu erfinden. Wo das Cardio-Mapping die Cardio-Übung nicht liefert, die Übung über `equipment_model_exercises` am Cardiomodell lesen.
- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** `feat(domain): Planübungen eines Studios als Generator-Kandidaten laden`.

---

### Task 7: Pläne speichern und API

**Files:**
- Create: `supabase/migrations/0061_trainingsplaene.sql`, `packages/domain/src/trainingsplan.ts`, `apps/web/app/api/v1/me/plans/route.ts`, `apps/web/app/api/v1/me/plans/[id]/accept/route.ts`
- Modify: `packages/domain/src/index.ts`
- Test: `tests/integration/api-plans.test.ts`, `tests/integration/domain-trainingsplan.test.ts`

**Interfaces:**
- Consumes: `generierePlan`, `GeneratorEingabe`, `PlanNichtMoeglichError` (Task 5), `ladeKandidaten` (Task 6), `getTrainingProfile`/`getTrainingLimits` (Task 3), `aktiveZiele` (`goals.ts`), `getProfile` (`profil.ts`, `training_goal`), `zielAusTrainingGoal`.
- Produces:
  - Tabelle `training_plans(id uuid pk default gen_random_uuid(), user_id → auth.users on delete cascade, studio_id → studios, version int not null, status text check in (vorschlag, aktiv, ersetzt, verworfen), regel_version text not null, eingabe jsonb not null, struktur text not null, einheiten jsonb not null, gruende text[] not null, created_at, accepted_at)`; `unique (user_id, studio_id, version)`; partieller Unique-Index `(user_id, studio_id) where status = 'aktiv'`; RLS wie `member_goals` mit `_select_own`, `_insert_own` und `_update_own` (kein Delete: Historische Versionen bleiben); der Server schreibt mit dem Client des Mitglieds.
  - SQL-Funktion `accept_training_plan(p_plan_id uuid) returns training_plans` (security invoker): setzt den aktiven Plan desselben (user, studio) auf `ersetzt`, den Vorschlag auf `aktiv` mit `accepted_at = now()`, in einer Transaktion; Fehler `plan_nicht_annehmbar` (SQLSTATE `P0001`), wenn der Plan nicht `vorschlag` des Aufrufers ist.
  - `type TrainingPlan = { id; studioId; version; status; regelVersion; eingabe: GeneratorEingabe-ohne-Kandidaten-Felder; struktur; einheiten: PlanEinheit[]; gruende: string[]; createdAt; acceptedAt: string | null }`
  - `erzeugePlanVorschlag(client, userId, studioId): Promise<TrainingPlan>` (liest Profil, Limits, Ziel, `weekly_days`, Kandidaten; fehlt Ziel, Tage oder Trainingsprofil → `ValidationError` mit Code `profil_unvollstaendig`; `PlanNichtMoeglichError` wird als `plan_nicht_moeglich` mit `baustein`/`grund` durchgereicht; verwirft vorhandene `vorschlag`-Zeilen des Paars; `version` = höchste vorhandene + 1; speichert `eingabe` ohne Kandidatenliste, aber mit den verwendeten `exerciseId`/`machineId` in `einheiten`), `acceptPlan(client, userId, planId): Promise<TrainingPlan>` (ruft die Funktion; Fehler → `ConflictError`), `listPlaene(client, userId, studioId): Promise<TrainingPlan[]>` (neueste Version zuerst; ohne `studioId`-Treffer leer).
  - API: `POST /api/v1/me/plans` Body `{ studioId }` → 201 `TrainingPlan`; `GET /api/v1/me/plans?studioId=` → 200 Liste (`private, no-store`); `POST /api/v1/me/plans/[id]/accept` → 200 `TrainingPlan`. Fehlercodes: 401, 404 (Studio unbekannt/kein Mitglied – Prüfung wie in den anderen studiobezogenen Routen, `grep -rn studioId apps/web/app/api/v1/me`), 409 (Plan nicht annehmbar), 422 (`profil_unvollstaendig`, `plan_nicht_moeglich`).

- [ ] **Step 1: Failing tests (Domain-Integration)** `domain-trainingsplan.test.ts` (Testdaten: Studio mit aktiven Geräten für alle Pflichtbausteine unter `GYMTAVO`, Profil, `weekly_days`, `training_goal`): `erzeugt Vorschlag mit version 1`; `zweiter Vorschlag verwirft den ersten und hat version 2`; `accept macht aktiv, ersetzt den bisherigen aktiven Plan`; `accept auf verworfenen Vorschlag wirft Konflikt`; `zwei parallele accept hinterlassen genau einen aktiven Plan` (Promise.all, danach Zeilen zählen); `Beschwerden meiden knie: keine Position mit Knie-Uebung`; `Beschwerden geloescht: gleicher Plan wie ohne Beschwerden`; `ohne Trainingsprofil: profil_unvollstaendig`; `ohne weekly_days: profil_unvollstaendig`; `weekly_days 7 plant wie 6` (Struktur `gk_abc`); `Studio ohne Druckmaschine: plan_nicht_moeglich baustein druecken`; `Plaene verschiedener Studios des Mitglieds sind unabhaengig` (aktiv in beiden); `fremder Nutzer sieht keinen Plan`.
- [ ] **Step 2: Failing tests (API)** `api-plans.test.ts` (Muster `api-goals.test.ts`): 401 ohne Token; POST → 201 mit `status: "vorschlag"` und `einheiten[0].positionen.length > 0`; accept → 200 `status: "aktiv"`; accept fremder Plan → 404 oder 409; GET listet; 422-Fälle tragen `code`.
- [ ] **Step 3: Run** beide Dateien → FAIL.
- [ ] **Step 4: Migration `0061`** inkl. Funktion und Index; lokal anwenden.
- [ ] **Step 5: Implement** `trainingsplan.ts` und die Routen (Muster `measurements/route.ts`; `PlanNichtMoeglichError` in `fromDomainError` auf 422 mappen).
- [ ] **Step 6: Run** beide Testdateien einzeln mit `--no-file-parallelism` → PASS; danach Gesamtlauf der berührten Domain-Unit-Tests `pnpm vitest run packages/domain` → PASS.
- [ ] **Step 7: Commit** `feat(api): Trainingspläne erzeugen, speichern und bestätigen`.

---

### Task 8: Abschluss und Übergabe

**Files:**
- Modify: `docs/superpowers/plans/2026-10-24-trainingsplan-etappe2-uebergabe.md` (Stand-Hinweis „umgesetzt“) oder neue Übergabe für Etappe 3 unter `docs/superpowers/plans/`

- [ ] **Step 1:** Volle Prüfung: `pnpm typecheck`, `pnpm lint`, `pnpm vitest run packages/domain`, Integrationsdateien dieser Etappe einzeln (Task 1, 3, 6, 7) – alles grün bis auf die bekannten Vorbefunde.
- [ ] **Step 2:** `superpowers:verification-before-completion`, dann `superpowers:requesting-code-review` über den Branch.
- [ ] **Step 3: Prod-Migrationen nur nach ausdrücklicher Freigabe von Tim**: Reihenfolge `0059`, `0060`, `0061` (alle additiv), jeweils vor dem Merge des Codes; vorher `list_migrations` gegen Prod prüfen. Danach Katalogimport auf Prod (`pnpm catalog:import`) ebenfalls nur mit Freigabe.
- [ ] **Step 4:** Übergabe-Notiz für Etappe 3 schreiben: Form von `TrainingPlan`/`PlanPosition` (Schlüssel `(plan_id, einheit_key, position_key)`), offene Punkte (Anfängerübergang, `member.plan` im Bootstrap, Textbausteine zu den Gründen, Hauptmuskeln aller Studioübungen für F17).
- [ ] **Step 5: Commit** `docs: Übergabe Trainingsplan Etappe 3`; Memory `project_trainingsplan-stand.md` aktualisieren.

---

## Self-Review (Spec-Abdeckung)

- Abschnitt 1 (Profil, Beschwerden, Einwilligung): Task 3, 7. Onboarding-UI: Etappe 3.
- Abschnitt 2 (Struktur, Bausteine, Zeitrechnung, F16): Task 4, 5; Katalogzuordnung Task 1, 2.
- Abschnitt 3 (Zielprofile, Fokus F9, Abnehmen-Hinweise als Codes): Task 4, 5. Anfängerübergang bewusst später.
- Abschnitt 7 (Profil, Plan mit Version, F20 je Studio): Task 3, 7. Session ↔ Planeinheit, Vorschlagsprotokoll: spätere Etappen.
- Abschnitt 8 (Freigabe nur ca. 30 Übungen): Task 2, Freigabe im PR.
- F1, F12, F14 (Pläne stabil, nur neuer Vorschlag auf Anforderung), F19 (Cardio als Position, entfällt ohne Gerät): Task 4, 5, 7.
