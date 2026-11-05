# UX-Vereinheitlichung Paket 1 – Home, Plan, Einheit – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Home wird Kurzansicht, der Plan-Tab der eine Trainingskalender (vor und zurück, Woche/Monat, verpasst/verschoben), und vergangene Trainings und geplante Einheiten sehen überall gleich aus: automatischer Name, Muskelmännchen, gleiche Karte, gleicher Detail-Kopf.

**Architecture:** Der Server liefert zusätzlich, welche Einheit an welchem Tag erledigt wurde, und den Planbeginn. Eine reine Funktion `PlanKalender.termine` legt daraus die Folge auf die Slots des Wochenrasters (vergangen: erledigt/verpasst, künftig: verschoben). Zwei neue Bausteine (`EinheitKarte`, `ProfilKopf`) ersetzen die vier bisherigen Darstellungen, `TrainingsProfil` benennt jetzt auch Planeinheiten.

**Tech Stack:** TypeScript/vitest (`packages/domain`), SwiftUI/Swift Testing (`apps/ios-member`), xcodegen.

**Spec:** `docs/superpowers/specs/2026-11-05-ux-vereinheitlichung-design.md` (Paket 1, Abschnitte 1.1–1.8). Mockups: https://claude.ai/artifact/6wzr9m7KFANPy2Ap5tKBEK (Boards Home, Plan-Tab, Einheiten-Detail).

## Global Constraints

- Kein Redesign: nur vorhandene Tokens aus `DesignSystem` (Farben, `Spacing`, `Radius`, `Typography`), vorhandene `Kalenderzelle`, `MuskelFigur`, `MuskelFarben.farben(profil:)`.
- Ein Thema, ein Baustein: Jede ersetzte View wird gelöscht, nicht daneben stehen gelassen (`HeuteDranZeile`, `HomeWocheKarte`/`HomeNaechsterKarte`, Monatsgitter in `HomeSerieView`, `PlanKuerzelKaestchen` in Karten).
- Die Folge ist kein Kalender (Plan-Spec F5): Reihenfolge der Einheiten bleibt, nur die Zuordnung zu Tagen verschiebt sich; nie zwei Einheiten an einem Tag.
- Kraft wandert nur auf Kraft-Slots, Cardio bleibt auf Cardio-Slots, Kurse verschieben sich nie.
- Namen immer automatisch, kein Umbenennen; Texte ohne „A/B“.
- Swift: nach neuen Dateien `cd apps/ios-member && xcodegen generate`. Tests: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Typname> 2>&1 | tail -20`; immer die Zeile „Test run with N tests“ prüfen (ein falscher Filter meldet trotzdem „TEST SUCCEEDED“).
- Domain: `pnpm --filter @fitretro/domain test -- <datei>`.
- Commit-Nachrichten Deutsch, Präfix wie im Repo (`feat(ios):`, `feat(domain):`), Ende mit `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Keine Prod-Migration, kein Prod-Deploy ohne Tims ausdrückliche Freigabe (Task 1 braucht keine Migration).

## Review Focus

1. **Plan ohne Wochenraster / ohne Kraft-Tage (I3):** Plan-Tab und Home zeigen weiter „Trainingstage festlegen“, `PlanKalender` liefert ohne Kraft-Slots keine Einheiten-Termine und stürzt nicht ab. → Test in Task 4.
2. **Heute ist ein Kraft-Slot, noch nicht trainiert:** heute ist nie „verpasst“, sondern „geplant“; erst ab morgen gilt der Tag als verpasst. → Test in Task 4.
3. **Neue Planversion durch Tausch (0062, neue `planId`):** `erledigt` und `beginn` dürfen nicht auf null zurückspringen; `beginn` ist der frühere von `acceptedAt ?? createdAt` und erstem `erledigt.startedAt`. → Test in Task 1 und Task 4.
4. **Zwei Trainings an einem Slot-Tag / Einheit an einem Nicht-Slot-Tag:** zählt einmal, die Folge rückt genau um die erledigten Einheiten weiter, kein Doppel-Termin. → Test in Task 4.
5. **Katalog noch nicht geladen (`muskeln` leer):** Name fällt auf den bisherigen mechanischen Namen zurück („Einheit A“ / „Oberkörper A“), keine leere Zeile, kein „Training“. → Test in Task 3.

---

### Task 1: Server liefert erledigte Einheiten und Planbeginn

**Files:**
- Modify: `packages/domain/src/trainingsplan-bootstrap.ts` (`PlanFuerApp`, `planFuerApp`)
- Test: `packages/domain/src/trainingsplan-bootstrap.test.ts`
- Modify: `apps/ios-member/FitnessMember/Networking/DTOs/Trainingsplan.swift`
- Test: `apps/ios-member/FitnessMemberTests/DTOTests.swift`

