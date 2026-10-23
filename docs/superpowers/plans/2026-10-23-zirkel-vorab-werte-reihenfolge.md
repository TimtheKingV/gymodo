# Zirkel: Werte vorab festlegen und Reihenfolge in der Pause – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Gewicht und Wiederholungen je Übung schon beim Anlegen des Zirkels festlegen, sodass im Zirkel kein Startwerte-Drawer mehr kommt, und in der Zirkel-Pause die ganze Reihenfolge mit Fortschritt je Übung zeigen.

**Architecture:** Der bestehende Mechanismus `ZirkelVormerkung` (Startwerte je Übung, einmal in Runde 1 entnommen) wird ab dem Start mit den Werten *aller* geplanten Übungen gefüllt statt nur mit denen der ersten. `zirkelWeiter()` überspringt den Drawer dadurch von selbst. Die Werte entstehen im Planungs-Sheet über den vorhandenen `UebungsstartSheet` (mit Wiederholungs-Rad). Der Pausenscreen ersetzt die Karte „Als Nächstes“ durch eine Liste im Katalog-Stil; der Fortschritt je Zeile ist eine reine Funktion `Zirkel.stand(an:)`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing (`@Test`, `#expect`), XcodeGen (keine neuen Dateien, `project.pbxproj` bleibt unberührt).

**Spec:** `docs/superpowers/specs/2026-10-21-mini-zirkel-design.md` (Änderungen dieses Plans an Entscheidung 5 und 9: siehe Task 5, letzter Schritt). Baut auf `docs/superpowers/plans/2026-10-21-mini-zirkel.md` auf, das gemergt ist.

## Global Constraints

- App-Code in `apps/ios-member/FitnessMember`, Tests in `apps/ios-member/FitnessMemberTests` (Swift Testing, `@testable import FitnessMember`).
- Testlauf: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40`; einzeln mit `-only-testing:FitnessMemberTests/<Suite>`.
- Texte deutsch, Kommentare deutsch mit dem Warum, ae/oe/ue in Bezeichnern und Kommentaren, Nutzertexte mit Umlauten; Kommentardichte wie die Umgebung.
- Fortschrittsanzeige je Übung: Format **`k/R`** (grün, wenn die Übung in der aktuellen Runde schon dran war), **„Nächste“** bei der Übung, die jetzt kommt, **`k/R`** (neutral) bei den noch offenen, **Häkchen** wenn alle `R` Runden erledigt sind.
- Zeilen im Stil des Katalogs: `UebungsVideoKachel` + Name (wie `ZirkelPlanungSheet.zeile`), keine neue Zeilenoptik erfinden.
- Der Startwerte-Drawer entfällt im Zirkel für jede Übung, deren Werte geplant wurden. Runde 2+ unverändert (Gewicht und Wdh. der Vorrunde, kein Drawer).
- Keine Server-/DB-Änderung, keine Änderung der Sensorerkennung.
- Commit-Nachrichten enden mit der Zeile `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Arbeit auf einem Branch `claude/zirkel-vorab-werte`, nicht auf `master`.

## Review Focus

- Cardio-/Zeit-Übung im Zirkel (kein Wiederholungs-Rad): sie bekommt keinen Werte-Eintrag und fällt auf den bisherigen Weg zurück; nichts wird als Gewicht 0 vorbelegt.
- Planung umsortieren, Übung löschen: Werte wandern mit der Übung; die einer gelöschten Übung bleiben nicht hängen und landen nicht bei einer anderen.
- Zwei Übungen derselben Station (Kurzhantel-Beispiel der Spec): jede hat eigene Werte.
- Drawer in der Planung abbrechen: es kommt keine halbe Übung in die Liste.
- Übersprungene Übung in der Pausenliste: zählt als „dran gewesen“ (Zirkel kennt nur `schritt`); das ist so gewollt, steht im Test.

---

### Task 0: Vorbereitung

**Files:** `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`, `…/Screens/Training/ZirkelUebungswahlSheet.swift`, `FitnessMember.xcodeproj/project.pbxproj`

Im Arbeitsbaum liegt ungesicherte Arbeit (Übungswahl als Sheet statt Dialog), die dieselbe Datei wie Task 5 anfasst.

- [ ] **Step 1:** Branch `claude/zirkel-vorab-werte` anlegen.
- [ ] **Step 2:** Bauen (`xcodebuild … build`), dann die vorhandene Arbeit getrennt committen: `git add apps/ios-member && git commit -m "refactor(ios): Zirkel-Übungswahl als Sheet statt Dialog"`. Schlägt der Build fehl, melden statt reparieren – das ist nicht Teil dieses Plans.

