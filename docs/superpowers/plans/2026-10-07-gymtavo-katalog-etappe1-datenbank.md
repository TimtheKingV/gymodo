# Gymtavo-Katalog Etappe 1: Datenbank — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Datenbank kennt das Gymtavo-Studio, lässt jeden Angemeldeten dessen Gerätetypen und Übungen lesen, erlaubt Sätze ohne QR-Gerät (Freies Training und freie Gewichte) und gibt jedem seinen ganzen Verlauf zurück. Die App und das Portal verhalten sich nach dieser Etappe **unverändert**. Neu nutzen werden die Möglichkeiten erst Etappe 3 (Domain/API) und Etappe 4 (iOS).

**Architecture:** Eine Migration `0047_gymtavo_katalog.sql`, abschnittsweise aufgebaut. Jeder Task fügt einen Abschnitt hinzu und bringt seinen Integrationstest mit.
- Grundlage ist das Gymtavo-Studio: eine normale `studios`-Zeile mit `is_catalog = true`. Die Leserechte werden um `or is_catalog_studio(…)` erweitert.
- `workout_sets` und `progression_suggestions` bekommen `equipment_model_id`, `machine_id` wird optional.
- Ein Füll-Trigger setzt `equipment_model_id` aus der Maschine. Deshalb läuft der heutige Schreibpfad in `workout.ts` ohne Änderung weiter.
- Drei Stellen in der Domain müssen gegen die neue Sichtbarkeit abgesichert werden (Task 7), sonst würde die App doch etwas Neues zeigen:
  - Das Gymtavo-Studio darf nicht als eigenes Studio auftauchen.
  - Der Verlauf aus verlassenen Studios darf ohne Namen nicht abstürzen.

**Tech Stack:** PostgreSQL 16 (lokal zur Syntax- und Rauchprüfung), Supabase-Migrationen, Vitest-Integrationstests in `tests/integration` (laufen gegen ein lokales Supabase), TypeScript in `packages/domain`.

**Quelle:** `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md`, Abschnitte 5 und 11 (Etappe 1).

## Global Constraints

- **Kommentare in SQL und TS ohne Umlaute** (ae/oe/ue), wie im Bestand. Kommentare begründen, sie beschreiben nicht.
- **Spalten der Zeile in Policies immer mit dem Tabellennamen qualifizieren** (Warnung aus 0007/0013). Unqualifiziert löst PostgreSQL `studio_id` gegen die innere Tabelle auf, und die Prüfung prüft dann stillschweigend nichts.
- **Neue SECURITY-DEFINER-Funktionen** bekommen `set search_path = public, pg_temp`, liefern nur Booleans oder eng zugeschnittene Zeilen, `revoke all … from public, anon` und `grant execute … to authenticated`.
- **Policies werden mit `drop policy` + `create policy` unter demselben Namen ersetzt**, wie in 0033. So bleibt die Policy-Liste lesbar.
- **Kein Verhalten der App ändert sich in dieser Etappe.** Wo die gelockerte Sichtbarkeit durchschlagen würde, wird der Leser in Task 7 abgesichert.
- **Integrationstests** laufen nur gegen ein lokales Supabase (`supabase start`, Docker). Ist das in der Umgebung nicht verfügbar, gilt:
  - Die Tests werden trotzdem geschrieben und mit `pnpm typecheck` typgeprüft.
  - Die Migration wird gegen einen lokalen PostgreSQL-16-Cluster geprüft (Task 8).
  - Im Abschluss steht ausdrücklich, dass die Tests nicht ausgeführt wurden.
- **Ein Commit je Task**, deutsche Message im Stil der Historie (`feat(db): …`, `fix(domain): …`, `docs: …`), mit den Trailern der Session.
- **Pushen** nur auf `claude/gymtavo-katalog-design`. `supabase db push` gegen Produktion ist **nicht** Teil dieses Plans. Das entscheidet Tim nach dem Merge.

---

## Task 1: Spec-Nachtrag — drei Präzisierungen aus dem Bestand

Beim Lesen der Migrationen sind drei Punkte aufgefallen, die die Spec genauer fassen muss, bevor Code entsteht.

**Files:**
- Modify: `docs/superpowers/specs/2026-10-06-gymtavo-katalog-offener-zugang-design.md` (Abschnitte 5.1, 5.4, 11)

