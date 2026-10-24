# Trainingsplan Etappe 2 – Übergabe an die nächste Session

Stand 24.10.2026. Noch **kein** Umsetzungsplan, sondern Vorarbeit dafür. Nächster Schritt: mit `superpowers:writing-plans` daraus `2026-10-24-trainingsplan-etappe2-profil-und-plan.md` schreiben, Tim prüfen lassen, dann umsetzen.

Spec: `docs/superpowers/specs/2026-10-21-trainingsplan-design.md` (Etappe 2 = Abschnitte 1, 2, 3, 7, 8; F1, F9, F12, F14, F16, F19, F20).

## Rahmen

- Branch `claude/trainingsplan-etappe2` (Worktree `.claude/worktrees/trainingsplan-e2`), auf Stand master inkl. Etappe 1 (PR #83, gemergt 24.10.).
- Migration `0058` ist auf Prod (24.10., mit Tims Freigabe). Weitere Prod-Migrationen nur mit Tims ausdrücklicher Freigabe **und vor** dem Merge des Codes. Etappe 2 beginnt bei `0059`.
- Lokale Integrationstests: siehe Abschnitt „Lokale Testumgebung“ unten.

## Code-Karte (geprüft 23.10.)

**Katalog → DB:** `pnpm catalog:import` → `scripts/catalog-import.ts` → `ladeKatalog` (`katalog-laden.ts:13`) → `importiereKatalog` (`katalog-import.ts:272`, Upsert `onConflict studio_id,catalog_key`, löscht nie). Validator `katalog-datei.ts`, alle zod-Objekte `.strict()` (unbekannte Felder werden abgelehnt), Übungsschema `uebungSchema` (:104-125), Querprüfungen `querPruefen` (:247). `GYMTAVO_STUDIO_ID = 00000000-0000-4000-8000-000000000001`.
Neues Übungsfeld end-to-end: `uebungSchema` (+ `.default()` oder Fixture `katalog-testdaten.ts:46` anpassen) → Migration `alter table exercises add column …` → `katalog-plan.ts` `UebungZeile` (:46), `UEBUNG_FELDER` (:138), Mapping (:250-259) → Select in `katalog-import.ts:91` → Tests `katalog-datei.test.ts`, `katalog-plan.test.ts`, `gymtavo-katalog.test.ts`, `tests/integration/katalog-import.test.ts`.
`exercises.muscles` ist jsonb `[{key,name,role}]` (0056), keine eigene Tabelle.

**Studio → Übungen:** `machines(studio_id, equipment_model_id, status active|inactive)` → `equipment_models` (`catalog_model_id` → Gymtavo-Typ, `category kraft|cardio`, `equipment_group`, `cardio_werte`) → `equipment_model_exercises`. Übungen eines Geräts = eigene + die des Katalogtyps, zusammengeführt mit `uebungenMitKatalog` (`bootstrap.ts:248`, gleiche Logik `uebungenZusammenfuehren` in `machine-context.ts:248`). `getBootstrap` (`bootstrap.ts:377`) baut das schon, filtert aber weder Studio noch `status`. Cardio: `cardioGeraeteLaden` + `istCardioModell` (`cardio-geraete.ts:17, :70`).

**Profil/Ziele:** `profil.ts` (`TRAINING_GOALS = lose_weight, build_muscle, stay_fit, get_stronger`; `updateProfile`), `goals.ts` (`weekly_days` 1–7 über RPC `set_member_goal`; `aktiveZiele(client, userId)`). Routen `PUT /api/v1/me/profile`, `PUT /api/v1/me/goals`, `DELETE /api/v1/me/goals/[kind]`. Tests importieren Route-Handler direkt (`tests/integration/api-profil.test.ts`, `api-goals.test.ts`).
Gewicht: `body_measurements` (0042), `getMeasurements` (`measurements.ts:69`).

**Konventionen:** Migration wie `0043_member_goals.sql` (deutscher Kopfkommentar, `force row level security`, Policies `<tabelle>_select_own/_insert_own/_update_own/_delete_own` mit `user_id = (select auth.uid())`, keine Tabellen-Grants). API wie `apps/web/app/api/v1/me/measurements/route.ts` (`bearerClientFrom`, `errorResponse`/`fromDomainError`; 422/401/404/409/500; GET mit `cache-control: private, no-store`).
Bootstrap: `member = Profil & { latestWeight, goals }` (`bootstrap.ts:634-644`) – Plan später als `member.plan` o. ä.
Namenskonflikt vermeiden: `katalog-plan.ts`/`planeImport` ist der Katalog-Importplan → neue Dateien `trainingsplan-*.ts`.
Testhelfer: `tests/integration/helpers/clients.ts` (`createTestUser`, `userClient`, `serviceClient`, `uniqueEmail`, `accessTokenFor`). Der echte Katalog ist in Tests **nicht** geladen; Tests legen eigene Typen/Übungen unter `GYMTAVO` an und prüfen „enthält“ statt exakter Listen.

## Entwurf der Entscheidungen (Claudes Vorschlag, noch nicht mit Tim abgestimmt)

1. **Katalogfelder** je Übung, nur für Planübungen: `plan_baustein` (`beine_knie, beine_huefte, druecken, ziehen, schulter, arme, rumpf, beine_ergaenzung, cardio`), `plan_typ` (`mehrgelenk|isolation`), `plan_bereiche` text[] (`knie, huefte, unterer_ruecken, schulter, ellenbogen_handgelenk`). Im JSON ein optionales Objekt `plan`; vorhanden = für Pläne freigegeben (Freigabe per PR-Review durch Tim/Fachperson).
2. **Katalogdaten:** ca. 30 Geräte-/Kabelübungen + Cardio im `gymtavo.json` belegen; Test: jeder Pflichtbaustein hat ≥ 2 Kandidaten.
3. **Profil:** Tabelle `training_profiles` (user_id PK, `minutes` 30/45/60/75/90, `experience` neu/unregelmaessig/regelmaessig, `focus` text[] ≤ 2 aus brust, ruecken, schultern, arme, po, beine, bauch). Beschwerden getrennt: `training_limits` (user_id PK, `consent_at` not null, `areas` jsonb `{bereich: meiden|vorsichtig}`), Löschen = Einwilligung zurückziehen. Ziel/Tage aus `profiles.training_goal` und `weekly_days`.
4. **Generator** rein in `packages/domain` (`trainingsplan-generator.ts`, `trainingsplan-zeit.ts`): Eingabe Ziel, Tage, Minuten, Fokus, Erfahrung, Bereiche, Kandidaten (exerciseId, machineId, baustein, typ, bereiche, primäre Muskeln, Cardio). Ziel-Mapping: build_muscle/get_stronger → Muskelaufbau, stay_fit → Fitness, lose_weight → Abnehmen.
   Zeitformel je Übung: 1,5 min Einstellen + Sätze × 0,75 + (Sätze − 1) × Pause (Mehrgelenk 2,5 / Isolation 1,5) + 1,5 bei Aufwärmsatz (Mehrgelenk). Aufwärmen 5 min (bei 30 min nicht). Cardio Abnehmen: ≥ 60 min → 20, 45 → 10, 30 → 0. Budget darf um 5 % überschritten werden.
   Ablauf: Pflichtbausteine mit Zielsätzen; zu lang → 2 Sätze; dann Fokus, dann Ergänzungen (GK: schulter, rumpf, arme, beine_ergaenzung) solange es passt. Variation A/B: Kandidat i mod n je Baustein. „meiden“ schließt aus, „vorsichtig“ sortiert nach hinten.
   Nachgerechnet: 60 min Muskelaufbau regelmäßig = 7 Übungen ≈ 62,75 min; 30 min = 5 Übungen à 2 Sätze ≈ 30 min.
   Sätze/Wdh./Reserve wie Spec Abschnitt 3; Erfahrung „neu“ → 2 Sätze, Reserve 3–4 (Übergang nach 8 Einheiten erst in einer späteren Etappe).
   Ausgabe: Struktur, Einheiten mit Positionen, geschätzte Minuten, Gründe als Codes (für die Erklärseite in Etappe 5).
5. **Speicherung:** `training_plans` (user_id, studio_id, version, status `vorschlag|aktiv|ersetzt|verworfen`, regel_version, eingabe jsonb, einheiten jsonb, gruende text[]); höchstens ein aktiver Plan je Mitglied und Studio.
6. **API:** `GET/PUT /api/v1/me/training-profile`, `PUT/DELETE /api/v1/me/training-limits`, `POST /api/v1/me/plans {studioId}` (erzeugt Vorschlag), `POST /api/v1/me/plans/[id]/accept`, `GET /api/v1/me/plans?studioId=`.
7. **Grobe Tasks:** (1) Katalogfelder, (2) Katalogdaten, (3) Profil + Beschwerden, (4) Zielprofile + Zeitrechnung, (5) Generator, (6) Kandidaten aus Studio laden, (7) Plan speichern + API.

## Lokale Testumgebung (Stolpersteine vom 22./23.10.)

- Docker läuft über `colima start`; danach `pnpm supabase start` im Worktree.
- Im frischen Worktree die Versionsdateien aus dem Hauptverzeichnis kopieren, **nicht** die Prod-Verknüpfung: `postgres-version storage-version storage-migration gotrue-version rest-version` aus `supabase/.temp/` – sonst bricht `0020_media_buckets` mit „storage.buckets does not exist“.
- Volle Integrationssuite parallel überlastet die lokale Supabase (Timeouts 10–30 s). Betroffene Dateien gezielt bzw. mit `--no-file-parallelism` laufen lassen; bei zunehmenden Timeouts `pnpm supabase stop && pnpm supabase start`.
- Die Colima-VM-Uhr geht ~0,2 s vor → `api-workout-sets` „beendet die eigene Session“ flackert (vorbestehend).
- `kurse-lesen.test.ts` hat 3 Tests, die auch auf master rot sind.
