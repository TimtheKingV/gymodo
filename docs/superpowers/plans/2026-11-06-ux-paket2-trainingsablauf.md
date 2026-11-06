# UX-Vereinheitlichung Paket 2 – Trainingsablauf – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Pausen-Screen, eine Kopfzeile mit Trainingsuhr, eine Ablaufzeile, eine Übungsauswahl und ein Übungsabschluss für freies Training, Plan und Mini-Zirkel – und der Kopf der Plan-Karte im Training-Tab aus den Paket-1-Bausteinen.

**Architecture:** Reine Werte-Typen (`Ablaufzeile`, `AblaufListe`, `PausenKnoepfe`) rechnen, was angezeigt wird; eine View `PausenScreen` zeigt es und meldet Taps über Callbacks. GeraetView (Pause als Phase im `GeraetModel`) und die Zirkel-Route `.zirkelPause` (Pause im `ZirkelAblauf`) behalten ihre Navigation und füttern denselben Screen. Plan-Vorgaben (Sätze, Wdh, Zielgewicht) kommen ins `GeraetModel`, damit Ablaufzeile, Räder und „Ziel erreicht“ nach dem Plan laufen.

**Tech Stack:** SwiftUI, Swift Testing, xcodegen (`apps/ios-member`).

**Spec:** `docs/superpowers/specs/2026-11-05-ux-vereinheitlichung-design.md` §2.1–2.6, dazu §1.4 (PlanKarte-Kopf, aus Paket 1 hierher verschoben). Mockups: https://claude.ai/artifact/6wzr9m7KFANPy2Ap5tKBEK (Boards „Gerät · Plan · Tracker“, „Pause · Plan“, „Pause · Zirkel“). Faktenblatt zum Code (Stand e66652f4): `.superpowers/paket2-fakten.md` im Worktree – für Implementer lesenswert, Zeilennummern können wandern.

## Global Constraints

- Kein Redesign: nur `DesignSystem`-Tokens, vorhandene Bausteine (`Zeitring`, `PrimaryButton`, `SecondaryButton`, `Card`, `RastRad`, `ReserveSkala`, `FertigRing`, `TrainingsuhrText`, `Laufpunkt`, `.trainingSteuerung`, `UebungsAnsichtBereich`, `MuskelAbschnitte`, `EinheitKarte`).
- Ein Thema, ein Baustein: `PausenRad` und der Körper von `ZirkelPauseView` werden durch `PausenScreen` ersetzt und gelöscht; die Rundenzusammenfassung, „Letztes Mal“ und das Video in der Pause entfallen.
- Jede Information nur einmal pro Screen; genau ein Primary-Knopf je Zustand.
- Pausen-Ring in Zirkel-Größe: `Zeitring(kante: 140)`; „+30 s“ direkt neben dem Ring.
- Ablauf-Liste: höchstens 2 erledigte darüber, die aktuelle, höchstens 2 nächste darunter, „Alle anzeigen“ klappt den Rest aus. Zeilenbild = Standbild (kein `UebungsVideoKachel`).
- Ablaufzeile-Texte exakt: Plan „Übung 3 von 6 · Satz 2 von 3“, Zirkel „Station 2 von 4 · Runde 1 von 3“, frei „Satz 2“.
- Plan-Ziel an den Rädern: „Ziel 8–10“ (Wiederholungsrad), „Plan 40 kg“ (Kontextzeile Gewichtsrad).
- Pausen-Knöpfe: nur frei „Zirkel mit weiterem Gerät“; nur Zirkel „Überspringen“, „+ Übung zum Zirkel“, „Zirkel beenden“; immer „± Gewicht“.
- Testnotiz-IDs (`.testnotizElement("geraet.naechster-satz", …)` usw.) bleiben erhalten, wo der Knopf weiterlebt.
- Tracker-Symbol in der Kopfzeile gehört zu Paket 3; die DEBUG-`SensorZeile` bleibt bis dahin, wo sie ist, außer in der Pause (dort entfällt sie, Spec 3.2 „Sensorblock in der Pause“ – darf schon jetzt weg).
- Tests: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite> 2>&1 | tail -20`, Zeile „Test run with N tests“ prüfen. Nach neuen/gelöschten Dateien `xcodegen generate`, `project.pbxproj` mitcommitten.
- Commits deutsch (`feat(ios): …`), Ende `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Entscheidungen dieses Plans (vom Spec offen gelassen)