- [ ] **Step 1 (5.1, Beitritt):** Den Satz „`join_studio_by_tag`, `join_studio_by_code` und `accept_staff_invite` weisen das Gymtavo-Studio ab“ ersetzen durch einen einzigen Wächter-Trigger auf `studio_memberships`: Im Gymtavo-Studio gibt es keine Rolle `member`.
  - Begründung: Das deckt jeden heutigen und künftigen Beitrittsweg ab, ohne drei Funktionsrümpfe neu zu tippen.
  - Trainer-Einladungen bleiben möglich. Das Gymtavo-Team braucht sie für die spätere Pflege (Etappe 6).
- [ ] **Step 2 (5.1, Geräte):** Ergänzen: Ein zweiter Wächter-Trigger verhindert `machines` und `machine_tags` mit dem Gymtavo-Studio. Der Satz „gibt es nicht“ wird damit durchgesetzt statt nur behauptet.
- [ ] **Step 3 (5.4):** Ergänzen: Ein Füll-Trigger setzt `equipment_model_id` aus `machine_id`, wenn es fehlt. Dadurch schreibt `workout.ts` bis Etappe 3 unverändert weiter.
- [ ] **Step 4 (11):** Etappe 1 um „Leser absichern“ ergänzen:
  - Bootstrap und Startseite blenden das Gymtavo-Studio aus.
  - Verlauf und Fortschritt fallen bei fehlenden Namen auf `my_history_labels()` zurück.
- [ ] **Step 5:** Ergänzen unter 13 (offen): `studio_overview` (0034) gibt dem Gymtavo-Owner Summen über Freies Training aus. Das sind nur Summen, die Datenschutzgrenze bleibt. Wenn das nicht gewollt ist, schließt Etappe 3 das Gymtavo-Studio dort aus.
- [ ] **Step 6:** Commit `docs(spec): Gymtavo-Katalog -- Waechter, Fuell-Trigger, Leser absichern`.

---

## Task 2: Gymtavo-Studio und Wächter

**Files:**
- Create: `supabase/migrations/0047_gymtavo_katalog.sql` (Abschnitt 1)
- Create: `tests/integration/rls-gymtavo-katalog.test.ts`

**Interfaces:**
- Produces:
  - Spalte `studios.is_catalog boolean not null default false`
  - Funktion `public.is_catalog_studio(uuid) returns boolean`
  - Konstante Studio-ID `00000000-0000-4000-8000-000000000001`, Name `Gymtavo`

- [ ] **Step 1: Roter Test** in `rls-gymtavo-katalog.test.ts`, im Stil von `rls-workout-sets.test.ts` (`serviceClient`, `createTestUser`, `userClient`, `uniqueEmail`). Testfälle:
  - Ein Nutzer ohne jede Mitgliedschaft liest `studios` und bekommt genau die Gymtavo-Zeile (`is_catalog = true`), sonst nichts.
  - Ein Mitglied von Studio A liest `studios` und bekommt Studio A und Gymtavo, nicht Studio B.
  - `service_role` kann keine Mitgliedschaft mit `role = 'member'` im Gymtavo-Studio anlegen. Erwartet wird ein Fehler mit Code `P0001` und dem Text `gymtavo_keine_mitglieder`.
  - `service_role` kann einen `owner` im Gymtavo-Studio anlegen.
  - Eine `machines`-Zeile im Gymtavo-Studio wird abgewiesen.
  - Eine `machine_tags`-Zeile mit `studio_id` = Gymtavo wird abgewiesen.
  - `join_studio_by_code` mit dem `join_code` des Gymtavo-Studios liefert die leere Menge (Code inaktiv).
  - Ein Trainer von Studio A kann `is_catalog` an seinem Studio nicht setzen. Erwartet wird Code `42501`, weil der Spalten-Grant aus 0032 nur `name, timezone, cancellation_deadline_hours` erlaubt. Der Test hält fest, dass diese Grenze auch das neue Feld schützt.
