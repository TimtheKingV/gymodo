# P4 Einheit ansehen und bearbeiten – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eine Planeinheit als Ganzes bearbeiten – ordnen, entfernen, beliebige Übung hinzufügen oder tauschen, Sätze/Wdh/Pause (Cardio: Dauer) ändern – und mit „Fertig“ als eine neue Planversion speichern; Ansehen und Bearbeiten zeigen dieselbe Übungskarte.

**Architecture:** Neue Reinfunktion `baueEinheit` in der Domain rechnet aus alter Einheit + Client-Eingabe + Übungsmerkmalen die neue Einheit (Werte, Rollen, Schlüssel, Minuten). `ersetzePlanEinheit` ruft damit die neue RPC `replace_training_plan_einheit` (Migration 0074), die prüft und eine Version schreibt; Route `PUT /api/v1/me/plans/{id}/einheiten/{einheitKey}`. Der Plan-Bootstrap liefert zusätzlich Vorgaben und Übungsmerkmale, damit die App Werte vorab zeigt und Unmarkiertes ausgraut. iOS: Entwurfsmodell `PlanEinheitEntwurf` statt `PlanEinheitBearbeitung`, Komponente `Uebungskarte`, Anpassen-Blatt, Plan-Übungsauswahl, umgebaute Bearbeiten- und Ansehen-Seite.

**Tech Stack:** TypeScript (packages/domain, vitest), Next.js Route Handler (apps/web), Supabase Postgres (plpgsql, tests/integration mit lokalem Supabase), SwiftUI iOS 17+ (Swift Testing, `xcodebuild test`).

**Spec:** `docs/superpowers/specs/2026-11-16-p4-einheit-bearbeiten-design.md`. Entwürfe: https://claude.ai/artifact/WjzFjBaepfAUupoBSD9tN4

## Global Constraints