**Interfaces:**
- Produces (TS): `PlanFuerApp.erledigt: { sessionId: string; einheitKey: string; startedAt: string }[]` (= `gezaehlt`, aufsteigend), `PlanFuerApp.beginn: string` (ISO-Zeitpunkt).
- Produces (Swift): `struct ErledigteEinheit: Decodable, Equatable, Sendable { let sessionId: String; let einheitKey: String; let startedAt: String }`; `Trainingsplan.erledigt: [ErledigteEinheit]` (fehlt → `[]`), `Trainingsplan.beginn: String?` (fehlt → nil).

- [ ] **Step 1: Failing tests (TS)** in `trainingsplan-bootstrap.test.ts`, describe `planFuerApp`:
  - `it("liefert die gezaehlten Einheiten als erledigt")`: zwei `GezaehlteEinheit` → `ergebnis.erledigt` gleich der Eingabe in gleicher Reihenfolge.
  - `it("beginn ist acceptedAt, sonst createdAt")`: `acceptedAt: "2026-10-20T08:00:00Z"` → `beginn === "2026-10-20T08:00:00Z"`; `acceptedAt: null, createdAt: "2026-10-19T08:00:00Z"` → `"2026-10-19T08:00:00Z"`.
  - `it("beginn reicht bis zur ersten erledigten Einheit zurueck")` (Review Focus 3): `acceptedAt: "2026-11-01T08:00:00Z"`, erste erledigte `startedAt: "2026-10-22T17:00:00Z"` → `beginn === "2026-10-22T17:00:00Z"`.
- [ ] **Step 2:** `pnpm --filter @fitretro/domain test -- trainingsplan-bootstrap` → FAIL (`erledigt` undefined).
- [ ] **Step 3:** In `planFuerApp` `erledigt: gezaehlt` und `beginn` = früherer Zeitpunkt aus `plan.acceptedAt ?? plan.createdAt` und `gezaehlt[0]?.startedAt` setzen; Typ `PlanFuerApp` ergänzen.
- [ ] **Step 4:** Test → PASS; `pnpm --filter @fitretro/domain test` → PASS; `pnpm -w typecheck` (oder `pnpm turbo typecheck`) → PASS.
- [ ] **Step 5: Failing test (Swift)** in `DTOTests`: `@Test func trainingsplanMitErledigtUndBeginn()` dekodiert ein Bootstrap-Plan-JSON mit `"erledigt":[{"sessionId":"s1","einheitKey":"A","startedAt":"2026-11-02T17:00:00Z"}],"beginn":"2026-10-20T08:00:00Z"` → `#expect(plan.erledigt == [ErledigteEinheit(sessionId: "s1", einheitKey: "A", startedAt: "2026-11-02T17:00:00Z")])`, `#expect(plan.beginn == "2026-10-20T08:00:00Z")`; zweiter Test ohne beide Felder → `erledigt == []`, `beginn == nil`.
- [ ] **Step 6:** Test → FAIL; dann `decodeIfPresent` für beide Felder in `Trainingsplan.init(from:)` (CodingKeys ergänzen) → PASS.
- [ ] **Step 7: Commit** `feat(domain): Plan liefert erledigte Einheiten und Planbeginn`

---

### Task 2: Muskelprofil einer Planeinheit

**Files:**
- Modify: `apps/ios-member/FitnessMember/Verlauf/TrainingsProfil.swift`
- Test: `apps/ios-member/FitnessMemberTests/TrainingsProfilTests.swift`

**Interfaces:**
- Produces: `static func berechne(einheit: TrainingsplanEinheit, muskeln: [String: [GeraetMuskel]]) -> TrainingsProfil`. Kraftsätze je Position = `position.saetze`, wenn `position.typ != "cardio"`; Cardio-Positionen setzen nur `hatCardio`. Muskeln aus `muskeln[position.exerciseId]`.
- Bestehendes `berechne(karte:muskeln:)` bleibt mit unveränderter Ausgabe; beide rufen eine private gemeinsame Funktion `profil(aus saetze: [(exerciseId: String, kraftSaetze: Int)], hatCardio: Bool, muskeln:)` auf (Titel-Logik und Schwellen unverändert).

- [ ] **Step 1: Failing tests:** `einheitBrustTrizeps` (Positionen Brustpresse 3 Sätze primär `chest`, Trizepsdrücken 3 Sätze primär `triceps`) → `titel == "Brust, Trizeps"`; `einheitGanzkoerper` (Beinpresse 3 + Rudern 3 + Brustpresse 3) → `"Ganzkörper"`; `einheitNurCardio` (eine Position `typ: "cardio"`) → `"Cardio"`; `einheitStufen` → `stufen["chest"] == .stark`. Bestehende Tests für `berechne(karte:)` bleiben grün (Regressionsschutz für den Umbau).
- [ ] **Step 2:** `-only-testing:FitnessMemberTests/TrainingsProfilTests` → FAIL.
- [ ] **Step 3:** Gemeinsamen Kern herausziehen, `berechne(einheit:muskeln:)` ergänzen.
- [ ] **Step 4:** Test → PASS (alle Fälle, alte und neue).
- [ ] **Step 5: Commit** `feat(ios): Muskelprofil auch für Planeinheiten`

---

