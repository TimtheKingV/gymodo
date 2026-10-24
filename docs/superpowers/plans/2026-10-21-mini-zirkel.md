# Mini-Zirkel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ein Mini-Zirkel in der iOS-Member-App: Übungen einmal anlegen, danach läuft die App Übung für Übung und Runde für Runde mit kurzen Pausen und Vorschau der nächsten Übung.

**Architecture:** Ein reiner Wertetyp `Zirkel` (Reihenfolge, Runden, Schrittzähler) trägt die ganze Ablauflogik und ist ohne UI testbar. Ein `@Observable` `ZirkelAblauf` an der Wurzel (`TrainingRootView`) hält den laufenden Zirkel und die Pause. Der bestehende Geräte-Screen (`GeraetModel`/`GeraetView`) bleibt eine Übung pro Screen. Im Zirkelmodus meldet er „Satz gesichert" nach oben, statt selbst in Pause oder Abschluss zu gehen. Zwei neue Routen (`zirkelPause`, `zirkelUebersicht`) zeigen Pause und Abschluss. Gespeichert wird wie bisher: ein Block je Übung, ein Satz je Runde.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing (`@Test`, `#expect`), XcodeGen (`project.yml`, `FitnessMember.xcodeproj` ist eingecheckt).

**Spec:** `docs/superpowers/specs/2026-10-21-mini-zirkel-design.md`

## Global Constraints

- App-Code in `apps/ios-member/FitnessMember`, Tests in `apps/ios-member/FitnessMemberTests` (Swift Testing, `@testable import FitnessMember`).
- Neue Dateien: danach `cd apps/ios-member && xcodegen generate` und `FitnessMember.xcodeproj/project.pbxproj` mit committen.
- Testlauf: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40`. Einzeltests mit `-only-testing:FitnessMemberTests/<Suite>`.
- Texte auf Deutsch, Stil und Kommentardichte wie die Umgebung (deutsche Kommentare mit dem Warum, ae/oe/ue in Bezeichnern und Kommentaren). Nutzertexte mit Umlauten.
- Standard „Pause zwischen Übungen": **20 s**. Stufen wie `Einstellungen.resttimerStufen`. Rundenpause-Standard: `Einstellungen.resttimerSekunden()` (Satzpause, 90 s).
- Rundenzahl: **2–6**, Standard **3**. Zirkel hat mindestens 2 Übungen.
- Startwerte-Drawer nur in Runde 1; Runde 2+ zeigt sofort das Wiederholungs-Rad mit dem Gewicht der Vorrunde. Kein Start-Countdown im Zirkel.
- „+ Übung zum Zirkel" nur direkt nach der letzten Zirkel-Übung von Runde 1; „Zirkel mit weiterem Gerät" nur in der Pause nach Satz 1 einer Einzelübung.
- „Übung überspringen" gilt nur für die aktuelle Runde und speichert keinen Satz.
- Keine Server- oder Datenbank-Änderung. Keine Änderung der Sensorerkennung.
- Alle Arbeit auf einem Branch `claude/mini-zirkel`, nicht auf `master`.

## Review Focus

- Zirkel mit nur einer verbliebenen Übung nach „überspringen": läuft weiter, kein Absturz bei Index/Division.
- Erweitern in genau dem Moment, in dem der Pausen-Timer abläuft: neue Übung wird trotzdem nächste Übung, keine doppelte Navigation.
- App in den Hintergrund während der Zirkel-Pause: Timer läuft über `endetAm` weiter, danach landet man bei der richtigen Übung.
- Satz wird abgelehnt (`satzAbgelehnt`, z. B. Ortswechsel): der Zirkel rückt nicht weiter.
- Übung ohne Video: Pausenscreen zeigt Platzhalter, nichts bricht.
- Cardio-Übung im Zirkel (kein Wiederholungs-Rad): rückt nach dem Sichern genauso weiter.
- „Zirkel beenden" mitten in der Runde: bereits gesicherte Sätze bleiben, Übersicht zeigt sie.

---

## Datei-Landkarte

| Datei | Verantwortung |
| --- | --- |
| `Workout/Zirkel.swift` (neu) | `ZirkelUebung`, `Zirkel` (reine Logik), `ZirkelAuswahl` (Übung zu Station auflösen) |
| `Workout/ZirkelAblauf.swift` (neu) | `@Observable ZirkelAblauf`: aktueller Zirkel, laufende Pause, Fortschritt |
| `Einstellungen.swift` | Schlüssel/Vorgabe/Leser für die Zirkel-Pause |
| `Screens/Profil/ProfilRootView.swift` | Picker „Pause zwischen Übungen im Zirkel" |
| `Screens/Geraet/GeraetModel.swift` | Zirkelmodus: Hook nach gesichertem Satz, kein Countdown, Gewicht-Vorbelegung |
| `Screens/Geraet/GeraetView.swift` | `PausenRad`-Knopf „Zirkel mit weiterem Gerät" nach Satz 1 |
| `DesignSystem/Components/PausenRad.swift` | optionaler Zusatzknopf |
| `Navigation/GeraetRoute.swift` | Routen `zirkelPause`, `zirkelUebersicht`; `zirkel`-Flag an `.geraet` |
| `Screens/Training/TrainingRootView.swift` | `ZirkelAblauf` halten, Navigation, Picker-Sheet |
| `Screens/Geraet/UebungsstartSheet.swift` | Knopf „Mini-Zirkel anlegen" im Startwerte-Schritt |
| `Screens/Zirkel/ZirkelPlanungSheet.swift` (neu) | Planungs-Screen (Variante A) |
| `Screens/Zirkel/ZirkelPauseView.swift` (neu) | Pausenscreen mit nächster Übung (Übungs- und Rundenpause) |
| `Screens/Zirkel/ZirkelUebersichtView.swift` (neu) | Übersicht am Ende, „Weiter" |

---

### Task 1: Zirkel-Logik (`Zirkel`)

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Zirkel.swift`
- Test: `apps/ios-member/FitnessMemberTests/ZirkelTests.swift`