- **E1 Plan-Vorgaben am Gerät:** Steht die Übung als Planposition in der laufenden Einheit, gelten `vorgabe.saetze` als `satzZiel`, `wdhVon…wdhBis` als Zielspanne, das Zielgewicht als „Plan … kg“. Sonst wie heute (Profil/Katalog).
- **E2 „Ziel erreicht“ ist der Abschluss-Zustand:** Nach dem letzten geplanten Satz geht das Gerät wie heute in `.abschluss` (Reserve-Frage). Dort heißt der Hauptknopf im Plan „Nächste Übung: <Name>“, „Weiterer Satz“ bleibt zweiter Knopf. Eine Pause mit „Ziel erreicht“ gibt es daher nicht.
- **E3 „Nächste Übung: <Name>“** führt zur Training-Wurzel und öffnet dort die Planposition dieses Namens genau so, als hätte man ihre Zeile in der Plan-Karte angetippt (`beiPosition`). Nächste Planposition = erste Planstelle mit Status `.offen` oder `.getauscht`, nicht ausgelassen, nicht die aktuelle Übung, in Ablauf-Reihenfolge.
- **E4 Übungsabschluss immer mit Reserve-Frage:** Jeder Weg aus einer Kraftübung (Pause → „Übung abschließen“/„Nächste Übung“, Räder → „Übung abschließen“) führt zuerst in `.abschluss`, wenn ein Satz geschrieben wurde. Cardio und Übungen ohne Satz verlassen direkt. Im Zirkel: einmal je Station auf der Zirkel-Übersicht.
- **E5 Plan-Ersatz-Auswahl:** gruppiert nach Muskelgruppen, innerhalb einer Gruppe in Server-Reihenfolge (die Server-Reihenfolge stellt „vorsichtig“ hinten an und bleibt fachlich bindend); keine Verlaufs-Sortierung.
- **E6 Ablauf-Liste ist nur Ansicht** (Paket-1-Ruling): Antippen einer Zeile springt nirgendwohin.
- **E7 Zirkel ohne „Übung abschließen“:** Im Zirkel übernehmen „Überspringen“ (nächste Station) und „Zirkel beenden“ diese Rolle; eine Station dauerhaft aus den restlichen Runden zu nehmen, gibt es heute nicht und kommt nicht dazu.

## Review Focus

1. **Cardio im Plan/frei:** Cardio hat keine Pause und keine Reserve-Frage; der neue Abschlussweg (E4) darf Cardio nicht in eine Reserve-Frage schicken. → Test in Task 6.
2. **Zirkel-Rundenpause:** Zwischen Runden ist die Pause länger und die Ablaufzeile nennt schon die neue Runde; die Liste zeigt die Stationen der neuen Runde als „nächste“. → Test in Task 2.
3. **Planübung an zwei Geräten:** `satzNummer` zählt je Gerät, der Plan je Übung. Die Ablaufzeile „Satz n von m“ nimmt die Plan-Zählung (`PlanAnzeige.satzzahl` + 1), damit Ablaufzeile und Plan-Karte „2/3“ übereinstimmen. → Test in Task 1.
4. **Freies Training mit nur einer Übung:** Ablauf-Liste zeigt nur die aktuelle Übung, kein „Alle anzeigen“. → Test in Task 2.
5. **Zirkel-Gewicht für die nächste Station:** Ein in der Pause gewähltes Gewicht gilt beim Start der Station auch ab Runde 2 (Vorrang vor „heutiger letzter Satz“). → Test in Task 5.

---

### Task 1: Plan-Vorgaben und Ablaufzeile am Gerät

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Ablaufzeile.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (`satzZiel` ~:769, `zielspanne` ~:684, `kontextzeileUmfang` ~:674, `kontextzeileBelastung` ~:666, neue Properties)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`geraetUndUebung`/`namen` ~:299-343: Ablaufzeile unter dem Übungsnamen)
- Test: Create `apps/ios-member/FitnessMemberTests/AblaufzeileTests.swift`; erweitern `GeraetModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum Ablaufzeile: Equatable {
      case plan(uebung: Int, von: Int, satz: Int, saetze: Int)
      case zirkel(station: Int, von: Int, runde: Int, runden: Int)
      case frei(satz: Int)
      var text: String
  }
  struct PlanStelleAmGeraet: Equatable {
      let positionKey: String
      let nummer: Int          // 1-basiert in Ablauf-Reihenfolge, ohne ausgelassene
      let gesamt: Int          // wie PlanAnzeige.fortschritt-Nenner
      let saetze: Int
      let wdhVon: Int?
      let wdhBis: Int?
      let satzGemacht: Int     // PlanAnzeige.satzzahl(exerciseId:bloecke:)
  }
  // GeraetModel:
  var planStelle: PlanStelleAmGeraet? { get }
  var ablaufzeile: Ablaufzeile? { get }   // nil im Zirkel (TrainingRootView setzt die Zirkel-Zeile, Task 4)
  ```