- [ ] **Step 2: Migration, Abschnitt 1**:
  ```sql
  alter table public.studios add column is_catalog boolean not null default false;
  create unique index studios_genau_ein_katalog on public.studios (is_catalog) where is_catalog;

  create or replace function public.is_catalog_studio(p_studio_id uuid)
  returns boolean language sql security definer stable
  set search_path = public, pg_temp
  as $$ select coalesce((select s.is_catalog from public.studios s where s.id = p_studio_id), false); $$;
  revoke all on function public.is_catalog_studio(uuid) from public, anon;
  grant execute on function public.is_catalog_studio(uuid) to authenticated, service_role;

  insert into public.studios (id, name, is_catalog, join_code_active)
  values ('00000000-0000-4000-8000-000000000001', 'Gymtavo', true, false);

  drop policy studios_select on public.studios;
  create policy studios_select on public.studios
    for select to authenticated
    using (public.is_studio_member(studios.id) or studios.is_catalog);
  ```
  Dazu zwei Wächter-Trigger:
  - `studio_memberships`, `before insert or update`: Ist `is_catalog_studio(new.studio_id) and new.role = 'member'`, dann `raise exception 'gymtavo_keine_mitglieder'`.
  - `machines` und `machine_tags`, `before insert or update of studio_id`: Ist `is_catalog_studio(new.studio_id)`, dann `raise exception 'gymtavo_ohne_geraete'`.

  Zu jedem Trigger gehört ein Begründungskommentar. Für die Mitgliedschaft lautet er sinngemäß: Ein Wächter an der Tabelle statt Prüfungen in drei Beitrittsfunktionen erreicht auch künftige Wege.
- [ ] **Step 3:** Test grün (oder, ohne Docker, typgeprüft plus Rauchprüfung aus Task 8 vorgezogen).
- [ ] **Step 4:** Commit `feat(db): Gymtavo-Studio als lesbarer Katalog mit Waechtern (0047, Teil 1)`.

---

## Task 3: Leserechte auf den Katalog

**Files:**
- Modify: `supabase/migrations/0047_gymtavo_katalog.sql` (Abschnitt 2)
- Modify: `tests/integration/rls-gymtavo-katalog.test.ts`

- [ ] **Step 1: Roter Test.** Im `beforeAll` legt der Service-Client im Gymtavo-Studio diese Inhalte an:
  - Gerätetyp „Langhantel“ (`load_step 2.5`) mit einer Einstellung
  - Übung „Bankdrücken“
  - die Verknüpfung zwischen beiden
  - ein `instruction_assets` mit Pfad `<gymtavo-id>/…`
  - eine Datei im Bucket `instruction-videos` unter diesem Pfad

  Testfälle:
  - Nutzer ohne Studio liest Gerätetyp, Einstellung, Übung, Verknüpfung und Video-Eintrag und kann eine signierte URL für die Datei erzeugen.
  - Nutzer ohne Studio sieht von Studio A weder Modell noch Übung.
  - Nutzer ohne Studio kann im Gymtavo-Studio **nichts** anlegen, ändern oder löschen (je ein Versuch auf `equipment_models`, `exercises`, `equipment_model_exercises`).
  - Der Owner des Gymtavo-Studios (per Service-Rolle eingetragen) kann eine Übung anlegen.
- [ ] **Step 2: Migration, Abschnitt 2.** `drop` + `create` mit demselben Namen und `or public.is_catalog_studio(…)` für:
  - `equipment_models_select`: `is_studio_member(equipment_models.studio_id) or is_catalog_studio(equipment_models.studio_id)`
  - `equipment_setting_definitions_select`: im `exists` über `em` dieselbe Erweiterung auf `em.studio_id`
  - `exercises_select`: wie Modelle
  - `instruction_assets_select`: im `exists` dieselbe Erweiterung auf `em.studio_id`
  - `media_select` auf `storage.objects`: `… and (is_studio_member(storage_studio_id(name)) or is_catalog_studio(storage_studio_id(name)))`

  `equipment_model_exercises_select` folgt in Task 4 zusammen mit der Verweisregel. Die Schreib-Policies bleiben unverändert, denn `is_studio_staff` deckt den Gymtavo-Owner bereits ab.
- [ ] **Step 3:** Test grün.
- [ ] **Step 4:** Commit `feat(db): Gymtavo-Katalog fuer alle Angemeldeten lesbar (0047, Teil 2)`.

---

## Task 4: Zuordnung zum Gymtavo-Typ und Verweis auf Gymtavo-Übungen

