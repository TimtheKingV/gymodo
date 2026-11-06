# UX-Vereinheitlichung Paket 3 – Gerät mit Tracker – Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Tracker wird einmal im Profil eingerichtet; im Training bleibt davon nur ein kleines Symbol in der Kopfzeile (grün/grau) mit einem Blatt für Status und Automatik-Schalter. Automatik aus heißt: der Tracker zählt nicht ins Rad und sichert nichts. Die große Sensor-Karte, Zählerzeile, Satz-Marken und das Befestigungsmenü verschwinden aus dem Training.

**Architecture:** Reine Anzeige-Logik (`TrackerAnzeige`) für Symbol und Statustext; `SatzZaehler` meldet, ob die Automatik an ist, und `GeraetModel` speist das Rad nur dann. Die Einrichtung (Verbinden, Auswahl bei mehreren Trackern, Vergessen, Entwickler-Diagnose) zieht ins Profil. Alles bleibt hinter dem bestehenden DEBUG-Tor (`Funktionen.sensorKarte`, Sensor-Unterbau `#if DEBUG`).

**Tech Stack:** SwiftUI, Swift Testing, xcodegen, Paket `Sensorik` (unverändert).

**Spec:** `docs/superpowers/specs/2026-11-05-ux-vereinheitlichung-design.md` §3.1–3.3. Faktenblatt zum Code (Stand 6661ff69): `.superpowers/paket3-fakten.md` im Worktree.

## Global Constraints

- Ohne gemerkten Tracker erscheint im Training nichts zum Tracker (kein Symbol, keine Zeile, keine Karte).
- Symbol: grün = verbunden (`DesignSystem.Color.accent`), grau = alles andere (`DesignSystem.Color.textFaint`). Kein Rot, auch nicht bei Akku ≤ 15 % oder Bluetooth aus.
- Tracker-Blatt im Training: Verbindungsstatus und `Toggle("Sätze automatisch starten und sichern")`. Sonst nichts.
- Entfällt im Training: „zählt · n“, „Satz Start“/„Satz Ende“, „Zahl prüfen“ in der Sensorzeile (bleibt am Rad, `WertZeile`), Befestigungsmenü, Sensor-Einstellungen/-Diagnose, die `SensorKarte` auf der Training-Tab-Wurzel.
- Bleibt: „Sichern nach Ruhe · n s“ (Text aus `SatzAutomatik.speichernIn`).
- Automatik aus: kein Auto-Start, kein Auto-Sichern, kein Rad-Feed, keine Zähler-Haptik; Satz wird wie ohne Tracker von Hand gesichert; Sensordaten werden weiter lokal aufgezeichnet.
- Kein Redesign; nur `DesignSystem`-Tokens. Testnotiz-IDs erhalten, wo ein Bedienelement weiterlebt.
- Tests: `cd apps/ios-member && xcodebuild -scheme FitnessMember -destination "platform=iOS Simulator,name=iPhone 17 Pro" test -only-testing:FitnessMemberTests/<Suite> 2>&1 | tail -20`, Zeile „Test run with N tests“ prüfen. Paket: `swift test --package-path apps/ios-member/Packages/Sensorik`. Nach neuen/gelöschten Dateien `xcodegen generate`, `project.pbxproj` mitcommitten.
- Commits deutsch (`feat(ios): …`), Ende `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Entscheidungen dieses Plans

- **F1 DEBUG bleibt:** Paket 3 schaltet den Tracker nicht für Release frei. `Funktionen.sensorKarte` bleibt das Tor; die Freischaltung (Hintergrundmodus, `Befestigungsart.freigegeben`) ist ein eigenes Vorhaben.
- **F2 Automatik aus = Satz „eingegeben“:** Der Server-Satz geht als `volumeSource: .eingegeben` ohne `volumeCounted`/`repEvents` (sonst verletzt er `herkunftPruefen`); das Zählergebnis geht trotzdem in die lokale Aufnahme (`GesicherterSatz.zaehler`).
- **F3 Befestigung bleibt aus dem Gerätenamen** (`Befestigungsart.vorschlag`, Paket unverändert); gespeicherte Wahlen bleiben gültig. Liefert der Vorschlag nichts, zählt der Tracker still nicht und es wird einmal je Station+Übung protokolliert.
- **F4 Einrichtung im Profil:** Zeile „Tracker“ im Abschnitt „Beim Training“ → `TrackerEinrichtungView` mit Verbinden, Auswahl bei mehreren Funden, „Tracker vergessen“, Automatik-Schalter, Bluetooth-verweigert → Einstellungen. Die bisherige Diagnose (Rate, 5-Minuten-Test, Freitext-Befestigung) steht dort in einem Abschnitt „Für Entwickler“ – raus aus dem Training, aber für die Erkennungsarbeit noch da.
- **F5 „Sichern nach Ruhe · n s“** steht am Gerät als kleine Zeile direkt unter der Kopfzeile, nur bei Automatik an und laufendem Satz. Die übrigen Automatik-Texte („Automatik bereit …“ usw.) entfallen.
- **F6 3.3 ist erledigt:** Das Vorschaubild links neben dem Namen und der Tipp zur Einweisung mit Video gibt es seit 11.10.; keine Änderung.
- **F7 Blatt bei nicht verbundenem Tracker:** Statustext („Nicht verbunden · wird gesucht“ usw.) und der Hinweis „Einrichtung im Profil“; kein Verbinden-Knopf im Training.

## Review Focus

1. **Tracker gemerkt, aber außer Reichweite:** Symbol grau, Blatt „Wird gesucht …“, kein Fehler, kein Rot; Training läuft ohne Tracker normal. → Test in Task 1.
2. **Automatik während eines laufenden Satzes ausschalten:** Rad bleibt beim aktuellen Wert, der Satz wird nicht automatisch gesichert, „Sichern nach Ruhe“ verschwindet. → Test in Task 2.
3. **Tracker im Profil vergessen, während ein Training läuft:** Symbol verschwindet sofort aus der Kopfzeile (beobachtbarer Zustand). → Test in Task 1.
4. **Mehrere Tracker in Reichweite:** Auswahl nur im Profil möglich; im Training kein Auswahlblatt. → Test in Task 4 (Anzeige-Logik).
5. **Cardio-Gerät mit Wiederholungs-Übung** (kein Vorschlag): zählt still nicht, genau ein Protokolleintrag je Station+Übung. → Test in Task 3.

---

### Task 1: Beobachtbarer gemerkter Tracker und Tracker-Anzeige

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/Sensor/BluetoothSensorQuelle.swift` (`gemerkt`/`hatGemerktenSensor` ~:116-120)
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/TrackerAnzeige.swift` (`#if DEBUG` wie die übrigen Sensor-Dateien)
- Test: Create `apps/ios-member/FitnessMemberTests/TrackerAnzeigeTests.swift` (DEBUG); `SensorAufnahmeKoordinatorTests.swift` (AttrappenQuelle bleibt)