### Task 3: Automatische Einheiten-Namen überall

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/PlanNamen.swift` (`EinheitName` ersetzen, `PlanStrukturText` ohne A/B)
- Modify (Aufrufer, alle über `EinheitNamen`): `Workout/PlanAnzeige.swift:175,283-286`, `Workout/PlanTausch.swift:254,259`, `Screens/Training/PlanKarte.swift:122`, `Screens/Plan/PlanEinheitView.swift:52,114`, `Screens/Plan/PlanTagListe.swift:95,129,242`, `Screens/Plan/PlanRootView.swift:277`, `Screens/Plan/PlanEinplanenSheet.swift:185`, `Onboarding/PlanVorschau.swift:186`, `Onboarding/PlanWochenSchritte.swift:420,424,564,573`
- Test: Create `apps/ios-member/FitnessMemberTests/EinheitNamenTests.swift`; anpassen: `PlanAnzeigeTests.swift`, `PlanTauschTests.swift` (erwartete Texte)

**Interfaces:**
- Consumes: `TrainingsProfil.berechne(einheit:muskeln:)` (Task 2), `BausteinName.text(_:)`.
- Produces:
  ```swift
  struct EinheitNamen: Equatable {
      init(plan: Trainingsplan, muskeln: [String: [GeraetMuskel]])
      func name(_ key: String) -> String
  }
  ```
  - Name = `TrainingsProfil.berechne(einheit:muskeln:).titel`.
  - Fallback, wenn `muskeln` leer ist oder der Titel `"Training"` lautet: der bisherige mechanische Name („Oberkörper A“ für `OK_A`, „Unterkörper A“ für `UK_A`, sonst „Einheit A“), als `private static func mechanisch(_ key:)`.
  - Gleichnamige Einheiten eines Plans: jede bekommt ` · Schwerpunkt <BausteinName>` ihres Bausteins mit den meisten Sätzen (bei Gleichstand der erste in Positionsreihenfolge). Sind auch die Zusätze gleich, bleibt der mechanische Buchstabe als letzter Zusatz: „Ganzkörper · Schwerpunkt Beine, Knie (A)“.
  - Unbekannter Key → mechanischer Name.
- `EinheitKuerzel.text` bleibt nur noch für `PlanWochenSchritte` (Onboarding-Raster, Zelle zu klein für Namen); dort zeigt die Zelle statt des Buchstabens „K“ wie Home (Kraft neutral). `EinheitKuerzel.untertitel` bleibt.
- `PlanStrukturText.text`: `"gk_ab"` → „Ganzkörper, zwei Einheiten im Wechsel. Die nächste folgt der letzten, egal an welchem Tag.“, `"gk_abc"` → „Ganzkörper, drei Einheiten im Wechsel. Die nächste folgt der letzten, egal an welchem Tag.“; übrige Fälle unverändert.

- [ ] **Step 1: Failing tests** in `EinheitNamenTests`:
  - `nameAusMuskeln`: Plan mit Einheit „A“ = Brust/Trizeps → `name("A") == "Brust, Trizeps"`.
  - `gleicheNamenBekommenSchwerpunkt`: Einheiten A (Beinpresse 4, Rudern 2, Brust 2; Baustein `beine_knie` mit den meisten Sätzen) und B (Kreuzheben 4 `beine_huefte`, Rudern 2, Brust 2), beide „Ganzkörper“ → `"Ganzkörper · Schwerpunkt Beine, Knie"` und `"Ganzkörper · Schwerpunkt Beine, Hüfte"`.
  - `ohneKatalogMechanisch` (Review Focus 5): `muskeln: [:]` → `name("A") == "Einheit A"`, `name("OK_A") == "Oberkörper A"`.
  - `unbekannterKey`: `name("Z") == "Einheit Z"`.
  - `strukturTextOhneBuchstaben`: `PlanStrukturText.text("gk_ab")` enthält weder „A und B“ noch „Nach A“.
- [ ] **Step 2:** `xcodegen generate`; `-only-testing:FitnessMemberTests/EinheitNamenTests` → FAIL.
- [ ] **Step 3:** `EinheitNamen` implementieren; `enum EinheitName` löschen; jeden Aufrufer aus der Dateiliste auf `EinheitNamen(plan:muskeln: HomeZeilen.muskelnJeUebung(bootstrap))` umstellen (wo nur ein Key und kein Plan vorliegt, den Plan aus `PlanAnzeige.plan(bootstrap:)` holen). Der Compiler findet jeden übersehenen Aufrufer.
- [ ] **Step 4:** Erwartete Texte in `PlanAnzeigeTests` und `PlanTauschTests` auf die neuen Namen ändern (die Tests reichen dafür einen `muskeln`-Fixture-Katalog oder prüfen den Fallback „Einheit A“ bewusst).
- [ ] **Step 5:** `EinheitNamenTests`, `PlanAnzeigeTests`, `PlanTauschTests`, `PlanWarumTextTests` → PASS; Build ohne Fehler.
- [ ] **Step 6: Commit** `feat(ios): Einheiten heißen nach ihren Muskeln statt A/B`

---

### Task 4: PlanKalender – Folge auf Slots, erledigt, verpasst, verschoben

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/PlanKalender.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/PlanWoche.swift` (`PlanTermin`, `PlanWoche.termine` entfällt zugunsten `PlanKalender.termine`)
- Test: Create `apps/ios-member/FitnessMemberTests/PlanKalenderTests.swift`; `PlanWocheTests.swift` auf `PlanKalender` umziehen (Fälle behalten, Erwartungen an neuen `PlanTermin` anpassen)