**Interfaces:**
- Produces:
  - `struct ZirkelUebung: Hashable, Sendable { let station: String; let exerciseId: String; let token: String? }`
  - `struct Zirkel: Equatable, Sendable` mit `private(set) var uebungen: [ZirkelUebung]`, `var runden: Int`, `var uebungspause: Int`, `var rundenpause: Int`, `private(set) var schritt: Int` (Anzahl erledigter Slots).
  - `init(uebungen: [ZirkelUebung], runden: Int = 3, uebungspause: Int, rundenpause: Int, schritt: Int = 0)`
  - `var runde: Int` (1-basiert), `var position: Int`, `var aktuelle: ZirkelUebung?`, `var naechste: ZirkelUebung?` (nil, wenn fertig), `var istFertig: Bool`
  - `var naechsterSchrittIstRundenwechsel: Bool` (wahr, wenn `schritt > 0 && schritt % uebungen.count == 0 && !istFertig`)
  - `var pausenSekunden: Int` (Rundenpause bei Rundenwechsel, sonst Übungspause)
  - `var kannErweitern: Bool` (wahr genau wenn `runden`-Runde 1 komplett ist: `schritt == uebungen.count`)
  - `mutating func weiter()` (schritt += 1, nur wenn nicht fertig), `mutating func ueberspringen()` (identisch, getrennter Name für Lesbarkeit der Aufrufer)
  - `mutating func erweitern(um: ZirkelUebung) -> Bool` (nur wenn `kannErweitern`)
  - `static func ausEinzelsatz(_ erste: ZirkelUebung, zweite: ZirkelUebung, runden: Int, uebungspause: Int, rundenpause: Int) -> Zirkel` (Zirkel `[erste, zweite]`, `schritt: 1`)
  - `static let rundenBereich = 2...6`, `static let mindestUebungen = 2`

