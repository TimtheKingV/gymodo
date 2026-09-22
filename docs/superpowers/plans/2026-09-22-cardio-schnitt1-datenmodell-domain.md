# Cardio Schnitt 1: Datenmodell und Domain — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Die Datenbank und `packages/domain` kennen Belastung, Nebenbelastung, Umfang und Kategorie statt Kilogramm und Wiederholungen. Eine Beinpresse mit 2,5-kg-Schritten und „Beidbeinig 8–12" verhält sich danach Bit für Bit wie heute; ein Laufband mit km/h, Neigung und „Dauerlauf 15–20 min" lässt sich anlegen, bespielen und bekommt denselben Vorschlag von derselben Regel. Web kompiliert und funktioniert unverändert (nur Feldnamen); die neue Portal-Oberfläche ist Schnitt 2, iOS ist Schnitt 3.

**Architecture:** Migration `0045` benennt Spalten um und ergänzt sechs (Spec Abschnitt 4). In der Domain entsteht ein Modul `belastung.ts` als einziger Ort für Einheiten, Umfangsarten, Grenzen und Formatierung. `progression.ts` wird zu Version 2.0.0: dieselbe Regel, nur der Blockvergleich vergleicht das Paar `(load, secondaryLoad)`. Alles andere ist Umbenennung entlang derselben Nahtstellen. Ein Wächter-Test hält `category` aus der Regel fern (Spec Abschnitt 3.5).

**Tech Stack:** PostgreSQL 16 (lokal nur zur Syntaxprüfung), Supabase-Migrationen, TypeScript / Zod / Vitest (`packages/domain`), Next.js Server Actions (`apps/web`, nur Umbenennung).

**Quelle:** `docs/superpowers/specs/2026-09-21-cardio-geraete-design.md`, Fassung 3. Abschnitt 14 dort nennt die drei Schnitte; dies ist der erste.

## Global Constraints

- **Kommentare in TS und SQL ohne Umlaute** (ASCII, ae/oe/ue), wie im Bestand. Nutzertexte (Zod-Meldungen, Formatierer-Ausgaben) tragen Umlaute.
- **Kommentare begründen, sie beschreiben nicht.** Jeder Kommentar, der durch die Umbenennung falsch wird („Gewicht", „Wiederholungen" als Datenmodellwort), wird im selben Task umgeschrieben.
- **`body_measurements.weight_kg` und alles um Körpergewicht bleibt unangetastet.** Betroffen wären sonst `measurements.ts`, `goals.ts`, `bootstrap.ts` (`latestWeight`), `0042`. Die Umbenennung gilt nur der Trainingsbelastung.
- **Kein Zweig „wenn Cardio" in der Domain.** Die Einheit ist ein Wert, den Formatierer und Validierung lesen; die Regel liest nur Zahlen. `category` kommt in `progression.ts`, `abschluss.ts`, `workout.ts`, `machine-context.ts` nicht vor (Wächter-Test, Task 8).
- **Domain-Tests mit Vitest** (`pnpm -F @fitretro/domain test`), grün vor dem nächsten Task. Typecheck des ganzen Repos (`pnpm typecheck`) grün vor dem Commit; er deckt `tests/integration` mit ab (Root-`tsconfig.json`).
- **Integrationstests laufen nur gegen ein lokales Supabase** (`supabase start`, Docker). Wo das nicht verfügbar ist, werden sie angepasst und typgeprüft, und der Plan hält fest, dass sie nicht ausgeführt wurden.
- **Ein Commit je Task**, deutsche Message im Stil der Historie (`feat(domain): …`, `feat(db): …`, `docs: …`), mit den Trailern aus der Session.
- **Pushen** auf `claude/cardio-geraete-logik-u5bceq`, nie auf einen anderen Branch.

---

## Task 1: Spec-Nachtrag — die Reserve ist in der App schon gefallen

`2026-09-11-satzpfad-feinschliff.md`, Punkt 4: RIR ist aus Eingabe, Profil und Verlauf entfernt, neue Sätze schreiben `null`. Spec Abschnitt 3.3 behauptet noch „Reserve bleibt, Wortlaut ändert sich". Das ist falsch und würde in Schnitt 3 ein Rad bauen lassen, das es nicht mehr gibt.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-21-cardio-geraete-design.md` (Abschnitt 3.3, Abschnitt 5.2 letzter Absatz, Abschnitt 9 Rudergerät-Satz)