**Files:**
- Modify: `supabase/migrations/0047_gymtavo_katalog.sql` (Abschnitt 3)
- Modify: `tests/integration/rls-gymtavo-katalog.test.ts`

- [ ] **Step 1: Roter Test.**
  - Ein Trainer von Studio A setzt `catalog_model_id` seines Modells auf die Gymtavo-Langhantel. Das geht.
  - Auf ein Modell von Studio B geht es nicht (`gymtavo_zuordnung_ungueltig`).
  - Ein Gymtavo-Modell mit gesetztem `catalog_model_id` wird abgewiesen, denn ein Katalog verweist nicht auf sich selbst.
  - Ein Trainer von Studio A hängt die Gymtavo-Übung „Bankdrücken“ an sein Modell. Das geht.
  - Ein Mitglied von Studio A sieht diese Verknüpfung.
  - Die Übung eines dritten Studios an sein Modell zu hängen, scheitert.
  - Eine Studio-A-Übung an das Gymtavo-Modell zu hängen, scheitert, auch für den Gymtavo-Owner.
  - Ein Trainer von Studio A legt unter seiner Verknüpfung mit der Gymtavo-Übung ein eigenes `instruction_assets` an. Das geht, und ein Nutzer ohne Studio sieht es nicht.
- [ ] **Step 2: Migration, Abschnitt 3:**
  - `alter table public.equipment_models add column catalog_model_id uuid references public.equipment_models (id) on delete restrict;` plus Index.
  - Trigger `equipment_models_zuordnung_pruefen` (security definer), `before insert or update of catalog_model_id, studio_id`. Ist `new.catalog_model_id` gesetzt, dann muss gelten:
    - `not is_catalog_studio(new.studio_id)`
    - das Ziel liegt in einem Katalog-Studio

    Sonst `raise exception 'gymtavo_zuordnung_ungueltig'`.
  - `equipment_models` hat keinen Spalten-Grant (nur `studios` und `machine_tags` haben einen, 0032/0026). Die neue Spalte ist damit für Personal schreibbar, und der Trigger ist die Grenze.
  - Die vier `equipment_model_exercises_*`-Policies neu. Der Join `e.studio_id = em.studio_id` wird zu
    `join public.exercises e on e.id = equipment_model_exercises.exercise_id and (e.studio_id = em.studio_id or public.is_catalog_studio(e.studio_id))`.
    - SELECT: `public.is_studio_member(em.studio_id) or public.is_catalog_studio(em.studio_id)`
    - INSERT/UPDATE/DELETE: `public.is_studio_staff(em.studio_id)`

    Die Bedingung `e.id = …exercise_id` steht jetzt im Join, deshalb fällt sie aus dem `where`. Der Kommentar aus 0005 („nur gueltig, wenn … demselben Studio“) wird umgeschrieben: dasselbe Studio oder Gymtavo, nie ein drittes, und ein Gymtavo-Modell nur mit Gymtavo-Übungen.
- [ ] **Step 3:** Test grün.
- [ ] **Step 4:** Commit `feat(db): Studio-Modell verweist auf Gymtavo-Typ, Gymtavo-Uebung am Studio-Geraet (0047, Teil 3)`.

---

## Task 5: Sätze ohne QR-Gerät und Freies Training

**Files:**
- Modify: `supabase/migrations/0047_gymtavo_katalog.sql` (Abschnitt 4)
- Modify: `tests/integration/rls-gymtavo-katalog.test.ts`
- Modify: `tests/integration/rls-workout-sets.test.ts` (nur, wenn ein bestehender Fall an der neuen Eindeutigkeit bricht)

**Interfaces:**
- Produces:
  - `workout_sets.equipment_model_id uuid not null`, `workout_sets.machine_id` nullable
  - `progression_suggestions.equipment_model_id uuid not null`, `progression_suggestions.machine_id` nullable
  - Eindeutigkeit je Block über `(session_id, machine_id, equipment_model_id, exercise_id, set_index)` mit `nulls not distinct`