---

### Task 1: Entwurf und Vormerkung tragen Werte für alle Übungen

**Files:**
- Modify: `Workout/Zirkel.swift` (`ZirkelEntwurf`, `ZirkelVormerkung`)
- Test: `FitnessMemberTests/ZirkelPlanungTests.swift`, `FitnessMemberTests/ZirkelTests.swift`

**Interfaces:**
- Produces:
  - `ZirkelEntwurf.werte: [ZirkelUebung: Startwerte]` (`private(set)`, Vorgabe `[:]`)
  - `mutating func setzeWerte(_ werte: Startwerte?, fuer uebung: ZirkelUebung)` – `nil` löscht den Eintrag
  - `mutating func hinzufuegen(_:)` bleibt; `entferne(at:)` löscht zusätzlich die Werte der entfernten Übungen
  - `ZirkelVormerkung.init(_ werte: [ZirkelUebung: Startwerte])`

- [ ] **Step 1: Failing tests** in `ZirkelPlanungTests` (Hilfen `uebung(_:)`, `entwurf(n:)` existieren): `werteBleibenBeiDerUebungWennUmsortiert` (Werte für Übung 1 setzen, `verschiebe(von: 0, nach: 3)`, `werte[uebung(1)]` unverändert), `entfernenLoeschtDieWerteDerUebung` (`entferne(at: 0)` → `werte[uebung(1)] == nil`, Werte von Übung 2 bleiben), `setzeWerteMitNilLoeschtDenEintrag`, `zweiUebungenDerselbenStationHabenEigeneWerte` (`geraet:g1` mit `e1` und `e2`). In `ZirkelTests`: `vormerkungAusMehrerenWertenEntnimmtJedeEinmalInRundeEins` (zwei Einträge; `entnehmen(a, runde: 1)` liefert Werte, zweiter Aufruf `nil`; `entnehmen(b, runde: 2)` liefert `nil`, gemerkter Eintrag ist danach auch weg).
- [ ] **Step 2:** Tests laufen lassen, Erwartung: Kompilierfehler/FAIL (`werte`, `setzeWerte` unbekannt).
- [ ] **Step 3: Implement** die Signaturen oben in `Workout/Zirkel.swift`; `ZirkelVormerkung.init(_ werte:)` neben den vorhandenen Inits. `ZirkelEntwurf` bleibt `Equatable` (Startwerte ist `Hashable`).
- [ ] **Step 4:** `-only-testing:FitnessMemberTests/ZirkelPlanungTests -only-testing:FitnessMemberTests/ZirkelTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Zirkel-Entwurf trägt Startwerte je Übung`.

---

### Task 2: Fortschritt je Übung (`Zirkel.stand(an:)`)

**Files:**
- Modify: `Workout/Zirkel.swift`, `Screens/Zirkel/ZirkelPauseView.swift` (nur `ZirkelPauseText`)
- Test: `FitnessMemberTests/ZirkelTests.swift`, `FitnessMemberTests/ZirkelPauseTextTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum ZirkelStand: Equatable {
      case abgeschlossen              // alle Runden dran gewesen -> Häkchen
      case naechste                   // die Übung, die jetzt kommt
      case dran(Int, von: Int)        // in der laufenden Runde schon dran, grün: "1/3"
      case offen(Int, von: Int)       // noch nicht dran, neutral: "0/3"
  }
  extension Zirkel { func stand(an index: Int) -> ZirkelStand }
  ```
  `ZirkelPauseText.standText(_ stand: ZirkelStand) -> String?` (`"1/3"`, `"Nächste"`, `nil` bei `.abgeschlossen`) und `ZirkelPauseText.standSprache(_ stand: ZirkelStand) -> String` (VoiceOver: `"Abgeschlossen"`, `"Nächste Übung"`, `"1 von 3 Runden gemacht"`).
- Regel: `gemacht(i) = schritt / n + (i < schritt % n ? 1 : 0)`; `gemacht == runden` → `.abgeschlossen`; sonst `i == position` und nicht fertig → `.naechste`; sonst `i < schritt % n` → `.dran(gemacht, von: runden)`; sonst `.offen(gemacht, von: runden)`. Ist der Zirkel fertig, sind alle `.abgeschlossen`.