- [ ] **Step 1: Tests schreiben** in `ZirkelTests.swift` (Struct `ZirkelTests`, Hilfsfunktion `zirkel(n:, runden:)` mit Stationen `"geraet:g1"…`):
  - `rundeUndPositionLeitenSichVomSchrittAb`: n=3, schritt 0 → runde 1/position 0; schritt 4 → runde 2/position 1.
  - `nachDerLetztenUebungDerRundeKommtDieRundenpause`: n=3, `weiter()` ×3 → `naechsterSchrittIstRundenwechsel == true`, `pausenSekunden == rundenpause`, `naechste == uebungen[0]`.
  - `zwischenDenUebungenGiltDieKurzePause`: nach `weiter()` ×1 → `pausenSekunden == uebungspause`.
  - `nachDerLetztenRundeIstDerZirkelFertig`: n=2, runden=2, `weiter()` ×4 → `istFertig`, `naechste == nil`; weiteres `weiter()` ändert `schritt` nicht.
  - `erweiternGehtNurNachRunde1`: n=2, schritt 1 → `erweitern` liefert false; schritt 2 → true, `uebungen.count == 3`, `naechste` ist die neue Übung, `runde == 1`.
  - `ausEinzelsatzStehtNachDemErstenSatz`: Ergebnis hat `schritt == 1`, `naechste == zweite`, `runde == 1`.
  - `ueberspringenRueckt`: n=2, `ueberspringen()` → `schritt == 1`.
  - `eineUebungBleibtBedienbar` (Review Focus): n=2, `runden=3`, alle Slots durch `ueberspringen()` außer einem: kein Absturz, `istFertig` erst am Ende.

