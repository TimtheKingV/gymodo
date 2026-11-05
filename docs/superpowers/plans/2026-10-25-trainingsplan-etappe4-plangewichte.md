# Trainingsplan Etappe 4: Plangewichte Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jede Kraft-Planposition bekommt ein Zielgewicht, das der Server nach jeder abgeschlossenen Einheit still für die nächsten Einheiten neu rechnet; ohne Plan gilt das letzte Gewicht.

**Architecture:** Reine Regel in `packages/domain` (`plangewicht.ts`), eigene Schicht `plan_gewichte` neben dem versionierten Plan (nur per `security definer`-RPC beschreibbar, Muster 0062/0063). Der Server liefert Zielgewicht samt Änderungswert und Grund-Code im Bootstrap und in der bestehenden `suggestion`-Form von Geräte-Kontext und Abschluss; die App zeigt an und rechnet nichts.

**Tech Stack:** TypeScript (`packages/domain`, vitest), Supabase/Postgres (Migrationen, RLS), Next.js-API (`apps/web`), SwiftUI (`apps/ios-member`).

**Spec:** `docs/superpowers/specs/2026-10-25-trainingsplan-plangewichte-design.md` (Entscheidungen G1–G21). Hintergrund: `2026-10-21-trainingsplan-design.md` Abschnitt 6 und `2026-10-24-trainingsplan-etappe4-uebergabe.md`.

## Global Constraints

- Alle Regeln laufen nur serverseitig in `packages/domain` (F15); die App rechnet keine Gewichte.
- Die Rechnung ist rein und versioniert: gleiche Eingabe, gleiches Ergebnis, keine Uhr, kein Zufall (Muster `progression.ts`). Version `PLANGEWICHT_ALGO_VERSION = "1.0.0"`.
- Nur Arbeitssätze (`set_role = 'arbeit'`) zählen; Problemmeldung schlägt jede Steigerung; Ergebnis liegt in `loadMin`..`loadMax` auf einer einstellbaren Stufe (abrunden).
- Die Planstruktur ändert sich durch Gewichtsänderungen nie (G1, keine neue Planversion).
- Laufende oder begonnene Einheiten werden nie verändert (G15: Session existiert = begonnen).
- Schreibwege nur über `security definer`-Funktionen, `revoke all … from public, anon, authenticated, service_role`, dann `grant execute … to authenticated` (Muster 0063).
- Hinweistext: ein Halbsatz aus festen Bausteinen, keine KI (F10), z. B. „+2,5 kg“.
- Prod-Schritte (Migrationen anwenden, Deploy) nur mit ausdrücklicher Freigabe von Tim. Reihenfolge: `0059`–`0064` vor dem API-Deploy.
- Tests: `pnpm --filter @fitretro/domain test` (rein), `pnpm test:integration -- <datei>` (Datenbank), Xcode-Tests für Swift. Der lokale Auth-Dienst ist langsam; Integrationstests einzeln laufen lassen.

## Review Focus

- Zielgewicht über `loadMax` oder zwischen zwei Stufen → auf die nächste einstellbare Stufe abgerundet, nie darüber (Task 1).
- Einheit ohne Arbeitssatz oder nur mit Aufwärmsätzen abgeschlossen → Ziele bleiben unverändert (Task 1, 4).
- Verspätet eintreffender Abschluss einer älteren Einheit nach einer neueren → ändert nichts (Task 3, 4).
- Mitglied nimmt am Gerät ein anderes Gewicht als das Ziel → die nächste Rechnung geht vom tatsächlichen Satz aus (Task 1, 4).
- Zweimaliges Abschließen/Neuberechnen derselben Einheit (Netzwiederholer, Lazy-Nachholen) → identisches Ergebnis, keine Dubletten (Task 3, 5).
- Position mit Tausch (`getauscht`) → Ziel der alten Übung wird nicht auf die Ersatzübung übertragen (Task 4).

## Dateien