- `satzZiel`: mit `planStelle` → `planStelle.saetze`, sonst unverändert. `zielspanne`: mit `wdhVon`/`wdhBis` → diese, sonst Katalog. `kontextzeileUmfang`: „Ziel 8–10“ (gleiches Format `Zahlformat.korridor`). `kontextzeileBelastung`: mit Zielgewicht „Plan 40 kg“ (Format wie `Zahlformat` für Lasten), sonst unverändert.
- `ablaufzeile`: Plan → `.plan(uebung: nummer, von: gesamt, satz: satzGemacht + 1, saetze: saetze)`; frei → `.frei(satz: satzNummer)`.

- [ ] **Step 1: Failing tests**
  - `AblaufzeileTests`: `.plan(uebung: 3, von: 6, satz: 2, saetze: 3).text == "Übung 3 von 6 · Satz 2 von 3"`, `.zirkel(station: 2, von: 4, runde: 1, runden: 3).text == "Station 2 von 4 · Runde 1 von 3"`, `.frei(satz: 2).text == "Satz 2"`.
  - `GeraetModelTests` (Plan-Fixture wie `pauseNachEinemPlansatzKommtAusDerPosition` ~:435):
    - `planStelleNenntPositionUndVorgabe`: Position an 3. Stelle von 6, `saetze 3`, `wdh 8–10` → `planStelle?.nummer == 3`, `gesamt == 6`, `satzZiel == 3`, `zielspanne == 8...10`, `kontextzeileUmfang == "Ziel 8–10"`.
    - `zielgewichtAlsPlanzeile`: Zielgewicht 40 → `kontextzeileBelastung == "Plan 40 kg"`.
    - `ohnePlanUnveraendert`: freie Übung → `planStelle == nil`, `satzZiel` = Profilwert, `ablaufzeile == .frei(satz: 1)`.
    - `planSatzZaehltUeberGeraete` (Review Focus 3): 1 Satz derselben Planübung an einer anderen Station → `ablaufzeile == .plan(…, satz: 2, saetze: 3)`.
    - `nachDemLetztenPlansatzKommtDerAbschluss`: 3 Sätze bei `saetze 3`, Profil-`satzZiel` 4 → Phase `.abschluss`.
- [ ] **Step 2:** `xcodegen generate`; `-only-testing:FitnessMemberTests/AblaufzeileTests` und `GeraetModelTests` → FAIL.
- [ ] **Step 3:** Implementieren. `planStelle` aus `PlanAnzeige.heute(bootstrap:…)` + `PlanAnzeige.planstellen` (Stelle mit `wirksam == uebungId`); `ablauf`/`bootstrap` sind im Modell privat – die Rechnung gehört ins Modell. GeraetView zeigt `modell.ablaufzeile?.text` als Pille (Board „Gerät · Plan · Tracker“) direkt unter dem Übungsnamen.
- [ ] **Step 4:** Beide Suiten → PASS; bestehende Erwartungen in `GeraetModelTests` (:879, :893), die von Profil-`satzZiel` ausgehen, gelten weiter für freie Übungen – nur anpassen, wo die Fixture eine Planposition ist, und das im Report begründen.
- [ ] **Step 5: Commit** `feat(ios): Gerät kennt Plan-Vorgaben und zeigt die Ablaufzeile`

---