- [ ] **Step 1:** Abschnitt 3.3 umschreiben: `rir` bleibt Spalte und Regelpfad für Altdaten, die App erfasst sie seit dem 11. September nicht mehr. Für Cardio wie für Kraft entscheidet damit der Zwei-Tage-Pfad (`topTwice`). Kein Reserve-Chip in Schnitt 3.
- [ ] **Step 2:** Abschnitt 9, Rudergerät: „Dann entscheidet allein die Reserve" → „Dann entscheidet der Zwei-Tage-Pfad: zweimal in Folge das Ziel erreicht, eine Stufe hoch."
- [ ] **Step 3:** Commit `docs(specs): Cardio -- Reserve ist in der App schon gefallen`.

---

## Task 2: Migration `0045_belastung_umfang.sql`

**Files:**
- Create: `supabase/migrations/0045_belastung_umfang.sql`

**Interfaces:**
- Produces: Spalten `equipment_models.load_unit/load_step/load_min/load_max/secondary_unit/secondary_step/secondary_min/secondary_max/category`, `exercises.volume_kind/target_min/target_max`, `workout_sets.load/volume/secondary_load`, `progression_suggestions.result_load`. Constraints wie Spec Abschnitt 4.3.

- [ ] **Step 1:** Migration schreiben, Inhalt aus Spec Abschnitt 4.3, mit Begründungskommentaren. Der Check auf `reps` heißt `workout_sets_reps_check` (inline in 0013, automatisch benannt).
- [ ] **Step 2:** Lokal gegen PostgreSQL 16 prüfen: temporärer Cluster im Scratchpad, ein Shim für `auth.users`, `auth.uid()`, die Rollen `anon`/`authenticated`/`service_role` und `storage.buckets`/`storage.objects`, dann alle 45 Migrationen in Reihenfolge. Danach ein Rauchtest: eine Beinpresse und ein Laufband anlegen, je eine Übung, einen Satz mit und ohne `secondary_load`, die Constraints `secondary_all_or_none` und `volume_check` gezielt verletzen. Der Cluster wird danach gelöscht; das Skript liegt nicht im Repo.
- [ ] **Step 3:** Commit `feat(db): Belastung und Umfang statt Kilogramm und Wiederholungen (0045)`.

---

## Task 3: `belastung.ts` — ein Ort für Einheiten

**Files:**
- Create: `packages/domain/src/belastung.ts`
- Create: `packages/domain/src/belastung.test.ts`

**Interfaces:**
```ts
export const LOAD_UNITS = ["kg", "watt", "level", "kmh", "pct", "rpm"] as const;
export type LoadUnit = (typeof LOAD_UNITS)[number];
export const VOLUME_KINDS = ["reps", "seconds", "meters"] as const;
export type VolumeKind = (typeof VOLUME_KINDS)[number];
export const CATEGORIES = ["kraft", "cardio"] as const;
export type Category = (typeof CATEGORIES)[number];
export const loadUnitSchema, volumeKindSchema, categorySchema; // z.enum
/** Obergrenze je Umfangsart; die DB kennt nur 100000. */
export const MAX_VOLUME: Record<VolumeKind, number>; // reps 1000, seconds 14400, meters 100000
export function volumeZuGross(kind: VolumeKind): string; // Zod-/DomainError-Meldung
export function formatLoad(value: number, unit: LoadUnit): string;      // "80,0 kg", "120 W", "Level 8", "8,5 km/h", "6,0 %", "85 U/min"
export function formatLoadDelta(delta: number, unit: LoadUnit): string; // "+2,5 kg", "-10 W", "+1 Level"
export function formatVolume(value: number, kind: VolumeKind): string;  // "12 Wdh.", "20:00 min", "2.000 m"
export function formatVolumeRange(min: number, max: number, kind: VolumeKind): string; // "8–12 Wiederholungen", "15–20 min", "2.000–5.000 m"
export function defaultLoadRange(unit: LoadUnit): { min: number; max: number | null; step: number };
export function defaultTargetRange(kind: VolumeKind): { min: number; max: number };
export function snapToStep(value: number, min: number, max: number | null, step: number): number;
```
`formatLoad` für `kg` liefert genau, was `kg()` in `layout.tsx` heute liefert (eine Nachkommastelle, `de-DE`), damit der E2E-Text „Schritt 2,5 kg · ab 5,0 kg bis 100,0 kg" unverändert bleibt.