- [ ] **Step 1: Roter Test.**
  - Ein Nutzer ohne Studio legt eine Einheit im Gymtavo-Studio an. Er speichert zwei Sätze an der Gymtavo-Langhantel mit „Bankdrücken“, ohne `machine_id`, und liest sie zurück.
  - Derselbe Nutzer kann keine Einheit in Studio A anlegen.
  - Ein Mitglied von Studio A speichert in einer Studio-A-Einheit:
    - einen Satz an seiner Maschine mit der Gymtavo-Übung (ohne `equipment_model_id` im Payload; der Füll-Trigger setzt es, und der Test prüft den Wert)
    - einen Satz ohne Maschine am Gymtavo-Typ
  - In einer Studio-A-Einheit wird abgewiesen:
    - eine Maschine, deren Modell nicht zum `equipment_model_id` passt
    - ein Modell aus Studio B
    - eine Übung aus Studio B
  - Blockstruktur ohne Maschine: zweimal Satz 1 am selben Gymtavo-Typ und derselben Übung in derselben Einheit wird abgewiesen (`23505`).
  - `progression_suggestions` ohne `machine_id` im Gymtavo-Studio wird gespeichert, mit Gerät aus fremdem Studio abgewiesen.
  - Bestehender Satz ohne Payload-Änderung: `rls-workout-sets.test.ts` läuft unverändert grün. Das ist der Beleg, dass `workout.ts` bis Etappe 3 weiterschreibt.
- [ ] **Step 2: Migration, Abschnitt 4:**
  ```sql
  alter table public.workout_sets add column equipment_model_id uuid references public.equipment_models (id) on delete restrict;
  update public.workout_sets s set equipment_model_id = m.equipment_model_id from public.machines m where m.id = s.machine_id;
  alter table public.workout_sets alter column equipment_model_id set not null,
                                  alter column machine_id drop not null;
  alter table public.workout_sets drop constraint workout_sets_unique_index_per_block;
  alter table public.workout_sets add constraint workout_sets_unique_index_per_block
    unique nulls not distinct (session_id, machine_id, equipment_model_id, exercise_id, set_index);
  create index on public.workout_sets (equipment_model_id);
  ```
  Dasselbe für `progression_suggestions` (ohne Eindeutigkeit).

  Füll-Trigger `fill_equipment_model_from_machine()` (plpgsql, security definer, ein Rumpf für beide Tabellen, `before insert or update of machine_id`): Ist `new.equipment_model_id is null and new.machine_id is not null`, dann wird es aus `machines` gelesen. Kommentar: Die RLS-Prüfung (`with check`) sieht die Zeile **nach** den BEFORE-Triggern. Die Konsistenzprüfung in der Policy wird deshalb nicht umgangen, sie prüft den gefüllten Wert.

  Policies neu (`drop` + `create`, Spalten qualifiziert):
  - `workout_sessions_insert` / `workout_sessions_update`: `is_studio_member(workout_sessions.studio_id)` wird zu `(public.is_studio_member(workout_sessions.studio_id) or public.is_catalog_studio(workout_sessions.studio_id))`.
  - `workout_sets_insert` und `workout_sets_update` (`using` und `with check`):
    ```sql
    workout_sets.user_id = (select auth.uid())
    and (public.is_studio_member(workout_sets.studio_id) or public.is_catalog_studio(workout_sets.studio_id))
    and exists (select 1 from public.workout_sessions ws
                where ws.id = workout_sets.session_id and ws.studio_id = workout_sets.studio_id and ws.user_id = workout_sets.user_id)
    and exists (select 1 from public.equipment_models em
                where em.id = workout_sets.equipment_model_id
                  and (em.studio_id = workout_sets.studio_id or public.is_catalog_studio(em.studio_id)))
    and (workout_sets.machine_id is null or exists (
          select 1 from public.machines m
          where m.id = workout_sets.machine_id and m.studio_id = workout_sets.studio_id
            and m.equipment_model_id = workout_sets.equipment_model_id))
    and exists (select 1 from public.exercises e
                where e.id = workout_sets.exercise_id
                  and (e.studio_id = workout_sets.studio_id or public.is_catalog_studio(e.studio_id)))
    ```
    Bei `using` reicht wie bisher Nutzer plus Studio.
  - `progression_suggestions_insert`: dieselbe Form ohne Session-Teil.
  - `member_machine_calibrations` bleibt unberührt.
- [ ] **Step 3:** Test grün, dazu die bestehenden `rls-workout-sets`, `rls-workout-sessions`, `rls-progression-suggestions`, `domain-record-set`, `api-workout-sets`.
- [ ] **Step 4:** Commit `feat(db): Saetze ohne QR-Geraet und Freies Training im Gymtavo-Studio (0047, Teil 4)`.