### Task 2: Ablauf-Liste (Modell)

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/AblaufListe.swift`
- Test: Create `apps/ios-member/FitnessMemberTests/AblaufListeTests.swift`

**Interfaces:**
- Consumes: `PlanAnzeige.zeilen(…)`/`planstellen`, `Zirkel.uebungen`/`stand(an:)`/`naechste`, `LokalerBlock`, `ZirkelPauseText.satzwerte(_:_:)`, `TrainingTab.blockzeile(_:)`.
- Produces:
  ```swift
  struct AblaufZeile: Identifiable, Equatable {
      enum Stand: Equatable { case erledigt, jetzt, naechste, offen }
      let id: String
      let name: String
      let detail: String        // erledigt: "3 × 11 · 30 kg"-artig bzw. Satzwerte; jetzt: "9 · 9 · Satz 3"; naechste/offen: Vorgabe "3 × 10–12" oder ""
      let stand: Stand
      let bildModellId: String?
  }
  enum AblaufListe {
      static func plan(plan: Trainingsplan, einheitKey: String, zustand: AblaufZustand?, ausgelassen: Set<String>,
                       bloecke: [LokalerBlock], aktuelleUebung: String?, bootstrap: BootstrapResponse?) -> [AblaufZeile]
      static func zirkel(_ zirkel: Zirkel, bloecke: [LokalerBlock], seit: Date?, name: (ZirkelUebung) -> String,
                         bildModellId: (ZirkelUebung) -> String?) -> [AblaufZeile]
      static func frei(bloecke: [LokalerBlock], aktuell: (stationSchluessel: String, exerciseId: String)?,
                       name: (LokalerBlock) -> String) -> [AblaufZeile]
      /// Höchstens 2 erledigte (die letzten), alle .jetzt, höchstens 2 der folgenden; `ausgeklappt` → alle.
      static func sichtbar(_ zeilen: [AblaufZeile], ausgeklappt: Bool) -> [AblaufZeile]
      static func hatMehr(_ zeilen: [AblaufZeile]) -> Bool
  }
  ```
- Plan: Reihenfolge = Ablauf-Reihenfolge ohne ausgelassene; Stand erledigt = Status `.erledigt`/`.optional`; jetzt = `aktuelleUebung`; die erste offene nach jetzt (E3-Regel) = `.naechste`, weitere `.offen`. Zirkel: `ZirkelStand.abgeschlossen` → erledigt, `naechste` → `.naechste`, Rest `.offen`; `jetzt` gibt es in der Zirkel-Pause nicht. Frei: alle Blöcke erledigt, der aktuelle `.jetzt` (auch ohne Satz).

- [ ] **Step 1: Failing tests**
  - `planReihenfolgeUndStand`: 6 Positionen, 2 erledigt, aktuelle = 3. → Stände `[erledigt, erledigt, jetzt, naechste, offen, offen]`.
  - `planOhneAusgelassene`: ausgelassen `["A4"]` → fehlt in der Liste.
  - `sichtbarZeigtZweiDarueberUndZweiDarunter`: 7 Zeilen, jetzt an Index 4 → sichtbar = Index 2…6, `hatMehr == true`; `ausgeklappt: true` → alle 7.
  - `zirkelRundenpause` (Review Focus 2): 3 Übungen, Runde 1 geschafft, Rundenwechsel → erste Übung `.naechste`, andere `.offen`, Detail der ersten = Satz aus Runde 1 nicht doppelt.
  - `freiEineUebung` (Review Focus 4): ein aktueller Block ohne Satz → eine Zeile `.jetzt`, `hatMehr == false`.
- [ ] **Step 2:** `xcodegen generate`; Test → FAIL.
- [ ] **Step 3:** Implementieren (reine Funktionen, keine Views).
- [ ] **Step 4:** Test → PASS.
- [ ] **Step 5: Commit** `feat(ios): Ablauf-Liste für Plan, Zirkel und freies Training`

---

### Task 3: Gemeinsame Kopfzeile mit Trainingsuhr

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Training/TrainingKopfzeile.swift`
- Modify: `Screens/Geraet/GeraetView.swift` (`kopfzeile`/`trainingsuhr` ~:252-290 → `TrainingKopfzeile`)
- Test: keine neue Logik; Build + Simulator (Task 9)

**Interfaces:**
- Produces:
  ```swift
  struct TrainingKopfzeile: View {
      let ort: String                    // bereits großgeschrieben übergeben
      let beiSteuerung: () -> Void       // öffnet .trainingSteuerung des Hosts
  }
  ```
  Liest `WorkoutSessionStore` aus der Umgebung; zeigt `Laufpunkt` + `TrainingsuhrText(font: .system(size: 15, weight: .semibold))` nur bei aktiver Session; Testnotiz-ID `geraet.trainingsuhr` bleibt.

- [ ] **Step 1:** `TrainingKopfzeile` aus GeraetView herauslösen, GeraetView nutzt sie (Verhalten gleich).
- [ ] **Step 2:** `xcodegen generate`; Build → BUILD SUCCEEDED; `GeraetModelTests` → PASS.
- [ ] **Step 3: Commit** `refactor(ios): Kopfzeile mit Trainingsuhr als eigener Baustein`

---