- Create: `packages/domain/src/plangewicht.ts` (Regel), `plangewicht-start.ts` (Startwert, Übertragung, Wiedereinstieg), `plangewichte.ts` (Laden, Schreiben, Auslöser, Vorschlagsform), je mit `.test.ts`.
- Create: `supabase/migrations/0064_plan_gewichte.sql`, `0065_plan_tausch_typ.sql`.
- Modify: `packages/domain/src/{workout.ts,trainingsplan-bootstrap.ts,machine-context.ts,abschluss.ts,index.ts}`, `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift`, `Screens/Geraet/GeraetModel.swift`, `Screens/Training/TrainingAbschlussView.swift`, `Workout/PlanTausch.swift` bei Bedarf.
- Test: `tests/integration/rls-plan-gewichte.test.ts`, `tests/integration/domain-plangewichte.test.ts`, bestehende `session-plan.test.ts`/`api-plans.test.ts` erweitern.

---

### Task 1: Regel `berechnePlanGewicht`

**Files:** Create `packages/domain/src/plangewicht.ts`, `plangewicht.test.ts`; Modify `index.ts` (Export).

**Interfaces:**
- Produces:
  ```ts
  export const PLANGEWICHT_ALGO_VERSION = "1.0.0";
  export type PlanGewichtGrund =
    | "korridor_oben_erreicht" | "korridor_unten_verfehlt" | "im_korridor"
    | "problem_gemeldet" | "geraetegrenze_erreicht" | "kein_verlauf" | "daten_uneindeutig"
    | "letztes_gewicht" | "startschaetzung" | "uebertragung" | "wiedereinstieg";
  export type PlanGewichtEingabe = {
    position: { wdhVon: number; wdhBis: number; reserveVon: number };
    geraet: { loadStep: number; loadMin: number; loadMax: number };
    /** Arbeitssätze der abgeschlossenen Einheit, chronologisch; nur diese Position/Übung/dieses Gerät. */
    block: WorkoutSetInput[];
    /** Arbeitssätze der Einheit davor am selben Gerät und derselben Übung, falls vorhanden. */
    vorher: WorkoutSetInput[] | null;
    aktuellesZiel: { load: number; secondaryLoad: number | null } | null;
  };
  export type PlanGewichtErgebnis = { load: number | null; secondaryLoad: number | null; grund: PlanGewichtGrund };
  export function berechnePlanGewicht(e: PlanGewichtEingabe): PlanGewichtErgebnis;
  ```
  `WorkoutSetInput` kommt aus `progression.ts`.

- [ ] **Step 1: Failing tests** (`plangewicht.test.ts`), je ein Fall mit festen Zahlen (Bereich 8–12, `reserveVon` 1, Stufe 2,5, min 5, max 100):
  - alle Sätze 12 Wdh. bei 40 kg, letzter Satz RIR 2 → `{ load: 42.5, grund: "korridor_oben_erreicht" }`
  - wie oben, aber RIR 0 → bleibt 40, `im_korridor`
  - alle Sätze 12, RIR `null`, `vorher` ebenfalls oben bei 40 kg → 42.5; ohne `vorher` → 40
  - erster Satz 6 Wdh. in `block` und in `vorher`, beide bei 40 kg → 37.5, `korridor_unten_verfehlt`; nur einmal → 40
  - ein Satz mit `problemFlag` → 40, `problem_gemeldet`, auch wenn sonst oben
  - Ziel 100 = `loadMax`, oben erreicht → 100, `geraetegrenze_erreicht`
  - Sätze mit 41 kg bei Stufe 2,5 ab min 5 → rastet auf 42.5 bzw. 40 (nächste Stufe für den Istwert, wie `snapToNearestStep`)
  - `block` leer → `{ load: aktuellesZiel?.load ?? null, grund: "kein_verlauf" }`, nie eine Änderung
  - uneinheitliche Last im Block → `daten_uneindeutig`, Ziel unverändert
  - Ist-Satz 45 kg (Ziel war 40), alle oben mit RIR 2 → 47.5 (rechnet vom Ist)
- [ ] **Step 2:** `pnpm --filter @fitretro/domain test -- plangewicht` → FAIL (Modul fehlt).
- [ ] **Step 3: Implementieren.** Schwellen unverändert aus `progression.ts` v2.0.0 (Spec G18): erster Satz zählt für „unten verfehlt“, „oben erreicht“ = alle Sätze ≥ `wdhBis` und letzter Satz RIR ≥ `reserveVon`, sonst zwei Einheiten oben ohne RIR; Nebenlast nie steigern. Wiederverwendbare Hilfen aus `progression.ts` exportieren statt kopieren (`uniformLoad`, `snapToNearestStep` im Eingabe-Typ anpassen).
- [ ] **Step 4:** Tests PASS, `pnpm typecheck`.
- [ ] **Step 5:** Commit `feat(domain): Regel für Zielgewichte je Planposition`.