**Interfaces:**
- Consumes: `Trainingsplan.erledigt`, `Trainingsplan.beginn` (Task 1), `PlanTabZustand.anzeigeRaster` (vorhanden; nur Tage und Arten werden genutzt, die Keys nicht mehr).
- Produces:
  ```swift
  enum TerminZustand: Equatable {
      case geplant
      case erledigt
      /// `verschobenAuf`: Tag (startOfDay), auf dem die Einheit jetzt liegt; nil bei Cardio/Kurs.
      case verpasst(verschobenAuf: Date?)
  }
  enum PlanTermin: Equatable {
      case einheit(key: String, zustand: TerminZustand)
      case kurs(titel: String, beginn: Date, angemeldet: Bool, zustand: TerminZustand)
      case cardio(arten: [String], zustand: TerminZustand)
  }
  enum PlanKalender {
      static func termine(
          tage: [Date], kalender: Calendar, raster: [Rasterplatz], einheiten: [String],
          naechsteEinheitKey: String?, erledigt: [ErledigteEinheit], trainiertAn: Set<String>,
          beginn: Date?, heute: Date, kurse: [CourseWeekSession], cardioErledigt: Set<String>,
          filter: PlanFilter
      ) -> [Date: [PlanTermin]]
      /// Erster Termin ab heute (heute eingeschlossen) mit Zustand .geplant.
      static func naechster(_ termine: [Date: [PlanTermin]], ab heute: Date, kalender: Calendar) -> (tag: Date, termin: PlanTermin)?
  }
  ```
  `trainiertAn` = Tagesschlüssel „yyyy-MM-dd“ mit mindestens einem Training (aus `HomeSerie.einheitenJeTag`).

**Algorithmus (nicht durch Signatur bestimmt):**
1. Kraft-Slots = alle Tage in `tage` ∪ (beginn…heute), deren ISO-Wochentag im Raster `.kraft` trägt, chronologisch; Tage vor `beginn` (startOfDay) haben keine Slots. Ohne `beginn` (alter Server) gibt es keine vergangenen Slots – lieber keine Vergangenheit als falsche „verpasst“.
2. Vergangenheit (Slot-Tag < heute): Zeiger `p` startet bei Index 0 von `einheiten`. Für jeden Tag ab `beginn` chronologisch: alle `erledigt` an diesem Tag (lokaler Tag von `startedAt` im `kalender`) → je Eintrag `p = index(einheitKey) + 1`; ist der Tag ein Slot und hat ein `erledigt` → `.einheit(key: <erledigter Key>, .erledigt)` (nur einer je Tag, der erste); Slot ohne `erledigt`, aber in `trainiertAn` → kein Einheiten-Termin (freies Training, Tag gilt als trainiert, `p` bleibt); Slot ohne beides → `.einheit(key: einheiten[p % n], .verpasst(verschobenAuf:))`, `p` bleibt.
3. Ab heute: Start-Index = `naechsteEinheitKey` (Server-Wahrheit), sonst `p`. Heute: hat heute ein `erledigt` → `.erledigt` wie oben; sonst Slot heute → `.geplant` mit aktuellem Index. Jeder weitere künftige Slot bekommt den nächsten Index im Kreis, `.geplant`.
4. `verschobenAuf` eines verpassten Slots = erster Tag ≥ heute, an dem derselbe Key `.geplant` liegt; wurde die Einheit inzwischen anderswo erledigt (liegt nicht mehr vorn in der Folge), `nil` → Text nur „verpasst“.
5. Cardio-Slot vergangen: `cardioErledigt` enthält Tag → `.erledigt`, sonst `.verpasst(verschobenAuf: nil)`; heute/künftig `.geplant` (bzw. `.erledigt`, wenn heute abgehakt).
6. Kurse: gebuchte Kurse wie bisher (`ownStatus == "booked"`, nicht `cancelled`); Beginn vorbei → `.erledigt` (Server meldet keine Teilnahme, wie `HomeWoche.erledigteTage`), sonst `.geplant`. Raster-Kurstag in der Vergangenheit ohne gebuchten Kurs in den geladenen Daten → kein Termin (keine falsche „verpasst“-Meldung, weil alte Wochen nicht geladen sind).
7. Ohne Kraft-Slots im Raster: keine Einheiten-Termine; Cardio/Kurse wie oben.
8. Filter wie bisher (`PlanFilter`).