### Task 4: Ein Pausen-Screen für alle Modi

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Training/PausenScreen.swift`, `apps/ios-member/FitnessMember/Workout/PausenKnoepfe.swift`
- Modify: `Screens/Geraet/GeraetView.swift` (`inhalt` ~:196-209: `PausenRad` → `PausenScreen`)
- Modify: `Screens/Zirkel/ZirkelPauseView.swift` (Körper → `PausenScreen`; `ZirkelPauseText.rundenzeilen` und Reihenfolge-Card entfallen)
- Modify: `Screens/Training/TrainingRootView.swift` (`.zirkelPause` ~:843: Kopf/Steuerung/Gewicht durchreichen; `.zirkelUebersicht`: `TrainingKopfzeile`)
- Delete: `PausenRad` (struct in `DesignSystem/Components/PausenRad.swift`; `Zeitring` und `FertigRing` bleiben – Datei ggf. in `Zeitring.swift` umbenennen); `PausenRad.gewichtTitel` → `PausenKnoepfe.gewichtTitel`
- Test: Create `apps/ios-member/FitnessMemberTests/PausenKnoepfeTests.swift`; anpassen `UebungsstartTests.swift:110-111`, `ZirkelPauseTextTests.swift` (Rundenzeilen-Test entfernen)

**Interfaces:**
- Consumes: `Ablaufzeile` (Task 1), `AblaufListe`/`AblaufZeile` (Task 2), `TrainingKopfzeile` (Task 3), `Zeitring`, `Resttimer`.
- Produces:
  ```swift
  enum PausenModus: Equatable {
      case frei(naechsterSatz: Int, kannZirkel: Bool)
      case plan(naechsterSatz: Int)
      case zirkel(naechsteUebung: String, kannErweitern: Bool)
  }
  struct PausenKnoepfe: Equatable {
      let haupt: String                  // "Satz 3 starten" | "Beinpresse starten"
      let abschliessen: String?          // frei "Übung abschließen", plan "Nächste Übung", zirkel nil
      let ueberspringen: Bool            // nur zirkel
      let zirkelBeginnen: Bool           // nur frei && kannZirkel
      let erweitern: Bool                // nur zirkel && kannErweitern
      let zirkelBeenden: Bool            // nur zirkel
      static func fuer(_ modus: PausenModus) -> PausenKnoepfe
      static func gewichtTitel(_ einheit: LoadUnit) -> String   // "± kg", "± km/h"
  }
  struct PausenScreen: View {
      let ort: String
      let ueberschrift: String           // "PAUSE · BRUSTPRESSE" / "PAUSE · MINI-ZIRKEL" / Zirkel-Rundenpause "RUNDENPAUSE · MINI-ZIRKEL"
      let ablaufzeile: Ablaufzeile?
      let timer: Resttimer
      let zeilen: [AblaufZeile]
      let knoepfe: PausenKnoepfe
      let einheit: LoadUnit
      let beiSteuerung: () -> Void
      let beiVerlaengern: () -> Void
      let beiHaupt: () -> Void
      let beiGewicht: () -> Void
      let beiAbschliessen: () -> Void
      let beiUeberspringen: () -> Void
      let beiZirkelBeginnen: () -> Void
      let beiErweitern: () -> Void
      let beiZirkelBeenden: () -> Void
  }
  ```
- Aufbau (Board „Pause · Plan“/„Pause · Zirkel“): `TrainingKopfzeile` → Überschrift (`label`) + Ablaufzeile-Pille → HStack[`Zeitring(kante: 140)`, „+30 s“] → Card mit `AblaufListe.sichtbar` (Zeilenbild `Geraetefoto(modellId:url: nil)` mit `Uebungsbild`-Platzhalter, `@State ausgeklappt`, Knopf „Alle anzeigen“ nur bei `hatMehr`) → unten Primary `haupt` (ID `geraet.naechster-satz`), Grid[„± Gewicht“, `abschliessen` bzw. „Überspringen“], darunter Textknöpfe (`zirkelBeginnen` ID `geraet.zirkel-beginnen`; „+ Übung zum Zirkel“, „Zirkel beenden“). VoiceOver-Ansage alle 15 s wie bisher in `PausenRad` (`.task(id: timer.endetAm)`).
- Zirkel: Ablaufzeile `.zirkel(station: Index von naechste + 1, von: uebungen.count, runde: zirkel.runde, runden: zirkel.runden)`; „± Gewicht“ öffnet das Gewicht der nächsten Station (Task 5 – bis dahin `beiGewicht` leer und Knopf ausgeblendet, sonst nichts halb Gebautes).
- Zirkel-Übersicht bekommt dieselbe `TrainingKopfzeile` (Uhr fehlte dort).

- [ ] **Step 1: Failing tests** `PausenKnoepfeTests`:
  - `frei`: `.frei(naechsterSatz: 3, kannZirkel: true)` → `haupt == "Satz 3 starten"`, `abschliessen == "Übung abschließen"`, `zirkelBeginnen`, nicht `ueberspringen/erweitern/zirkelBeenden`.
  - `freiOhneZirkel`: `kannZirkel: false` → `zirkelBeginnen == false`.
  - `plan`: `.plan(naechsterSatz: 2)` → `haupt == "Satz 2 starten"`, `abschliessen == "Nächste Übung"`, kein Zirkel-Knopf.
  - `zirkel`: `.zirkel(naechsteUebung: "Beinpresse", kannErweitern: true)` → `haupt == "Beinpresse starten"`, `abschliessen == nil`, `ueberspringen`, `erweitern`, `zirkelBeenden`.
  - `gewichtTitel`: `.kg` → „± kg“, `.kmh` → „± km/h“ (ersetzt `UebungsstartTests:110-111`).
- [ ] **Step 2:** `xcodegen generate`; Test → FAIL.
- [ ] **Step 3:** `PausenKnoepfe`, `PausenScreen` bauen; GeraetView (frei/plan; `modell.planStelle != nil` → `.plan`) und ZirkelPauseView umstellen; `PausenRad` löschen; Steuerung: GeraetView nutzt sein `steuerungOffen`, ZirkelPauseView bekommt `beiSteuerung` von TrainingRootView (`steuerungOffen = true` der Wurzel, die `.trainingSteuerung` schon trägt).
- [ ] **Step 4:** `PausenKnoepfeTests`, `ZirkelPauseTextTests`, `ZirkelAblaufTests`, `GeraetModelTests`, `UebungsstartTests` → PASS; `rg "PausenRad" apps/ios-member` → keine Treffer.
- [ ] **Step 5: Commit** `feat(ios): ein Pausen-Screen für freies Training, Plan und Zirkel`

---

### Task 5: Gewicht der nächsten Zirkel-Station in der Pause

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/Zirkel.swift` (`ZirkelVormerkung` ~:278)
- Modify: `Screens/Geraet/GeraetModel.swift` (Startwerte-Vorrang in `init` ~:367)
- Modify: `Screens/Geraet/GeraetView.swift` (`GewichtAendernSheet` ~:721 von `private` auf intern)
- Modify: `Screens/Training/TrainingRootView.swift` (`.zirkelPause`: Sheet für die nächste Station)
- Test: `ZirkelTests.swift` (oder `ZirkelPlanungTests.swift`, wo `ZirkelVormerkung` getestet ist), `GeraetModelTests.swift`