**Interfaces:**
- `BluetoothSensorQuelle`: `private(set) var gemerkt: UUID?` als gespeicherte, beobachtete Property (aus UserDefaults im `init` geladen, in `waehlen`/`vergessen` gesetzt); `hatGemerktenSensor` liest sie.
- Produces:
  ```swift
  enum TrackerAnzeige {
      enum Symbol: Equatable { case verbunden, nichtVerbunden }
      static func symbol(_ zustand: SensorZustand) -> Symbol
      /// "Verbunden · Akku 80 %", "Wird gesucht …", "Verbindet …", "Getrennt · wird neu verbunden …",
      /// "Bluetooth ist aus", "Bluetooth nicht erlaubt", "Mehrere Tracker gefunden", "Nicht verbunden"
      static func status(_ zustand: SensorZustand) -> String
      /// Im Training sichtbar? Nur mit gemerktem Tracker.
      static func sichtbar(hatGemerktenSensor: Bool) -> Bool
  }
  ```
  Name des Trackers über `SensorName.anzeige` dort, wo ein Name erscheint (Profil).
- [ ] **Step 1: Failing tests:** `verbundenIstGruen` (`.verbunden(name: "WT901BLE", akkuProzent: 80)` → `.verbunden`, Status „Verbunden · Akku 80 %“); `akkuNiedrigBleibtGruen` (Akku 10 → `.verbunden`); `suchtIstGrau` (Review Focus 1: `.sucht` → `.nichtVerbunden`, „Wird gesucht …“); `bluetoothAusIstGrau` (`.bluetoothNichtBereit(.ausgeschaltet)` → grau, „Bluetooth ist aus“); `ohneGemerktenUnsichtbar`; `vergessenSchaltetSofortUm` (Review Focus 3: Quelle mit gemerktem Sensor, `vergessen()` → `hatGemerktenSensor == false` ohne neuen Defaults-Lesezugriff; UserDefaults-Suite im Test). Die Fälle aus `SensorKarteAnzeigeTests` (`verbundenZeigtNameUndAkku`, `nurDerBausteinnameWirdUmbenannt`, `nichtVerbundenUndFehler`) ziehen hierher um (Texte an die neuen Statustexte angepasst, `SensorName`-Fall unverändert).
- [ ] **Step 2:** `xcodegen generate`; `-only-testing:FitnessMemberTests/TrackerAnzeigeTests` → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** `TrackerAnzeigeTests`, `SensorAufnahmeKoordinatorTests`, `SensorZeileTextTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Tracker-Anzeige grün/grau und gemerkter Tracker beobachtbar`