- [ ] **Step 1: Failing tests** in `PlanKalenderTests` (Raster Kraft Mo/Di/Do, Cardio Sa; Einheiten `["A","B","C"]`; Europe/Berlin; heute = Mi 4.11.2026; beginn = Mo 26.10.2026):
  - `verpasstVerschiebtAufNaechstenKraftSlot`: erledigt Mo 2.11. „A“; Di 3.11. ohne Training; `naechsteEinheitKey: "B"` → Di 3.11. `.einheit("B", .verpasst(verschobenAuf: Do 5.11.))`, Do 5.11. `.einheit("B", .geplant)`, Mo 9.11. `.einheit("C", .geplant)`, Sa 7.11. `.cardio([], .geplant)` (Cardio-Slot nicht belegt).
  - `heuteNieVerpasst` (Review Focus 2): heute = Do 5.11., kein Training → Do `.einheit(_, .geplant)`.
  - `erledigtAnNichtSlotTag` (Review Focus 4): erledigt Mo 2.11. „A“ und Mi 4.11. (kein Slot) „B“, `naechsteEinheitKey: "C"` → Mi trägt keinen Einheiten-Termin, Di 3.11. ist `.verpasst` mit „B“ (`verschobenAuf: nil`, weil „B“ künftig nicht mehr geplant ist), Do 5.11. `.einheit("C", .geplant)`.
  - `zweiTrainingsAmSlotTag` (Review Focus 4): zwei `erledigt` am Mo 2.11. („A“, „B“) → genau ein Termin am Mo (`"A"`, `.erledigt`), nächster Slot trägt `"C"`.
  - `freiesTrainingAmSlotTag`: `trainiertAn` enthält Di 3.11., kein `erledigt` → kein Einheiten-Termin am Di, Folge unverändert.
  - `vorBeginnKeineSlots` (Review Focus 3): Tage vor `beginn` → keine Termine.
  - `ohneKraftSlots` (Review Focus 1): Raster nur Cardio → keine `.einheit`-Termine, kein Absturz.
  - `cardioVerpasst`: Sa 31.10. ohne Haken → `.cardio([], .verpasst(verschobenAuf: nil))`.
  - `naechsterAbHeute`: `PlanKalender.naechster` liefert am Mi 4.11. Do 5.11. „B“; ist heute ein geplanter Slot, heute selbst.
- [ ] **Step 2:** `xcodegen generate`; `-only-testing:FitnessMemberTests/PlanKalenderTests` → FAIL.
- [ ] **Step 3:** `PlanKalender` implementieren, `PlanTermin` umstellen, `PlanWoche.termine` löschen (`sichtbareFilter` bleibt in `PlanWoche`); Aufrufer (`PlanRootView`, `HomeWoche.alsNaechstes`) auf `PlanKalender` umstellen, damit der Build grün bleibt (beide werden in Task 7/8 weiter umgebaut).
- [ ] **Step 4:** `PlanKalenderTests`, umgezogene `PlanWocheTests`, `PlanTabZustandTests`, `HomeWocheKarteTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Plan-Kalender legt die Folge auf Slots, zeigt erledigt und verpasst`

---