- [ ] **Step 1:** Tests zuerst: je Einheit ein Formatierungsfall, `20:00 min` und `12:30 min`, Bereich mit Tausenderpunkt, `snapToStep` rastet 82 auf 80 und 83 auf 85 (Schritt 5, min 50), klemmt am Maximum.
- [ ] **Step 2:** Modul schreiben. Kommentar am Kopf: warum ein Ort (Spec 5.3), und dass eine neue Einheit hier eine Zeile je Funktion kostet, sonst nichts.
- [ ] **Step 3:** Commit `feat(domain): belastung.ts -- ein Ort fuer Einheiten, Umfangsarten und Formatierung`.

---

## Task 4: `progression.ts` — Version 2.0.0

**Files:**
- Modify: `packages/domain/src/progression.ts`
- Modify: `packages/domain/src/progression.test.ts`
- Modify: `packages/domain/src/index.test.ts` (Version, Feldnamen)

**Interfaces:**
```ts
export const PROGRESSION_ALGO_VERSION = "2.0.0";
export type WorkoutSetInput = { load: number; secondaryLoad: number | null; volume: number; rir: number | null; problemFlag: boolean };
export type SatzZeile = { performed_at; load; secondary_load; volume; rir; problem_flag };
export type ProgressionInput = { targetMin; targetMax; loadStep; loadMin; loadMax; history };
export type ProgressionInputsRecord = { targetMin; targetMax; loadStep; loadMin; loadMax; currentLoad; currentSecondaryLoad; consideredBlocks };
export type ProgressionSuggestion = { algoVersion; resultLoad; resultSecondaryLoad; reasonCode; inputs };
export function suggestNextLoad(input: ProgressionInput): ProgressionSuggestion;
```
`uniformWeight` → `uniformLoad`, liefert `{ load, secondaryLoad } | null`. `topTwice` und `missedTwice` vergleichen das Paar des Vorblocks. `resultSecondaryLoad = resultLoad === null ? null : currentSecondaryLoad`. Begründungscodes unverändert.

- [ ] **Step 1:** Bestehende Tests umbenennen (Felder), dann je Fall eine Kopie mit `watt`/`seconds`-Werten und identischer Erwartung (`describe.each` über zwei Geräte: Beinpresse 2,5 kg 8–12 und Ergometer 5 W 1200–1800 s).
- [ ] **Step 2:** Neue Fälle: Neigung wechselt im Block → `daten_uneindeutig`; Neigung im Vorblock anders → kein `topTwice` (bleibt `im_korridor`), kein `missedTwice`; gleiche Neigung → identisch zu ohne; `secondaryLoad` wird im Ergebnis und in `inputs` mitgegeben; `target_min = target_max` mit zwei Tagen → Stufe hoch.
- [ ] **Step 3:** Implementierung. Kopfkommentar ergänzen: Version 2.0.0, was sich änderte und warum die Regel keinen Zweig hat.
- [ ] **Step 4:** Commit `feat(domain): Progression 2.0.0 -- Belastung und Umfang, Nebenbelastung muss gleich bleiben`.

---

## Task 5: `abschluss.ts` — Vorschlag mit Einheit

**Files:**
- Modify: `packages/domain/src/abschluss.ts`
- Modify: `packages/domain/src/abschluss.test.ts`

**Interfaces:**
```ts
export type Blockvorschlag = { machineId; exerciseId; resultLoad; deltaLoad; secondaryLoad; loadUnit: LoadUnit; secondaryUnit: LoadUnit | null; reasonCode; algoVersion };
export type Blockeinheiten = { loadUnit: LoadUnit; secondaryUnit: LoadUnit | null };
export function zuVorschlag(eingabe: { machineId; exerciseId; suggestion; einheiten: Blockeinheiten }): Blockvorschlag;
export function ausGespeichertenZeilen(paare, zeilen, completedAt, einheitenJeGeraet: Map<string, Blockeinheiten>): Blockvorschlag[];
export type GespeicherteVorschlagZeile = { …; result_load; inputs: { currentLoad?; currentSecondaryLoad? } | null };
```
`bloeckeDerSession` liest die Einheiten mit (`machines (equipment_models (load_unit, secondary_unit))` in derselben Abfrage über `workout_sets`) und gibt `einheitenJeGeraet` zurück; beide Pfade (rechnen, zurücklesen) bekommen sie so ohne zusätzlichen Roundtrip. Fehlt ein Gerät in der Map (darf nicht vorkommen), fällt der Block weg statt auf `kg` zu raten.

