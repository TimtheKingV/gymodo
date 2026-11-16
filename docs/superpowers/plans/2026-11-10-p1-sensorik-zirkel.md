# P1 Sensorik: Auto-Start im Zirkel – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Mini-Zirkel gehören Sensor, Zähler und Aufnahme immer der Station, die gerade dran ist; eine Aufnahme ohne Satz bleibt nie offen, und die Satzautomatik startet nicht auf Hantel-Hantieren.

**Architecture:** Zwei Ursachen im App-Code (GeraetModel/TrainingRootView), eine in der Satzautomatik (Package Sensorik). Die App-Fixes sind Sperren an der einen Stelle, an der ein Modell Sensor und Zähler übernimmt (`GeraetModel.mitschnittBeginnen`); der Automatik-Fix ist eine Startregel in `SatzAutomatik.wiederholungen(_:)`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing; `swift test` im Package `apps/ios-member/Packages/Sensorik`, `xcodebuild test` für `FitnessMemberTests`.

**Spec:** `docs/superpowers/plans/2026-11-10-testnotizen-pakete.md`, Abschnitt P1 (im Haupt-Checkout), dazu dieser Befund.

## Befund (systematic-debugging, 10.11.)

Wahrheit aus `workout_sets` (Prod, nur gelesen) in `data/sensoraufnahmen/saetze-2026-11-10.csv`: 12 Kraftsätze + Ruderergometer. Zirkel 1 ist vollständig (Curl, Schulterdrücken, Trizeps je 3), Zirkel 2 endet nach Bankdrücken S1, Rudern S1, Bankdrücken S2 – danach hat Tim den Zirkel verlassen (Testnotiz 18:34 auf „Gerät wählen“, 12 Sätze).

1. **Altes Modell übernimmt Sensor und Zähler.** Alle 10 Aufnahmen nach dem ersten Stationswechsel tragen in `kontext.exerciseName` die Übung der *vorigen* Station (DB-Übung über `setId` weicht ab). Protokoll je Wechsel: `begonnen (neue Übung)` → in derselben Sekunde `abgebrochen` → `begonnen (vorige Übung)`. Ursache: Ein Zirkel-Modell bleibt nach dem Sichern in Phase `.eingabe` (`GeraetModel.swift`, „Im Zirkel bleibt die Phase stehen“). Läuft das `.task` seines GeraetScreens beim Pfadtausch `ZirkelPfad.ausPause` erneut, ruft `geraetGeoeffnet()` → `mitschnittBeginnen()`, das sich `ZaehlerKoordinator.aktivesModell` nimmt und `eingabeBegonnen` mit dem alten Kontext ruft. Danach gehen Automatik-Ereignisse an ein Modell, das sie wegen `zirkelSatzAbgegeben` verwirft: kein automatisches Satzende, Tim musste von Hand sichern. Ein frisch im ViewBuilder gebautes Modell der alten Route (`TrainingRootView.modell(...)`, ohne Cache) kann dasselbe tun – das erklärt `1832-01`/`1832-02` (zweimal „begonnen Bankdrücken“).
2. **22-Minuten-Aufnahme.** Besitzer von `1832-02` war ein Modell, dessen Screen nicht mehr oben lag. `GeraetModel.screenVerlassen()` gibt nur frei, wenn das Modell selbst `aktivesModell` ist; `TrainingRootView.zirkelBeenden()` gibt nur `vorbereitetesModell` frei. Niemand beendete die Aufnahme, bis das Ruderergometer 18:54 eine neue begann. Bewegung darin: 18:35:30–18:39 und 18:47–18:49, sonst Ruhe.
3. **Fehlstarts der Satzautomatik.** Replay der Automatik (Takt je Sekunde, wie live) über die Aufnahmen: In `1823-02` startet sie bei s 0 und würde bei s 18,5 beenden, die echten 10 Curls liegen bei s 40–68; in `1830-03` Start bei s 6,8, Ende bei s 22,6, echte Wiederholungen ab s 21,7. Die Fehlstart-„Wiederholungen“ haben `ausschlag` 0,00 und `sicherheit` 0,10–0,36; echte Wiederholungen derselben Aufnahmen 0,07–0,45 bzw. 0,19–0,86. Nach Fix 1 würde jeder solche Fehlstart einen Fantasiesatz automatisch sichern und den Zirkel weiterrücken – das ist der „Autopilot“.

## Global Constraints

- Nur DEBUG-Pfade ändern sich in der App (`#if DEBUG` um Zähler/Automatik bleibt).
- Sprache in Code-Kommentaren und Tests: Deutsch ohne Umlaute in Bezeichnern, wie im Bestand.
- Keine Änderung an Server, Migrationen oder `workout_sets`.

## Review Focus

- Runde 1 mit Drawer (keine vorbereitete Station): die neue Station muss den Sensor bekommen, auch wenn ihr `.task` vor oder nach dem der alten läuft.
- „Überspringen“ in der Pause: `zirkelAutomatikFreigeben` + neu vorbereiten, die übersprungene Station darf den Sensor nicht behalten.
- Zirkel beenden aus der Pause und vom Geräte-Screen: danach läuft keine Aufnahme mehr.
- Echte kurze Sätze (4 Wiederholungen Trizeps/Schulterdrücken am 10.11.) müssen weiter automatisch starten.
- Einzelübung (kein Zirkel): Verhalten unverändert, insbesondere „Weiterer Satz“ und Rückkehr per Zurück.