---

### Task 2: Startwert, Übertragung, Wiedereinstieg (rein)

**Files:** Create `packages/domain/src/plangewicht-start.ts`, `plangewicht-start.test.ts`.

**Interfaces:**
- Consumes: `PlanGewichtGrund` (Task 1), Erfahrungs- und Ziel-Typen aus `trainingsplan-typen.ts`.
- Produces:
  ```ts
  export function startgewichtAusHistorie(block: WorkoutSetInput[], geraet: Geraetegrenzen): number | null; // G12
  export function schaetzeStartgewicht(e: { loadStart: number | null; erfahrung: Erfahrung; geschlecht: string | null; altersgruppe: string | null; koerpergewichtKg: number | null; geraet: Geraetegrenzen }): number;
  export function uebertragungsFaktor(e: { gemacht: number; reserve: number; wdhMitte: number; zielreserve: number }): number; // 3 %/Wdh., ±20 %
  export function wiedereinstieg(abstandTage: number, ziel: number, geraet: Geraetegrenzen): { load: number | null; saetzeMinus: 0 | 1; grund: PlanGewichtGrund | null }; // F18-Tabelle
  ```
- [ ] **Step 1: Tests** mit den Spec-Werten: Block 3×10 bei 40 kg → 40; Block mit gemischten Lasten → Last des letzten Arbeitssatzes; Faktor bei 12 gemacht + Reserve 3 gegen Mitte 10 + Zielreserve 2 → +3 % (Abweichung 3 → 9 %: Test gegen die Formel „3 % Last je Wiederholung“ und Deckel ±20 %); Wiedereinstieg: 7 Tage → Ziel unverändert, 10 Tage → Ziel gehalten (keine Steigerung, `grund: null`), 20 Tage → −7,5 % abgerundet auf Stufe und `saetzeMinus: 1`, 35 Tage → −12,5 %, 50 Tage → `load: null` (Startschätzung gilt); Startschätzung ≥ `loadMin`, ≤ `loadMax`, auf Stufe gerastet, ohne Profilangaben = `loadStart` oder `loadMin`.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren; Faktortabelle der Startschätzung als versionierte Konstante (`STARTSCHAETZUNG_VERSION = "1.0.0"`), konservativ („lieber zu leicht“); Werte begründet im Kommentar. **Step 4:** PASS. **Step 5:** Commit `feat(domain): Startwert, Übertragung und Wiedereinstieg`.

---

### Task 3: Migration `0064_plan_gewichte.sql`

**Files:** Create `supabase/migrations/0064_plan_gewichte.sql`, `tests/integration/rls-plan-gewichte.test.ts`.

**Interfaces:**
- Produces: Tabelle `plan_gewichte (plan_id, position_key, user_id, load numeric, secondary_load numeric null, grund text, algo_version text, stand_session_id uuid, stand_completed_at timestamptz, primary key (plan_id, position_key))`; Spalte `workout_sessions.gewichte_berechnet_at timestamptz null`; RPC `set_plan_gewichte(p_session_id uuid, p_plan_id uuid, p_zeilen jsonb) returns void`; RPC `init_plan_gewichte(p_plan_id uuid, p_zeilen jsonb) returns void`.
- Regeln (Spec G10/G14): Select nur eigene Zeilen (`force row level security`, keine Insert/Update/Delete-Policy). `set_plan_gewichte` prüft Aufrufer = Besitzer von Session und Plan, Session abgeschlossen (oder 4 h idle, wie der Server sie zählt), Plan im Studio der Session in `aktiv`/`ersetzt`; jede `position_key` gehört zum Plan; ändert eine Zeile nur, wenn `stand_completed_at` der Session **neuer** ist als der gespeicherte (ältere Abschlüsse ändern nichts, gleiche Session ist idempotent); setzt `gewichte_berechnet_at`. `init_plan_gewichte` schreibt nur Positionen ohne Zeile. Fremd und unbekannt antworten gleich (`plan_ungueltig`). Ein Trigger wie in 0063 schützt `gewichte_berechnet_at` vor direktem Schreiben.
- [ ] **Step 1: Tests** (Muster `session-plan.test.ts`): Fremder sieht und schreibt nichts; direkter Insert/Update scheitert; ältere Session überschreibt neuere nicht; dieselbe Session zweimal → eine Zeile, gleiche Werte; Position eines anderen Plans → `plan_ungueltig`; Session nicht abgeschlossen → `plan_ungueltig`; direktes Setzen von `gewichte_berechnet_at` scheitert.
- [ ] **Step 2:** `pnpm test:integration -- rls-plan-gewichte` → FAIL. **Step 3:** Migration schreiben. **Step 4:** lokal anwenden (`supabase db reset` oder das Projektmuster, `pnpm smoke:migrations`), Tests PASS. **Step 5:** Commit `feat(db): Zielgewichte je Planposition (0064)`.