**Interfaces:**
- Produces: `ZirkelVormerkung.vormerken(_ uebung: ZirkelUebung, startwerte: Startwerte)` für jede Runde; `entnehmen(_:runde:)` liefert eine Vormerkung jetzt auch ab Runde 2 (und entfernt sie).
- In der Zirkel-Pause baut TrainingRootView für „± Gewicht“ ein Modell der nächsten Station über das vorhandene `modell(station:exerciseId:token:startwerte:zirkel:)`, öffnet `GewichtAendernSheet(modell:beiFertig:)` und merkt beim Schließen `Startwerte(load: modell.belastung, …)` für `zirkel.naechste` vor. Danach startet die Station mit diesem Gewicht.
- `GeraetModel.init`: übergebene `startwerte` haben Vorrang vor `letzterSatzHeute`.

- [ ] **Step 1: Failing tests:** `vormerkungGiltAuchAbRundeZwei` (vormerken in Runde 2, `entnehmen(_, runde: 2)` liefert sie, danach nil); `startwerteVorHeutigemSatz` (Review Focus 5: heutiger Satz 40 kg, Startwerte 45 kg → `belastung == 45`).
- [ ] **Step 2:** Tests → FAIL.
- [ ] **Step 3:** Implementieren; in `PausenScreen` (Zirkel) „± Gewicht“ einblenden und verdrahten.
- [ ] **Step 4:** Tests + `ZirkelAblaufTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Gewicht der nächsten Zirkel-Station schon in der Pause wählen`

---