- [ ] **Step 2: Test laufen lassen**, Erwartung: FAIL („cannot find 'Zirkel' in scope").
  Run: `xcodebuild … test -only-testing:FitnessMemberTests/ZirkelTests`

- [ ] **Step 3: `Zirkel.swift` implementieren** mit den Signaturen oben. `runde = schritt / uebungen.count + 1`, `position = schritt % uebungen.count`; `init` klemmt `runden` auf `rundenBereich` und `schritt` auf `>= 0`. `uebungen.count >= mindestUebungen` wird per `precondition` im `init` verlangt; `ausEinzelsatz` ist der einzige Weg, mit 1 Übung anzufangen, und erzeugt gleich 2.

- [ ] **Step 4: Tests laufen lassen**, Erwartung: PASS.

- [ ] **Step 5: Commit**
  ```bash
  cd apps/ios-member && xcodegen generate
  git add FitnessMember/Workout/Zirkel.swift FitnessMemberTests/ZirkelTests.swift FitnessMember.xcodeproj
  git commit -m "feat(ios): Zirkel-Logik als reiner Wertetyp"
  ```

---

### Task 2: Profil-Einstellung „Pause zwischen Übungen im Zirkel"

**Files:**
- Modify: `apps/ios-member/FitnessMember/Einstellungen.swift` (neben `resttimerSekundenKey`)
- Modify: `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift` (`beimTraining`, nach dem Picker „Pause zwischen Sätzen")
- Test: `apps/ios-member/FitnessMemberTests/EinstellungenTests.swift`

**Interfaces:**
- Produces: `Einstellungen.zirkelPauseSekundenKey = "zirkelPauseSekunden"`, `Einstellungen.zirkelPauseVorgabe = 20`, `Einstellungen.zirkelPauseSekunden(_ defaults: UserDefaults = .standard) -> Int`

- [ ] **Step 1: Tests ergänzen** in `EinstellungenTests`:
  - `dieZirkelPauseHatEinenFestenSchluessel`: `Einstellungen.zirkelPauseSekundenKey == "zirkelPauseSekunden"`.
  - `ohneGesetztenWertGiltDieZirkelVorgabe`: leere Suite → 20.
  - `gesetzterZirkelWertSchlaegtDieVorgabe`: 30 gesetzt → 30.
  - `dieZirkelVorgabeStehtUnterDenStufen`: `Einstellungen.resttimerStufen.contains(Einstellungen.zirkelPauseVorgabe)`.

- [ ] **Step 2: Tests laufen lassen**, Erwartung: FAIL.

- [ ] **Step 3: Implementieren.** Leser wie `resttimerSekunden` (0 = nie gesetzt → Vorgabe). In `ProfilRootView` ein `@AppStorage(Einstellungen.zirkelPauseSekundenKey) private var zirkelPauseSekunden = Einstellungen.zirkelPauseVorgabe` und ein `Picker("Pause zwischen Übungen im Zirkel", …)` über `Einstellungen.resttimerStufen`, mit `.testnotizElement("profil.zirkelpause", typ: "Picker")`.

- [ ] **Step 4: Tests laufen lassen**, Erwartung: PASS.

- [ ] **Step 5: Commit** `feat(ios): Profil-Einstellung Pause zwischen Übungen im Zirkel`

---

### Task 3: Zirkelmodus im `GeraetModel`

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (`uebungStarten(mit:)` ~Z. 268, `satzSichern` Ende ~Z. 876)
- Test: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift` (bestehende Hilfsfunktion `modell(maschine:bootstrap:…)`, ggf. um einen Parameter `zirkelSatzGesichert` erweitern)

**Interfaces:**
- Produces:
  - `var beiZirkelSatzGesichert: (() -> Void)?` an `GeraetModel`. Gesetzt: nach erfolgreich gesichertem Satz wird dieser Hook aufgerufen **statt** `phase = …` zu setzen; `phase` bleibt `.eingabe`.
  - `func uebungStarten(mit startwerte: Startwerte, mitCountdown: Bool = true)`. Mit `false`: Werte setzen wie bisher, aber `phase = .eingabe` und `mitschnittBeginnen()` sofort.
- Consumes: bestehende `satzSichern(problemFlag:problemReason:)`.

- [ ] **Step 1: Tests schreiben** (in `GeraetModelTests`):
  - `imZirkelRuftSichernDenHookStattPauseOderAbschluss`: Hook zählt Aufrufe; nach `satzSichern` → Zähler 1, `phase == .eingabe`.
  - `einAbgelehnterSatzRuftDenHookNicht` (Review Focus): `satzAbgelehnt` gesetzt (laufende Einheit an anderem Ort, vorhandene Testdaten aus `OrtswechselTests` als Vorbild) → Zähler 0.
  - `ohneHookBleibtDasVerhaltenUnveraendert`: wie bisher `.pause` bzw. `.abschluss`.
  - `startOhneCountdownGehtGleichInDieEingabe`: `uebungStarten(mit:, mitCountdown: false)` → `phase == .eingabe`, `belastung` == Startwert.
  - `dasGewichtDerVorrundeIstInRunde2Vorbelegt`: erst Satz mit 14 kg sichern, dann neues Modell derselben Station/Übung ohne Startwerte → `belastung == 14`. **Schlägt das fehl,** liest der Modell-`init` das Gewicht nur aus `bootstrap.lastSets` und nicht aus der laufenden Einheit: dann in `init` zuerst den letzten Satz der laufenden Einheit (`sessions.aktiveSession()?.bloecke`) auswerten.

- [ ] **Step 2: Tests laufen lassen**, Erwartung: FAIL.

- [ ] **Step 3: Implementieren.** Hook am Ende von `satzSichern` vor der `phase`-Zuweisung abfragen; `uebungStarten` auf die neue Signatur umstellen (bestehende Aufrufer bleiben unverändert wegen des Defaults).

- [ ] **Step 4: Tests laufen lassen**, auch `-only-testing:FitnessMemberTests/GeraetModelTests` und `CardioGeraetModelTests` (Cardio rückt im Zirkel genauso weiter: ein Test mit Cardio-Maschine, Hook zählt 1).

- [ ] **Step 5: Commit** `feat(ios): GeraetModel meldet gesicherte Sätze an den Zirkel`

---

### Task 4: `ZirkelAblauf` und Navigation

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/ZirkelAblauf.swift`
- Modify: `apps/ios-member/FitnessMember/Navigation/GeraetRoute.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`ziel(_:)` ~Z. 570, `modell(station:…)` ~Z. 620, `uebungStarten(_:mit:)` ~Z. 850, `oeffne(_ block:)`)
- Test: `apps/ios-member/FitnessMemberTests/ZirkelAblaufTests.swift`

**Interfaces:**
- Produces:
  - `@MainActor @Observable final class ZirkelAblauf` mit `private(set) var zirkel: Zirkel?`, `private(set) var pause: Resttimer?`
  - `func starten(_ zirkel: Zirkel)`, `func satzGesichert(jetzt: Date = Date())` (ruft `zirkel.weiter()`, setzt `pause = Resttimer(start: jetzt, dauer: TimeInterval(zirkel.pausenSekunden))`, außer fertig → `pause = nil`), `func ueberspringen(jetzt:)`, `func pauseVerlaengern()` (ruft `Resttimer.verlaengert()`), `func erweitern(um: ZirkelUebung) -> Bool`, `func beenden()` (setzt beides auf nil)
  - Route: `GeraetRoute.geraet(station:exerciseId:token:start:zirkel: Bool = false)`, `case zirkelPause`, `case zirkelUebersicht`
- Consumes: `Zirkel` (Task 1), `GeraetModel.beiZirkelSatzGesichert`, `uebungStarten(mit:mitCountdown:)` (Task 3).

- [ ] **Step 1: Tests** (`ZirkelAblaufTests`):
  - `einGesicherterSatzStartetDieUebungspause`: Zirkel n=3 → `pause.gesamtdauer == 20`.
  - `nachDerRundeStartetDieRundenpause`: nach 3 Sätzen → `gesamtdauer == rundenpause`.
  - `nachDemLetztenSatzGibtEsKeinePause`: `pause == nil`, `zirkel.istFertig`.
  - `verlaengernWirktNurAufDieLaufendePause`.
  - `beendenRaeumtAuf`.

- [ ] **Step 2: FAIL sehen.** **Step 3: `ZirkelAblauf` implementieren** (reine Logik, Zeit über Parameter `jetzt`).

- [ ] **Step 4: Navigation in `TrainingRootView`.**
  - `@State private var zirkelAblauf = ZirkelAblauf()`; in `ziel(_:)` die neuen Routen (Views kommen in Task 5 und 8; bis dahin `Text`-Platzhalter, die dort ersetzt werden).
  - `modell(station:exerciseId:token:startwerte:zirkel:)`: bei `zirkel == true` den Hook setzen: `modell.beiZirkelSatzGesichert = { zirkelAblauf.satzGesichert(); pfad.append(zirkelAblauf.zirkel?.istFertig == true ? .zirkelUebersicht : .zirkelPause) }`.
  - `uebungStarten(_ auftrag:, mit:)`: Auftrag trägt `zirkel: Bool` (neues Feld in `UebungsstartAuftrag`, Standard false); bei true `.geraet(…, start: werte, zirkel: true)` und `GeraetModel.uebungStarten(mit:, mitCountdown: false)` über einen neuen Routen-Parameter bzw. daran erkennen, dass `zirkel == true`.
  - Beim Wechsel zur nächsten Zirkel-Übung: `pfad.removeLast(2)` (Pause und Geräte-Screen), dann `.geraet(…, zirkel: true)` anhängen; in Runde 1 vorher den Drawer (`UebungsstartSheet`, `mitUebersicht: false`) für die Übung öffnen, in Runde 2+ direkt anhängen ohne `start`.

- [ ] **Step 5: Tests (Unit)** laufen lassen; App bauen: `xcodebuild … build`.

- [ ] **Step 6: Commit** `feat(ios): ZirkelAblauf und Navigation zwischen Zirkel-Übungen`

---

### Task 5: Pausenscreen mit nächster Übung (`ZirkelPauseView`)

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zirkel/ZirkelPauseView.swift`
- Test: `apps/ios-member/FitnessMemberTests/ZirkelPauseTextTests.swift` (reine Textfunktionen)

**Interfaces:**
- Produces: `struct ZirkelPauseView: View` mit `ablauf: ZirkelAblauf`, `uebungsname: (ZirkelUebung) -> String`, `beiStarten: () -> Void`, `beiErweitern: (() -> Void)?`, `beiBeenden: () -> Void`
- Produces: `enum ZirkelPauseText { static func kopf(runde: Int, runden: Int, rundenwechsel: Bool) -> String; static func startTitel(uebungsname: String) -> String }`: „Runde 1 von 3" / „Runde 1 von 3 · Rundenpause"; „\(name) starten".
- Consumes: `UebungsVideoKachel(exerciseId:hoehe:platzhalter:)` aus `Schleifenvideo.swift` (Video-Thumbnail mit Platzhalter), `Zeitring` (aus `PausenRad.swift`) mit kleinerer Größe.

- [ ] **Step 1: Tests** für `ZirkelPauseText` (beide Kopf-Varianten, Titel).
- [ ] **Step 2: FAIL sehen.**
- [ ] **Step 3: View bauen** nach Mockup 3: kleinere Uhr (`Zeitring` in verkleinerter Variante, `Zeitring` ggf. um `kante`-Parameter erweitern), darunter eine Karte „ALS NÄCHSTES" mit `UebungsVideoKachel(exerciseId: …, hoehe: 160, ersatz: nil)`, Name und Zeile „Letztes Mal …" (`GeraetModel.letzterSatzText` bzw. gleiche Quelle wie die Startwerte), „Danach: …" falls vorhanden. Knöpfe: `PrimaryButton("<Name> starten")`, `SecondaryButton("+30 s")`, optional `SecondaryButton("+ Übung zum Zirkel")` (nur wenn `beiErweitern != nil`), `SecondaryButton("Überspringen")`, Textlink „Zirkel beenden". Rundenpause zeigt zusätzlich die Zusammenfassung der Runde (je Übung „Name Gewicht × Wdh", aus den Blöcken der laufenden Einheit, `sessions.aktiveSession()?.bloecke`). Das Ende des Timers ruft `beiStarten` wie `GeraetView` es mit `.task(id: endetAm)` für die Pause macht.
- [ ] **Step 4: Tests PASS, App bauen**, in Simulator durchspielen: Zirkel mit zwei Übungen, Pause erscheint, Thumbnail sichtbar, ohne Video Platzhalter.
- [ ] **Step 5: Commit** `feat(ios): Zirkel-Pausenscreen mit nächster Übung`

---

### Task 6: Zirkel anlegen (Planungs-Screen und Einstieg)

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zirkel/ZirkelPlanungSheet.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/UebungsstartSheet.swift` (Startwerte-Schritt)
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (Sheet für die Planung und das Picker-Sheet)
- Modify: `apps/ios-member/FitnessMember/Workout/Zirkel.swift` (`ZirkelAuswahl`)
- Test: `apps/ios-member/FitnessMemberTests/ZirkelPlanungTests.swift`

**Interfaces:**
- Produces:
  - `struct ZirkelEntwurf: Equatable { var uebungen: [ZirkelUebung]; var runden: Int = 3; var uebungspause: Int; var rundenpause: Int; mutating func verschiebe(von: IndexSet, nach: Int); mutating func entferne(at: IndexSet); var istGueltig: Bool }`, `istGueltig` ⇔ `uebungen.count >= Zirkel.mindestUebungen && Zirkel.rundenBereich.contains(runden)`; `func zirkel() -> Zirkel`. Standardwerte aus `Einstellungen.zirkelPauseSekunden()` und `Einstellungen.resttimerSekunden()`.
  - `enum ZirkelAuswahl { static func uebung(station: Station, uebungId: String?, bootstrap: BootstrapResponse) -> ZirkelUebung? }`: nimmt `uebungId`, sonst `GeraetEinstiegRechner.letzteUebung(station:in:)`, sonst `station.exercises.first`.
  - View: `ZirkelPlanungSheet(entwurf: Binding<ZirkelEntwurf>, name: (ZirkelUebung) -> String, beiHinzufuegen: () -> Void, beiStart: () -> Void)` mit Liste (`.onMove`, `.onDelete`), „+ Übung hinzufügen", Stepper für Runden, zwei Picker für Pausen (Stufen `Einstellungen.resttimerStufen`), „Zirkel starten" (deaktiviert bei `!istGueltig`).

- [ ] **Step 1: Tests** (`ZirkelPlanungTests`): Entwurf mit 1 Übung ist ungültig, mit 2 gültig; `runden` 1 und 7 sind ungültig; `verschiebe` ändert die Reihenfolge; Standardpausen kommen aus den Einstellungen (Suite mit gesetzten Werten); `ZirkelAuswahl.uebung` nimmt die übergebene Übung, sonst die zuletzt genutzte, sonst die erste.
- [ ] **Step 2: FAIL sehen. Step 3: implementieren.**
- [ ] **Step 4: Einstieg.** In `UebungsstartSheet` im Startwerte-Schritt unter „Übung starten" ein `SecondaryButton("Mini-Zirkel anlegen")`; neuer Callback `beiZirkel: ((Startwerte) -> Void)?`. `TrainingRootView` öffnet darauf `ZirkelPlanungSheet` mit der gewählten Übung vorbelegt und merkt sich deren `Startwerte` (sie gelten für Übung 1). „+ Übung hinzufügen" öffnet ein Sheet mit eigenem `NavigationStack`, das `GeraeteAuswahlView` verwendet (gleiche Initialisierung wie in `wurzel(mitte:session:)`, `beiAuswahl` ruft `ZirkelAuswahl.uebung`, schließt das Sheet und hängt an den Entwurf an; `.navigationDestination(for: GeraetRoute.self)` dort bedient nur `.kategorie`). „Zirkel starten": `zirkelAblauf.starten(entwurf.zirkel())`, `uebungStarten(auftrag, mit: startwerte)` mit `zirkel: true`.
- [ ] **Step 5: Tests PASS, im Simulator durchspielen:** Gerät wählen → Drawer → „Mini-Zirkel anlegen" → drei Übungen → starten → Übung 1 → Satz sichern → Pause mit Übung 2.
- [ ] **Step 6: Commit** `feat(ios): Mini-Zirkel anlegen`

---

### Task 7: Zirkel nachträglich erweitern

**Files:**
- Modify: `apps/ios-member/FitnessMember/DesignSystem/Components/PausenRad.swift` (optionaler Zusatzknopf)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`inhalt`, ~Z. 191; `GeraetScreen`, ~Z. 505)
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`
- Test: `apps/ios-member/FitnessMemberTests/ZirkelErweiternTests.swift`

**Interfaces:**
- Produces: `PausenRad(…, beiZirkel: (() -> Void)? = nil)`: zeigt bei gesetztem Callback `SecondaryButton("Zirkel mit weiterem Gerät")`.
- Produces: `GeraetModel.kannZirkelBeginnen: Bool` ⇔ `zirkelModus == false && satzNummer == 2 && volumeKind == .reps && laufendePause != nil`.
- Consumes: `Zirkel.ausEinzelsatz`, `ZirkelAblauf.erweitern(um:)`, Picker-Sheet aus Task 6.

- [ ] **Step 1: Tests:** `kannZirkelBeginnen` wahr nach genau einem gesicherten Satz in der Pause, falsch nach zwei Sätzen, falsch im Zirkelmodus, falsch ohne Pause; `ZirkelAblauf.erweitern` in der Pause nach der letzten Übung von Runde 1 hängt an und `naechste` ist die neue Übung; nach Runde 1 liefert es false (Review Focus: nicht doppelt navigieren, wenn die Pause währenddessen abläuft: `erweitern` ändert `pause` nicht).
- [ ] **Step 2: FAIL sehen. Step 3: implementieren.**
  - Einzelübung: Knopf öffnet das Picker-Sheet; nach Wahl Startwerte-Drawer der neuen Übung (Runde 1, mit Startwerte), danach `Zirkel.ausEinzelsatz(erste: aktuelle, zweite: neue, runden: 3, …)`, `ZirkelAblauf.starten`, Pause läuft weiter; Weiter in den Zirkel-Pfad über Task 4 (`zirkel: true` für die neue Übung).
  - Im Zirkel: `ZirkelPauseView.beiErweitern` nur gesetzt, wenn `zirkel.kannErweitern`.
- [ ] **Step 4: Tests PASS, im Simulator:** Einzelübung, Satz 1, Pause, „Zirkel mit weiterem Gerät"; im Zirkel nach der letzten Übung von Runde 1 „+ Übung zum Zirkel".
- [ ] **Step 5: Commit** `feat(ios): Zirkel nachträglich erweitern`

---

### Task 8: Abschluss-Übersicht, Überspringen, Beenden

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Zirkel/ZirkelUebersichtView.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift`
- Test: `apps/ios-member/FitnessMemberTests/ZirkelUebersichtTests.swift`

**Interfaces:**
- Produces: `struct ZirkelZeile: Equatable { let uebungsname: String; let saetze: [String] }` und `enum ZirkelUebersicht { static func zeilen(zirkel: Zirkel, bloecke: [LokalerBlock], name: (ZirkelUebung) -> String) -> [ZirkelZeile] }`; jede Zeile: ein Text je gesichertem Satz („14 kg × 10"), übersprungene Runden fehlen einfach.
- View: `ZirkelUebersichtView(zeilen: [ZirkelZeile], beiWeiter: () -> Void)`; `beiWeiter` ruft `zirkelAblauf.beenden()` und `pfad.removeAll()`.

- [ ] **Step 1: Tests:** drei Übungen × zwei Runden → drei Zeilen mit je zwei Texten; eine übersprungene Übung → Zeile mit einem Text; Zirkel ohne Sätze → Zeilen mit leerer Liste (kein Absturz).
- [ ] **Step 2: FAIL sehen. Step 3: implementieren.** Texte mit `Zahlformat.gewicht`. „Überspringen" in `ZirkelPauseView` ruft `ablauf.ueberspringen()` und die Navigation wie nach dem Pausenende. „Zirkel beenden" (Textlink) ruft `zirkelAblauf.beenden()` und öffnet `.zirkelUebersicht` mit dem bisherigen Stand; die Zeilen kommen dafür aus den Blöcken der Einheit, nicht aus dem Zirkel-Schrittzähler.
- [ ] **Step 4: Tests PASS.** 
- [ ] **Step 5: Commit** `feat(ios): Zirkel-Übersicht, Überspringen und Beenden`

---

### Task 9: Gesamtprüfung

- [ ] **Step 1:** Vollständiger Testlauf: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test 2>&1 | tail -40`. Erwartung: alle Tests grün.
- [ ] **Step 2:** Im Simulator einen echten Durchlauf: Zirkel mit Bizeps-Curls, Seitheben, Schrägbankdrücken, 3 Runden. Prüfen: Drawer nur in Runde 1, Pause 20 s mit Thumbnail der nächsten Übung, Rundenpause mit Zusammenfassung, Wdh.-Rad sofort in Runde 2 mit Gewicht der Vorrunde, Abschluss-Übersicht, „Weiter" führt zur Wurzel. Dazu je einmal: Profil-Pause ändern, „+ Übung zum Zirkel" in Runde 1, „Zirkel mit weiterem Gerät" nach Satz 1, Überspringen, Zirkel beenden.
- [ ] **Step 3:** Mit `superpowers:verification-before-completion` Ergebnisse festhalten; PR gegen `master` nur auf Tims Freigabe.

---

## Selbstprüfung

- **Spec-Abdeckung:** Auswahl nach Geräte-Wahl (Task 6), Planungs-Screen A mit beiden Pausen und Rundenzahl (6), Profil-Einstellung (2), Pausenscreen mit Thumbnail (5), Rundenpause mit Zusammenfassung und Thumbnail (5), Abschluss-Übersicht (8), Eintragen nach jeder Übung und Startwerte-Drawer nur in Runde 1 (3, 4), Erweitern in Runde 1 und nach Satz 1 (7), Überspringen/Beenden (8), kein Countdown (3).
- **Typkonsistenz:** `Zirkel`, `ZirkelUebung`, `ZirkelAblauf`, `ZirkelEntwurf`, `ZirkelAuswahl` heißen überall gleich; `uebungStarten(mit:mitCountdown:)` und `beiZirkelSatzGesichert` stammen aus Task 3 und werden in 4, 6, 7 verwendet.
- **Offene Punkte für den Umsetzer:** App-Neustart mitten im Zirkel (in-memory, geht verloren; der Geräte-Screen bleibt ein normaler), Platzhalterbild bei fehlendem Video (vorhandenes `UebungsVideoKachel`-Platzhalter-Muster), Inhalt der Rundenzusammenfassung (Gewicht × Wdh. je Übung).