- [ ] **Step 1: Failing tests** (`ZirkelTests`, Zirkel mit 3 Übungen, 3 Runden): `schritt 0` → `[.naechste, .offen(0,3), .offen(0,3)]`; nach einem `weiter()` → `[.dran(1,3), .naechste, .offen(0,3)]`; Rundenwechsel (`schritt 3`) → `[.naechste, .offen(1,3), .offen(1,3)]`; `schritt 4` (Runde 2, erste Übung gemacht) → `[.dran(2,3), .naechste, .offen(1,3)]`; letzte Runde, `schritt 7` → `[.abgeschlossen, .abgeschlossen, .naechste]`; `istFertig` → drei mal `.abgeschlossen`; `uebersprungenZaehltAlsDran` (erste Übung per `ueberspringen()` → `.dran(1,3)`). In `ZirkelPauseTextTests`: `standText(.dran(1, von: 3)) == "1/3"`, `.offen(0, von: 3) == "0/3"`, `.naechste == "Nächste"`, `.abgeschlossen == nil`; `standSprache` für alle vier.
- [ ] **Step 2:** Läuft rot (Typen fehlen).
- [ ] **Step 3: Implement** `ZirkelStand` + `Zirkel.stand(an:)` in `Workout/Zirkel.swift`, die zwei Text-Funktionen in `ZirkelPauseText`. `ZirkelPauseText.danach(_:)` und seine Tests entfallen (Task 3 ersetzt die Zeile „Danach“); jetzt entfernen, damit nichts totes bleibt.
- [ ] **Step 4:** `-only-testing:FitnessMemberTests/ZirkelTests -only-testing:FitnessMemberTests/ZirkelPauseTextTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Fortschritt je Zirkel-Übung als reine Funktion`.

---

### Task 3: Pausenscreen zeigt die Reihenfolge

**Files:**
- Modify: `Screens/Zirkel/ZirkelPauseView.swift` (`alsNaechstes` ersetzen, neue private `ZirkelReihenfolgeZeile`)

**Interfaces:**
- Consumes: `Zirkel.stand(an:)`, `ZirkelPauseText.standText/standSprache` (Task 2); bestehend `UebungsVideoKachel`, `Uebungsbild`, `letztesMal`, `uebungsname`.
- Produces: keine neue öffentliche Schnittstelle; `ZirkelPauseView.init` bleibt unverändert.

- [ ] **Step 1:** `alsNaechstes(_:danach:)` durch `reihenfolge(_ zirkel: Zirkel)` ersetzen: eine `Card` mit einer Zeile je `zirkel.uebungen` (`ForEach` über `enumerated`), Zeilen wie `ZirkelPlanungSheet.zeile` (Kachel `kante: 56`, Name in `Typography.uebungsname`), rechts der Stand: `.dran` als `standText` in `DesignSystem.Color.success` (falls der Token anders heißt: den grünen Erfolgs-Token aus `DesignSystem.Color` nehmen), `.offen` in `textMuted`, `.naechste` als Plakette „Nächste“ in `accent`, `.abgeschlossen` als `Image(systemName: "checkmark.circle.fill")` in Grün. Die Zeile der nächsten Übung trägt zusätzlich „Letztes Mal …“ (wie bisher) und einen Akzentrand; jede Zeile `accessibilityElement(children: .combine)` mit `standSprache`. `testnotizElement("zirkel.pause.reihenfolge", typ: "Card")` statt `…als-naechstes`.
- [ ] **Step 2:** Die große Videokarte entfällt bewusst (Anti-Ziel „Pausenscreen nicht überladen“): das Video lebt in der Kachel der nächsten Zeile. Nicht größer ziehen als 56.
- [ ] **Step 3:** Bauen, in der Simulator-App einen Zirkel mit 3 Übungen starten und prüfen: nach Satz 1 `1/3` grün, `Nächste`, `0/3`; in der Rundenpause `Nächste` oben und `1/3` darunter; in der letzten Runde Häkchen bei den fertigen; bei 6 Übungen scrollt die Seite, „Zirkel beenden“ bleibt erreichbar. Ergebnis mit Screenshot melden.
- [ ] **Step 4:** Alle Zirkel-Suiten laufen lassen (`ZirkelTests`, `ZirkelAblaufTests`, `ZirkelPauseTextTests`, `ZirkelUebersichtTests`, `ZirkelErweiternTests`) → PASS.
- [ ] **Step 5: Commit** `feat(ios): Zirkel-Pause zeigt Reihenfolge mit Fortschritt`.