- [ ] **Step 1:** Tests umbenennen und um Einheiten ergänzen; ein Fall „Einheit fehlt → Block fällt weg".
- [ ] **Step 2:** Implementierung; Abfragen auf `load`, `volume`, `secondary_load`, `result_load`, `target_min/max`, `load_step/min/max`.
- [ ] **Step 3:** Commit `feat(domain): Abschlussvorschlag traegt Belastungseinheit und Nebenbelastung`.

---

## Task 6: `workout.ts` — Satz-PUT mit Nebenbelastung

**Files:**
- Modify: `packages/domain/src/workout.ts`
- Modify: `packages/domain/src/workout.test.ts`

**Interfaces:**
```ts
export const recordSetInputSchema = z.preprocess(aliasAufloesen, z.object({ …, load, volume, secondaryLoad: nullish, … }).refine(…));
export type RecordedSet = { …; load; secondaryLoad: number | null; volume; … };
```
`aliasAufloesen`: trägt das Objekt `weightKg` ohne `load`, wird es zu `load`; `reps` ohne `volume` zu `volume`. Kommentar nennt den Grund (`PendingWriteStore` alter App-Stände) und das Ablaufdatum (übernächster Release).

`recordSet` lädt mit dem Gerät das Modell (`equipment_models (secondary_unit, secondary_step, secondary_min, secondary_max)`) und mit der Übung `volume_kind`, prüft dann:
1. `volume <= MAX_VOLUME[volume_kind]`, sonst `validation_failed` mit `volumeZuGross(kind)`.
2. `secondary_unit` gesetzt ⇒ `secondaryLoad` Pflicht; nicht gesetzt ⇒ `secondaryLoad` muss fehlen oder `null` sein. Sonst `validation_failed`.
3. `secondaryLoad` wird mit `snapToStep` auf die Rastung des Modells gerundet.

- [ ] **Step 1:** Tests: Alias wird abgebildet; `secondaryLoad` optional im Schema; Beginn-nach-Satz-Fall bleibt. (Die Modellprüfung braucht die Datenbank und lebt in `tests/integration/domain-record-set.test.ts`, Task 9.)
- [ ] **Step 2:** Implementierung.
- [ ] **Step 3:** Commit `feat(domain): Satz-PUT mit load, volume und secondaryLoad; Aliase fuer einen Release`.

---

## Task 7: Lesepfade — `machine-context`, `bootstrap`, `sessions`, `progress`, `catalog`, `index`

**Files:**
- Modify: `packages/domain/src/machine-context.ts`, `bootstrap.ts`, `sessions.ts`, `progress.ts`, `catalog.ts`, `index.ts`

Feldnamen nach Spec Abschnitt 5.4 und 6:

| Datei | Alt | Neu |
|---|---|---|
| machine-context | `equipmentModel.weightStepKg/minWeightKg/maxWeightKg` | `loadUnit, loadStep, loadMin, loadMax, secondaryUnit, secondaryStep, secondaryMin, secondaryMax` |
| machine-context | `exercises[].targetRepsMin/Max` | `volumeKind, targetMin, targetMax` |
| machine-context | `history[].weightKg, reps[]` | `load, secondaryLoad, volume[]` |
| bootstrap | wie oben, plus `equipmentModel.category`, `lastSets[].load/secondaryLoad/volume` | |
| sessions | `SessionBlock.sets[].weightKg/reps` | `load, secondaryLoad, volume`; am Block `loadUnit, secondaryUnit, volumeKind` |
| progress | `firstWeightKg/currentWeightKg/changeKg`, `points[].topWeightKg/reps` | `firstLoad/currentLoad/changeLoad`, `loadUnit`, `volumeKind`, `points[].topLoad/volume` |
| catalog | `equipmentModelInputSchema`, `PatchSchema`, `CatalogModel` | `loadUnit`, `loadStep/Min/Max`, `category`, `secondaryUnit/Step/Min/Max` (alle vier oder keines, `superRefine`) |
| catalog | `exerciseInputSchema`, `CatalogExercise`, `StudioExercise` | `volumeKind`, `targetMin`, `targetMax` |
| index | Exporte | `suggestNextLoad`, `belastung.ts`-Exporte, Typen |