---

## Task 6: Der Verlauf gehört dem Nutzer

**Files:**
- Modify: `supabase/migrations/0047_gymtavo_katalog.sql` (Abschnitt 5)
- Modify: `tests/integration/rls-gymtavo-katalog.test.ts`

**Interfaces:**
- Produces: `public.my_history_labels()`. Sie liefert eine Tabelle mit diesen Spalten:
  - `exercise_id uuid`, `exercise_name text`, `volume_kind text`
  - `equipment_model_id uuid`, `model_name text`, `load_unit text`, `secondary_unit text`
  - `machine_id uuid`, `machine_label text`
  - `studio_id uuid`, `studio_name text`

  Sie gibt je verschiedener Kombination in den **eigenen** Sätzen eine Zeile aus.

- [ ] **Step 1: Roter Test.**
  - Ein Mitglied trainiert in Studio A an einer Studio-Übung und tritt per `delete` auf die eigene Mitgliedschaft aus.
  - Danach liest es seine Einheiten, Sätze und Vorschläge weiter.
  - `machines` und `exercises` von Studio A sieht es nicht mehr.
  - `rpc('my_history_labels')` liefert Übungsname, Gerätelabel und Studioname.
  - Ein anderer Nutzer bekommt aus `my_history_labels` keine dieser Zeilen.
  - Der Trainer von Studio A sieht die Sätze weiterhin nicht. Die Datenschutzgrenze aus 0033 bleibt bestehen; der Fall steht schon in `rls-workout-sets.test.ts` und muss grün bleiben.
- [ ] **Step 2: Migration, Abschnitt 5:**
  - `workout_sessions_select`, `workout_sets_select` und `progression_suggestions_select` neu, jeweils nur `<tabelle>.user_id = (select auth.uid())`.
  - Kommentar mit Bezug auf 0033: Die Grenze gegenüber dem Personal bleibt. Gelockert wird nur, was der Nutzer selbst sieht, weil der Fortschritt einer Gymtavo-Übung über Studios hinweg läuft (Spec E5).
  - `my_history_labels()`: `language sql security definer stable`, `where s.user_id = auth.uid()`, Left Joins auf `machines`, `equipment_models`, `exercises`, `studios`, `select distinct`.
  - `revoke` von `public, anon`; `grant execute` an `authenticated`.
  - Kommentar: Die Funktion gibt ausschließlich Namen von Zeilen heraus, auf die eigene Sätze verweisen. Sie ist kein Weg, einen fremden Katalog zu lesen.
- [ ] **Step 3:** Test grün.
- [ ] **Step 4:** Commit `feat(db): eigener Verlauf bleibt nach dem Austritt sichtbar (0047, Teil 5)`.

---

## Task 7: Leser absichern, damit die App sich nicht ändert

Durch die Tasks 2 bis 6 sehen drei Leser mehr als vorher. Ohne Absicherung würden sie Folgendes tun:
- `bootstrap.ts` würde Gymtavo als Studio melden, und `hasStudio` wäre für alle `true`.
- Die Startseite `apps/web/app/page.tsx` sähe nie mehr „Noch kein Studio“.
- `sessions.ts` und `progress.ts` bekämen nach einem Austritt Sätze mit `machines`/`exercises` = `null`.

**Files:**
- Modify: `packages/domain/src/bootstrap.ts` (Studio-Abfrage um Zeile 152)
- Modify: `apps/web/app/page.tsx` (Zeile 41)
- Modify: `packages/domain/src/sessions.ts` (Satz-Abfrage um Zeile 300, Typ `SetRow`)
- Modify: `packages/domain/src/progress.ts` (Satz-Abfrage um Zeile 79)
- Modify: `tests/integration/domain-bootstrap.test.ts`, `tests/integration/domain-sessions.test.ts`, `tests/integration/domain-progress.test.ts`

- [ ] **Step 1: Rote Tests:**
  - **Bootstrap:** Ein Nutzer ohne Studio bekommt `studios: []`. Ein Mitglied von A bekommt nur A, nicht Gymtavo.
  - **Sessions:** Nach dem Austritt aus A liefert `listMySessions` die alte Einheit mit Übungsname und Gerätelabel und wirft nicht.
  - **Progress:** Nach dem Austritt aus A erscheint die Übung im Fortschritt mit Namen.