---

### Task 2: Automatik aus heißt: nicht zählen, nicht sichern

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/SatzZaehler.swift` (`protocol SatzZaehler`)
- Modify: `apps/ios-member/FitnessMember/Workout/Sensor/ZaehlerKoordinator.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (`zaehlerMeldung` ~:1433, `satzLokalSichern` ~:1216-1313, `herkunft` ~:1462)
- Test: `GeraetModelTests.swift` (`ZaehlerDouble` ~:2427), `ZaehlerKoordinatorTests.swift`

**Interfaces:**
- `protocol SatzZaehler` bekommt `var automatikAktiv: Bool { get }`; `ZaehlerKoordinator` erfüllt es schon; `ZaehlerDouble` bekommt `var automatikAktiv = true`.
- `GeraetModel.zaehlerMeldung`: bei `zaehler?.automatikAktiv == false` kein `umfang`-Setzen und kein `zaehlerZustand`-Wechsel (bleibt `.aus`) → keine Haptik, kein „Zahl prüfen“ am Rad.
- `satzLokalSichern`: bei Automatik aus kein Überschreiben von `umfang` mit `ergebnis.gezaehlt`; Server-Body `volumeSource = .eingegeben`, `volumeCounted = nil`, `repEvents = nil` (F2); `mitschnitt?.satzGesichert(GesicherterSatz(..., zaehler: ergebnis, ...))` bekommt das Ergebnis weiter.
- Umschalten während eines Satzes: `automatikUmschalten(aktiv: false)` setzt `zaehlerZustand = .aus`, der Rad-Wert bleibt.
- [ ] **Step 1: Failing tests** (GeraetModelTests):
  - `automatikAusDrehtDasRadNicht`: Double `automatikAktiv = false`, `melde?(.stand(7))` → `umfang` unverändert, `zaehlerZustand == .aus`.
  - `automatikAusSichertAlsEingegeben`: Rad 10, Zähler-Ergebnis 8 → Body `volumeSource == .eingegeben`, `volume == 10`, `volumeCounted == nil`, `repEvents == nil`; Mitschnitt-Double erhielt `zaehler?.gezaehlt == 8`.
  - `automatikAusschaltenImSatz` (Review Focus 2): erst `.stand(5)` bei an → `umfang == 5`; Umschalten auf aus → `zaehlerZustand == .aus`, `umfang == 5`, folgendes `.stand(6)` ändert nichts.
  - Bestehende Rad-Feed-Tests (:2149-2325) laufen mit `automatikAktiv = true` unverändert grün.
- [ ] **Step 2:** Tests → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** `GeraetModelTests`, `ZaehlerKoordinatorTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Automatik aus – Tracker zählt nicht ins Rad und sichert nichts`

---

### Task 3: Befestigung nur noch aus der Übung, ohne Menü

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/Sensor/ZaehlerKoordinator.swift` (`neuStarten` ~:241-263)
- Modify: `apps/ios-member/FitnessMemberApp.swift` (Verdrahtung des Protokoll-Hooks, `#if DEBUG`)
- Test: `ZaehlerKoordinatorTests.swift`