- [ ] **Step 1:** Datei für Datei umbenennen, Abfragen auf die neuen Spalten, Kommentare nachziehen. `machine-context` und `abschluss` rufen `suggestNextLoad` mit `loadMax: model.load_max ?? 9999` wie heute.
- [ ] **Step 2:** `pnpm -F @fitretro/domain typecheck` und `test` grün.
- [ ] **Step 3:** Commit `feat(domain): Lesepfade auf Belastung, Umfang und Kategorie`.

---

## Task 8: Wächter-Test für `category`

**Files:**
- Create: `packages/domain/src/kategorie-waechter.test.ts`

- [ ] **Step 1:** Test liest `progression.ts`, `abschluss.ts`, `workout.ts`, `machine-context.ts` als Text (`readFileSync`) und erwartet, dass `/\bcategory\b/` nirgends vorkommt. Kommentar: Spec Abschnitt 3.5, warum das die einzige Stelle ist, die das Versprechen hält.
- [ ] **Step 2:** Commit `test(domain): Waechter -- category bleibt aus der Regel draussen`.

---

## Task 9: Web kompiliert, Integrationstests angepasst

**Files:**
- Modify: `apps/web/app/portal/actions.ts`, `apps/web/app/portal/[studioId]/einrichten/actions.ts`
- Modify: `apps/web/app/portal/bausteine/ModellGewichtRad.tsx`, `UebungRepsRad.tsx` (nur `name`-Attribute)
- Modify: `apps/web/app/portal/[studioId]/(schreibtisch)/geraete/[modelId]/StammdatenFormular.tsx`, `layout.tsx`, `uebungen/page.tsx`
- Modify: `apps/web/app/portal/[studioId]/einrichten/geraet/[machineId]/uebungen/UebungSheet.tsx`, `page.tsx`
- Modify: `tests/integration/*.test.ts` (Spaltennamen in Seeds und Erwartungen; Liste in Spec Abschnitt 11)
- Modify: `tests/integration/domain-record-set.test.ts` (neue Fälle: Nebenbelastung Pflicht/verboten, Rundung, Umfangsgrenze, Alias), `domain-machine-context.test.ts` (Laufband liefert `loadUnit: "kmh"`, `secondaryUnit: "pct"`, Übung `volumeKind: "seconds"`)

Keine neue Oberfläche. Formularfelder heißen `loadMin/loadMax/loadStep` und `targetMin/targetMax`; Labels und Texte bleiben. `layout.tsx` formatiert über `formatLoad(wert, modell.loadUnit)`; für `kg` ist die Ausgabe identisch. Übungstexte „8–12 Wiederholungen" über `formatVolumeRange`.

- [ ] **Step 1:** Web umbenennen; `pnpm typecheck` grün.
- [ ] **Step 2:** Integrationstests umbenennen und ergänzen; `pnpm typecheck` grün. Ausführen, wenn `supabase start` verfügbar ist (`pnpm test:integration`); sonst im Commit und in der Zusammenfassung ausdrücklich festhalten, dass sie nicht gelaufen sind.
- [ ] **Step 3:** Commit `feat(web,tests): Feldnamen auf Belastung und Umfang; Integrationstests fuer Laufband und Nebenbelastung`.

---

## Selbstprüfung

- [ ] `pnpm -F @fitretro/domain test` grün, Zahl der Tests gestiegen (Progression doppelt, belastung, Wächter).
- [ ] `pnpm typecheck` grün über Domain, Web, Tests, E2E.
- [ ] `grep -rn "weight_kg\|weightKg" packages apps/web tests` trifft nur noch Körpergewicht (`measurements`, `goals`, `body_measurements`, `latestWeight`).
- [ ] `grep -n category packages/domain/src/{progression,abschluss,workout,machine-context}.ts` leer.
- [ ] Migration lief lokal gegen Postgres 16 durch, samt Rauchtest.
- [ ] Spec Abschnitt 3.3 stimmt mit dem Stand der App überein.

## Was dieser Schnitt NICHT tut

- Keine Portal-Oberfläche für Kategorie und Nebenbelastung (Schnitt 2). Neue Modelle entstehen mit `kg`, `kraft`, ohne Nebenbelastung; neue Übungen mit `reps`.
- Keine iOS-Änderung (Schnitt 3). Die App sendet `weightKg`/`reps`, der Alias fängt das.
- Kein `Kategorie`-Filter, keine Kennzahl.
- Keine Änderung an Schwellen oder Begründungscodes der Regel.