- [ ] **Step 2: Umsetzung:**
  - `bootstrap.ts`: `.eq("is_catalog", false)` an der Studio-Abfrage. Den Kommentar „RLS beschraenkt jede dieser Abfragen auf die Studios des Mitglieds“ richtigstellen: Das Gymtavo-Studio ist für alle lesbar, und erst Etappe 3 liefert es gesondert als `catalog`. Die übrigen Bootstrap-Abfragen (Verknüpfungen, Einstellungen) liefern jetzt auch Gymtavo-Zeilen. Sie hängen aber nur an Modellen, die über die eigenen Maschinen erreicht werden, und bleiben deshalb unsichtbar. Das hält ein Kommentar fest, und der Bootstrap-Test prüft es (keine Gymtavo-Übung unter `machines[].exercises`).
  - `apps/web/app/page.tsx`: `.eq("is_catalog", false)`.
  - `sessions.ts` und `progress.ts`:
    - `SetRow.machine_id` wird zu `string | null`, die eingebetteten `machines`/`exercises` werden nullable.
    - Hat eine Zeile `machines === null` oder `exercises === null`, wird **einmal** `client.rpc("my_history_labels")` gerufen. Daraus entsteht eine Map je (`machine_id ?? equipment_model_id`, `exercise_id`), die die Lücken füllt.
    - Der Blockschlüssel in `sessions.ts` (`${row.machine_id}:${row.exercise_id}`) bleibt. Bis Etappe 3 schreibt die App nur Sätze mit Maschine.
    - Das Gerätelabel fällt ohne Maschine auf `model_name` zurück.
  - Keine weitere Verhaltensänderung. `machine-context.ts`, `abschluss.ts` und `workout.ts` filtern ohnehin nach `machine_id`/`session_id` und bleiben unberührt.
- [ ] **Step 3:** `pnpm -F @fitretro/domain test`, `pnpm typecheck`, Integrationstests aus Step 1 grün.
- [ ] **Step 4:** Commit `fix(domain): Gymtavo-Studio nicht als eigenes Studio, Verlauf nach Austritt mit Namen`.

---

## Task 8: Gesamtprüfung

- [ ] **Step 1: Migration gegen PostgreSQL 16**, wie im Cardio-Plan:
  - Temporärer Cluster im Scratchpad.
  - Ein Shim für `auth.users`, `auth.uid()`, die Rollen `anon`/`authenticated`/`service_role` und `storage.buckets`/`storage.objects`.
  - Alle 47 Migrationen in Reihenfolge.

  Danach ein Rauchtest in SQL mit `set local role authenticated` und `request.jwt.claims`:
  - Ein Nutzer ohne Studio liest Gymtavo, schreibt eine Einheit mit zwei Sätzen ohne Maschine und scheitert in einem fremden Studio.
  - Ein Altsatz mit Maschine bekommt per Füll-Trigger sein Modell.

  Der Cluster wird gelöscht, das Skript liegt nicht im Repo.
- [ ] **Step 2:** Wenn Docker verfügbar ist: `supabase start`, dann `pnpm test:integration` vollständig. Sonst den Grund festhalten.
- [ ] **Step 3:** `pnpm typecheck`, `pnpm -F @fitretro/domain test`, `pnpm -F web test`.
- [ ] **Step 4:** Diff gegen `master` adversarial lesen. Dabei vor allem prüfen:
  - jede neue Policy auf qualifizierte Spalten
  - jede SECURITY-DEFINER-Funktion auf `search_path` und Grants
  - dass keine Policy `is_catalog_studio` auf **Schreibwege** des Katalogs ausweitet
- [ ] **Step 5:** Push auf `claude/gymtavo-katalog-design`. In der Zusammenfassung an Tim stehen:
  - was lief und was nicht (Docker),
  - dass `supabase db push` aussteht,
  - dass das Gymtavo-Studio danach per Service-Rolle einen Owner braucht (sein Konto).

---

## Danach

Etappe 2 (Import) und Etappe 5 (Portal) bauen nur auf dieser Etappe auf und können parallel geplant werden. Etappe 3 (Domain/API) ist die Voraussetzung für die iOS-Etappe 4.