### Task 5: Ein Kartenbaustein für Training und Einheit

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/EinheitKarte.swift`
- Modify: `Screens/Home/HomeSerieView.swift` (`tageskarte`, `tageskartenText` entfallen → `EinheitKarte`)
- Modify: `Screens/Plan/PlanTagListe.swift` (`einheitKarte`, `naechsteZeile` für Einheiten → `EinheitKarte`; `PlanKuerzelKaestchen` löschen, sobald ungenutzt)
- Test: Create `apps/ios-member/FitnessMemberTests/EinheitKarteModellTests.swift`

**Interfaces:**
- Consumes: `TrainingsProfil` (Task 2), `EinheitNamen` (Task 3), `TerminZustand` (Task 4), `HomeZeilen.grosseZeile/kleineZeile`, `EinheitKuerzel.untertitel`.
- Produces:
  ```swift
  struct EinheitKarteModell: Equatable {
      let titel: String
      /// Zeile unter dem Titel: Tag („Freitag, 6. Nov“, Akzent) oder nil.
      let tag: String?
      let zeilen: [String]          // 1–2 Kurzinfo-Zeilen
      let stufen: [String: TrainingsProfil.Stufe]
      let zustand: TerminZustand
      static func training(_ karte: Trainingskarte, muskeln: [String: [GeraetMuskel]]) -> EinheitKarteModell
      static func einheit(_ einheit: TrainingsplanEinheit, namen: EinheitNamen, muskeln: [String: [GeraetMuskel]],
                          tag: String?, zustand: TerminZustand) -> EinheitKarteModell
      /// „verpasst · verschoben auf Fr“, „verpasst“, „Erledigt“, nil bei .geplant.
      static func zustandsText(_ zustand: TerminZustand, kalender: Calendar) -> String?
  }
  struct EinheitKarte: View {
      let modell: EinheitKarteModell
      let geschlecht: Geschlecht?
      /// Optionaler Knopf rechts unten („Training starten“), nur am geplanten Tag.
      var aktion: (titel: String, ausloesen: () -> Void)? = nil
  }
  ```
- Aussehen: heutige `tageskarte` (Figur kompakt 76 pt mit „vorne/hinten“, `surface`, `Radius.card`, `Spacing.s16`). Titel in `uebungsname` statt `label` (Board „Home“). `.verpasst` → Inhalt mit 0.75 Deckkraft und Pille „verpasst · verschoben auf <Kurztag>“ (gestrichelter Rand `textFaint`); `.erledigt` bei Einheit → Zeile „Erledigt“.
- Trainingszeilen: `[grosseZeile, kleineZeile]` wie heute. Einheitenzeilen: `[EinheitKuerzel.untertitel(einheit)]` („6 Übungen · ca. 50 Min“).

- [ ] **Step 1: Failing tests:** `trainingModellTitelUndZeilen` (Karte mit Brust/Trizeps-Sätzen → `titel == "Brust, Trizeps"`, `zeilen.count == 2`, `zustand == .erledigt`); `einheitModell` (→ Titel aus `EinheitNamen`, `zeilen == ["6 Übungen · ca. 50 Min"]`, `tag == "Freitag, 6. Nov"` durchgereicht); `verpasstText`: `EinheitKarteModell.zustandsText(.verpasst(verschobenAuf: Fr 6.11.), kalender:) == "verpasst · verschoben auf Fr"`.
- [ ] **Step 2:** `xcodegen generate`; Test → FAIL.
- [ ] **Step 3:** Modell und View bauen; `HomeSerieView.tageskarte` und `PlanTagListe.einheitKarte`/`naechsteZeile` auf `EinheitKarte` umstellen; der Start-Knopf in `PlanTagListe` wird `aktion` (gleiche Bedingung wie heute, `zeigtStart`).
- [ ] **Step 4:** Test → PASS; `HomeSerieTests`, `PlanTabZustandTests` → PASS; Build grün.
- [ ] **Step 5: Commit** `feat(ios): eine Karte für Training und geplante Einheit`

---

### Task 6: Gleicher Detail-Kopf mit großem Männchen

**Files:**
- Create: `apps/ios-member/FitnessMember/DesignSystem/Components/ProfilKopf.swift`
- Modify: `Screens/Home/SessionDetailView.swift` (Kopf ab `:115`)
- Modify: `Screens/Plan/PlanEinheitView.swift` (Kopf `:40-60`, Kürzel-Kästchen entfällt)
- Test: `apps/ios-member/FitnessMemberTests/EinheitKarteModellTests.swift` (Kopfzeilen-Text)

**Interfaces:**
- Consumes: `EinheitKarteModell` (Task 5) – der Kopf nutzt dasselbe Modell, damit Karte und Detail dieselben Texte zeigen.
- Produces:
  ```swift
  struct ProfilKopf: View {
      /// Kleine Zeile über dem Titel: „GEPLANT · FREITAG, 6. NOV“ oder das Datum des Trainings.
      let ueberzeile: String
      let modell: EinheitKarteModell
      let geschlecht: Geschlecht?
  }
  ```
- Aufbau (Board „Einheiten-Detail“): Überzeile (`label`, Akzent bei geplant, `textMuted` bei Training), Titel `detailScreentitel`, Kurzinfo `fliesstext`/`textMuted`, darunter `MuskelKartenRahmen` mit `MuskelFigur(farben: MuskelFarben.farben(profil:), geschlecht:)` in voller Breite, „Vorderseite“/„Rückseite“ wie in `MuskelgruppenUebersichtView.ansichtsname`, Legende „stark“ (`accent`) / „mit“ (`accentPressed`). Figur `accessibilityHidden`, Titel trägt die Aussage.
- `SessionDetailView`: „Auto beendet“-Hinweis und Toolbar (Löschen, Fortsetzen) bleiben; Blöcke darunter unverändert.
- `PlanEinheitView`: unter dem Kopf Übungsliste, „Warum diese Einheit so aussieht“, Bearbeiten/Tauschen, Knopf „Im Training öffnen“ → Beschriftung „Training starten“ am geplanten Tag, sonst „Jetzt starten (vorziehen)“. Der Text an `:114` lautet neu: „Dran ist gerade <Name>. Der Plan folgt der Reihenfolge, nicht dem Wochentag.“

- [ ] **Step 1: Failing test:** `ueberzeileGeplant`: `ProfilKopf.ueberzeile(geplantAm: Fr 6.11., kalender:) == "GEPLANT · FREITAG, 6. NOV"`; `startKnopfText(istGeplanterTag: true) == "Training starten"`, `false` → „Jetzt starten (vorziehen)“ (statische Funktionen auf `ProfilKopf`).
- [ ] **Step 2:** `xcodegen generate`; Test → FAIL.
- [ ] **Step 3:** `ProfilKopf` bauen, in beiden Details einsetzen.
- [ ] **Step 4:** Test → PASS; Build grün; im Simulator Training-Detail und Einheiten-Detail öffnen und gegen das Board „Einheiten-Detail“ abgleichen (Screenshot im PR).
- [ ] **Step 5: Commit** `feat(ios): Training- und Einheiten-Detail mit gleichem Kopf und großem Männchen`

---

### Task 7: Plan-Tab als Trainingskalender

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Plan/PlanMonatsgitter.swift` (aus `HomeSerieView.monatsgitter`/`monatszelle` herausgelöst)
- Modify: `Screens/Plan/PlanRootView.swift`, `Screens/Plan/PlanTabZustand.swift`, `Screens/Plan/PlanTagListe.swift`
- Modify: `Navigation/KursRoute.swift` (Fall `.sessionDetail(id:)`), `Navigation/MainTabView.swift:35-50` (Destination `SessionDetailView` im Plan-Stack)
- Modify: `Screens/Kurse/KurseWochenView.swift` (`KurseWochenBerechnung.wochenMontage` um Vergangenheit)
- Test: `apps/ios-member/FitnessMemberTests/PlanTabZustandTests.swift`, `KurseWochenPagingTests.swift`