---

### Task 4: Drawer als Planungs-Eingabe (Gewicht und Wdh.)

**Files:**
- Modify: `Screens/Geraet/UebungsstartSheet.swift` (`UebungsstartSheet`, `StartwerteSchritt`), `Workout/Uebungsstart.swift` (`UebungsstartAuftrag`)

**Interfaces:**
- Produces:
  - `UebungsstartAuftrag.planung: Bool = false` (Drawer gehört zur Zirkel-Planung)
  - `UebungsstartSheet.init(modell:mitUebersicht:startTitel:mitUmfang:beiStart:beiZirkel:beiSchliessen:)` – neu `startTitel: String = "Übung starten"` und `mitUmfang: Bool = false`, beide mit Vorgabe, bestehende Aufrufer bleiben gültig
  - `StartwerteSchritt` reicht beide an `PrimaryButton(title:)` bzw. `WertZeile(modell:mitUmfang:)` durch; im Planungs-Drawer entfällt der Satz „Mit ‚Übung starten‘ läuft deine Trainingsuhr“ (er stimmt dort nicht).

- [ ] **Step 1:** Parameter wie oben ergänzen; ohne gesetzte Parameter ändert sich nichts (bestehende Tests `UebungsstartTests`/`GeraetModelTests` laufen weiter grün – laufen lassen).
- [ ] **Step 2:** Planungs-Drawer: `startTitel: "Zur Planung"`, `mitUmfang: true`, kein `beiZirkel`. Der Erstkontakt-Pfad (Einweisung, Einstellung) bleibt, damit eine neue Übung ihre Einweisung nicht verliert, wenn der Zirkel später keinen Drawer mehr zeigt.
- [ ] **Step 3:** Bauen. Commit `feat(ios): Drawer kann Wiederholungen und eigenen Knopftitel`.

---

### Task 5: Planung nutzt den Drawer, Start füllt die Vormerkung

**Files:**
- Modify: `Screens/Training/TrainingRootView.swift` (`zirkelPlanen`, `zirkelHinzufuegen`, `zirkelStarten`, Sheet-Verdrahtung), `Screens/Zirkel/ZirkelPlanungSheet.swift`
- Modify: `docs/superpowers/specs/2026-10-21-mini-zirkel-design.md`
- Test: `FitnessMemberTests/ZirkelPlanungTests.swift`

**Interfaces:**
- Consumes: `ZirkelEntwurf.werte/setzeWerte` (Task 1), `UebungsstartAuftrag.planung`, `UebungsstartSheet(startTitel:mitUmfang:)` (Task 4).
- Produces:
  - `ZirkelPlanungSheet` neu: `werteText: (ZirkelUebung) -> String?` und `beiBearbeiten: (ZirkelUebung) -> Void`; Zeile zeigt unter dem Namen `„12,5 kg × 10“` (Fallback „Werte festlegen“ in `textMuted`, falls keine) und ist antippbar.
  - `ZirkelPlanungText.werte(_ werte: Startwerte, einheit: LoadUnit, nebeneinheit: LoadUnit?, art: VolumeKind) -> String` – dünner Aufruf von `Zahlformat.satz(werte.belastung, einheit, neben: werte.nebenbelastung, nebeneinheit, umfang: werte.umfang, art)`.