**Interfaces:**
- `ZaehlerKoordinator.beiKeinerBefestigung: ((SatzZaehlerKontext) -> Void)?` – wird in `neuStarten` beim `.keineBefestigung`-Zweig aufgerufen, höchstens einmal je `station.schluessel + exerciseId` und App-Lauf.
- `FitnessMemberApp` verdrahtet ihn mit `SensorAufnahmeKoordinator`-Protokoll: Zeile „Keine Befestigung: <Gerätename> / <exerciseId>“ (Methode am Koordinator, z. B. `func protokollieren(_ text: String)`, die in `SensorProtokoll` schreibt).
- `befestigungWaehlen(_:)` bleibt als interne API (von ~15 Tests als Setup genutzt), hat aber keinen UI-Aufrufer mehr (Menü fällt in Task 5).
- [ ] **Step 1: Failing tests:** `ohneVorschlagWirdEinmalProtokolliert` (Review Focus 5: Cardio-Kontext mit reps zweimal `satzBeginnt` → Hook genau 1× mit dieser Station/Übung, Meldung `.zaehltNicht(.keineBefestigung)`); `gespeicherteWahlGiltWeiter` (gemerkte `.kurzhantel` für Station+Übung → `befestigung == .gewaehlt(.kurzhantel)` auch ohne Menü).
- [ ] **Step 2:** Tests → FAIL.
- [ ] **Step 3:** Implementieren.
- [ ] **Step 4:** `ZaehlerKoordinatorTests`, `BefestigungsspeicherTests`, `SensorAufnahmeKoordinatorTests` → PASS.
- [ ] **Step 5: Commit** `feat(ios): Befestigung kommt aus der Übung, fehlender Vorschlag wird protokolliert`

---

### Task 4: Tracker-Einrichtung im Profil

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Profil/TrackerEinrichtungView.swift` (`#if DEBUG`)
- Modify: `apps/ios-member/FitnessMember/Screens/Profil/ProfilRootView.swift` (Abschnitt `beimTraining` ~:279-305)
- Modify: `apps/ios-member/FitnessMember/Profil/ProfilZeilen.swift`
- Move: Inhalt von `Screens/Geraet/SensorDiagnoseBlatt.swift` in den Abschnitt „Für Entwickler“ der Einrichtung (Datei danach löschen)
- Test: `ProfilZeilenTests.swift`, `TrackerAnzeigeTests.swift`

**Interfaces:**
- Consumes: `TrackerAnzeige` (Task 1), `ZaehlerKoordinator.automatikAktiv`, `SensorQuelle.verbinden/waehlen/trennen/vergessen`.
- Produces:
  - `ProfilZeilen.trackerWert(hatGemerktenSensor: Bool, zustand: SensorZustand) -> String`: „Nicht eingerichtet“ ohne gemerkten, sonst `TrackerAnzeige.status` in Kurzform („Verbunden“, „Nicht verbunden“).
  - `TrackerAnzeige.einrichtungsAktion(_ zustand: SensorZustand, hatGemerktenSensor: Bool) -> Aktion` mit `enum Aktion { case verbinden, auswaehlen([SensorFund]), einstellungenOeffnen, keine }` (Review Focus 4: `.mehrereGefunden(f)` → `.auswaehlen(f)`).
  - `TrackerEinrichtungView`: Status mit Name (`SensorName.anzeige`) und Akku; Knopf je `einrichtungsAktion` („Tracker verbinden“, Auswahlliste „Tracker wählen“, „In Einstellungen erlauben“); `Toggle("Sätze automatisch starten und sichern")`; „Tracker vergessen“ (destructive, mit Bestätigung); Abschnitt „Für Entwickler“ mit dem bisherigen Diagnose-Inhalt (Rate, 5-Minuten-Test, Freitext-Befestigung je Station, Empfangsstatistik).
  - Profilzeile „Tracker“ in `beimTraining`, nur wenn `Funktionen.sensorKarte`.
- [ ] **Step 1: Failing tests:** `trackerWertOhneGemerkten` („Nicht eingerichtet“), `trackerWertVerbunden` („Verbunden“), `aktionBeiMehrerenFunden` (→ `.auswaehlen` mit beiden Funden), `aktionBeiVerweigert` (→ `.einstellungenOeffnen`), `aktionOhneGemerkten` (→ `.verbinden`).
- [ ] **Step 2:** `xcodegen generate`; Tests → FAIL.
- [ ] **Step 3:** Implementieren; `SensorDiagnoseBlatt.swift` löschen, Inhalt umgezogen.
- [ ] **Step 4:** `ProfilZeilenTests`, `TrackerAnzeigeTests` → PASS; Build grün.
- [ ] **Step 5: Commit** `feat(ios): Tracker wird im Profil eingerichtet`