---

### Task 1: Erledigte Zirkel-Station nimmt Sensor und Zähler nicht mehr

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (`mitschnittBeginnen`, neue Eigenschaft)
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (Ziel `.geraet`, `zirkelAutomatikVorbereiten`)
- Test: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift` (DEBUG-Extension mit echtem `ZaehlerKoordinator`)

**Interfaces:**
- Produces: `GeraetModel.zirkelSlotAktiv: (() -> Bool)?` – nil außerhalb des Zirkels; TrainingRootView setzt `{ zirkelAblauf.zirkel?.schritt == slot }` für das Modell jeder Zirkel-Route und das vorbereitete Modell.

- [ ] **Step 1: Failing tests**

```swift
@Test func gesicherteZirkelStationNimmtDenZaehlerNichtZurueck() async  // A zirkel (Hook gesetzt), sichert; B automatikVorbereiten(); A.geraetGeoeffnet()
// #expect(zaehler.aktivesModell === B); #expect(spionA.eingaben == 1)  (nur die erste Eingabe von A)
@Test func zirkelStationAusserhalbIhresSlotsBeginntKeinenMitschnitt()  // zirkelSlotAktiv = { false }; geraetGeoeffnet()
// #expect(spion.eingaben == 0); #expect(zaehler.aktivesModell == nil)
@Test func zirkelStationImSlotBeginntWieBisher()  // zirkelSlotAktiv = { true } → eingaben == 1
```

- [ ] **Step 2:** `xcodebuild test … -only-testing:FitnessMemberTests/GeraetModelTests` → die ersten beiden FAIL.
- [ ] **Step 3:** In `mitschnittBeginnen` zusätzlich `guard !zirkelSatzAbgegeben, zirkelSlotAktiv?() ?? true`. In TrainingRootView die Closure im Ziel `.geraet` (Slot aus der Route) und in `zirkelAutomatikVorbereiten` (`zirkel.schritt`) setzen.
- [ ] **Step 4:** Tests grün, ganze `GeraetModelTests` und `ZaehlerKoordinatorTests` grün.
- [ ] **Step 5:** Commit `fix(ios): im Zirkel gehört der Sensor nur der Station, die dran ist`.

### Task 2: Zirkel beenden gibt jeden Besitzer frei

**Files:** Modify `TrainingRootView.swift` (`zirkelBeenden`)

- [ ] **Step 1:** In `zirkelBeenden()` unter `#if DEBUG` `satzZaehler.aktivesModell?.screenVerlassen()` vor dem Freigeben des vorbereiteten Modells (wie `beenden()`).
- [ ] **Step 2:** Build + volle App-Tests. Ein View-Test ist hier nicht möglich (privater SwiftUI-State); die Absicherung liegt in Task 1, dieser Schritt ist die zweite Linie.
- [ ] **Step 3:** Commit `fix(ios): Zirkel beenden schließt eine offene Aufnahme`.

### Task 3: Satzautomatik startet nicht auf ausschlaglose Bewegung

Regel aus dem Replay über alle 185 Aufnahmen mit Korrektur-Eintrag: Starts auf Wiederholungen mit Ausschlag ≤ 0,003 waren ausnahmslos Abbrüche ohne Satz oder lagen 10–40 s vor dem Satz (u. a. 2026-10-08-0837/0846, 2026-11-10-1820/1823/1830); der kleinste Ausschlag eines echten Starts war 0,023. Schwelle `SatzAutomatik.startAusschlag = 0.01`; Wiederholungen darunter werden vor dem Start übergangen, im laufenden Satz zählen sie weiter als Bewegung.

**Files:** Modify `apps/ios-member/Packages/Sensorik/Sources/Sensorik/SatzAutomatik.swift`; Test `Tests/SensorikTests/SatzAutomatikTests.swift`, neuer Replay-Test `Tests/SensorikTests/SatzAutomatikReplayTests.swift`.

- [ ] **Step 1:** Replay-Test über alle Aufnahmen mit Wahrheit: Automatik-Start liegt nicht mehr als 2 s vor der ersten Wiederholung der Satzende-Auswertung; `1823-02` und `1830-03` namentlich.
- [ ] **Step 2:** `swift test --filter SatzAutomatikReplay` → FAIL für 1823-02, 1830-03.
- [ ] **Step 3:** Startregel umsetzen.
- [ ] **Step 4:** Replay- und alle Sensorik-Tests grün; Taktbericht unverändert.
- [ ] **Step 5:** Commit `fix(sensorik): Automatik startet nicht auf Hantieren ohne Ausschlag`.

### Task 4: Daten und README

- [ ] Aufnahmen 10.11., `protokoll-2026-11-10.log`, `saetze-2026-11-10.csv`, `korrekturen.json`, README „Stand 10. November“ committen (`chore(sensorik): Aufnahmen vom 10.11. mit Wahrheit`).