- [ ] **Step 1: Failing test** `ZirkelPlanungTests.werteTextNenntGewichtUndWiederholungen` (`Startwerte(belastung: 12.5, umfang: 10, nebenbelastung: nil)`, `.kg`, `.reps` → String enthält `"12,5"` und `"10"`; Locale-Format der vorhandenen `ZirkelPauseText.satzwerte`-Tests übernehmen). Rot, dann `ZirkelPlanungText.werte` in `ZirkelPlanungSheet.swift` implementieren, grün.
- [ ] **Step 2: Übung 1:** `zirkelPlanen(_:mit:)` trägt die Drawer-Werte der ersten Übung direkt in den neuen `ZirkelEntwurf` ein (`setzeWerte`), sofern `modell.volumeKind == .reps`; `ZirkelPlanung.startwerte` entfällt, `zirkelStarten` liest nur noch `entwurf.werte`.
- [ ] **Step 3: Hinzufügen:** In `zirkelHinzufuegen`, Fall `.uebung(let uebung)`: Auswahl-Sheet schließen und die Übung **nicht** direkt anhängen, sondern als wartenden `UebungsstartAuftrag(…, zirkel: true, planung: true)` merken; im `onDismiss` des Auswahl-Sheets (Muster wie `zirkelErweiternNachAuswahl`, zwei Sheets in einem Zug verschluckt SwiftUI) den Drawer am **Planungs-Sheet** öffnen (`mitUmfang: true`, `startTitel: "Zur Planung"`). `beiStart(werte)`: `entwurf.hinzufuegen(uebung)` + `setzeWerte` (nur bei `.reps`, sonst ohne Werte). Schließen ohne Start: nichts wird hinzugefügt.
- [ ] **Step 4: Bearbeiten:** Tipp auf eine Zeile → derselbe Drawer, Modell mit `startwerte:` des Eintrags (Vorbelegung über den vorhandenen `GeraetModel.init(startwerte:mitCountdown: false)`), `beiStart` ersetzt die Werte (`setzeWerte`).
- [ ] **Step 5: Start:** `zirkelStarten` baut `zirkelVormerkung = ZirkelVormerkung(planung.entwurf.werte).behalten(nur: planung.entwurf.uebungen)`; der bestehende Zweig `if let werte = zirkelVormerkung.entnehmen(erste, runde: 1)` startet Übung 1 ohne Drawer. Übungen ohne Werte (Cardio) nehmen weiter den Drawer-Weg in `zirkelWeiter`. Die Hinweiszeile unter der Liste ergänzen: „Tippen, um Gewicht und Wiederholungen zu ändern.“
- [ ] **Step 6: Prüfen im Simulator:** Zirkel mit 3 Freihantel-Übungen anlegen (Gewicht/Wdh. je Übung), starten. Erwartung: Übung 1 öffnet ohne Drawer mit den Rädern auf den geplanten Werten; nach Satz und Pause öffnet Übung 2 ebenfalls ohne Drawer; Runde 2 unverändert. Zusätzlich: Übung in der Planung löschen und neu hinzufügen, Zeile umsortieren, Drawer abbrechen, Cardio-Gerät hinzufügen. Screenshots/Beobachtung melden.
- [ ] **Step 7: Spec nachziehen:** In der Spec Entscheidung 9 ändern auf „Gewicht und Wiederholungen je Übung werden beim Anlegen festgelegt (Drawer in der Planung); im Zirkel kein Startwerte-Drawer mehr“ und Entscheidung 5 ergänzen um „Reihenfolge mit Fortschritt statt großer Karte“; die Ziel-Zeile „Das Startwerte-Gewicht wird nur in Runde 1 abgefragt“ entsprechend anpassen.
- [ ] **Step 8:** Gesamte Suite (`xcodebuild … test`) → grün. Commit `feat(ios): Zirkel-Werte beim Anlegen festlegen` und Spec-Änderung im selben Commit.

---

## Offene Annahmen (bitte prüfen)

1. **„Nicht mehr einzeln klicken“** verstehe ich so: Gewicht *und* Wiederholungen sind vorbelegt, der Drawer vor jeder Übung entfällt. Gesichert wird weiterhin mit einem Tipp (oder Sensor), die Räder lassen sich im Satz noch ändern. Sollen Sätze komplett automatisch ohne Tipp gesichert werden, ist das eine andere, größere Änderung.
2. **Eine Wiederholungszahl je Übung** gilt für alle Runden (keine Pyramide).
3. **Erweitern in Runde 1** (`+ Übung zum Zirkel`, „Zirkel mit weiterem Gerät“) behält den bisherigen Drawer; nur die Planung ändert sich.
4. **Pausenliste:** die große Videokarte „Als Nächstes“ entfällt zugunsten der Liste; das Video steht in der Kachel der nächsten Zeile.
5. **Übersprungene Übung** zählt in der Liste als „dran gewesen“, weil der Zirkel nur `schritt` kennt.

## Self-Review

- Spec-Abdeckung (Nachricht vom 23.10.): Werte beim Erstellen → Tasks 1, 4, 5; kein Einzelklicken im Zirkel → Task 5 Step 5; Reihenfolge in der Pause im Katalog-Stil → Task 3; `1/3` grün / `Nächste` / `0/3` / Häkchen → Task 2 (Regel + Tests) und Task 3.
- Typen: `ZirkelStand`, `stand(an:)`, `setzeWerte(_:fuer:)`, `ZirkelVormerkung.init(_:)`, `UebungsstartAuftrag.planung` sind in den nutzenden Tasks gleich benannt.
- Proportion: Code nur dort, wo die Signatur den Rest nicht festlegt.