---

### Task 4: Laden, Rechnen, Schreiben (`plangewichte.ts`)

**Files:** Create `packages/domain/src/plangewichte.ts`, `tests/integration/domain-plangewichte.test.ts`.

**Interfaces:**
- Consumes: Tasks 1–3; `ladeKandidaten`, `naechsteEinheitKey`, `aktivePlaeneDerMitgliedschaften`.
- Produces:
  ```ts
  export async function aktualisierePlanGewichte(client: SupabaseClient, userId: string, sessionId: string): Promise<void>;
  export async function initialisierePlanGewichte(client: SupabaseClient, userId: string, plan: TrainingPlan): Promise<void>; // G13
  export type PositionsZiel = { load: number; secondaryLoad: number | null; aenderung: number | null; grund: PlanGewichtGrund };
  export async function ladeZielgewichte(client: SupabaseClient, userId: string, plan: TrainingPlan): Promise<Record<string, PositionsZiel>>; // key = Positionsschlüssel
  ```
- Verhalten von `aktualisierePlanGewichte` (G2–G4, G9, G14–G16, G21): Session lesen (Plan, Einheit, Abschlusszeit), Arbeitssätze je (Übung, Gerät) lesen, Planpositionen der **aktiven Version** des Paars (Nutzer, Studio) nehmen, die Positionen mit gleicher Übung und gleichem Gerät wie ein erledigter Block in den **nächsten drei noch nicht begonnenen Einheiten** (Planreihenfolge nach der abgeschlossenen, Einheiten mit offener Session ausgenommen, weniger vorhandene = alle) mit `berechnePlanGewicht` neu rechnen; Positionen ohne eigene Historie, die einen Hauptmuskel mit einer abgeschlossenen Übung teilen, per `uebertragungsFaktor` (Task 2); getauschte Positionen (`getauscht`) ausnehmen; das Ergebnis über `set_plan_gewichte` schreiben. `aenderung` in `ladeZielgewichte` = Ziel minus letztes tatsächlich benutztes Gewicht am Gerät (`null` ohne Vorgänger oder bei Gleichheit). `initialisierePlanGewichte`: pro Position ohne Zeile `startgewichtAusHistorie`, sonst `schaetzeStartgewicht`, dann `wiedereinstieg` nach Abstand zum letzten Block.
- [ ] **Step 1: Tests** (Integration, Muster `domain-record-set.test.ts`): Einheit A mit oben erreichter Bankdrückenposition → Position in Einheit C (Wiederholung) steigt, Position in dazwischenliegender Einheit B mit anderer Übung bleibt; offene Session auf Einheit C → C unverändert; Aufwärmsatz-only → nichts; Ist-Satz 45 statt Ziel 40 → Rechnung von 45; zweimal aufrufen → gleiche Zeilen; Abschluss der älteren Session nach der neueren → keine Änderung; `getauscht` → Ersatzübung ohne Ziel der alten; Plan ohne Zeilen → `initialisierePlanGewichte` füllt (Historie / Schätzung); weniger als drei Folgeeinheiten → alle.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren (Abfragen bündeln, Muster `vorschlaegeFuerAbschluss`: ein Satz-Select über alle betroffenen Geräte, error immer prüfen und werfen). **Step 4:** PASS. **Step 5:** Commit `feat(domain): Zielgewichte nach Einheit neu rechnen`.