**Interfaces:**
- Consumes: `PlanKalender.termine` (Task 4), `EinheitKarte`/`EinheitKarteModell` (Task 5), `HomeSerie.einheitenJeTag`, `HomeZeilen.karte(fuer:in:)`.
- Produces:
  - `PlanTabZustand.ansicht: PlanAnsicht` mit `enum PlanAnsicht { case woche, monat }` (Vorgabe `.woche`).
  - `KurseWochenBerechnung.wochenMontage(ab jetzt: Date, zeitzone: String, zurueckBis: Date?) -> [Date]`: zusätzlich alle Montage von der Woche von `zurueckBis` bis vor die laufende Woche, höchstens 26 Wochen zurück; ohne `zurueckBis` wie heute. Der Index der laufenden Woche ist damit nicht mehr 0 – Vorauswahl über `PlanTabZustand.vorauswahl`.
  - `PlanMonatsgitter(monat: Date, kalender: Calendar, marken: (Date) -> some View, gewaehlt: Date?, beiTag: (Date) -> Void)` nutzt `Kalenderzelle`.
  - `KursRoute.sessionDetail(id: String)`.
- Inhalt unter dem gewählten Tag (Board „Plan-Tab · Kalender“):
  - vergangen/heute: Trainings des Tages als `EinheitKarte(.training)` → `planPfad.append(.sessionDetail(id:))`; Termine mit `.verpasst` als `EinheitKarte(.einheit, zustand: .verpasst)` bzw. Cardio-Zeile „verpasst“.
  - heute/künftig: `.geplant`-Termine wie bisher, Einheiten als `EinheitKarte`, Tipp → `.einheit(key:)`.
  - Kalenderzelle: Marke „verpasst“ = gestrichelter Ring `textFaint` (neuer Fall in `PlanTagMarke.Art`), sonst bestehende Marken.
- Umschalter Woche/Monat oben rechts im Kopf (Segment wie `SegmentSchalter`); Monat zeigt `PlanMonatsgitter`, Tag antippen wählt Tag und schaltet auf Woche zurück.

- [ ] **Step 1: Failing tests:** `PlanTabZustandTests.ansichtVorgabeWoche`; `KurseWochenPagingTests.montageReichenZurueckBisBeginn` (jetzt Mi 4.11., `zurueckBis` Mo 19.10. → erste Montage 19.10., 26.10., dann laufende Woche 2.11.); `montageHoechstens26Zurueck` (`zurueckBis` vor einem Jahr → 26 vergangene Montage); `ohneZurueckBisWieBisher`.
- [ ] **Step 2:** `xcodegen generate`; Tests → FAIL.
- [ ] **Step 3:** Umsetzen; `beginn` = `ISO8601` aus `plan.beginn`, `trainiertAn` aus `HomeSerie.einheitenJeTag(verlauf.sessions, zeitzone:)` (Keys), `erledigt` aus `plan.erledigt`.
- [ ] **Step 4:** Tests → PASS; alle `PlanTabZustandTests`, `KurseWochenPagingTests`, `KurseWochenBerechnungTests` → PASS; Simulator: in die Vorwoche wischen, verpassten Tag antippen, Training antippen → Detail im Plan-Stack; Monat öffnen.
- [ ] **Step 5: Commit** `feat(ios): Plan-Tab zeigt Vergangenheit, Monat und verpasste Termine`

---

### Task 8: Home aufräumen – Streak-Woche mit Plan, eine „Nächste Einheit“

**Files:**
- Modify: `Screens/Home/HomeRootView.swift:111-145, 330-360` (`woche(plan:)` entfällt)
- Modify: `Screens/Home/HomeSerieView.swift` (Monatsansicht, `umschalterKnopf`, `monatOffen` entfallen; geplante Tage markieren; künftige Tage antippbar)
- Modify: `Verlauf/HomeSerie.swift` (`HomeSerieTag` bekommt `geplant: PlanTagMarke.Art?`)
- Create: `apps/ios-member/FitnessMember/Screens/Home/NaechsteEinheitKarte.swift`
- Delete: `Screens/Home/HeuteDranZeile.swift`, `Screens/Home/HomeWocheKarte.swift` (`PlanSprung` vorher nach `Navigation/HomeRoute.swift` verschieben), `FitnessMemberTests/HomeWocheKarteTests.swift` (Fälle, die noch gelten, nach `HomeSerieTests`/`PlanKalenderTests`)
- Test: `apps/ios-member/FitnessMemberTests/HomeSerieTests.swift`