---

### Task 5: Tracker-Symbol in der Kopfzeile, Sensor-Karte raus aus dem Training

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingKopfzeile.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Training/TrackerSymbol.swift` (`#if DEBUG`)
- Modify: `Screens/Geraet/GeraetView.swift` (`SensorZeile` ~:86-90 → Ruhe-Zeile)
- Modify: `Screens/Training/TrainingRootView.swift` (`sensorKarte` ~:498-505 und Verwendungen :450, :480, :563 entfernen)
- Delete: `Screens/Geraet/SensorKarte.swift`, `Screens/Geraet/SensorZeile.swift`
- Test: `SensorZeileTextTests.swift` → umbenennen/umziehen nach `TrackerAnzeigeTests.swift`

**Interfaces:**
- Consumes: `TrackerAnzeige` (Task 1), `ZaehlerKoordinator.automatik.speichernIn`.
- Produces:
  - `TrackerSymbol: View` – liest `ZaehlerKoordinator`/`SensorAufnahmeKoordinator` aus der Umgebung, rendert nur bei `TrackerAnzeige.sichtbar(...)`; Bild `Image("SensorGeraet")` (oder SF-Symbol) 20 pt in grün/grau, Trefferfläche 44 pt ohne die Zeile zu strecken (gleicher Kniff wie die Uhr: `.padding(.vertical, -s12)`); `aria`: „Tracker verbunden“/„Tracker nicht verbunden“, Hint „Zeigt den Tracker“; testnotiz `geraet.tracker`.
  - Tipp → `.sheet` mit `TrackerAnzeige.status`, `Toggle("Sätze automatisch starten und sichern", isOn: zaehler.automatikAktiv)`, bei `.nichtVerbunden` der Hinweis „Einrichtung im Profil“ (F7); Detent `.height(220)` bzw. `.medium`.
  - `TrainingKopfzeile`: `Ort · Spacer · TrackerSymbol · Uhr` (Spec 2.3); im Release-Build kein Symbol (`#if DEBUG`).
  - `TrackerAnzeige.ruheText(_ automatik: SatzAutomatik, aktiv: Bool) -> String?`: „Sichern nach Ruhe · 5 s“ nur bei `aktiv` und Zustand `.laeuft` mit `speichernIn`, sonst nil (F5). GeraetView zeigt ihn als Zeile unter der Kopfzeile (`fliesstext`, `textMuted`).
- [ ] **Step 1: Failing tests:** `ruheTextNurBeiLaufendemSatz` („Sichern nach Ruhe · 5 s“ bei `.laeuft`, sonst nil); `ruheTextNichtBeiAutomatikAus`; die übrigen Fälle aus `SensorZeileTextTests` werden gelöscht, soweit sie entfernte Texte pinnen („zählt · n“, Marken, Befestigungsmenü), und im Report aufgezählt.
- [ ] **Step 2:** `xcodegen generate`; Tests → FAIL.
- [ ] **Step 3:** Implementieren; SensorKarte/SensorZeile löschen; die drei `sensorKarte`-Stellen in TrainingRootView entfernen.
- [ ] **Step 4:** `rg "SensorKarte|SensorZeile|SensorDiagnoseBlatt|markenZeile|befestigungText" apps/ios-member/FitnessMember` → keine Treffer; volle Suite → PASS.
- [ ] **Step 5: Commit** `feat(ios): im Training nur noch ein Tracker-Symbol in der Kopfzeile`

---

### Task 6: Abschluss Paket 3

- [ ] **Step 1:** Volle iOS-Suite und `swift test --package-path apps/ios-member/Packages/Sensorik` → grün.
- [ ] **Step 2:** Auf dem iPhone (DEBUG-Build, `xcrun devicectl`): ohne gemerkten Tracker → kein Symbol; Profil → Tracker verbinden; Training → grünes Symbol, Blatt mit Schalter; Automatik aus → Rad dreht nicht mit, Satz von Hand; Tracker ausschalten → Symbol grau. Screenshots in den PR.
- [ ] **Step 3:** PR gegen `master`; Entscheidungen F1–F7 nennen.