### Task 6: Übungsabschluss einheitlich mit Reserve-Frage

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/WorkoutSessionStore.swift` (letzter Satz-Write je Block)
- Modify: `Screens/Geraet/GeraetModel.swift` (`zeigtReserveFrage` ~:181, `reserveSetzen` ~:185, neuer Weg in den Abschluss)
- Modify: `Screens/Geraet/GeraetView.swift` (`abschlussEntscheidung` ~:439-482; Knöpfe „Übung abschließen“/„Nächste Übung“ aus Pause und Rädern)
- Modify: `Screens/Zirkel/ZirkelUebersichtView.swift` (Reserve je Station)
- Modify: `Screens/Training/TrainingRootView.swift` („Nächste Übung: <Name>“ → Wurzel + Planposition öffnen)
- Test: `GeraetModelTests.swift`, `ZirkelUebersichtTests.swift`, `WorkoutSessionStoreTests.swift`

**Interfaces:**
- Produces:
  - `WorkoutSessionStore.letzterWrite(blockId: String) -> PendingSetWrite?` (gemerkt beim Enqueue eines Satzes) und `reserveNachtragen(blockId: String, reserve: Reserve)` (setzt lokal wie `reserveSetzen(setId:rir:)` und reiht den gemerkten Write mit `rir` erneut ein – derselbe Weg, den `GeraetModel.reserveSetzen` heute privat geht; das Modell nutzt danach diesen Store-Weg).
  - `GeraetModel.abschlussAnfragen() -> Bool`: Kraftübung mit geschriebenem Satz → Phase `.abschluss`, `true`; Cardio oder ohne Satz → `false` (Aufrufer verlässt wie bisher).
  - `GeraetModel.naechstePlanuebung: (positionKey: String, name: String)?` (E3-Regel; nil ohne Plan).
  - Abschluss-Titel: „\(n) SÄTZE GESCHAFFT“ mit der tatsächlichen Satzzahl dieses Blocks (heute fälschlich `satzZiel`), Singular „1 SATZ GESCHAFFT“.
  - Hauptknopf im Abschluss: Plan mit `naechstePlanuebung` → „Nächste Übung: \(name)“, sonst „Nächste Übung“; zweiter Knopf „Weiterer Satz“.
  - Zirkel-Übersicht: je `ZirkelZeile` eine kompakte `ReserveSkala` (nur Kraftübungen mit Satz), die `reserveNachtragen(blockId:)` aufruft; `ZirkelZeile` bekommt `blockId: String?` und `fragtReserve: Bool`.
- Navigation „Nächste Übung: X“: `GeraetScreen` meldet `beiNaechstePlanuebung(positionKey)`; TrainingRootView leert `pfad` und ruft denselben Weg wie `PlanKarte.beiPosition(positionKey)`.

- [ ] **Step 1: Failing tests**
  - `abschlussAusDerPauseFragtNachReserve`: 2 Sätze, Pause, `abschlussAnfragen()` → `true`, Phase `.abschluss`, `zeigtReserveFrage`.
  - `cardioVerlaesstOhneReserve` (Review Focus 1): Cardio-Satz, `abschlussAnfragen()` → `false`.
  - `ohneSatzVerlaesstDirekt`: kein Satz → `false`.
  - `abschlussTitelZaehltEchteSaetze`: 2 Sätze bei `satzZiel` 3 → Titeltext „2 SÄTZE GESCHAFFT“ (Titel als statische Funktion, z. B. `GeraetModel.abschlussTitel(saetze:)`).
  - `naechstePlanuebungFolgtDerReihenfolge`: Positionen A0 erledigt, A1 aktuell, A2 ausgelassen, A3 offen → `naechstePlanuebung?.positionKey == "A3"`.
  - `WorkoutSessionStoreTests.reserveNachtragenReihtDenLetztenWriteMitRirEin`.
  - `ZirkelUebersichtTests.zeileFragtReserveNurBeiKraftMitSatz`.
- [ ] **Step 2:** Tests → FAIL.
- [ ] **Step 3:** Implementieren; GeraetView: „Übung abschließen“ (Räder) und `beiAbschliessen` (Pause) rufen erst `modell.abschlussAnfragen()`, nur bei `false` den bisherigen Weg (`SatzOffenSheet`/`UebungAbschliessenSheet`/zurück).
- [ ] **Step 4:** Tests + `GeraetModelTests`, `CardioGeraetModelTests`, `ZirkelUebersichtTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): jede Übung endet mit derselben Abfrage, auch im Zirkel`

---

### Task 7: Übungsauswahl im Zirkel und beim Plan-Ersatz

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/ZirkelUebungswahlSheet.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/PlanErsatzKopf.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/UebungsGruppierung.swift` (falls ein Mapping-Helfer nötig ist)
- Test: `UebungsGruppierungTests.swift`, `PlanTauschTests.swift` (Reihenfolge unverändert)