---

### Task 5: Auslöser und Bootstrap

**Files:** Modify `packages/domain/src/workout.ts` (`completeSession`), `trainingsplan-bootstrap.ts` (`PlanFuerApp`, `ladePlaeneFuerApp`), `trainingsplan.ts` (`acceptPlan`, `tauschePlanPosition`); Test: `domain-plangewichte.test.ts`, `domain-bootstrap.test.ts`, `api-plans.test.ts`.

**Interfaces:**
- Consumes: Task 4.
- Produces: `PlanFuerApp.zielgewichte: Record<string, PositionsZiel>` (Positionsschlüssel → Ziel), additiv; fehlt der Planteil, bleibt `plans: []` wie bisher.
- [ ] **Step 1: Tests:** (a) `completeSession` schreibt Ziele; schlägt die Rechnung fehl, bleibt die Session trotzdem beendet und der Aufruf antwortet 200. (b) Bootstrap rechnet **lazy** nach: eine nach 4 h Stillstand automatisch abgeschlossene Session mit `gewichte_berechnet_at is null` wird beim nächsten Bootstrap verarbeitet (der Auto-Abschluss ist laut `complete/route.ts` eine Leseregel, kein Aufruf), in Reihenfolge `stand_completed_at` aufsteigend, höchstens die letzten fünf. (c) `acceptPlan` und `tauschePlanPosition` rufen `initialisierePlanGewichte`; ein dauerhafter Tausch behält die Ziele von Positionen mit gleicher Übung und gleichem Gerät (G9). (d) Bootstrap enthält `zielgewichte` mit `aenderung` und `grund`; ein Bestandsplan ohne Zeilen bekommt sie beim ersten Bootstrap (G13).
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren; Auslöserfehler werden geloggt (bestehendes Logging-Muster), nie geworfen. **Step 4:** PASS. **Step 5:** Commit `feat(api): Zielgewichte im Bootstrap und nach Abschluss`.

---

### Task 6: Vorschläge am Gerät und im Abschluss

**Files:** Modify `packages/domain/src/machine-context.ts` (Aufrufe `suggestNextLoad` ab Zeile ~368/443), `abschluss.ts` (`vorschlaegeFuerAbschluss`), `plangewichte.ts` (Funktion unten); Test: `domain-machine-context.test.ts`, `abschluss.test.ts`, `domain-typ-kontext.test.ts`.

**Interfaces:**
- Produces: `export function vorschlagAusZiel(ziel: PositionsZiel | null, letzte: { load: number; secondaryLoad: number | null } | null, geraet: Geraetegrenzen): ProgressionSuggestion` — gleiche Form wie bisher (`resultLoad`, `reasonCode`, `inputs.currentLoad`), damit iOS und `zuVorschlag`/`deltaLoad` unverändert greifen (Spec G17, G19). Ohne Ziel: `resultLoad = letzte.load`, `reasonCode = "letztes_gewicht"`; ohne beides `kein_verlauf`. `algoVersion = PLANGEWICHT_ALGO_VERSION`.
- Position suchen: Position mit gleicher Übung im Plan des Studios, zuerst in der nächsten Einheit (`naechsteEinheitKey`), sonst die früheste spätere; nur bei aktivem Plan. Cardio bleibt unverändert (keine Progression).
- [ ] **Step 1: Tests:** Gerät mit Planposition → `suggestion.resultLoad` = Ziel, `reasonCode` aus dem Ziel; Gerät ohne Plan → letztes Gewicht, `letztes_gewicht`; Abschluss: `deltaLoad` = Ziel − bisher, Zeile in `progression_suggestions` mit neuer `algo_version` (wiederholter Abschluss liest sie unverändert zurück); Cardio unverändert.
- [ ] **Step 2:** FAIL. **Step 3:** Implementieren; `suggestNextLoad` bleibt nur noch in `progression.ts` für Altdaten-Tests, wird von keinem Laufweg mehr aufgerufen. **Step 4:** PASS, `pnpm test`. **Step 5:** Commit `feat(domain): Vorschläge aus Zielgewicht oder letztem Gewicht`.