- Branch `claude/p4-einheit-bearbeiten`, Basis `claude/training-flows` (PR #102). Merge erst nach #102.
- Neue Migration heißt `0074_plan_einheit_ersetzen.sql`; 0073 (`order_training_plan_einheit`) und `swap_training_plan_position` bleiben unverändert.
- Grenzen: saetze 1–10 (ganz), wdhVon 1–50, wdhBis wdhVon–50, pauseSek 0–600 (ganz), dauerMin 5–120; Cardio: saetze 1, wdhVon/wdhBis null, pauseSek 0. 1–20 Positionen je Einheit.
- Reserve, Aufwärmsatz, baustein, typ, rolle, hauptmuskeln kommen nie vom Client.
- Übungen ohne `plan_baustein`/`plan_typ` → 422 Code `uebung_ohne_planmerkmale`, Text „Diese Übung ist noch nicht für Trainingspläne freigegeben.“
- Übung in gemiedenem Bereich → 422 Code `uebung_gemieden`, Text „Diese Übung belastet einen Bereich, den du schonen willst.“
- Modell nicht im Katalog-Studio → 422 `validation_failed`, Text „Diese Übung gibt es an diesem Gerät nicht.“
- Deutsche Bezeichner; Kommentare im Code ohne Umlaute (ae/oe/ue/ss) mit Verweis `(P4, Testnotiz 10.11. #n)`; sichtbare Texte mit Umlauten.
- iOS-Farben nur über `DesignSystem.Color`; eine Hauptaktion (Akzent) je Bildschirm; Trefferflächen ≥ 44 pt.
- Übungskarte Variante A: Thumbnail 56 pt links, Titel `DesignSystem.Typography.uebungsname`, Chips „N Sätze“ / „von–bis Wdh“ / „N s“, Cardio nur „N min“; Karte `surface`, Rand `line` 1 pt, Radius 14.

## Review Focus

1. **Blatt nur öffnen und schließen ändert nichts** – auch bei Pause 150 s oder 75 s (nicht in den Stufen). Test in Task 7.
2. **Alle Positionen entfernen** geht nicht, auch nicht per Wischen auf die letzte. Test in Task 5.
3. **Dieselbe Übung zweimal** in einer Einheit (hinzufügen, was schon drin ist): App verhindert es (ausgegraut „Schon in der Einheit“), Server lehnt mit 422 `validation_failed` ab. Tests in Task 1 und Task 8.
4. **Plan wurde zwischendurch woanders geändert** (409): Entwurf bleibt erhalten, Banner „Dein Plan hat sich inzwischen geändert …“, nach Neuladen kann man erneut speichern; Schlüssel, die es nicht mehr gibt, werden zu neuen Positionen. Test in Task 5.
5. **Tausch Kraft → Cardio und zurück** setzt Werte der neuen Art, keine wdh bei Cardio, keine Dauer bei Kraft. Tests in Task 1 und Task 5.

---

### Task 1: Domain – `baueEinheit` (rein)

**Files:**
- Create: `packages/domain/src/plan-einheit-ersetzen.ts`
- Test: `packages/domain/src/plan-einheit-ersetzen.test.ts`
- Modify: `packages/domain/src/index.ts` (Exporte)

**Interfaces:**
- Consumes: `PlanEinheit`, `PlanPosition` (`trainingsplan-generator.ts:37-55`), `tauschVorgaben`, `zielprofil`, `uebungMinuten`-Konstanten `ZEIT`, `aufwaermenMinuten`, `cardioMinuten` (`trainingsplan-zeit.ts`).
- Produces:
  ```ts
  export type EinheitEingabePosition = {
    key: string | null; exerciseId: string; modelId: string;
    saetze?: number; wdhVon?: number; wdhBis?: number; pauseSek?: number; dauerMin?: number;
  };
  export type UebungsMerkmale = { baustein: Baustein | null; typ: PlanTyp | null; hauptmuskeln: string[] };
  export type EinheitVorgaben = { typ: Record<PlanTyp, TypVorgaben>; saetze: number; cardioMin: number; aufwaermenMin: number };
  export function vorgabenAusEingabe(eingabe: Pick<GeneratorEingabe, "ziel"|"erfahrung"|"anfaengerBeendet"|"minuten">): EinheitVorgaben;
  export function positionMinuten(p: Pick<PlanPosition,"baustein"|"saetze"|"pauseSek"|"aufwaermsatz"|"dauerMin">): number;
  export function baueEinheit(alt: PlanEinheit, eingabe: EinheitEingabePosition[], merkmale: Record<string, UebungsMerkmale>, vorgaben: EinheitVorgaben): PlanEinheit; // wirft DomainError
  ```

Regeln (aus der Spec, hier verbindlich):
- Leere Liste, > 20, doppelter nicht-null Schlüssel, Schlüssel nicht in `alt`, doppelte `exerciseId` → `DomainError("validation_failed", "Diese Einheit kann so nicht gespeichert werden.")`.
- Merkmal fehlt oder `baustein`/`typ` null → `DomainError("uebung_ohne_planmerkmale", …)` (neuer Code in `errors.ts`, HTTP 422 in `fromDomainError`).
- Cardio = `merkmale.baustein === "cardio"`.
- Bestehende Position, gleiche Übung: alle Werte aus `alt`, überschrieben durch gelieferte Werte.
- Bestehende Position, andere Übung, gleiche Art (Kraft↔Kraft): saetze/wdh/pause/reserve von der Stelle (überschreibbar), `aufwaermsatz = typ === "mehrgelenk"` der neuen Übung, rolle bleibt.
- Art wechselt (Kraft↔Cardio) oder `key === null`: alles aus `vorgaben` (Kraft: `vorgaben.typ[typ]` + `saetze: vorgaben.saetze`; Cardio: saetze 1, wdh null, pause 0, aufwaermsatz false, `dauerMin: vorgaben.cardioMin`, reserve wie `vorgaben.typ.isolation`), überschreibbar; rolle neu: `ergaenzung` bzw. `cardio`.
- Grenzen aus Global Constraints nach dem Überschreiben prüfen → `validation_failed`.
- Neue Schlüssel: `String(max(numerische Schlüssel in alt) + 1)`, fortlaufend in Listenreihenfolge.
- `hauptmuskeln` aus `merkmale`, `baustein`/`typ` aus `merkmale`.
- `positionMinuten`: Cardio `dauerMin`; sonst `ZEIT.einstellenMin + saetze*ZEIT.satzMin + (saetze-1)*pauseSek/60 + (aufwaermsatz ? ZEIT.aufwaermsatzMin : 0)`. `geschaetzteMinuten = vorgaben.aufwaermenMin + Σ positionMinuten`, auf 0,5 gerundet wie der Generator (prüfen, wie `generator.ts:305` rundet, und gleich runden).

- [ ] **Step 1: Failing tests** in `plan-einheit-ersetzen.test.ts` (Fixtures: alte Einheit mit Keys "0" Beinpresse mehrgelenk 3×8–12 Pause 150, "1" Curl isolation 3×10–15 Pause 90, "2" Laufband cardio 20 min):
  - `ordnet und entfernt` – Eingabe `[{key:"1"},{key:"0"}]` → Keys `["1","0"]`.
  - `neue Position bekommt Schluessel 3 und Vorgaben` – `key:null`, isolation → `{key:"3", saetze: vorgaben.saetze, wdhVon:10, wdhBis:15, pauseSek:90, rolle:"ergaenzung", aufwaermsatz:false}`.
  - `Tausch Kraft->Kraft behaelt Saetze Wdh Pause Reserve, Aufwaermsatz nach neuer Uebung` – Key "1" mit mehrgelenk-Übung → saetze 3, wdh 10–15, pause 90, `aufwaermsatz: true`, rolle alt.
  - `Tausch Kraft->Cardio setzt Cardio-Werte` – Key "1" → cardio: `saetze 1, wdhVon null, pauseSek 0, dauerMin 20, rolle "cardio"`.
  - `Tausch Cardio->Kraft setzt Kraft-Vorgaben` – Key "2" mit isolation-Übung → wdh 10–15, `dauerMin null`, rolle `ergaenzung`.
  - `gelieferte Werte ueberschreiben` – Key "0" `saetze:4,wdhVon:6,wdhBis:8,pauseSek:120` → genau diese.
  - `Grenzen` – je ein Fall: saetze 0, saetze 11, wdhVon 0, wdhBis < wdhVon, wdhBis 51, pauseSek 601, dauerMin 4, dauerMin 121 → `validation_failed`.
  - `leer, doppelter Key, fremder Key, doppelte Uebung, 21 Positionen` → `validation_failed`.
  - `Uebung ohne Planmerkmale` → Code `uebung_ohne_planmerkmale`.
  - `Minuten neu gerechnet` – unveränderte Eingabe ergibt dieselben `geschaetzteMinuten` wie eine vom Generator erzeugte Einheit mit denselben Positionen (Fixture aus `generierePlan` ziehen); Sätze 3→4 erhöht um `ZEIT.satzMin + pauseSek/60`.
- [ ] **Step 2:** `cd packages/domain && npx vitest run plan-einheit-ersetzen` → FAIL (Modul fehlt).
- [ ] **Step 3:** Implementieren wie oben; `uebung_ohne_planmerkmale` und `uebung_gemieden` in `errors.ts` als Codes mit Status 422 ergänzen (Muster der vorhandenen Codes).
- [ ] **Step 4:** Test → PASS; `npx vitest run` im Paket ganz grün.
- [ ] **Step 5:** Commit `feat(domain): Einheit als Ganzes neu bauen (P4)`.

### Task 2: Migration 0074 – `replace_training_plan_einheit`

**Files:**
- Create: `supabase/migrations/0074_plan_einheit_ersetzen.sql`
- Test: `tests/integration/plan-einheit-ersetzen.test.ts`

**Interfaces:**
- Produces: `public.replace_training_plan_einheit(p_plan_id uuid, p_einheit_key text, p_positionen jsonb, p_minuten numeric) returns public.training_plans`, `security definer`, `grant execute … to authenticated`.

SQL-Ablauf (Muster 0073 Zeilen 8–110 und 0070 Zeilen 67–222):
1. auth.uid, Besitz, Advisory-Lock `'training_plans:'||user||':'||studio`, `FOR UPDATE`, Status `aktiv` + Katalog-Studio → sonst `raise 'plan_nicht_annehmbar'`.
2. `p_positionen` ist ein Array mit 1–20 Objekten, Einheit existiert, `p_minuten` 0–600 → sonst `plan_ungueltig`.
3. Je Position: Pflichtfelder `key, baustein, rolle, exerciseId, modelId, typ, saetze, reserveVon, reserveBis, pauseSek, aufwaermsatz`; Grenzen wie Global Constraints; Keys eindeutig; exerciseId eindeutig → sonst `plan_ungueltig`.
4. Je Position `exercises.plan_baustein/plan_typ` nicht null und gleich der gelieferten → sonst `uebung_ohne_planmerkmale`.
5. `training_plan_pruefen` je Modell/Übung → sonst `plan_ungueltig`.
6. „meiden“ wie 0070:163-168 mit `plan_bereiche` → `uebung_gemieden`.
7. `hauptmuskeln` aus `exercises.muscles` (primär) setzen wie in 0070, geliefertes überschreiben.
8. Neue Version max+1, alte → `ersetzt`, kopiert `regel_version, eingabe, struktur, gruende, wochenraster`, ersetzt nur diese Einheit, `geschaetzteMinuten = p_minuten`.

- [ ] **Step 1: Failing tests** (Fixtures wie `plan-schreibwege.test.ts`): `schreibt eine neue aktive Version und setzt die alte auf ersetzt`; `fremder Plan → plan_nicht_annehmbar`; `ersetzter Plan → plan_nicht_annehmbar`; `Uebung ohne plan_baustein → uebung_ohne_planmerkmale`; `gemiedener Bereich → uebung_gemieden`; `Modell eines normalen Studios → plan_ungueltig`; `doppelte exerciseId → plan_ungueltig`; `saetze 11 → plan_ungueltig`; `hauptmuskeln kommen aus exercises, nicht aus dem Rumpf`.
- [ ] **Step 2:** `supabase db reset && pnpm vitest run tests/integration/plan-einheit-ersetzen.test.ts` → FAIL (Funktion fehlt).
- [ ] **Step 3:** Migration schreiben.
- [ ] **Step 4:** Tests → PASS; `pnpm vitest run tests/integration/plan-schreibwege.test.ts tests/integration/api-plans.test.ts` weiter grün. Läuft lokales Supabase nicht: Migration mit `node scripts/smoke-migrations.mjs` prüfen und im Plan unter „Geprüft“ als nicht gesehen vermerken.
- [ ] **Step 5:** Commit `feat(db): replace_training_plan_einheit (0074, P4)`.

### Task 3: Domain `ersetzePlanEinheit` + API-Route

**Files:**
- Modify: `packages/domain/src/trainingsplan.ts` (neben `ordnePlanEinheit`)
- Create: `apps/web/app/api/v1/me/plans/[id]/einheiten/[einheitKey]/route.ts`
- Modify: `apps/web/lib/api/respond.ts` (falls `fromDomainError` die neuen Codes nicht generisch auf 422 abbildet)
- Test: `tests/integration/api-plans.test.ts` (neuer `describe("PUT einheiten")`)

**Interfaces:**
- Consumes: `baueEinheit`, `vorgabenAusEingabe` (Task 1), RPC (Task 2).
- Produces: `export async function ersetzePlanEinheit(client, userId, planId, input: { einheitKey: string; positionen: EinheitEingabePosition[] }): Promise<TrainingPlan>`; Route `PUT` mit Zod: `positionen` 1–20, je `key: string|null`, `exerciseId`/`modelId` uuid, optionale Ganzzahlen.

Ablauf: Plan (`einheiten, eingabe`) lesen wie `ordnePlanEinheit`; Merkmale aller `exerciseId` aus `exercises` (`plan_baustein, plan_typ, muscles`) lesen; `baueEinheit`; RPC mit `p_positionen = einheit.positionen`, `p_minuten = einheit.geschaetzteMinuten`; Fehler: `plan_nicht_annehmbar`→conflict, `plan_ungueltig`→validation_failed, `uebung_ohne_planmerkmale`/`uebung_gemieden`→eigene Codes, 23505→conflict; danach `uebernehmePlanGewichte` + `initialisierePlanGewichte` wie `ordnePlanEinheit`.

- [ ] **Step 1: Failing tests:** `PUT ordnet, tauscht, fuegt hinzu in einem Aufruf (200, eine neue Version)`; `ohne Token 401`; `fremde Plan-ID 409`; `ungueltiger Rumpf 422`; `Uebung ohne Planmerkmale 422 code uebung_ohne_planmerkmale`; `Zielgewicht einer unveraenderten Position bleibt erhalten`.
- [ ] **Step 2:** laufen lassen → FAIL (404).
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** PASS; `cd apps/web && npx vitest run` grün; `pnpm -w typecheck` (bzw. `turbo run typecheck`) grün.
- [ ] **Step 5:** Commit `feat(api): Einheit als Ganzes speichern (P4)`.

### Task 4: Bootstrap liefert Vorgaben und Plan-Übungsmerkmale

**Files:**
- Modify: `packages/domain/src/trainingsplan-bootstrap.ts` (Plan-Teil des Bootstraps, neben `alternativen`)
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift`
- Test: `packages/domain/src/trainingsplan-bootstrap.test.ts`, `apps/ios-member/FitnessMemberTests/` (Decoding-Test zum Plan, vorhandene Datei für Trainingsplan-DTO nutzen)

**Interfaces:**
- Produces (JSON am Plan): `vorgaben: EinheitVorgaben` (aus Task 1, Felder `typ.mehrgelenk|isolation {wdhVon,wdhBis,reserveVon,reserveBis,pauseSek,aufwaermsatz}`, `saetze`, `cardioMin`, `aufwaermenMin`) und `planUebungen: Record<exerciseId, { baustein: string; typ: string }>` (nur Übungen mit beiden Merkmalen).
- Swift: `struct PlanVorgaben: Decodable, Equatable, Sendable` und `let planUebungen: [String: PlanUebungsMerkmal]` auf `Trainingsplan`, beide mit `decodeIfPresent` und leerem/`nil`-Fallback.

- [ ] **Step 1: Failing tests:** Domain: `Plan im Bootstrap traegt vorgaben aus der Eingabe` und `planUebungen enthaelt nur verschlagwortete Uebungen`. iOS: `TrainingsplanDecodingTests.vorgabenUndPlanUebungen` und `…fehlenDarfNichtBrechen`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** PASS (`npx vitest run trainingsplan-bootstrap`; `xcodebuild test -only-testing:FitnessMemberTests/TrainingsplanDecodingTests`).
- [ ] **Step 5:** Commit `feat(plan): Vorgaben und Planmerkmale im Bootstrap (P4)`.

### Task 5: iOS – Entwurfsmodell `PlanEinheitEntwurf` + API-Aufruf

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/PlanEinheitEntwurf.swift` (ersetzt `PlanEinheitBearbeitung.swift`; alte Datei und ihre Tests löschen, `darfBearbeiten` mit Test übernehmen)
- Modify: `apps/ios-member/FitnessMember/Networking/APIClient.swift` (`ersetzePlanEinheit`; `ordnePlanEinheit` entfernen, Test dazu anpassen)
- Test: `apps/ios-member/FitnessMemberTests/PlanEinheitEntwurfTests.swift`, `APIClientTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct EntwurfsPosition: Equatable, Identifiable {
      let id: UUID                    // lokal stabil fuers Ziehen
      var key: String?                // nil = neu
      var exerciseId: String; var modelId: String
      var art: Art                    // .kraft(typ) | .cardio
      var saetze: Int; var wdhVon: Int?; var wdhBis: Int?; var pauseSek: Int; var dauerMin: Int?
      var ersetzt: String?            // Name der alten Uebung fuer "statt X"
      var neu: Bool { key == nil }
  }
  struct PlanEinheitEntwurf: Equatable {
      init(einheit: TrainingsplanEinheit, vorgaben: PlanVorgaben?, merkmale: [String: PlanUebungsMerkmal])
      private(set) var positionen: [EntwurfsPosition]
      var geaendert: Bool
      var darfEntfernen: Bool          // positionen.count > 1
      static func darfBearbeiten(einheitKey: String, laufEinheitKey: String?, gebunden: Bool) -> Bool
      mutating func verschieben(von: IndexSet, nach: Int)
      @discardableResult mutating func entfernen(id: UUID) -> Bool
      mutating func hinzufuegen(exerciseId: String, modelId: String)
      mutating func tauschen(id: UUID, exerciseId: String, modelId: String, alterName: String)
      mutating func werteSetzen(id: UUID, saetze: Int, wdhVon: Int?, wdhBis: Int?, pauseSek: Int, dauerMin: Int?)
      func geaenderteWerte(id: UUID) -> Set<WertFeld>   // .saetze/.wdh/.pause/.dauer fuer gruene Chips
      var geschaetzteMinuten: Double   // dieselbe Formel wie positionMinuten (Task 1), mit vorgaben.aufwaermenMin
      var rumpf: [ErsetzenPosition]    // Encodable fuer den PUT
      mutating func nachKonflikt(neueEinheit: TrainingsplanEinheit) // Keys, die fehlen -> nil (neu)
  }
  // APIClient
  func ersetzePlanEinheit(planId: String, einheitKey: String, positionen: [ErsetzenPosition]) async throws(APIError) -> Trainingsplan
  ```
- Werte-Regeln für `hinzufuegen`/`tauschen` = Task 1 (gleiche Art behält, Artwechsel/neu aus `vorgaben`; ohne `vorgaben` nur Übung setzen und Werte weglassen, der Server füllt). `rumpf` sendet Werte nur, wenn sie vom Ausgang abweichen oder die Position neu/getauscht ist.

- [ ] **Step 1: Failing tests** (`PlanEinheitEntwurfTests`): `unveraendertIstNichtGeaendert`; `verschiebenWieArrayMove`; `letztePositionLaesstSichNichtEntfernen`; `hinzufuegenSetztVorgabenUndKeinenKey`; `tauschKraftBehaeltWerteUndMerktAltenNamen`; `tauschKraftZuCardioSetztDauer`; `werteSetzenMarkiertGeaenderteFelder`; `minutenWieDomain` (gleiche Zahlen wie der Domain-Test in Task 1 für dieselbe Fixture); `rumpfSendetNurAbweichungenUndNeues`; `nachKonfliktWerdenFehlendeKeysNeu`; `darfBearbeiten…` (übernommen). `APIClientTests`: `ersetzePlanEinheit sendet PUT me/plans/P1/einheiten/A mit positionen`.
- [ ] **Step 2:** `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:FitnessMemberTests/PlanEinheitEntwurfTests` → FAIL.
- [ ] **Step 3:** Implementieren; Projekt per `project.yml` (xcodegen) bzw. Ordner-Referenz – vorhandenes Vorgehen des Repos prüfen, keine Handarbeit an `project.pbxproj`, wenn xcodegen genutzt wird.
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(ios): Entwurf fuer die ganze Einheit (P4)`.

### Task 6: iOS – `Uebungskarte` und Ansehen-Seite

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/Uebungskarte.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Plan/PlanEinheitView.swift:110-125` (Liste) und Seitenaufbau
- Test: `apps/ios-member/FitnessMemberTests/UebungskarteModellTests.swift`

**Interfaces:**
- Produces:
  ```swift
  struct UebungskarteModell: Equatable {
      let name: String; let exerciseId: String; let vorschaubildModell: String?
      let chips: [Chip]            // Chip(symbol: String, text: String, hervorgehoben: Bool)
      let markierung: String?      // "statt Reverse Butterfly" | "neu" | nil
      static func aus(_ p: EntwurfsPosition, name: String, bild: String?, geaendert: Set<WertFeld>) -> UebungskarteModell
      static func aus(_ p: TrainingsplanPosition, bootstrap: BootstrapResponse?) -> UebungskarteModell
  }
  struct Uebungskarte<Rechts: View>: View { init(modell:, foto: UIImage?, @ViewBuilder rechts: () -> Rechts) }
  ```
- SF Symbols: Sätze `square.stack.3d.up`, Wdh `arrow.triangle.2.circlepath`, Pause/Dauer `timer`. Chip-Hintergrund `surfaceRaised`, hervorgehoben `accentMuted` + Text `accent`.

- [ ] **Step 1: Failing tests:** `chipsKraft` → `["3 Sätze","8–12 Wdh","150 s"]`; `chipsGleicheWdh` (wdhVon==wdhBis) → `"10 Wdh"`; `chipsCardio` → `["20 min"]`; `markierungGetauscht` → `"statt Reverse Butterfly"`; `markierungNeu` → `"neu"`; `geaenderteFelderHervorgehoben`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Komponente bauen (Accessibility: Karte als ein Element „Name, 3 Sätze, 8 bis 12 Wiederholungen, 150 Sekunden Pause“). `PlanEinheitView`: Übungen als `Uebungskarte` in einem `VStack(spacing: 10)`, Überschrift „N ÜBUNGEN · IN DIESER REIHENFOLGE“, Kopf zeigt „N Übungen · ca. M min“; ganze Seite bleibt eine `ScrollView`; Fotos wie `PlanEinheitBearbeitenView.fotoLaden`.
- [ ] **Step 4:** PASS; Build grün.
- [ ] **Step 5:** Commit `feat(ios): Uebungskarte und Einheit ansehen als Karten (P4, Testnotiz 10.11. #7)`.

### Task 7: iOS – Anpassen-Blatt

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Plan/PlanPositionAnpassenSheet.swift`
- Create: `apps/ios-member/FitnessMember/Workout/PlanWerteAuswahl.swift` (Reinfunktionen)
- Test: `apps/ios-member/FitnessMemberTests/PlanWerteAuswahlTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PlanWerteAuswahl {
      static func pausenStufen(aktuell: Int) -> [Int]   // resttimerStufen + 150, plus aktuell, sortiert, ohne Dubletten
      static let saetzeBereich = 1...10
      static func wdhBisBereich(von: Int) -> ClosedRange<Int>   // von...50
      static let dauerStufen: [Int]                     // 5,10,15,20,25,30,40,45,60,75,90,120
      static func dauerStufen(aktuell: Int) -> [Int]
  }
  struct PlanPositionAnpassenSheet: View {
      init(modell: UebungskarteModell, position: EntwurfsPosition, darfEntfernen: Bool,
           beiUebernehmen: (saetze: Int, wdhVon: Int?, wdhBis: Int?, pauseSek: Int, dauerMin: Int?) -> Void,
           beiTauschen: () -> Void, beiEntfernen: () -> Void)
  }
  ```
- Aufbau wie Tafel 4: Kopf mit Thumbnail und Name, Abschnitt „IM PLAN“ (Stepper Sätze, Wdh von/bis als zwei Menü-Picker, Pause-Picker), Hinweis „Reserve und Aufwärmsatz legt der Plan fest.“, „Übung tauschen“ (sekundär), „Aus der Einheit entfernen“ (`.destructive`, nur wenn `darfEntfernen`), Hauptknopf „Übernehmen“. Cardio: nur Dauer-Picker. `presentationDetents([.medium, .large])`.

- [ ] **Step 1: Failing tests:** `pausenStufenEnthalten150`; `pausenStufenNehmenUngewoehnlichenWertAuf` (75 → enthalten, sortiert); `pausenStufenOhneDubletten` (aktuell 90); `wdhBisNieUnterVon`; `dauerStufenNehmenAktuellAuf` (33).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementieren; „Übernehmen“ ohne Änderung ruft `beiUebernehmen` mit den Ausgangswerten, sodass `geaendert` false bleibt (Review Focus 1).
- [ ] **Step 4:** PASS.
- [ ] **Step 5:** Commit `feat(ios): Blatt Uebung anpassen (P4)`.

### Task 8: iOS – Plan-Übungsauswahl (Tauschen und Hinzufügen)

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Plan/PlanUebungAuswahlSheet.swift`
- Create: `apps/ios-member/FitnessMember/Workout/PlanUebungWahl.swift` (Reinfunktionen)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraeteAuswahlView.swift` (optionaler Parameter zum Ausgrauen)
- Modify/Delete: `apps/ios-member/FitnessMember/Screens/Plan/PlanEinheitErsatzSheet.swift` (Vorschläge-Abschnitt wiederverwenden oder darin aufgehen)
- Test: `apps/ios-member/FitnessMemberTests/PlanUebungWahlTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum PlanUebungWahl {
      enum Sperre: Equatable { case keinKatalogmodell, ohnePlanmerkmale, schonInDerEinheit }
      static func sperre(station: Station, uebungId: String, merkmale: [String: PlanUebungsMerkmal], belegt: Set<String>) -> Sperre?
      static func modellId(station: Station) -> String?   // equipmentModel.catalogModelId ?? (Katalog-Studio ? equipmentModel.id : nil), wie PlanTausch.aktivesGeraet
      static func text(_ sperre: Sperre) -> String       // "Nicht im Plan möglich" | "Noch nicht für Pläne freigegeben" | "Schon in der Einheit"
  }
  enum PlanUebungAuswahlZweck: Equatable { case tauschen(alt: UebungskarteModell, kandidaten: [TauschKandidat]); case hinzufuegen }
  struct PlanUebungAuswahlSheet: View {
      init(zweck: PlanUebungAuswahlZweck, merkmale:, belegt:, fotoLader:, vorschauLader:,
           beiWahl: (exerciseId: String, modelId: String, name: String) -> Void, beiAbbrechen: () -> Void)
  }
  // GeraeteAuswahlView: neuer optionaler Parameter
  var gesperrt: ((Station, String) -> String?)? = nil   // Rueckgabe = Grund-Text, Zeile ausgegraut und ohne Tipp
  ```
- Aufbau wie Tafel 5: bei `.tauschen` oben Kasten „DU ERSETZT“ (Hintergrund `accentMuted`, Rand `accentDim`, Thumbnail, Name, „Sätze · Wdh bleiben“), dann „PASST AN DIESE STELLE“ (`kandidaten`), dann „ODER EINE ANDERE ÜBUNG“ mit `GeraeteAuswahlView` (Suche, Bullets, Favoriten) im selben NavigationStack wie `zirkelAuswahl` in `TrainingRootView.swift:1407-1450`; Geräte mit mehreren Übungen über die vorhandene Übungswahl (`ZirkelUebungswahlSheet`-Muster). `.hinzufuegen`: Titel „Übung hinzufügen“, ohne Kasten und Vorschläge.

- [ ] **Step 1: Failing tests:** `ohneKatalogmodellGesperrt`; `ohnePlanmerkmaleGesperrt`; `schonInDerEinheitGesperrt`; `verschlagworteteKatalogUebungFrei`; `modellIdNimmtCatalogModelId`.
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** PASS; Build grün; vorhandene `GeraeteAuswahlView`-Tests weiter grün (Parameter ist optional).
- [ ] **Step 5:** Commit `feat(ios): Uebung fuer den Plan waehlen, frei oder als Vorschlag (P4, Testnotiz 10.11. #5)`.

### Task 9: iOS – Bearbeiten-Seite neu

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Plan/PlanEinheitBearbeitenView.swift` (weitgehend neu)
- Test: Verhalten über `PlanEinheitEntwurfTests` (Task 5); hier nur ein Test für die Fehlertexte, falls neu

**Interfaces:**
- Consumes: `PlanEinheitEntwurf`, `APIClient.ersetzePlanEinheit` (Task 5), `Uebungskarte` (Task 6), `PlanPositionAnpassenSheet` (Task 7), `PlanUebungAuswahlSheet` (Task 8).

Aufbau wie Tafel 3:
- Leiste: „Abbrechen“ (immer so benannt; bei `geaendert` Rückfrage „Änderungen verwerfen?“), Titel „Bearbeiten“, „Fertig“ (Akzent-Text).
- Die ganze Seite scrollt: `List(.plain)` mit Kopf (Name, „Tippe auf eine Übung …“, Minuten, Fehlerbanner) als erste Zeile ohne Hintergrund, dann Karten als Zeilen (`listRowSeparator(.hidden)`, `listRowInsets` 5/20, `listRowBackground(.clear)`), dann die gestrichelte Karte „Übung hinzufügen“ und der Hinweis „Nach links wischen zum Entfernen. Eine Übung bleibt immer.“ Ziehen über `.onMove` (nur Karten-Zeilen), Wischen über `.swipeActions` „Entfernen“ (deaktiviert bei letzter). Kein `editMode`, kein rotes Minus, kein Tausch-Icon. Griff rechts als Symbol `line.3.horizontal` (Zieh-Hinweis; `onMove` braucht ohne editMode langes Drücken – prüfen, ob das auf iOS 17 reicht, sonst `.environment(\.editMode, .constant(.active))` nur mit ausgeblendetem Delete-Knopf via `.deleteDisabled(true)`).
- Tipp auf Karte → Anpassen-Blatt; „Übung tauschen“ dort → Blatt schließt, Auswahl `.tauschen`; „+ Übung hinzufügen“ → Auswahl `.hinzufuegen`.
- „Fertig“: unverändert → schließen; sonst `ersetzePlanEinheit`, bei Erfolg Bootstrap neu laden (`neuLaden()` wie heute) und schließen; bei `.conflict` neu laden, `nachKonflikt`, Banner mit `PlanTausch.fehlerText`; sonst Banner, Entwurf bleibt. Neue Codes `uebung_ohne_planmerkmale`/`uebung_gemieden` in `APIError.map` auf `.validation(message:)` mit Server-Text und in `PlanTausch.fehlerText` den Server-Text zeigen, wenn vorhanden.
- `hatGetauscht`, `schliessenTitel`, `verwerfenHinweis`, Sofort-Tausch und `ordnePlanEinheit`-Aufruf entfallen.

- [ ] **Step 1: Failing test:** `PlanTauschTests.fehlerTextZeigtServerTextBeiValidation` (Text „Diese Übung ist noch nicht für Trainingspläne freigegeben.“ wird angezeigt).
- [ ] **Step 2:** FAIL.
- [ ] **Step 3:** Seite umbauen.
- [ ] **Step 4:** Ganze iOS-Suite: `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 16'` grün.
- [ ] **Step 5:** Commit `feat(ios): Einheit bearbeiten als ganze Seite mit Karten, Blatt und Hinzufuegen (P4, Testnotiz 10.11. #3 #4 #6)`.

### Task 10: Prüfen und abschließen

- [ ] **Step 1:** `pnpm -w turbo run test typecheck lint` (bzw. die Skripte aus `package.json`) grün; Integrationstests mit lokalem Supabase grün oder als nicht gelaufen vermerkt.
- [ ] **Step 2:** Im Simulator (Testkonto aus den Seed-Dateien): Einheit ansehen (Karten, ganze Seite scrollt), Bearbeiten: ziehen, wischen, Werte ändern (Chips grün), tauschen mit Vorschlag und frei, hinzufügen, Fertig → Plan zeigt alles, Abbrechen verwirft alles. Screenshots in den PR.
- [ ] **Step 3:** Abschnitt „Geprüft“ unten ausfüllen; Status-Zeile P4 in `/Users/timbuttner/Documents/gymtavo/fitness-app/docs/superpowers/plans/2026-11-10-testnotizen-pakete.md` aktualisieren.
- [ ] **Step 4:** Commit; PR gegen `claude/training-flows` (bzw. `master`, falls #102 gemergt ist) erst nach Tims Freigabe; Migration 0074 auf Prod nur mit Tims ausdrücklicher Freigabe.

## Geprüft

Stand 17.11.2026, Branch `claude/p4-einheit-bearbeiten`.

**Gelaufen**
- `pnpm turbo run test typecheck`: 5 von 5 Aufgaben grün (Web: 49 Dateien, 311 Tests). Ein `lint`-Skript gibt es im Repo nicht (turbo: „Could not find task `lint`“), daher nicht gelaufen. Root-`tsc --noEmit`: grün.
- Integrationstests gegen den lokalen Supabase-Stack (Projekt `m0-fundament`, ohne `db reset`): `api-plans` 36/36, `plan-schreibwege` 25/25, `domain-trainingsplan` 29/29 grün; `plan-einheit-ersetzen` 10 von 11 grün. Fehlschlag: „Cardio-Position behaelt reserveVon/reserveBis“ (Zeile 241). Ursache im Test: der erste `ersetze`-Aufruf legt eine neue aktive Planversion an und setzt die alte auf `ersetzt`; der zweite Aufruf mit der alten `plan.id` liefert deshalb `plan_nicht_annehmbar` statt `plan_ungueltig`. Der Test muss die `id` des neuen Plans verwenden. Auf diesem Branch verursacht, noch nicht behoben.
- Lokal: 0073 war als Funktion schon vorhanden (Rumpf identisch, vermutlich von Hand eingespielt), aber nicht im Migrationsverlauf; per `migration repair --status applied 0073 --local` nachgetragen. 0074 lief fehlerfrei durch. Der Kong-Container musste neu erzeugt werden (`supabase stop`/`start`, Daten blieben erhalten).
- iOS-Gesamtsuite (`xcodebuild test`, Simulator AE2ECAA2): 2055 Tests in 173 Suites, `TEST SUCCEEDED`.

**Nicht gelaufen**
- Simulator-Durchgang (Task 10 Schritt 2): braucht eine Anmeldung, daher ausgelassen. Keine Screenshots für den PR.
- Prod: nichts angewendet. Status-Zeile P4 in `2026-11-10-testnotizen-pakete.md` noch nicht aktualisiert.

**Tim prüft auf dem Gerät**
- Ziehen zum Umsortieren gegenüber Tippen auf die Karten (Tipp öffnet das Blatt, Ziehen verschiebt nur).
- Nach links wischen zum Entfernen; die letzte Übung bleibt.
- Werte im Anpassen-Blatt (Chips grün bei Änderung, unberührte Werte unverändert).
- Tauschen mit Vorschlag und per freier Suche.
- Übung hinzufügen.
- Fertig (Plan zeigt alles) und Abbrechen (verwirft alles, Rückfrage bei Änderungen).

**Reihenfolge beim Ausrollen**
1. PR #102 und Migration 0073 zuerst, 2. dann 0074 (nur mit Tims ausdrücklicher Freigabe auf Prod), 3. API deployen, 4. erst danach die App.