**Interfaces:**
- Consumes: `PlanKalender.termine/naechster` (Task 4), `EinheitKarte` (Task 5), `PlanSprung` (`.tag(Date)`, `.einheit(key:)`), `beiPlanZeigen`.
- Produces:
  - `HomeSerie.tage(_ stand:, trainingstage:, geplant: [String: PlanTagMarke.Art])`: Tagesschlüssel → Marke für heute und künftige Tage der laufenden Woche, aus `PlanKalender.termine` (`.geplant` → `.kraft`/`.cardio`/`.kurs`, `.verpasst` → `.verpasst`).
  - `HomeSerieView.istWaehlbar`: vergangene Tage wie heute (Session oder Kurs); heute und künftige Tage mit Marke → wählbar und lösen `beiPlanTag(Date)` aus (neuer Parameter, ruft `beiPlanZeigen(.tag(date))`).
  - `NaechsteEinheitKarte(termin: (tag: Date, termin: PlanTermin), modell: EinheitKarteModell?, istHeute: Bool, beiTippen: () -> Void, beiStart: () -> Void)`: Einheit → `EinheitKarte` mit `tag` und, nur wenn `istHeute`, `aktion: ("Training starten", beiStart)`; Kurs/Cardio → eine `EinheitKarte`-ähnliche Zeile mit Kurs-/Cardio-Kästchen (vorhandene `PlanKursKaestchen`/`PlanCardioKaestchen`) und Tag.
  - Reihenfolge auf Home (Spec 1.1, Board „Home“): Kopf → Streak-Woche (mit Tageskarten darunter) → „NÄCHSTE EINHEIT“ → `PlanEinrichtenKarte` → Ziele → Fortschritt. Ohne Kraft-Tage bleibt `TrainingstageFestlegenZeile` an der Stelle der Karte.
  - Läuft die nächste Einheit bereits (Ablauf gebunden, `PlanAnzeige.heute(...).zustand != nil`), zeigt die Karte den Fortschritt aus `PlanAnzeige` als Zeile und „Weiter trainieren“ statt „Training starten“.

- [ ] **Step 1: Failing tests** in `HomeSerieTests`: `geplanteTageTragenMarke` (Fr 6.11. `.kraft`, Sa 7.11. `.cardio`); `kuenftigerTagMitMarkeWaehlbar` / `kuenftigerTagOhneMarkeNicht`; `monatsansichtEntfaellt` entfällt als Test – stattdessen Compile-Prüfung, dass `HomeSerieView` keinen `monatOffen`-State mehr hat (Code-Review).
- [ ] **Step 2:** `xcodegen generate`; `-only-testing:FitnessMemberTests/HomeSerieTests` → FAIL.
- [ ] **Step 3:** Umsetzen, alte Dateien löschen, `xcodegen generate`.
- [ ] **Step 4:** `HomeSerieTests`, `HomeZeilenTests`, `PlanKalenderTests` → PASS; voller Testlauf `xcodebuild … test` → PASS; Simulator: Home gegen Board „Home“ abgleichen (Streak-Woche mit Marken, verpasster Tag gestrichelt, Karte „Nächste Einheit · Freitag“ ohne Start-Knopf; an einem Plantag mit Start-Knopf), künftigen Tag antippen → Plan-Tab an diesem Tag, Karte antippen → Einheiten-Detail im Plan-Tab.
- [ ] **Step 5: Commit** `feat(ios): Home zeigt die Woche mit Plan und eine nächste Einheit`

---

### Task 9: Abschluss Paket 1

- [ ] **Step 1:** Voller iOS-Testlauf und `pnpm --filter @fitretro/domain test` → PASS; Zeile „Test run with N tests“ notieren.
- [ ] **Step 2:** `rg "EinheitName\.|HeuteDranZeile|HomeWocheKarte|monatOffen|PlanKuerzelKaestchen" apps/ios-member/FitnessMember` → keine Treffer (Ausnahme: `EinheitKuerzel` in `PlanWochenSchritte`).
- [ ] **Step 3:** Spec-Abschnitt 1.8: doppelte Route `KursDetailView` prüfen; nur zusammenlegen, wenn es ohne Verhaltensänderung geht, sonst im PR als offen nennen.
- [ ] **Step 4:** PR gegen `master` mit Screenshots (Home, Plan-Tab Woche/Monat mit verpasstem Tag, Einheiten-Detail, Training-Detail) und dem Hinweis, dass Task 1 einen API-Deploy braucht, bevor die App-Version mit „verpasst/erledigt“ sinnvoll ist (ohne Deploy: `erledigt == []`, `beginn == nil` → keine Vergangenheit, keine falschen „verpasst“).