---

### Task 7: Tausch über die Typgrenze (Übergabe Punkt 2) und Planversion der Session (Punkt 5)

**Files:** Create `supabase/migrations/0065_plan_tausch_typ.sql`; Modify `packages/domain/src/plangewichte.ts`; Test: `tests/integration/plan-schreibwege.test.ts`, `domain-plangewichte.test.ts`.

- [ ] **Step 1: Tests:** (a) Tausch Mehrgelenk → Isolation: die neue Position trägt `typ`, `wdhVon/Bis` und `pauseSek` der **neuen** Übung nach dem Zielprofil des Plans (nicht die der alten). (b) Hat eine Session die Planversion N, der Bootstrap ist bei N+1 (dauerhafter Tausch in der Einheit), rechnet `aktualisierePlanGewichte` gegen die aktive Version N+1 und findet die Positionen über Übung und Gerät, nicht über die Versions-ID.
- [ ] **Step 2:** FAIL. **Step 3:** `swap_training_plan_position` (0062) liest bisher Bereich/Pause der alten Position; neue Migration ersetzt die Funktion so, dass der Server (TS) typ-passende Werte mitgibt oder die Funktion sie aus `eingabe` des Plans (Ziel, Erfahrung) ableitet — Umsetzer wählt, solange `zielprofil(...)` die einzige Quelle bleibt. Gewichtsübernahme (G9) bleibt in Task 5. **Step 4:** PASS. **Step 5:** Commit `fix(plan): Tausch über die Typgrenze übernimmt Bereich der neuen Übung (0065)`.

---

### Task 8: iOS: Hinweis am Gerät, Abschluss-Screen, DTOs

**Files:** Modify `Networking/DTOs/Trainingsplan.swift` (`zielgewichte`), `Screens/Geraet/GeraetModel.swift` (Zeilen ~715 und ~837: Vorbelegung und Delta-Hinweis), `Screens/Training/TrainingAbschlussView.swift` (Textbausteine ~500), `FitnessMemberTests/{DTOTests,GeraetModelTests}.swift`.

- [ ] **Step 1: Tests (Swift):** DTO dekodiert `zielgewichte` (fehlt → leer, alte Server-Antwort bleibt lesbar); Hinweistext aus (`grund`, `aenderung`): `korridor_oben_erreicht` mit +2,5 → „+2,5 kg“ (Einheit aus `LoadUnit`, deutsche Dezimalschreibweise), `korridor_unten_verfehlt` mit −2,5 → „−2,5 kg“, `im_korridor`/`letztes_gewicht` oder `aenderung == 0` → kein Hinweis; `wiedereinstieg` → „−7,5 kg“-Form mit kurzem Grund; Text je Fall ein Halbsatz.
- [ ] **Step 2:** Xcode-Test FAIL. **Step 3:** Implementieren; Textbausteine zentral neben den bestehenden (`TrainingAbschlussView` ~500); die App rechnet nur Anzeige, nie Gewicht. **Step 4:** Tests PASS; manuell im Simulator mit Testkonto (Debug-Build zeigt auf Prod, Übergabe Punkt 8). **Step 5:** Commit `feat(ios): Hinweis zur Gewichtsänderung am Gerät`.

---

### Task 9: Abschluss der Etappe

- [ ] **Step 1:** `pnpm typecheck && pnpm test && pnpm test:integration` einzeln auf Flackern achten (`api-workout-sets` „beendet die eigene Session“ ist vorbestehend).
- [ ] **Step 2:** Haupt-Spec Abschnitt 6 „Fortlaufende Anpassung“ durch Verweis auf das Etappe-4-Design ersetzen; Übergabe `2026-10-25-trainingsplan-etappe5-uebergabe.md` schreiben (offene Punkte aus Etappe 3 Nr. 3, 4, 6 bis 10 fortschreiben; Textbausteine „Warum so?“ als Etappe 5).
- [ ] **Step 3:** Memory `project_trainingsplan-stand.md` aktualisieren; Commit `docs: Übergabe Trainingsplan Etappe 5`. Push, PR und jede Prod-Aktion erst nach Tims Freigabe.