**Interfaces:**
- Consumes: `UebungsAnsichtBereich`, `UebungsUntertitel`, `MuskelAbschnitte`, `UebungsGruppierung.abschnitte(_:muskeln:nur:)`, `TrainingTab.blockzeile`.
- Produces:
  - `ZirkelUebungswahl.geraetUebungen: [GeraetUebung]` (aus `station.exercises`, Zuordnung wie `GeraetModel.uebungen` Bootstrap-Zweig) und `ZirkelUebungswahl.untertitel(_ uebung: GeraetUebung, bloecke: [LokalerBlock]) -> (text: String, hatHistorie: Bool)`: heute schon gemacht → „Heute · \(blockzeile)“, sonst „Ziel \(korridor)“. Reihenfolge: heute gemachte zuerst, sonst Katalogreihenfolge. Das Sheet nutzt `UebungsAnsichtBereich` (ab 6 Übungen Segment + Muskelgruppen), Hinweis „Schon im Zirkel: …“ bleibt; bereits im Zirkel befindliche erscheinen nicht.
  - `PlanErsatzKopf`: Kandidaten in `MuskelAbschnitte` nach Muskelgruppe (`TauschKandidat.hauptmuskeln` → `GeraetMuskel(key:role: .primary)`), innerhalb der Gruppe Server-Reihenfolge (E5); Zeilenaussehen bleibt.
- [ ] **Step 1: Failing tests:** `zirkelWahlGruppiertNachMuskeln` (7 Übungen über 3 Gruppen → `UebungsGruppierung.abschnitte` liefert 3 Abschnitte in fester Gruppenreihenfolge); `zirkelUntertitelHeute` („Heute · 2 Sätze · 7,5 kg“); `ersatzGruppenBehaltenServerreihenfolge` (Kandidaten [x(brust), y(ruecken), z(brust)] → Brust [x, z], Rücken [y]).
- [ ] **Step 2:** Tests → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** Tests + `PlanTauschTests`, `GeraeteAuswahlTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Zirkel- und Ersatz-Auswahl nach Muskelgruppen wie die normale Übungsauswahl`

---

### Task 8: Kopf der Plan-Karte aus den Paket-1-Bausteinen

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/PlanKarte.swift` (`kopf` ~:153-182)
- Test: `EinheitKarteModellTests.swift`

**Interfaces:**
- Consumes: `EinheitKarteModell.einheit(_:namen:muskeln:tag:zustand:)`, `EinheitKarte`, `PlanAnzeige.fortschritt`, `PlanAnzeige.restminutenText`, `PlanAnzeige.metaText`.
- Produces: `EinheitKarteModell.laufend(_ modell: EinheitKarteModell, fortschritt: String?) -> EinheitKarteModell` (ersetzt `zeilen` durch `["4 von 7 · noch ca. 35 Min"]`, sonst unverändert; dieselbe Idee wie `HomeRootView.einheitModell`, das danach diese Funktion nutzt).
- Die Karte zeigt statt der Label-Zeile „EINHEIT A“ eine `EinheitKarte` (Name, kleines Männchen, Meta bzw. Fortschritt) **über** der Zeilen-Card, nicht darin (keine Doppelrahmung). Kein Tag, Zustand `.geplant`.
- [ ] **Step 1: Failing test:** `laufendErsetztZeilen` (`zeilen == ["4 von 7 · noch ca. 35 Min"]`, Titel unverändert).
- [ ] **Step 2:** Test → FAIL.
- [ ] **Step 3:** Implementieren; `HomeRootView.einheitModell` auf `EinheitKarteModell.laufend` umstellen.
- [ ] **Step 4:** `EinheitKarteModellTests`, `PlanAnzeigeTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Plan-Karte im Training-Tab mit dem gemeinsamen Einheiten-Kopf`

---

### Task 9: Abschluss Paket 2

- [ ] **Step 1:** Voller iOS-Testlauf → „Test run with N tests … passed“.
- [ ] **Step 2:** `rg "PausenRad|rundenzeilen|UebungsVideoKachel" apps/ios-member/FitnessMember/Screens/Training/PausenScreen.swift apps/ios-member/FitnessMember/Screens/Zirkel` → kein `PausenRad`/`rundenzeilen`; kein Video in der Pause.
- [ ] **Step 3:** Auf dem iPhone (`xcrun devicectl`) bzw. Simulator mit Login: freies Training mit 2 Sätzen → Pause; Plan-Übung → Ablaufzeile, „Plan … kg“, nach letztem Satz Reserve-Frage + „Nächste Übung: X“; Mini-Zirkel → gleiche Pause, „± Gewicht“, Übersicht mit Reserve. Gegen Boards „Pause · Plan“, „Pause · Zirkel“, „Gerät · Plan · Tracker“ abgleichen; Screenshots in den PR.
- [ ] **Step 4:** PR gegen `master`; im PR die Entscheidungen E1–E6 nennen.
