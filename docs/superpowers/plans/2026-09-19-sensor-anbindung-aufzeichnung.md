# Bewegungssensor Teilprojekt A: Anbindung und Rohdaten-Aufzeichnung — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Der Debug-Build der Member-App verbindet sich per Core Bluetooth mit dem WitMotion WT9011DCL-BT50, schreibt je Satz einen beschrifteten Mitschnitt (`Sensoraufnahmen/<zeit>/aufnahme.json` + `messwerte.csv`) und misst die reale Paketrate. Am Ende liegen mindestens 20 gesicherte Aufnahmen als Startmaterial für den Zähler (Teilprojekt B) vor.

**Architecture:** Schichten hinter einem schmalen Protokoll. Ein reiner Parser macht aus Bytes Pakete; `SensorQuelle` liefert Zustand und einen Ereignisstrom; `BluetoothSensorQuelle` ist die einzige Datei mit `import CoreBluetooth`, `AbspielSensorQuelle` spielt eine Aufnahme über dieselbe Schnittstelle ab. `SensorAufnahme` schreibt Dateien und kennt kein Bluetooth. `SensorAufnahmeKoordinator` verbindet beides mit dem Satzpfad; `GeraetModel` kennt nur das winzige, immer kompilierte Protokoll `SatzMitschnitt` und ruft es an drei Stellen. Alles andere steht hinter `#if DEBUG`.

**Tech Stack:** Swift 6 / SwiftUI / Observation / Core Bluetooth / Swift Testing / XcodeGen (`apps/ios-member`). Keine Änderung an `packages/domain`, `apps/web` oder `supabase`.

**Spec:** `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md` — Executor lesen beide Dokumente. „Spec §n" verweist dorthin.

**Abweichungen von der Spec, bewusst:**

1. **`SatzMitschnitt` statt `SensorAufnahmeKoordinator?` in `GeraetModel`** (Spec §7.3). Der Koordinator existiert nur im Debug-Build, `GeraetModel` wird auch im Release kompiliert. Deshalb bekommt `GeraetModel` ein immer kompiliertes Protokoll mit drei Methoden; der Koordinator erfüllt es. Im Release ist der Parameter `nil`.
2. **Ein Ereignisstrom statt `messwerte: AsyncStream<SensorMesswert>`** (Spec §5.2 lässt die Form offen). `ereignisse()` liefert Messwerte und Zustandswechsel in einem Strom, damit eine Lücke in der richtigen Reihenfolge zwischen den Messwerten ankommt.
3. **Verifikation in zwei Teilen** (Spec §4). Punkte 1 bis 6 klärt eine Wegwerf-Probe auf dem Mac (Task 1), ohne iOS-Build. Punkt 7 (Rate am iPhone) misst der 5-Minuten-Test der fertigen Diagnose (Task 11).
4. **Kein Test „fehlgeschlagenes Sichern meldet nichts"** (Spec §9). `GeraetModel.satzSichern` hat keinen Fehlschlagpfad (siehe Kommentar dort), es gäbe nichts zu prüfen.

## Global Constraints

- **Alles Neue hinter `#if DEBUG`**, ganze Datei umschlossen, wie `FitnessMember/Testnotiz/`. Ausnahmen: `Workout/SatzMitschnitt.swift`, die Änderungen in `GeraetModel.swift` und der Usage-Text in `project.yml`. Testdateien für Debug-Typen sind ebenfalls ganz in `#if DEBUG` gefasst.
- **In A verlässt kein Sensorwert das iPhone.** Keine Änderung an DTOs, `APIClient`, `PendingSetWrite`, Domain oder Migrationen.
- **Kalibrieren (`FF AA 01 01 00`) und Speichern (`FF AA 00 00 00`) existieren im Code nicht.** Kein Task fügt sie hinzu.
- **Die Aufnahme gefährdet nie den Satz.** Keine Methode von `SatzMitschnitt` wirft, keine wird vor dem Sichern abgewartet.
- **Kommentare in Swift ohne Umlaute** (ASCII) und mit Begründung, nicht Beschreibung. Nutzertexte tragen Umlaute.
- **Design-Tokens aus `DesignSystem.swift`**, nie als Literal. Hit-Targets nie unter 44 pt.
- **Swift-Tests mit Swift Testing** (`import Testing`, `@Test`, `#expect`), als `struct`-Suite, deutsche Testnamen. Ableitungen bekommen ihren Test vor dem View. SwiftUI-Views und `BluetoothSensorQuelle` werden am Gerät geprüft (Task 11), nicht unit-getestet.
- **Neue Swift-Dateien:** `project.yml` zieht Verzeichnisse; nach dem Anlegen `xcodegen generate` in `apps/ios-member`. Danach nie blind `git add -u`: `git status` vor jedem Commit, `Package.resolved` bleibt unangetastet.
- **iOS-Tests:** in `apps/ios-member`
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`.
  Einzelne Suite: `-only-testing:FitnessMemberTests/<Suite>`. Vor jedem Build `df -h /System/Volumes/Data` (über 3 GB frei nötig; am 19. September waren es 7,3 GB). Nur eine Session baut zur selben Zeit. Grün vor dem nächsten Task.
- **Arbeitsort:** Worktree `.claude/worktrees/sensor-anbindung`, Branch `claude/sensor-anbindung-aufzeichnung`. `.env` und `apps/ios-member/Config.xcconfig` sind dort schon hineinkopiert.
- **Ein Commit je Task**, deutsche Message mit ae/oe/ue im Stil der Historie (`feat(sensor): …`, `test(sensor): …`, `docs(sensor): …`). Trailer wörtlich so, wie ihn die ausführende Session vorgibt; nach jedem Commit mit `git log -1 --format=%B` prüfen.
- **Nicht pushen.**

## Dateien

Neu unter `apps/ios-member/FitnessMember/`:

| Datei | Verantwortung | Task |
|---|---|---|
| `Workout/SatzMitschnitt.swift` | Protokoll + zwei Wert-Typen zwischen Satzpfad und Mitschnitt. Immer kompiliert. | 8 |
| `Workout/Sensor/SensorMesswert.swift` | `Vektor3`, `SensorMesswert` | 2 |
| `Workout/Sensor/WitMotionPaket.swift` | `WitMotionPaket`, `WitMotionParser` | 2 |
| `Workout/Sensor/WitMotionBefehl.swift` | `SensorRate`, `WitMotionBefehl`, `Akkustand` | 3 |
| `Workout/Sensor/SensorStatistik.swift` | Rate und Abstände aus Zeitstempeln | 4 |
| `Workout/Sensor/SensorAufnahmeDatei.swift` | Codable-Typen des Formats `gymodo.sensoraufnahme/1` | 5 |
| `Workout/Sensor/SensorAufnahme.swift` | Schreibt einen Aufnahme-Ordner, trägt Verwaiste nach | 5 |
| `Workout/Sensor/SensorQuelle.swift` | `SensorZustand`, `SensorFund`, `SensorEreignis`, `SensorQuelle`, `SensorVerteiler` | 6 |
| `Workout/Sensor/SensorAufnahmeLeser.swift` | Liest einen Aufnahme-Ordner | 6 |
| `Workout/Sensor/AbspielSensorQuelle.swift` | Spielt eine Aufnahme als `SensorQuelle` ab | 6 |
| `Workout/Sensor/SensorAufnahmeKoordinator.swift` | Satzpfad ↔ Aufnahme, Anzeige-Statistik, Ratentest, Befestigung | 7 |
| `Workout/Sensor/BluetoothSensorQuelle.swift` | Core Bluetooth | 9 |
| `Screens/Geraet/SensorZeile.swift` | Die Zeile im Geräte-Screen | 10 |
| `Screens/Geraet/SensorDiagnoseBlatt.swift` | Diagnose, Rate, Ratentest, Befestigung | 10 |

Geändert: `Screens/Geraet/GeraetModel.swift` (8), `Screens/Geraet/GeraetView.swift` (10), `Screens/Training/TrainingRootView.swift` (10), `FitnessMemberApp.swift` (10), `project.yml` (6, 9).

Tests neu unter `apps/ios-member/FitnessMemberTests/`: `WitMotionPaketTests.swift`, `WitMotionBefehlTests.swift`, `SensorStatistikTests.swift`, `SensorAufnahmeTests.swift`, `AbspielSensorQuelleTests.swift`, `SensorAufnahmeKoordinatorTests.swift`, dazu `Fixtures/sensoraufnahme-beispiel/{aufnahme.json,messwerte.csv}`. Erweitert: `GeraetModelTests.swift`.

---

## Task 1: Verifikation am Sensor (Mac-Probe, Spec §4 Punkte 1–6)

Braucht Tim und den eingeschalteten Sensor. Der Sensor darf dabei **nicht** mit dem iPhone oder der WitMotion-App verbunden sein, sonst sendet er keine Advertisements.

**Files:**
- Create (außerhalb des Repos, im Scratchpad der Session): `probe.swift`
- Modify: `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md` (§3, §4)

**Interfaces:**
- Produces: bestätigte Bytes für Task 2 (ein echtes `55 61`-Paket, eine echte `55 71`-Antwort), die Entscheidung „Entsperren nötig ja/nein" für Task 3 und „steht `FFE5` im Advertisement ja/nein" für Task 9.

- [ ] **Step 1: Probe schreiben.** `probe.swift` im Scratchpad:

```swift
import CoreBluetooth
import Foundation

// Wegwerf-Probe: loggt alles roh, deutet nichts. Aufruf:
//   swift probe.swift            -> scannen, verbinden, 10 s Pakete loggen
//   swift probe.swift FFAA030900 -> wie oben, schreibt nach 3 s diese Bytes
//   swift probe.swift A,B        -> mehrere Befehle, 200 ms Abstand
final class Probe: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var zentrale: CBCentralManager!
    var sensor: CBPeripheral?
    var schreiben: CBCharacteristic?
    let befehle: [Data]
    var pakete = 0
    var start = Date()

    init(befehle: [Data]) {
        self.befehle = befehle
        super.init()
        zentrale = CBCentralManager(delegate: self, queue: nil)
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("Zustand:", central.state.rawValue)
        if central.state == .poweredOn { central.scanForPeripherals(withServices: nil) }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard let name = peripheral.name, name.hasPrefix("WT") else { return }
        print("Fund:", name, peripheral.identifier, "RSSI", RSSI)
        print("Advertisement:", advertisementData)
        sensor = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Verbunden")
        peripheral.discoverServices(nil)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for dienst in peripheral.services ?? [] {
            print("Service:", dienst.uuid)
            peripheral.discoverCharacteristics(nil, for: dienst)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for c in service.characteristics ?? [] {
            print("  Characteristic:", c.uuid, "Eigenschaften:", c.properties.rawValue)
            if c.properties.contains(.notify) { peripheral.setNotifyValue(true, for: c) }
            if c.properties.contains(.write) || c.properties.contains(.writeWithoutResponse) { schreiben = c }
        }
        start = Date()
        for (n, befehl) in befehle.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3 + Double(n) * 0.2) { [self] in
                guard let schreiben else { return }
                let art: CBCharacteristicWriteType =
                    schreiben.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
                print(">>> schreibe", befehl.map { String(format: "%02X", $0) }.joined(separator: " "))
                peripheral.writeValue(befehl, for: schreiben, type: art)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [self] in
            let dauer = Date().timeIntervalSince(start)
            print(String(format: "%d Notifications in %.1f s = %.1f /s", pakete, dauer, Double(pakete) / dauer))
            exit(0)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let daten = characteristic.value else { return }
        pakete += 1
        let istMesswert = daten.count == 20 && daten[0] == 0x55 && daten[1] == 0x61
        // Messwerte nur die ersten fuenf und danach jedes fuenfzigste; alles andere immer.
        if !istMesswert || pakete <= 5 || pakete % 50 == 0 {
            print(String(format: "%6.3f", Date().timeIntervalSince(start)), "[\(daten.count)]",
                  daten.map { String(format: "%02X", $0) }.joined(separator: " "))
        }
    }
}

func bytes(_ hex: String) -> Data {
    var daten = Data(); var rest = Substring(hex)
    while rest.count >= 2 { daten.append(UInt8(rest.prefix(2), radix: 16)!); rest = rest.dropFirst(2) }
    return daten
}

let probe = Probe(befehle: (CommandLine.arguments.dropFirst().first ?? "")
    .split(separator: ",").map { bytes(String($0)) })
RunLoop.main.run()
```

- [ ] **Step 2: Laufen lassen, sieben Durchgänge.** macOS fragt beim ersten Mal nach der Bluetooth-Berechtigung für das Terminal. Bricht der Prozess stattdessen mit einem Privacy-Fehler ab, lässt Tim die Befehle selbst im Terminal laufen (`! swift <pfad>/probe.swift`).

| # | Aufruf | Klärt |
|---|---|---|
| a | `swift probe.swift` (Sensor flach und ruhig) | UUIDs, Eigenschaften von `FFE9`, steht `FFE5` im Advertisement, Header, Länge, Pakete je Notification, Plausibilität (eine Achse ≈ ±1 g) |
| b | `swift probe.swift FFAA276400` | Format der Akku-Antwort |
| c | `swift probe.swift FFAA030900` | 100 Hz ohne Entsperren und ohne Speichern: steigt die Notification-Rate? |
| d | nur falls c nichts ändert: `swift probe.swift FFAA6988B5,FFAA030900` | ob vor dem Ratenbefehl ein Entsperren (`FF AA 69 88 B5`) nötig ist. Die Probe schreibt mehrere durch Komma getrennte Befehle im Abstand von 200 ms in derselben Verbindung. |
| e | `swift probe.swift FFAA030700` | 20 Hz |
| f | `swift probe.swift FFAA030800` | zurück auf 50 Hz |
| g | Sensor aus- und einschalten, dann `swift probe.swift` | Rate nach Neustart (erwartet: die in der WitMotion-App gespeicherten 50 Hz) |

- [ ] **Step 3: Spec §4 ausfüllen.** Unter „**Ergebnis:**" je Punkt 1–6 ein bis drei Sätze mit den beobachteten Bytes, im Stil von `docs/m0-ergebnis.md`. Ein vollständiges `55 61`-Paket und die vollständige `55 71`-Antwort wörtlich als Hex eintragen. Punkt 7 bleibt mit dem Vermerk „folgt aus Task 11" offen. Weicht etwas von Spec §3 ab (UUID, Header, Befehl, Entsperren nötig), §3 im selben Commit korrigieren.

- [ ] **Step 4: Probe löschen.** Sie liegt im Scratchpad und kommt nicht ins Repo. `git status` zeigt nur die Spec.

- [ ] **Step 5: Commit** — `docs(sensor): Protokoll am Sensor verifiziert`

**Wenn ein Ergebnis von den Annahmen dieses Plans abweicht:** anhalten und Tim fragen, bevor Task 2 beginnt. Die Tasks 2, 3 und 9 tragen die Annahmen aus Spec §3 als Code.

---

## Task 2: `SensorMesswert` und der Parser

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorMesswert.swift`
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/WitMotionPaket.swift`
- Test: `apps/ios-member/FitnessMemberTests/WitMotionPaketTests.swift`

**Interfaces:**
- Produces:
  - `struct Vektor3: Sendable, Equatable { let x, y, z: Double }`
  - `struct SensorMesswert: Sendable, Equatable { let t: TimeInterval; let beschleunigung, drehrate, winkel: Vektor3 }` — `t` ist die Geräte-Uptime in Sekunden beim Empfang.
  - `enum WitMotionPaket: Sendable, Equatable { case messwert(beschleunigung: Vektor3, drehrate: Vektor3, winkel: Vektor3); case register(adresse: UInt16, werte: [Int16]) }`
  - `struct WitMotionParser { private(set) var verworfeneBytes: Int; mutating func lesen(_ daten: Data) -> [WitMotionPaket] }`

- [ ] **Step 1: Tests schreiben.** `WitMotionPaketTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct WitMotionPaketTests {
    /// ay = -2048 (-1 g), az = 2048 (1 g), gx = 16384 (1000 Grad/s), wx = -16384 (-90 Grad).
    static let messwert: [UInt8] = [
        0x55, 0x61,
        0x00, 0x00, 0x00, 0xF8, 0x00, 0x08,
        0x00, 0x40, 0x00, 0x00, 0x00, 0x00,
        0x00, 0xC0, 0x00, 0x00, 0x00, 0x00,
    ]
    /// Antwort auf "Akku lesen": Register 0x64, erster Wert 396 (3,96 V).
    static let register: [UInt8] = [0x55, 0x71, 0x64, 0x00, 0x8C, 0x01] + [UInt8](repeating: 0, count: 14)

    static let erwartet = WitMotionPaket.messwert(
        beschleunigung: Vektor3(x: 0, y: -1, z: 1),
        drehrate: Vektor3(x: 1000, y: 0, z: 0),
        winkel: Vektor3(x: -90, y: 0, z: 0)
    )

    @Test func liestEinPaketMitVorzeichenUndSkalierung() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data(Self.messwert)) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 0)
    }

    @Test func skaliertDieRaender() {
        var bytes = Self.messwert
        bytes[2] = 0x00; bytes[3] = 0x80   // ax = Int16.min
        bytes[4] = 0xFF; bytes[5] = 0x7F   // ay = Int16.max
        var sut = WitMotionParser()
        guard case .messwert(let a, _, _)? = sut.lesen(Data(bytes)).first else {
            Issue.record("kein Messwert"); return
        }
        #expect(a.x == -16)
        #expect(a.y == 32767.0 / 32768.0 * 16)
    }

    @Test func liestZweiPaketeAusEinerNotification() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data(Self.messwert + Self.messwert)) == [Self.erwartet, Self.erwartet])
    }

    @Test func setztEinGeteiltesPaketZusammen() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data(Self.messwert.prefix(7))).isEmpty)
        #expect(sut.lesen(Data(Self.messwert.dropFirst(7))) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 0)
    }

    @Test func haeltEinEinzelnesHeaderByteAmEndeZurueck() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data([0x55])).isEmpty)
        #expect(sut.lesen(Data(Self.messwert.dropFirst())) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 0)
    }

    @Test func richtetSichNachUnbekanntemNeuAusUndZaehlt() {
        var sut = WitMotionParser()
        // 0x55 0x00 ist kein Header: beide Bytes zaehlen als verworfen.
        #expect(sut.lesen(Data([0x01, 0x02, 0x55, 0x00] + Self.messwert)) == [Self.erwartet])
        #expect(sut.verworfeneBytes == 4)
    }

    @Test func deutetEineRegisterantwortNieAlsMesswert() {
        var sut = WitMotionParser()
        let ergebnis = sut.lesen(Data(Self.register))
        #expect(ergebnis == [.register(adresse: 0x64, werte: [396, 0, 0, 0, 0, 0, 0, 0])])
    }

    @Test func leereDatenErgebenNichts() {
        var sut = WitMotionParser()
        #expect(sut.lesen(Data()).isEmpty)
        #expect(sut.verworfeneBytes == 0)
    }
}
#endif
```

Hat Task 1 ein echtes Paket geliefert, kommt es als weiterer Test dazu (`liestDasEchtePaketAusDerVerifikation`), mit den in Spec §4 notierten Sollwerten und einer Toleranz von `0.001`.

- [ ] **Step 2: `xcodegen generate`, Test laufen lassen, Fehlschlag sehen.**
  `xcodebuild test … -only-testing:FitnessMemberTests/WitMotionPaketTests` → FAIL: `cannot find 'WitMotionParser' in scope`.

- [ ] **Step 3: `SensorMesswert.swift`:**

```swift
#if DEBUG
import Foundation

struct Vektor3: Sendable, Equatable {
    let x: Double
    let y: Double
    let z: Double
}

/// Ein Messwert samt Empfangszeitpunkt. Der Sensor schickt keinen
/// Zeitstempel mit (Spec 3) -- `t` ist die Uptime des iPhones in dem
/// Moment, in dem Core Bluetooth das Paket abgeliefert hat.
struct SensorMesswert: Sendable, Equatable {
    let t: TimeInterval
    /// in g
    let beschleunigung: Vektor3
    /// in Grad pro Sekunde
    let drehrate: Vektor3
    /// in Grad. Yaw (z) ist am Stahl nicht belastbar (Spec 2).
    let winkel: Vektor3
}
#endif
```

- [ ] **Step 4: `WitMotionPaket.swift`:**

```swift
#if DEBUG
import Foundation

enum WitMotionPaket: Sendable, Equatable {
    case messwert(beschleunigung: Vektor3, drehrate: Vektor3, winkel: Vektor3)
    /// Antwort auf einen Lesebefehl: acht Register ab `adresse`.
    case register(adresse: UInt16, werte: [Int16])

    static let laenge = 20
}

/// Haelt einen Puffer ueber Aufrufe hinweg: Core Bluetooth garantiert nicht,
/// dass eine Notification genau ein Paket traegt (Spec 5.1).
struct WitMotionParser {
    private var puffer: [UInt8] = []
    /// Bytes, die zu keinem Paket gehoerten. Gezaehlt statt still verworfen,
    /// damit eine kaputte Verbindung in der Statistik sichtbar wird.
    private(set) var verworfeneBytes = 0

    mutating func lesen(_ daten: Data) -> [WitMotionPaket] {
        puffer.append(contentsOf: daten)
        var pakete: [WitMotionPaket] = []
        var i = 0
        while i < puffer.count {
            guard puffer[i] == 0x55 else {
                i += 1; verworfeneBytes += 1
                continue
            }
            // Header oder Paket noch unvollstaendig: auf die naechste
            // Notification warten statt zu raten.
            guard i + 1 < puffer.count else { break }
            let typ = puffer[i + 1]
            guard typ == 0x61 || typ == 0x71 else {
                i += 1; verworfeneBytes += 1
                continue
            }
            guard i + WitMotionPaket.laenge <= puffer.count else { break }

            let werte = (0..<9).map { n -> Int16 in
                let lo = UInt16(puffer[i + 2 + n * 2])
                let hi = UInt16(puffer[i + 3 + n * 2])
                return Int16(bitPattern: lo | hi << 8)
            }
            if typ == 0x61 {
                func vektor(_ ab: Int, _ bereich: Double) -> Vektor3 {
                    Vektor3(x: Double(werte[ab]) / 32768 * bereich,
                            y: Double(werte[ab + 1]) / 32768 * bereich,
                            z: Double(werte[ab + 2]) / 32768 * bereich)
                }
                pakete.append(.messwert(beschleunigung: vektor(0, 16),
                                        drehrate: vektor(3, 2000),
                                        winkel: vektor(6, 180)))
            } else {
                pakete.append(.register(adresse: UInt16(bitPattern: werte[0]),
                                        werte: Array(werte.dropFirst())))
            }
            i += WitMotionPaket.laenge
        }
        puffer.removeFirst(i)
        return pakete
    }
}
#endif
```

- [ ] **Step 5: Test grün.** Dieselbe `-only-testing`-Zeile → PASS.

- [ ] **Step 6: Commit** — `feat(sensor): Messwert und Parser fuer das WitMotion-Paket`

---

## Task 3: Befehle und Akkustand

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/WitMotionBefehl.swift`
- Test: `apps/ios-member/FitnessMemberTests/WitMotionBefehlTests.swift`

**Interfaces:**
- Produces:
  - `enum SensorRate: Int, Sendable, CaseIterable, Codable { case hz20 = 20, hz50 = 50, hz100 = 100 }`
  - `enum WitMotionBefehl: Sendable, Equatable { case rate(SensorRate); case akkuLesen; var bytes: Data; static var alle: [WitMotionBefehl] }`
  - `enum Akkustand { static let register: UInt16 = 0x64; static func prozent(hundertstelVolt: Int) -> Int }`

- [ ] **Step 1: Tests schreiben.** `WitMotionBefehlTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct WitMotionBefehlTests {
    @Test func bytesDerVierBefehle() {
        #expect(WitMotionBefehl.rate(.hz20).bytes == Data([0xFF, 0xAA, 0x03, 0x07, 0x00]))
        #expect(WitMotionBefehl.rate(.hz50).bytes == Data([0xFF, 0xAA, 0x03, 0x08, 0x00]))
        #expect(WitMotionBefehl.rate(.hz100).bytes == Data([0xFF, 0xAA, 0x03, 0x09, 0x00]))
        #expect(WitMotionBefehl.akkuLesen.bytes == Data([0xFF, 0xAA, 0x27, 0x64, 0x00]))
    }

    @Test func kenntWederKalibrierenNochSpeichern() {
        // Ein Kalibrier-Befehl am schraeg haengenden Sensor verfaelscht alle
        // folgenden Daten, ein Speichern macht einen Fehlversuch dauerhaft
        // (Spec 2). Der Test haelt fest, dass niemand sie nachruestet.
        let verboten = [Data([0xFF, 0xAA, 0x01, 0x01, 0x00]), Data([0xFF, 0xAA, 0x00, 0x00, 0x00])]
        for befehl in WitMotionBefehl.alle {
            #expect(!verboten.contains(befehl.bytes))
        }
        #expect(WitMotionBefehl.alle.count == 4)
    }

    @Test func akkuInProzent() {
        #expect(Akkustand.prozent(hundertstelVolt: 410) == 100)
        #expect(Akkustand.prozent(hundertstelVolt: 396) == 90)
        #expect(Akkustand.prozent(hundertstelVolt: 380) == 50)
        #expect(Akkustand.prozent(hundertstelVolt: 369) == 15)
        #expect(Akkustand.prozent(hundertstelVolt: 300) == 0)
    }
}
#endif
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag sehen** (`cannot find 'WitMotionBefehl'`).

- [ ] **Step 3: `WitMotionBefehl.swift`:**

```swift
#if DEBUG
import Foundation

enum SensorRate: Int, Sendable, CaseIterable, Codable {
    case hz20 = 20
    case hz50 = 50
    case hz100 = 100

    /// Wert fuer das Raten-Register 0x03.
    fileprivate var registerwert: UInt8 {
        switch self {
        case .hz20: 0x07
        case .hz50: 0x08
        case .hz100: 0x09
        }
    }
}

/// Bewusst nur, was A braucht. Kalibrieren und "Konfiguration speichern"
/// fehlen mit Absicht (Spec 2) -- wer sie braucht, fuehrt die Diskussion
/// in der Spec, nicht hier.
enum WitMotionBefehl: Sendable, Equatable {
    case rate(SensorRate)
    case akkuLesen

    static var alle: [WitMotionBefehl] { SensorRate.allCases.map(WitMotionBefehl.rate) + [.akkuLesen] }

    var bytes: Data {
        switch self {
        case .rate(let rate): Data([0xFF, 0xAA, 0x03, rate.registerwert, 0x00])
        case .akkuLesen: Data([0xFF, 0xAA, 0x27, 0x64, 0x00])
        }
    }
}

enum Akkustand {
    static let register: UInt16 = 0x64

    /// Der Sensor meldet die Zellspannung in Hundertstel Volt. Die Stufen
    /// stammen aus der Herstellertabelle; eine LiPo-Kurve ist nicht linear,
    /// eine Geradengleichung wuerde bei 3,7 V "50 %" behaupten.
    static func prozent(hundertstelVolt wert: Int) -> Int {
        let stufen: [(ab: Int, prozent: Int)] = [
            (397, 100), (393, 90), (387, 75), (382, 60), (379, 50), (377, 40),
            (373, 30), (370, 20), (368, 15), (350, 10), (340, 5),
        ]
        return stufen.first { wert >= $0.ab }?.prozent ?? 0
    }
}
#endif
```

- [ ] **Step 4: Nur falls Task 1 gezeigt hat, dass Ratenbefehle ein Entsperren brauchen:** `case entsperren` mit `Data([0xFF, 0xAA, 0x69, 0x88, 0xB5])` ergänzen, in `alle` aufnehmen, den Zähltest auf 5 heben und im Bytes-Test prüfen. Hat Task 1 eine andere Akku-Kodierung gezeigt als „Hundertstel Volt im ersten Wert", `Akkustand` und seinen Test an das in Spec §4 notierte Format anpassen.

- [ ] **Step 5: Test grün.**

- [ ] **Step 6: Commit** — `feat(sensor): Befehle fuer Rate und Akku, ohne Kalibrieren und Speichern`

---

## Task 4: `SensorStatistik`

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorStatistik.swift`
- Test: `apps/ios-member/FitnessMemberTests/SensorStatistikTests.swift`

**Interfaces:**
- Produces:

```swift
struct SensorStatistik: Sendable {
    struct Abstand: Codable, Equatable, Sendable { var median: Double; var p95: Double; var max: Double }
    struct Ergebnis: Codable, Equatable, Sendable {
        var pakete: Int; var rateIstHz: Double; var abstandMs: Abstand
        var luecken: Int; var verworfeneBytes: Int
        static let leer: Ergebnis
    }
    mutating func erfassen(t: TimeInterval)
    mutating func lueckeBegonnen()
    func rateLetzteSekunde(bis jetzt: TimeInterval) -> Double
    func ergebnis(verworfeneBytes: Int) -> Ergebnis
}
```

- [ ] **Step 1: Tests schreiben.** `SensorStatistikTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct SensorStatistikTests {
    @Test func leerIstNull() {
        #expect(SensorStatistik().ergebnis(verworfeneBytes: 0) == .leer)
    }

    @Test func rateUndAbstaendeAusZeitstempeln() {
        var sut = SensorStatistik()
        // Abstaende 20, 20, 20, 40 ms -> 4 Abstaende in 100 ms = 40 Hz.
        for t in [10.00, 10.02, 10.04, 10.06, 10.10] { sut.erfassen(t: t) }
        let e = sut.ergebnis(verworfeneBytes: 3)
        #expect(e.pakete == 5)
        #expect(e.rateIstHz == 40.0)
        #expect(e.abstandMs == .init(median: 20, p95: 40, max: 40))
        #expect(e.luecken == 0)
        #expect(e.verworfeneBytes == 3)
    }

    @Test func gebuendelteMesswerteZeigenSichAlsAbstandNull() {
        var sut = SensorStatistik()
        for t in [1.00, 1.00, 1.04, 1.04] { sut.erfassen(t: t) }
        // Abstaende 0, 40, 0 -> Median 0. Die Buendelung bleibt sichtbar
        // statt herausgerechnet zu werden (Spec 5.1).
        #expect(sut.ergebnis(verworfeneBytes: 0).abstandMs.median == 0)
        #expect(sut.ergebnis(verworfeneBytes: 0).abstandMs.max == 40)
    }

    @Test func eineLueckeZaehltNichtAlsAbstand() {
        var sut = SensorStatistik()
        sut.erfassen(t: 1.00); sut.erfassen(t: 1.02)
        sut.lueckeBegonnen()
        sut.erfassen(t: 5.00); sut.erfassen(t: 5.02)
        let e = sut.ergebnis(verworfeneBytes: 0)
        #expect(e.luecken == 1)
        #expect(e.abstandMs.max == 20)
        #expect(e.rateIstHz == 50.0)
    }

    @Test func rateDerLetztenSekunde() {
        var sut = SensorStatistik()
        for n in 0..<150 { sut.erfassen(t: Double(n) * 0.02) }   // 3 s bei 50 Hz
        #expect(sut.rateLetzteSekunde(bis: 2.98) == 50)
        // Nach einer Sekunde Stille steht 0 da, nicht der alte Wert.
        #expect(sut.rateLetzteSekunde(bis: 4.5) == 0)
    }
}
#endif
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag sehen.**

- [ ] **Step 3: `SensorStatistik.swift`:**

```swift
#if DEBUG
import Foundation

/// Was am iPhone ankommt, nicht was am Sensor eingestellt ist (Spec 4.7).
/// Rein: bekommt Zeitstempel, kennt weder Bluetooth noch Dateien.
struct SensorStatistik: Sendable {
    struct Abstand: Codable, Equatable, Sendable {
        var median: Double
        var p95: Double
        var max: Double
    }

    struct Ergebnis: Codable, Equatable, Sendable {
        var pakete: Int
        var rateIstHz: Double
        var abstandMs: Abstand
        var luecken: Int
        var verworfeneBytes: Int

        static let leer = Ergebnis(pakete: 0, rateIstHz: 0,
                                   abstandMs: Abstand(median: 0, p95: 0, max: 0),
                                   luecken: 0, verworfeneBytes: 0)
    }

    private var pakete = 0
    private var letzter: TimeInterval?
    /// In Sekunden. Fuenf Minuten bei 100 Hz sind 30 000 Doubles -- das
    /// darf im Speicher liegen, dafuer stimmen Median und p95 exakt.
    private var abstaende: [Double] = []
    private var luecken = 0
    private var nachLuecke = false
    /// Nur das letzte Stueck, fuer die Anzeige in der Sensor-Zeile.
    private var juengste: [TimeInterval] = []

    mutating func erfassen(t: TimeInterval) {
        pakete += 1
        if let letzter, !nachLuecke { abstaende.append(t - letzter) }
        letzter = t
        nachLuecke = false
        juengste.append(t)
        if let erster = juengste.first, t - erster > 2 {
            juengste.removeAll { t - $0 > 1 }
        }
    }

    /// Der Abstand ueber eine getrennte Verbindung hinweg ist keine
    /// Eigenschaft der Funkstrecke und verdirbt sonst Maximum und Rate.
    mutating func lueckeBegonnen() {
        luecken += 1
        nachLuecke = true
    }

    func rateLetzteSekunde(bis jetzt: TimeInterval) -> Double {
        Double(juengste.filter { $0 <= jetzt && jetzt - $0 < 1 }.count)
    }

    func ergebnis(verworfeneBytes: Int) -> Ergebnis {
        guard !abstaende.isEmpty else {
            var leer = Ergebnis.leer
            leer.pakete = pakete; leer.luecken = luecken; leer.verworfeneBytes = verworfeneBytes
            return leer
        }
        let sortiert = abstaende.sorted()
        let n = sortiert.count
        let median = n % 2 == 1 ? sortiert[n / 2] : (sortiert[n / 2 - 1] + sortiert[n / 2]) / 2
        let p95 = sortiert[min(n - 1, Int((Double(n) * 0.95).rounded(.up)) - 1)]
        let summe = abstaende.reduce(0, +)
        func ms(_ sekunden: Double) -> Double { (sekunden * 1000 * 100).rounded() / 100 }
        return Ergebnis(
            pakete: pakete,
            rateIstHz: summe > 0 ? (Double(n) / summe * 10).rounded() / 10 : 0,
            abstandMs: Abstand(median: ms(median), p95: ms(p95), max: ms(sortiert[n - 1])),
            luecken: luecken,
            verworfeneBytes: verworfeneBytes
        )
    }
}
#endif
```

- [ ] **Step 4: Test grün.** Schlägt `rateLetzteSekunde` um eins daneben (Gleitkomma an der Sekundengrenze), die Grenze im Test auf `2.985` legen, nicht die Implementierung aufweichen.

- [ ] **Step 5: Commit** — `feat(sensor): Statistik ueber Rate und Paketabstaende`

---

## Task 5: Aufnahmeformat und `SensorAufnahme`

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorAufnahmeDatei.swift`
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorAufnahme.swift`
- Test: `apps/ios-member/FitnessMemberTests/SensorAufnahmeTests.swift`

**Interfaces:**
- Consumes: `SensorMesswert`, `SensorStatistik.Ergebnis`, `Zeitformat.ordnername(_:zeitzone:)`, `JSONEncoder.testnotiz(zeitzone:)`, `JSONDecoder.testnotiz()` (alle Debug, vorhanden).
- Produces:

```swift
struct SensorAufnahmeDatei: Codable, Equatable {
    static let formatkennung = "gymodo.sensoraufnahme/1"
    enum Abschluss: String, Codable { case laeuft, gesichert, abgebrochen }
    struct Sensor: Codable, Equatable { var name: String; var rateSollHz: Int; var akkuProzent: Int? }
    struct Geraet: Codable, Equatable { var model: String; var os: String; var appBuild: String }
    struct Kontext: Codable, Equatable {
        var machineId: String; var machineName: String
        var exerciseId: String; var exerciseName: String
        var sessionId: String?; var setId: String?; var setIndex: Int?
    }
    struct Label: Codable, Equatable { var weightKg: Double?; var reps: Int?; var problemFlag: Bool? }
    var format: String; var startedAt: Date; var endedAt: Date?
    var sensor: Sensor; var geraet: Geraet; var kontext: Kontext; var label: Label
    var befestigung: String?; var statistik: SensorStatistik.Ergebnis; var abschluss: Abschluss
}

struct SensorRatentestDatei: Codable, Equatable {
    static let formatkennung = "gymodo.sensorratentest/1"
    var format: String; var startedAt: Date; var endedAt: Date
    var sensor: SensorAufnahmeDatei.Sensor; var geraet: SensorAufnahmeDatei.Geraet
    var statistik: SensorStatistik.Ergebnis
}

final class SensorAufnahme {
    static let csvKopf = "t,ax,ay,az,gx,gy,gz,wx,wy,wz"
    let ordner: URL
    private(set) var datei: SensorAufnahmeDatei
    init(wurzel: URL, start: Date, startT: TimeInterval, sensor: SensorAufnahmeDatei.Sensor,
         geraet: SensorAufnahmeDatei.Geraet, kontext: SensorAufnahmeDatei.Kontext,
         befestigung: String?, zeitzone: TimeZone = .current) throws
    func schreiben(_ messwert: SensorMesswert) throws
    func lueckeBeginnt(t: TimeInterval)
    func lueckeEndet(t: TimeInterval) throws
    func abschliessen(_ abschluss: SensorAufnahmeDatei.Abschluss, kontext: SensorAufnahmeDatei.Kontext,
                      label: SensorAufnahmeDatei.Label, akkuProzent: Int?,
                      statistik: SensorStatistik.Ergebnis, ende: Date, endeT: TimeInterval) throws
    static func zeile(_ messwert: SensorMesswert, startT: TimeInterval) -> String
    static func verwaisteNachtragen(wurzel: URL, zeitzone: TimeZone = .current)
}
```

- [ ] **Step 1: Tests schreiben.** `SensorAufnahmeTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct SensorAufnahmeTests {
    static let berlin = TimeZone(identifier: "Europe/Berlin")!
    /// 2026-09-19 14:12:03 +02:00
    static let start = Date(timeIntervalSince1970: 1_789_819_923)

    static let sensor = SensorAufnahmeDatei.Sensor(name: "WT901BLE67", rateSollHz: 50, akkuProzent: 82)
    static let geraet = SensorAufnahmeDatei.Geraet(model: "iPhone17,1", os: "iOS 26.0", appBuild: "1")
    static let kontext = SensorAufnahmeDatei.Kontext(
        machineId: "m1", machineName: "Beinpresse", exerciseId: "e1", exerciseName: "Beidbeinig",
        sessionId: nil, setId: nil, setIndex: nil)

    static func messwert(t: TimeInterval) -> SensorMesswert {
        SensorMesswert(t: t,
                       beschleunigung: Vektor3(x: 0.0125, y: -0.9981, z: 0.0312),
                       drehrate: Vektor3(x: 1.25, y: -0.5, z: 0),
                       winkel: Vektor3(x: -88.5, y: 1.25, z: 0))
    }

    private func wurzel() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func neu(_ wurzel: URL) throws -> SensorAufnahme {
        try SensorAufnahme(wurzel: wurzel, start: Self.start, startT: 100, sensor: Self.sensor,
                           geraet: Self.geraet, kontext: Self.kontext,
                           befestigung: "Gewichtsstapel oben", zeitzone: Self.berlin)
    }

    private func csv(_ aufnahme: SensorAufnahme) throws -> [String] {
        try String(contentsOf: aufnahme.ordner.appendingPathComponent("messwerte.csv"), encoding: .utf8)
            .split(separator: "\n").map(String.init)
    }

    private func json(_ ordner: URL) throws -> SensorAufnahmeDatei {
        try JSONDecoder.testnotiz().decode(
            SensorAufnahmeDatei.self, from: Data(contentsOf: ordner.appendingPathComponent("aufnahme.json")))
    }

    @Test func zeileMitPunktUndFestenStellen() {
        #expect(SensorAufnahme.zeile(Self.messwert(t: 100.02), startT: 100)
            == "0.020000,0.0125,-0.9981,0.0312,1.25,-0.50,0.00,-88.50,1.25,0.00")
    }

    @Test func ordnernameMitLaufenderNummer() throws {
        let w = wurzel()
        #expect(try neu(w).ordner.lastPathComponent == "2026-09-19-1412-01")
        #expect(try neu(w).ordner.lastPathComponent == "2026-09-19-1412-02")
    }

    @Test func legtKopfUndLaufendeDateiAn() throws {
        let sut = try neu(wurzel())
        #expect(try csv(sut) == [SensorAufnahme.csvKopf])
        let datei = try json(sut.ordner)
        #expect(datei.format == "gymodo.sensoraufnahme/1")
        #expect(datei.abschluss == .laeuft)
        #expect(datei.endedAt == nil)
        #expect(datei.befestigung == "Gewichtsstapel oben")
        #expect(datei.statistik == .leer)
    }

    @Test func jedesFeldStehtImmerDa() throws {
        let sut = try neu(wurzel())
        let text = try String(contentsOf: sut.ordner.appendingPathComponent("aufnahme.json"), encoding: .utf8)
        for feld in ["\"endedAt\" : null", "\"sessionId\" : null", "\"setId\" : null",
                     "\"setIndex\" : null", "\"weightKg\" : null", "\"reps\" : null", "\"problemFlag\" : null"] {
            #expect(text.contains(feld), "fehlt: \(feld)")
        }
        #expect(text.contains("\"startedAt\" : \"2026-09-19T14:12:03+02:00\""))
    }

    @Test func schreibtMesswerteUndLuecke() throws {
        let sut = try neu(wurzel())
        try sut.schreiben(Self.messwert(t: 100.00))
        try sut.schreiben(Self.messwert(t: 100.02))
        sut.lueckeBeginnt(t: 112.431)
        try sut.lueckeEndet(t: 114.902)
        try sut.schreiben(Self.messwert(t: 114.902))
        let zeilen = try csv(sut)
        #expect(zeilen.count == 5)
        #expect(zeilen[3] == "# luecke 12.431000-14.902000")
        #expect(zeilen[4].hasPrefix("14.902000,"))
    }

    @Test func abschlussGesichertTraegtLabelsEin() throws {
        let sut = try neu(wurzel())
        try sut.schreiben(Self.messwert(t: 100.00))
        var kontext = Self.kontext
        kontext.sessionId = "S"; kontext.setId = "T"; kontext.setIndex = 2
        var statistik = SensorStatistik.Ergebnis.leer
        statistik.pakete = 1
        try sut.abschliessen(.gesichert, kontext: kontext,
                             label: .init(weightKg: 77.5, reps: 11, problemFlag: false),
                             akkuProzent: 80, statistik: statistik,
                             ende: Self.start.addingTimeInterval(42), endeT: 142)
        let datei = try json(sut.ordner)
        #expect(datei.abschluss == .gesichert)
        #expect(datei.label == .init(weightKg: 77.5, reps: 11, problemFlag: false))
        #expect(datei.kontext.setIndex == 2)
        #expect(datei.sensor.akkuProzent == 80)
        #expect(datei.statistik.pakete == 1)
        #expect(datei.endedAt == Self.start.addingTimeInterval(42))
    }

    @Test func abschlussMitOffenerLueckeSchreibtSieBisZumEnde() throws {
        let sut = try neu(wurzel())
        try sut.schreiben(Self.messwert(t: 100.00))
        sut.lueckeBeginnt(t: 105)
        try sut.abschliessen(.abgebrochen, kontext: Self.kontext, label: .init(),
                             akkuProzent: nil, statistik: .leer,
                             ende: Self.start.addingTimeInterval(9), endeT: 109)
        #expect(try csv(sut).last == "# luecke 5.000000-9.000000")
        #expect(try json(sut.ordner).label.reps == nil)
    }

    @Test func nachAbschlussWirdNichtMehrGeschrieben() throws {
        let sut = try neu(wurzel())
        try sut.abschliessen(.abgebrochen, kontext: Self.kontext, label: .init(), akkuProzent: nil,
                             statistik: .leer, ende: Self.start, endeT: 100)
        #expect(throws: (any Error).self) { try sut.schreiben(Self.messwert(t: 101)) }
    }

    @Test func traegtVerwaisteOrdnerNach() throws {
        let w = wurzel()
        let verwaist = try neu(w)
        try verwaist.schreiben(Self.messwert(t: 100.00))
        try verwaist.schreiben(Self.messwert(t: 107.50))
        let ordner = verwaist.ordner
        // Kein abschliessen(): so sieht der Ordner nach einem Absturz aus.

        SensorAufnahme.verwaisteNachtragen(wurzel: w, zeitzone: Self.berlin)

        let datei = try json(ordner)
        #expect(datei.abschluss == .abgebrochen)
        #expect(datei.endedAt == Self.start.addingTimeInterval(7))
    }

    @Test func nachtragenLaesstFertigeOrdnerInRuhe() throws {
        let w = wurzel()
        let fertig = try neu(w)
        try fertig.abschliessen(.gesichert, kontext: Self.kontext,
                                label: .init(weightKg: 50, reps: 8, problemFlag: false),
                                akkuProzent: nil, statistik: .leer, ende: Self.start, endeT: 100)
        SensorAufnahme.verwaisteNachtragen(wurzel: w, zeitzone: Self.berlin)
        #expect(try json(fertig.ordner).abschluss == .gesichert)
    }
}
#endif
```

`verwaisteNachtragen` rundet `endedAt` auf ganze Sekunden, weil das Format keine Sekundenbruchteile trägt (7,5 s → der Test erwartet `+7`; `Date`-Vergleich nach JSON-Roundtrip ist sekundengenau).

- [ ] **Step 2: Test laufen lassen, Fehlschlag sehen.**

- [ ] **Step 3: `SensorAufnahmeDatei.swift`.** Die `encode(to:)`-Methoden sind nötig, weil der synthetisierte Encoder `nil` weglässt; das Format verlangt `null` (Spec §6.3).

```swift
#if DEBUG
import Foundation

/// aufnahme.json im Format gymodo.sensoraufnahme/1 (Spec 6.3). Der Vertrag
/// zwischen Teilprojekt A (schreibt) und B (liest) -- Aenderungen hier sind
/// Formataenderungen und brauchen eine neue Kennung.
struct SensorAufnahmeDatei: Codable, Equatable {
    static let formatkennung = "gymodo.sensoraufnahme/1"

    enum Abschluss: String, Codable { case laeuft, gesichert, abgebrochen }

    struct Sensor: Codable, Equatable {
        var name: String
        var rateSollHz: Int
        var akkuProzent: Int?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(name, forKey: .name)
            try c.encode(rateSollHz, forKey: .rateSollHz)
            try c.encode(akkuProzent, forKey: .akkuProzent)
        }
    }

    struct Geraet: Codable, Equatable {
        var model: String
        var os: String
        var appBuild: String
    }

    struct Kontext: Codable, Equatable {
        var machineId: String
        var machineName: String
        var exerciseId: String
        var exerciseName: String
        var sessionId: String?
        var setId: String?
        var setIndex: Int?

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(machineId, forKey: .machineId)
            try c.encode(machineName, forKey: .machineName)
            try c.encode(exerciseId, forKey: .exerciseId)
            try c.encode(exerciseName, forKey: .exerciseName)
            try c.encode(sessionId, forKey: .sessionId)
            try c.encode(setId, forKey: .setId)
            try c.encode(setIndex, forKey: .setIndex)
        }
    }

    struct Label: Codable, Equatable {
        var weightKg: Double?
        /// Der am Rad bestaetigte Wert -- die Wahrheit, gegen die der
        /// Zaehler in B getestet wird.
        var reps: Int?
        var problemFlag: Bool?

        init(weightKg: Double? = nil, reps: Int? = nil, problemFlag: Bool? = nil) {
            self.weightKg = weightKg; self.reps = reps; self.problemFlag = problemFlag
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(weightKg, forKey: .weightKg)
            try c.encode(reps, forKey: .reps)
            try c.encode(problemFlag, forKey: .problemFlag)
        }
    }

    var format: String
    var startedAt: Date
    var endedAt: Date?
    var sensor: Sensor
    var geraet: Geraet
    var kontext: Kontext
    var label: Label
    var befestigung: String?
    var statistik: SensorStatistik.Ergebnis
    var abschluss: Abschluss

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(format, forKey: .format)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encode(endedAt, forKey: .endedAt)
        try c.encode(sensor, forKey: .sensor)
        try c.encode(geraet, forKey: .geraet)
        try c.encode(kontext, forKey: .kontext)
        try c.encode(label, forKey: .label)
        try c.encode(befestigung, forKey: .befestigung)
        try c.encode(statistik, forKey: .statistik)
        try c.encode(abschluss, forKey: .abschluss)
    }
}

/// ratentest-<zeit>.json: dieselbe Statistik ohne Messwerte (Spec 7.2).
struct SensorRatentestDatei: Codable, Equatable {
    static let formatkennung = "gymodo.sensorratentest/1"

    var format: String
    var startedAt: Date
    var endedAt: Date
    var sensor: SensorAufnahmeDatei.Sensor
    var geraet: SensorAufnahmeDatei.Geraet
    var statistik: SensorStatistik.Ergebnis
}
#endif
```

- [ ] **Step 4: `SensorAufnahme.swift`:**

```swift
#if DEBUG
import Foundation

/// Ein Aufnahme-Ordner auf der Platte (Spec 6). Kennt kein Bluetooth: bekommt
/// Messwerte und schreibt sie weg. Keine Nebenlaeufigkeit -- der Koordinator
/// ruft vom MainActor, und 100 Zeilen zu 70 Byte je Sekunde sind fuer einen
/// offenen FileHandle keine Last.
final class SensorAufnahme {
    enum Fehler: Error { case abgeschlossen }

    static let csvKopf = "t,ax,ay,az,gx,gy,gz,wx,wy,wz"

    let ordner: URL
    private(set) var datei: SensorAufnahmeDatei
    private let startT: TimeInterval
    private let zeitzone: TimeZone
    private var griff: FileHandle?
    private var lueckeSeit: TimeInterval?
    private var zeilenSeitSync = 0

    init(wurzel: URL, start: Date, startT: TimeInterval, sensor: SensorAufnahmeDatei.Sensor,
         geraet: SensorAufnahmeDatei.Geraet, kontext: SensorAufnahmeDatei.Kontext,
         befestigung: String?, zeitzone: TimeZone = .current) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: wurzel, withIntermediateDirectories: true)
        let basis = Zeitformat.ordnername(start, zeitzone: zeitzone)
        var nummer = 1
        var ordner = wurzel.appendingPathComponent(String(format: "%@-%02d", basis, nummer))
        while fm.fileExists(atPath: ordner.path) {
            nummer += 1
            ordner = wurzel.appendingPathComponent(String(format: "%@-%02d", basis, nummer))
        }
        try fm.createDirectory(at: ordner, withIntermediateDirectories: false)

        let csv = ordner.appendingPathComponent("messwerte.csv")
        try Data((Self.csvKopf + "\n").utf8).write(to: csv)
        griff = try FileHandle(forWritingTo: csv)
        try griff?.seekToEnd()

        self.ordner = ordner
        self.startT = startT
        self.zeitzone = zeitzone
        datei = SensorAufnahmeDatei(
            format: SensorAufnahmeDatei.formatkennung, startedAt: start, endedAt: nil,
            sensor: sensor, geraet: geraet, kontext: kontext, label: .init(),
            befestigung: befestigung, statistik: .leer, abschluss: .laeuft)
        try kopfSchreiben()
    }

    deinit { try? griff?.close() }

    func schreiben(_ messwert: SensorMesswert) throws {
        try anhaengen(Self.zeile(messwert, startT: startT))
    }

    func lueckeBeginnt(t: TimeInterval) {
        if lueckeSeit == nil { lueckeSeit = t }
    }

    func lueckeEndet(t: TimeInterval) throws {
        guard let von = lueckeSeit else { return }
        lueckeSeit = nil
        try anhaengen("# luecke \(Self.zahl(von - startT, stellen: 6))-\(Self.zahl(t - startT, stellen: 6))")
    }

    func abschliessen(_ abschluss: SensorAufnahmeDatei.Abschluss, kontext: SensorAufnahmeDatei.Kontext,
                      label: SensorAufnahmeDatei.Label, akkuProzent: Int?,
                      statistik: SensorStatistik.Ergebnis, ende: Date, endeT: TimeInterval) throws {
        // Eine offene Luecke reicht bis zum Ende: der Sensor kam nicht wieder.
        try lueckeEndet(t: endeT)
        try griff?.synchronize()
        try griff?.close()
        griff = nil
        datei.abschluss = abschluss
        datei.kontext = kontext
        datei.label = label
        datei.sensor.akkuProzent = akkuProzent ?? datei.sensor.akkuProzent
        datei.statistik = statistik
        datei.endedAt = ende
        try kopfSchreiben()
    }

    static func zeile(_ m: SensorMesswert, startT: TimeInterval) -> String {
        [zahl(m.t - startT, stellen: 6),
         zahl(m.beschleunigung.x, stellen: 4), zahl(m.beschleunigung.y, stellen: 4), zahl(m.beschleunigung.z, stellen: 4),
         zahl(m.drehrate.x, stellen: 2), zahl(m.drehrate.y, stellen: 2), zahl(m.drehrate.z, stellen: 2),
         zahl(m.winkel.x, stellen: 2), zahl(m.winkel.y, stellen: 2), zahl(m.winkel.z, stellen: 2)]
            .joined(separator: ",")
    }

    /// Punkt als Dezimaltrenner, egal welches Gebietsschema das Telefon hat:
    /// ein Komma in einer CSV mit Komma als Spaltentrenner zerlegt die Zeile.
    private static let posix = Locale(identifier: "en_US_POSIX")
    private static func zahl(_ wert: Double, stellen: Int) -> String {
        let text = String(format: "%.\(stellen)f", locale: posix, wert)
        // "-0.00" ist fuer einen Leser dieselbe Zahl, aber ein anderer Text.
        return text.allSatisfy({ "-0.".contains($0) }) && text.hasPrefix("-") ? String(text.dropFirst()) : text
    }

    private func anhaengen(_ zeile: String) throws {
        guard let griff else { throw Fehler.abgeschlossen }
        try griff.write(contentsOf: Data((zeile + "\n").utf8))
        zeilenSeitSync += 1
        // Einmal je Sekunde bei 50 Hz: nach einem Absturz fehlt hoechstens
        // das letzte Stueck (Spec 6.2).
        if zeilenSeitSync >= 50 {
            try griff.synchronize()
            zeilenSeitSync = 0
        }
    }

    private func kopfSchreiben() throws {
        let json = try JSONEncoder.testnotiz(zeitzone: zeitzone).encode(datei)
        try json.write(to: ordner.appendingPathComponent("aufnahme.json"), options: .atomic)
    }

    /// Beim App-Start: Ordner, die noch "laeuft" sagen, stammen aus einem
    /// Lauf, den es nicht mehr gibt. Ohne Nachtrag saehe B eine Aufnahme ohne
    /// Ende und muesste raten, ob sie vollstaendig ist.
    static func verwaisteNachtragen(wurzel: URL, zeitzone: TimeZone = .current) {
        let fm = FileManager.default
        guard let ordnerListe = try? fm.contentsOfDirectory(at: wurzel, includingPropertiesForKeys: nil) else { return }
        for ordner in ordnerListe {
            let kopf = ordner.appendingPathComponent("aufnahme.json")
            guard let daten = try? Data(contentsOf: kopf),
                  var datei = try? JSONDecoder.testnotiz().decode(SensorAufnahmeDatei.self, from: daten),
                  datei.abschluss == .laeuft
            else { continue }
            let csv = (try? String(contentsOf: ordner.appendingPathComponent("messwerte.csv"), encoding: .utf8)) ?? ""
            let letzteT = csv.split(separator: "\n")
                .last { !$0.hasPrefix("#") && !$0.hasPrefix("t,") }
                .flatMap { $0.split(separator: ",").first }
                .flatMap { Double($0) } ?? 0
            datei.abschluss = .abgebrochen
            datei.endedAt = datei.startedAt.addingTimeInterval(letzteT.rounded(.down))
            if let json = try? JSONEncoder.testnotiz(zeitzone: zeitzone).encode(datei) {
                try? json.write(to: kopf, options: .atomic)
            }
        }
    }
}
#endif
```

- [ ] **Step 5: Test grün.** Stimmt in `jedesFeldStehtImmerDa` nur der Leerraum nicht (`" : "` gegen `": "`), den Test an die tatsächliche Ausgabe von `.prettyPrinted` anpassen — geprüft wird das Vorhandensein von `null`, nicht die Einrückung.

- [ ] **Step 6: Commit** — `feat(sensor): Aufnahmeformat gymodo.sensoraufnahme/1 und Schreiber`

---

## Task 6: `SensorQuelle`, Leser, Abspiel-Quelle, verbindliches Beispiel

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorQuelle.swift`
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorAufnahmeLeser.swift`
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/AbspielSensorQuelle.swift`
- Create: `apps/ios-member/FitnessMemberTests/Fixtures/sensoraufnahme-beispiel/aufnahme.json`
- Create: `apps/ios-member/FitnessMemberTests/Fixtures/sensoraufnahme-beispiel/messwerte.csv`
- Modify: `apps/ios-member/project.yml` (Quellen des Test-Targets)
- Test: `apps/ios-member/FitnessMemberTests/AbspielSensorQuelleTests.swift`

**Interfaces:**
- Consumes: `SensorMesswert`, `SensorRate`, `SensorAufnahmeDatei`, `SensorAufnahme`.
- Produces:

```swift
struct SensorFund: Identifiable, Equatable, Sendable { let id: UUID; let name: String; let rssi: Int }

enum SensorZustand: Equatable, Sendable {
    enum Grund: Equatable, Sendable { case ausgeschaltet, verweigert, nichtUnterstuetzt }
    case aus
    case bluetoothNichtBereit(Grund)
    case sucht
    case mehrereGefunden([SensorFund])
    case verbindet
    case verbunden(name: String, akkuProzent: Int?)
    case getrennt(wirdNeuVerbunden: Bool)
    var istVerbunden: Bool { get }
    var name: String? { get }          // nur bei .verbunden
    var akkuProzent: Int? { get }      // nur bei .verbunden
}

enum SensorEreignis: Equatable, Sendable { case messwert(SensorMesswert); case zustand(SensorZustand) }

@MainActor protocol SensorQuelle: AnyObject, Sendable {
    var zustand: SensorZustand { get }
    var rate: SensorRate { get }
    var verworfeneBytes: Int { get }
    func ereignisse() -> AsyncStream<SensorEreignis>
    func verbinden()
    func waehlen(_ fund: SensorFund)
    func trennen()
    func vergessen()
    func rateSetzen(_ rate: SensorRate)
    func akkuLesen()
}

@MainActor final class SensorVerteiler {
    func strom() -> AsyncStream<SensorEreignis>
    func senden(_ ereignis: SensorEreignis)
}

enum SensorAufnahmeLeser {
    enum Eintrag: Equatable { case messwert(SensorMesswert); case luecke(von: TimeInterval, bis: TimeInterval) }
    static func lesen(ordner: URL) throws -> (datei: SensorAufnahmeDatei, eintraege: [Eintrag])
}

@MainActor @Observable final class AbspielSensorQuelle: SensorQuelle {
    enum Tempo { case sofort, echtzeit }
    init(ordner: URL, tempo: Tempo) throws
}
```

- [ ] **Step 1: Das verbindliche Beispiel anlegen.** `Fixtures/sensoraufnahme-beispiel/messwerte.csv`:

```
t,ax,ay,az,gx,gy,gz,wx,wy,wz
0.000000,0.0125,-0.9981,0.0312,1.25,-0.50,0.00,-88.50,1.25,0.00
0.020000,0.0131,-0.9977,0.0308,1.10,-0.55,0.06,-88.40,1.21,0.00
0.040000,0.0140,-1.1200,0.0300,2.50,-0.50,0.00,-88.25,1.20,0.00
# luecke 0.040000-2.500000
2.500000,0.0125,-0.9000,0.0312,-3.75,0.25,0.00,-87.50,1.25,0.00
2.520000,0.0125,-0.9981,0.0312,0.00,0.00,0.00,-88.50,1.25,0.00
```

`Fixtures/sensoraufnahme-beispiel/aufnahme.json`:

```json
{
  "abschluss" : "gesichert",
  "befestigung" : "Gewichtsstapel oben",
  "endedAt" : "2026-09-19T14:12:45+02:00",
  "format" : "gymodo.sensoraufnahme/1",
  "geraet" : { "appBuild" : "1", "model" : "iPhone17,1", "os" : "iOS 26.0" },
  "kontext" : {
    "exerciseId" : "e1", "exerciseName" : "Beidbeinig",
    "machineId" : "m1", "machineName" : "Beinpresse",
    "sessionId" : "6F1B1C9E-3C0B-4C58-9F5B-0B9B1B7C2A11",
    "setId" : "0D3C2E44-8A77-4E0A-8C35-5D2A0E6B9F02",
    "setIndex" : 2
  },
  "label" : { "problemFlag" : false, "reps" : 11, "weightKg" : 77.5 },
  "sensor" : { "akkuProzent" : 82, "name" : "WT901BLE67", "rateSollHz" : 50 },
  "startedAt" : "2026-09-19T14:12:03+02:00",
  "statistik" : {
    "abstandMs" : { "max" : 20, "median" : 20, "p95" : 20 },
    "luecken" : 1, "pakete" : 5, "rateIstHz" : 50, "verworfeneBytes" : 0
  }
}
```

- [ ] **Step 2: Den Ordner als Ordner ins Test-Bundle bringen.** XcodeGen flacht Ressourcen sonst ab; `aufnahme.json` und `messwerte.csv` lägen namenlos neben `testnotiz-beispiel.json`. In `project.yml` beim Target `FitnessMemberTests` die Quellen ersetzen:

```yaml
    sources:
      - path: FitnessMemberTests
        excludes:
          - "Fixtures/sensoraufnahme-beispiel"
      # Als Ordner-Referenz: der Abspiel-Test liest einen Aufnahme-ORDNER,
      # und abgeflachte Ressourcen haetten keine Ordnerstruktur mehr.
      - path: FitnessMemberTests/Fixtures/sensoraufnahme-beispiel
        type: folder
        buildPhase: resources
```

- [ ] **Step 3: Tests schreiben.** `AbspielSensorQuelleTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

@MainActor
struct AbspielSensorQuelleTests {
    private final class Marker {}

    private func beispiel() throws -> URL {
        try #require(Bundle(for: Marker.self).url(forResource: "sensoraufnahme-beispiel", withExtension: nil))
    }

    @Test func dasVerbindlicheBeispielIstLesbar() throws {
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: try beispiel())
        #expect(gelesen.datei.format == SensorAufnahmeDatei.formatkennung)
        #expect(gelesen.datei.label.reps == 11)
        #expect(gelesen.datei.abschluss == .gesichert)
        #expect(gelesen.eintraege.count == 6)
        #expect(gelesen.eintraege[3] == .luecke(von: 0.04, bis: 2.5))
        #expect(gelesen.eintraege[0] == .messwert(SensorMesswert(
            t: 0,
            beschleunigung: Vektor3(x: 0.0125, y: -0.9981, z: 0.0312),
            drehrate: Vektor3(x: 1.25, y: -0.5, z: 0),
            winkel: Vektor3(x: -88.5, y: 1.25, z: 0))))
    }

    @Test func unbekanntesFormatWirdAbgelehnt() throws {
        let kopie = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: try beispiel(), to: kopie)
        let kopf = kopie.appendingPathComponent("aufnahme.json")
        let text = try String(contentsOf: kopf, encoding: .utf8)
            .replacingOccurrences(of: "gymodo.sensoraufnahme/1", with: "gymodo.sensoraufnahme/9")
        try Data(text.utf8).write(to: kopf)
        #expect(throws: (any Error).self) { try SensorAufnahmeLeser.lesen(ordner: kopie) }
    }

    /// Der Vertragstest fuer B: was der Schreiber schreibt, liest der Leser.
    @Test func schreibenUndLesenErgibtDieselbenMesswerte() throws {
        let wurzel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let aufnahme = try SensorAufnahme(
            wurzel: wurzel, start: SensorAufnahmeTests.start, startT: 100,
            sensor: SensorAufnahmeTests.sensor, geraet: SensorAufnahmeTests.geraet,
            kontext: SensorAufnahmeTests.kontext, befestigung: nil, zeitzone: SensorAufnahmeTests.berlin)
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.00))
        try aufnahme.schreiben(SensorAufnahmeTests.messwert(t: 100.02))
        try aufnahme.abschliessen(.gesichert, kontext: SensorAufnahmeTests.kontext,
                                  label: .init(weightKg: 50, reps: 8, problemFlag: false), akkuProzent: nil,
                                  statistik: .leer, ende: SensorAufnahmeTests.start, endeT: 101)

        let gelesen = try SensorAufnahmeLeser.lesen(ordner: aufnahme.ordner)

        // t ist nach dem Roundtrip relativ zum Aufnahmestart.
        #expect(gelesen.eintraege == [
            .messwert(SensorAufnahmeTests.messwert(t: 0)),
            .messwert(SensorAufnahmeTests.messwert(t: 0.02)),
        ])
        #expect(gelesen.datei.label.reps == 8)
    }

    @Test func spieltMesswerteAbUndUeberspringtLuecken() async throws {
        let sut = try AbspielSensorQuelle(ordner: try beispiel(), tempo: .sofort)
        #expect(sut.zustand == .aus)
        let strom = sut.ereignisse()
        sut.verbinden()

        var messwerte: [SensorMesswert] = []
        var zustaende: [SensorZustand] = []
        for await ereignis in strom {
            switch ereignis {
            case .messwert(let m): messwerte.append(m)
            case .zustand(let z): zustaende.append(z)
            }
            if case .zustand(.getrennt(wirdNeuVerbunden: false)) = ereignis { break }
        }

        #expect(messwerte.map(\.t) == [0, 0.02, 0.04, 2.5, 2.52])
        // Die Luecke kommt als Zustandswechsel an der richtigen Stelle an.
        #expect(zustaende == [
            .verbunden(name: "WT901BLE67", akkuProzent: 82),
            .getrennt(wirdNeuVerbunden: true),
            .verbunden(name: "WT901BLE67", akkuProzent: 82),
            .getrennt(wirdNeuVerbunden: false),
        ])
    }
}
#endif
```

`SensorAufnahmeTests.start`, `.sensor`, `.geraet`, `.kontext`, `.berlin` und `.messwert(t:)` sind die `static`-Hilfen aus Task 5.

- [ ] **Step 4: `xcodegen generate`, Test laufen lassen, Fehlschlag sehen.**

- [ ] **Step 5: `SensorQuelle.swift`:**

```swift
#if DEBUG
import Foundation

struct SensorFund: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let rssi: Int
}

enum SensorZustand: Equatable, Sendable {
    enum Grund: Equatable, Sendable { case ausgeschaltet, verweigert, nichtUnterstuetzt }

    case aus
    case bluetoothNichtBereit(Grund)
    case sucht
    case mehrereGefunden([SensorFund])
    case verbindet
    case verbunden(name: String, akkuProzent: Int?)
    case getrennt(wirdNeuVerbunden: Bool)

    var istVerbunden: Bool {
        if case .verbunden = self { return true }
        return false
    }

    var name: String? {
        if case .verbunden(let name, _) = self { return name }
        return nil
    }

    var akkuProzent: Int? {
        if case .verbunden(_, let akku) = self { return akku }
        return nil
    }
}

/// Messwerte und Zustandswechsel in EINEM Strom: eine Luecke muss zwischen
/// den Messwerten ankommen, zwischen denen sie lag. Zwei Stroeme haetten
/// dafuer keine gemeinsame Reihenfolge.
enum SensorEreignis: Equatable, Sendable {
    case messwert(SensorMesswert)
    case zustand(SensorZustand)
}

/// Alles, was Verbraucher vom Sensor sehen (Spec 5.2). Hinter diesem
/// Protokoll stehen Bluetooth, die Abspiel-Quelle und die Attrappe der Tests.
@MainActor
protocol SensorQuelle: AnyObject, Sendable {
    var zustand: SensorZustand { get }
    var rate: SensorRate { get }
    var verworfeneBytes: Int { get }
    /// Ein eigener Strom je Aufruf.
    func ereignisse() -> AsyncStream<SensorEreignis>
    func verbinden()
    func waehlen(_ fund: SensorFund)
    func trennen()
    /// Trennt und loescht den gemerkten Sensor.
    func vergessen()
    func rateSetzen(_ rate: SensorRate)
    func akkuLesen()
}

/// Ein AsyncStream hat genau einen Leser. Zeile, Koordinator und spaeter der
/// Zaehler wollen gleichzeitig zuhoeren.
@MainActor
final class SensorVerteiler {
    private var abonnenten: [UUID: AsyncStream<SensorEreignis>.Continuation] = [:]

    func strom() -> AsyncStream<SensorEreignis> {
        let id = UUID()
        // Begrenzt: ein haengender Leser darf den Speicher nicht fuellen.
        let (strom, fortsetzung) = AsyncStream.makeStream(
            of: SensorEreignis.self, bufferingPolicy: .bufferingNewest(2048))
        abonnenten[id] = fortsetzung
        fortsetzung.onTermination = { [weak self] _ in
            Task { @MainActor in self?.abonnenten[id] = nil }
        }
        return strom
    }

    func senden(_ ereignis: SensorEreignis) {
        for abonnent in abonnenten.values { abonnent.yield(ereignis) }
    }
}
#endif
```

- [ ] **Step 6: `SensorAufnahmeLeser.swift`:**

```swift
#if DEBUG
import Foundation

enum SensorAufnahmeLeser {
    enum Fehler: Error { case unbekanntesFormat(String), kaputteZeile(String) }

    enum Eintrag: Equatable {
        case messwert(SensorMesswert)
        case luecke(von: TimeInterval, bis: TimeInterval)
    }

    static func lesen(ordner: URL) throws -> (datei: SensorAufnahmeDatei, eintraege: [Eintrag]) {
        let datei = try JSONDecoder.testnotiz().decode(
            SensorAufnahmeDatei.self, from: Data(contentsOf: ordner.appendingPathComponent("aufnahme.json")))
        // Unbekanntes ablehnen statt raten (Spec 6.3).
        guard datei.format == SensorAufnahmeDatei.formatkennung else {
            throw Fehler.unbekanntesFormat(datei.format)
        }
        let csv = try String(contentsOf: ordner.appendingPathComponent("messwerte.csv"), encoding: .utf8)
        var eintraege: [Eintrag] = []
        for zeile in csv.split(separator: "\n").dropFirst() {
            if zeile.hasPrefix("# luecke ") {
                let grenzen = zeile.dropFirst("# luecke ".count).split(separator: "-").compactMap { Double($0) }
                guard grenzen.count == 2 else { throw Fehler.kaputteZeile(String(zeile)) }
                eintraege.append(.luecke(von: grenzen[0], bis: grenzen[1]))
            } else if zeile.hasPrefix("#") {
                continue
            } else {
                let z = zeile.split(separator: ",").compactMap { Double($0) }
                guard z.count == 10 else { throw Fehler.kaputteZeile(String(zeile)) }
                eintraege.append(.messwert(SensorMesswert(
                    t: z[0],
                    beschleunigung: Vektor3(x: z[1], y: z[2], z: z[3]),
                    drehrate: Vektor3(x: z[4], y: z[5], z: z[6]),
                    winkel: Vektor3(x: z[7], y: z[8], z: z[9]))))
            }
        }
        return (datei, eintraege)
    }
}
#endif
```

- [ ] **Step 7: `AbspielSensorQuelle.swift`:**

```swift
#if DEBUG
import Foundation
import Observation

/// Eine Aufnahme als Sensor. Dafuer gibt es das Protokoll: der Zaehler in B
/// und das Spiel in D laufen im Simulator gegen echte Saetze, ohne Sensor.
@MainActor
@Observable
final class AbspielSensorQuelle: SensorQuelle {
    enum Tempo { case sofort, echtzeit }

    private(set) var zustand: SensorZustand = .aus
    let rate: SensorRate
    let verworfeneBytes = 0

    @ObservationIgnored private let datei: SensorAufnahmeDatei
    @ObservationIgnored private let eintraege: [SensorAufnahmeLeser.Eintrag]
    @ObservationIgnored private let tempo: Tempo
    @ObservationIgnored private let verteiler = SensorVerteiler()
    @ObservationIgnored private var lauf: Task<Void, Never>?

    init(ordner: URL, tempo: Tempo) throws {
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: ordner)
        datei = gelesen.datei
        eintraege = gelesen.eintraege
        rate = SensorRate(rawValue: gelesen.datei.sensor.rateSollHz) ?? .hz50
        self.tempo = tempo
    }

    func ereignisse() -> AsyncStream<SensorEreignis> { verteiler.strom() }

    func verbinden() {
        guard lauf == nil else { return }
        let verbunden = SensorZustand.verbunden(name: datei.sensor.name, akkuProzent: datei.sensor.akkuProzent)
        setze(verbunden)
        lauf = Task { [weak self, eintraege, tempo] in
            var zuletzt: TimeInterval = 0
            for eintrag in eintraege {
                guard let self, !Task.isCancelled else { return }
                switch eintrag {
                case .messwert(let messwert):
                    if tempo == .echtzeit, messwert.t > zuletzt {
                        try? await Task.sleep(for: .seconds(messwert.t - zuletzt))
                    }
                    zuletzt = messwert.t
                    self.verteiler.senden(.messwert(messwert))
                case .luecke(_, let bis):
                    self.setze(.getrennt(wirdNeuVerbunden: true))
                    if tempo == .echtzeit, bis > zuletzt {
                        try? await Task.sleep(for: .seconds(bis - zuletzt))
                    }
                    zuletzt = bis
                    self.setze(verbunden)
                }
            }
            self?.setze(.getrennt(wirdNeuVerbunden: false))
            self?.lauf = nil
        }
    }

    func trennen() {
        lauf?.cancel()
        lauf = nil
        setze(.aus)
    }

    // Eine Datei hat nichts zu waehlen, zu vergessen oder umzustellen.
    func waehlen(_ fund: SensorFund) {}
    func vergessen() { trennen() }
    func rateSetzen(_ rate: SensorRate) {}
    func akkuLesen() {}

    private func setze(_ neu: SensorZustand) {
        zustand = neu
        verteiler.senden(.zustand(neu))
    }
}
#endif
```

- [ ] **Step 8: Test grün.** Findet `Bundle.url(forResource:withExtension:)` den Ordner nicht, im gebauten `.xctest`-Bundle nachsehen (`find ~/Library/Developer/Xcode/DerivedData -name "sensoraufnahme-beispiel" -maxdepth 8`), ob er als Ordner angekommen ist; falls nicht, stimmt Step 2 nicht.

- [ ] **Step 9: Commit** — `feat(sensor): SensorQuelle, Abspiel-Quelle und das verbindliche Beispiel`

---

## Task 7: `SensorAufnahmeKoordinator`

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/SatzMitschnitt.swift` (immer kompiliert)
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/SensorAufnahmeKoordinator.swift`
- Test: `apps/ios-member/FitnessMemberTests/SensorAufnahmeKoordinatorTests.swift`

`SatzMitschnitt.swift` entsteht schon hier, weil der Koordinator es erfüllt; `GeraetModel` benutzt es erst in Task 8.

**Interfaces:**
- Consumes: alles aus Task 2–6.
- Produces:

```swift
// SatzMitschnitt.swift -- OHNE #if DEBUG
struct SatzMitschnittKontext: Equatable, Sendable {
    let machineId: String; let machineName: String; let exerciseId: String; let exerciseName: String
}
struct GesicherterSatz: Equatable, Sendable {
    let sessionId: UUID; let setId: UUID; let setIndex: Int
    let weightKg: Double; let reps: Int; let problemFlag: Bool
}
@MainActor protocol SatzMitschnitt: AnyObject {
    func eingabeBegonnen(_ kontext: SatzMitschnittKontext)
    func satzGesichert(_ satz: GesicherterSatz)
    func screenVerlassen()
}

// SensorAufnahmeKoordinator.swift -- #if DEBUG
@MainActor @Observable final class SensorAufnahmeKoordinator: SatzMitschnitt {
    let quelle: any SensorQuelle
    private(set) var aufnahmeLaeuft: Bool
    private(set) var fehler: String?
    private(set) var anzeigeRateHz: Double
    private(set) var statistik: SensorStatistik.Ergebnis      // seit dem Verbinden
    private(set) var verbundenSeit: Date?
    private(set) var ratentestRest: Int?                      // Sekunden, nil = laeuft nicht
    private(set) var letzterRatentest: URL?
    init(quelle: any SensorQuelle, wurzel: URL, geraet: SensorAufnahmeDatei.Geraet,
         einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         jetzt: @escaping () -> Date = { Date() })
    func starten()                                  // haengt sich an quelle.ereignisse()
    func empfangen(_ ereignis: SensorEreignis)      // synchroner Eingang, den die Tests benutzen
    func befestigung(fuer machineId: String) -> String
    func befestigungSetzen(_ text: String, fuer machineId: String)
    func ratentestStarten()
    static let ratentestDauer: TimeInterval = 300
}
```

- [ ] **Step 1: `SatzMitschnitt.swift`:**

```swift
import Foundation

/// Was der Satzpfad einem Mitschnitt erzaehlt -- und nicht mehr.
///
/// Immer kompiliert, obwohl der einzige Mitschnitt (der Sensor-Koordinator)
/// nur im Debug-Build existiert: GeraetModel wird auch im Release gebaut und
/// darf keinen Debug-Typ im Konstruktor tragen. Im Release ist der Parameter
/// nil und dieses Protokoll ohne Erfueller.
///
/// Keine Methode wirft und keine ist async: der Satz darf an einem
/// Mitschnitt weder scheitern noch auf ihn warten.
struct SatzMitschnittKontext: Equatable, Sendable {
    let machineId: String
    let machineName: String
    let exerciseId: String
    let exerciseName: String
}

struct GesicherterSatz: Equatable, Sendable {
    let sessionId: UUID
    let setId: UUID
    let setIndex: Int
    let weightKg: Double
    let reps: Int
    let problemFlag: Bool
}

@MainActor
protocol SatzMitschnitt: AnyObject {
    /// Die Raeder stehen da. Laeuft noch ein Mitschnitt (Uebungswechsel),
    /// gehoert er zum alten Kontext und wird abgebrochen.
    func eingabeBegonnen(_ kontext: SatzMitschnittKontext)
    func satzGesichert(_ satz: GesicherterSatz)
    func screenVerlassen()
}
```

- [ ] **Step 2: Tests schreiben.** `SensorAufnahmeKoordinatorTests.swift`:

```swift
#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

@MainActor
final class AttrappenQuelle: SensorQuelle {
    var zustand: SensorZustand = .aus
    var rate: SensorRate = .hz50
    var verworfeneBytes = 0
    let verteiler = SensorVerteiler()
    func ereignisse() -> AsyncStream<SensorEreignis> { verteiler.strom() }
    func verbinden() {}
    func waehlen(_ fund: SensorFund) {}
    func trennen() {}
    func vergessen() {}
    func rateSetzen(_ rate: SensorRate) { self.rate = rate }
    func akkuLesen() {}
}

@MainActor
struct SensorAufnahmeKoordinatorTests {
    static let verbunden = SensorZustand.verbunden(name: "WT901BLE67", akkuProzent: 82)
    static let kontext = SatzMitschnittKontext(machineId: "m1", machineName: "Beinpresse",
                                               exerciseId: "e1", exerciseName: "Beidbeinig")
    static let satz = GesicherterSatz(sessionId: UUID(), setId: UUID(), setIndex: 2,
                                      weightKg: 77.5, reps: 11, problemFlag: false)

    final class Uhr { var t: TimeInterval = 100 }

    private func aufbau(zustand: SensorZustand = verbunden, wurzel: URL? = nil)
        -> (sut: SensorAufnahmeKoordinator, quelle: AttrappenQuelle, wurzel: URL, uhr: Uhr) {
        let quelle = AttrappenQuelle()
        quelle.zustand = zustand
        let wurzel = wurzel ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let uhr = Uhr()
        let einstellungen = UserDefaults(suiteName: UUID().uuidString)!
        let sut = SensorAufnahmeKoordinator(
            quelle: quelle, wurzel: wurzel, geraet: SensorAufnahmeTests.geraet,
            einstellungen: einstellungen, uhr: { uhr.t }, jetzt: { SensorAufnahmeTests.start })
        return (sut, quelle, wurzel, uhr)
    }

    private func ordner(in wurzel: URL) -> [URL] {
        ((try? FileManager.default.contentsOfDirectory(at: wurzel, includingPropertiesForKeys: nil)) ?? [])
            .filter(\.hasDirectoryPath).sorted { $0.path < $1.path }
    }

    private func datei(_ ordner: URL) throws -> SensorAufnahmeDatei {
        try SensorAufnahmeLeser.lesen(ordner: ordner).datei
    }

    @Test func startetMitDerEingabeWennVerbunden() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        #expect(sut.aufnahmeLaeuft)
        #expect(try datei(ordner(in: wurzel)[0]).kontext.exerciseName == "Beidbeinig")
    }

    @Test func ohneVerbundenenSensorKeineAufnahme() {
        let (sut, _, wurzel, _) = aufbau(zustand: .aus)
        sut.eingabeBegonnen(Self.kontext)
        sut.satzGesichert(Self.satz)
        #expect(!sut.aufnahmeLaeuft)
        #expect(ordner(in: wurzel).isEmpty)
    }

    @Test func startetErstWennDerSensorSichMittenInDerEingabeVerbindet() {
        let (sut, quelle, wurzel, _) = aufbau(zustand: .sucht)
        sut.eingabeBegonnen(Self.kontext)
        #expect(!sut.aufnahmeLaeuft)
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        #expect(sut.aufnahmeLaeuft)
        #expect(ordner(in: wurzel).count == 1)
    }

    @Test func sichernSchliesstMitLabelsAb() throws {
        let (sut, _, wurzel, uhr) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        for n in 0..<5 { sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100 + Double(n) * 0.02))) }
        uhr.t = 130
        sut.satzGesichert(Self.satz)

        #expect(!sut.aufnahmeLaeuft)
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: ordner(in: wurzel)[0])
        #expect(gelesen.datei.abschluss == .gesichert)
        #expect(gelesen.datei.label == .init(weightKg: 77.5, reps: 11, problemFlag: false))
        #expect(gelesen.datei.kontext.setId == Self.satz.setId.uuidString)
        #expect(gelesen.datei.kontext.sessionId == Self.satz.sessionId.uuidString)
        #expect(gelesen.datei.kontext.setIndex == 2)
        #expect(gelesen.datei.statistik.pakete == 5)
        #expect(gelesen.datei.statistik.rateIstHz == 50)
        #expect(gelesen.eintraege.count == 5)
    }

    @Test func inDerPauseLaeuftNichtsUndDerNaechsteSatzBeginntNeu() {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.satzGesichert(Self.satz)
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 140)))   // Pause: geht nirgends hin
        sut.eingabeBegonnen(Self.kontext)
        #expect(ordner(in: wurzel).count == 2)
        #expect(sut.aufnahmeLaeuft)
    }

    @Test func verlassenOhneSichernBrichtAb() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.screenVerlassen()
        let d = try datei(ordner(in: wurzel)[0])
        #expect(d.abschluss == .abgebrochen)
        #expect(d.label.reps == nil)
        // Nach dem Verlassen wartet niemand mehr auf einen Sensor.
        sut.empfangen(.zustand(Self.verbunden))
        #expect(!sut.aufnahmeLaeuft)
    }

    @Test func neueEingabeBrichtEineLaufendeAufnahmeAb() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.eingabeBegonnen(SatzMitschnittKontext(machineId: "m1", machineName: "Beinpresse",
                                                  exerciseId: "e2", exerciseName: "Einbeinig"))
        let alle = ordner(in: wurzel)
        #expect(alle.count == 2)
        #expect(try datei(alle[0]).abschluss == .abgebrochen)
        #expect(try datei(alle[1]).kontext.exerciseId == "e2")
    }

    @Test func abrissSchreibtEineLueckeUndDieAufnahmeLaeuftWeiter() throws {
        let (sut, quelle, wurzel, uhr) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100)))
        uhr.t = 105
        quelle.zustand = .getrennt(wirdNeuVerbunden: true)
        sut.empfangen(.zustand(quelle.zustand))
        #expect(sut.aufnahmeLaeuft)
        uhr.t = 108
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 108)))
        sut.satzGesichert(Self.satz)

        let gelesen = try SensorAufnahmeLeser.lesen(ordner: ordner(in: wurzel)[0])
        #expect(gelesen.eintraege.contains(.luecke(von: 5, bis: 8)))
        #expect(gelesen.datei.statistik.luecken == 1)
        #expect(gelesen.datei.abschluss == .gesichert)
    }

    @Test func einSchreibfehlerLaesstDasSichernDurchlaufen() throws {
        // Die Wurzel ist eine DATEI: der Ordner laesst sich nicht anlegen.
        let kaputt = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: kaputt)
        let (sut, _, _, _) = aufbau(wurzel: kaputt)

        sut.eingabeBegonnen(Self.kontext)
        #expect(!sut.aufnahmeLaeuft)
        #expect(sut.fehler != nil)
        sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100)))
        sut.satzGesichert(Self.satz)     // wirft nicht, stuerzt nicht ab
        sut.screenVerlassen()
    }

    @Test func derFehlerVerschwindetMitDemNaechstenSatz() throws {
        let kaputt = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data("x".utf8).write(to: kaputt)
        let (sut, _, _, _) = aufbau(wurzel: kaputt)
        sut.eingabeBegonnen(Self.kontext)
        #expect(sut.fehler != nil)
        try FileManager.default.removeItem(at: kaputt)
        sut.eingabeBegonnen(Self.kontext)
        #expect(sut.fehler == nil)
        #expect(sut.aufnahmeLaeuft)
    }

    @Test func befestigungWirdJeGeraetGemerktUndLandetInDerAufnahme() throws {
        let (sut, _, wurzel, _) = aufbau()
        #expect(sut.befestigung(fuer: "m1") == "")
        sut.befestigungSetzen("Gewichtsstapel oben", fuer: "m1")
        #expect(sut.befestigung(fuer: "m1") == "Gewichtsstapel oben")
        #expect(sut.befestigung(fuer: "m2") == "")
        sut.eingabeBegonnen(Self.kontext)
        #expect(try datei(ordner(in: wurzel)[0]).befestigung == "Gewichtsstapel oben")
    }

    @Test func anzeigeRateFolgtDenMesswerten() {
        let (sut, _, _, uhr) = aufbau()
        for n in 0..<100 {
            uhr.t = 100 + Double(n) * 0.02
            sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: uhr.t)))
        }
        #expect(sut.anzeigeRateHz == 50)
        #expect(sut.statistik.pakete > 0)
    }

    @Test func ratentestSchreibtNachFuenfMinutenEineDatei() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.ratentestStarten()
        #expect(sut.ratentestRest == 300)
        // 10 Hz reichen, um die Logik zu pruefen, und halten den Test kurz.
        for n in 0...3001 { sut.empfangen(.messwert(SensorAufnahmeTests.messwert(t: 100 + Double(n) * 0.1))) }

        #expect(sut.ratentestRest == nil)
        let url = try #require(sut.letzterRatentest)
        #expect(url.deletingLastPathComponent().path == wurzel.path)
        #expect(url.lastPathComponent == "ratentest-2026-09-19-1412.json")
        let ergebnis = try JSONDecoder.testnotiz().decode(SensorRatentestDatei.self, from: Data(contentsOf: url))
        #expect(ergebnis.format == SensorRatentestDatei.formatkennung)
        #expect(ergebnis.statistik.rateIstHz == 10)
        #expect(ergebnis.sensor.name == "WT901BLE67")
    }
}
#endif
```

Der Ordnername im Ratentest setzt voraus, dass der Koordinator `Zeitformat.ordnername` mit `TimeZone.current` aufruft; läuft der Test-Mac nicht in `Europe/Berlin`, statt des festen Namens `url.lastPathComponent.hasPrefix("ratentest-")` prüfen.

- [ ] **Step 3: `xcodegen generate`, Test laufen lassen, Fehlschlag sehen.**

- [ ] **Step 4: `SensorAufnahmeKoordinator.swift`:**

```swift
#if DEBUG
import Foundation
import Observation
import os

/// Zwischen Satzpfad und Sensor (Spec 7.3). GeraetModel sagt, wo der Satz
/// steht; die Quelle sagt, was der Sensor schickt; hier wird daraus ein
/// Aufnahme-Ordner.
///
/// Nichts hier wirft nach aussen. Jeder Fehler landet in `fehler` und im
/// Log -- der Satz des Mitglieds haengt nicht an einem Debug-Mitschnitt.
@MainActor
@Observable
final class SensorAufnahmeKoordinator: SatzMitschnitt {
    static let ratentestDauer: TimeInterval = 300
    /// Eigene Kategorie: in der Konsole getrennt vom Tag-Protokoll filterbar.
    private static let log = Logger(subsystem: "de.gymtaro.member", category: "sensor")

    let quelle: any SensorQuelle
    private(set) var aufnahmeLaeuft = false
    private(set) var fehler: String?
    /// Einmal je Sekunde aktualisiert, nicht je Messwert: bei 50 Hz wuerde
    /// die Zeile sonst fuenfzigmal je Sekunde neu gezeichnet.
    private(set) var anzeigeRateHz: Double = 0
    private(set) var statistik: SensorStatistik.Ergebnis = .leer
    private(set) var verbundenSeit: Date?
    private(set) var ratentestRest: Int?
    private(set) var letzterRatentest: URL?

    @ObservationIgnored private let wurzel: URL
    @ObservationIgnored private let geraet: SensorAufnahmeDatei.Geraet
    @ObservationIgnored private let einstellungen: UserDefaults
    @ObservationIgnored private let uhr: () -> TimeInterval
    @ObservationIgnored private let jetzt: () -> Date

    @ObservationIgnored private var aufnahme: SensorAufnahme?
    @ObservationIgnored private var aufnahmeStatistik = SensorStatistik()
    @ObservationIgnored private var verworfenBeiStart = 0
    /// Gesetzt, solange die Raeder stehen. Verbindet sich der Sensor erst
    /// dann, beginnt die Aufnahme in diesem Moment (Spec 6.4).
    @ObservationIgnored private var offenerKontext: SatzMitschnittKontext?
    @ObservationIgnored private var gesamt = SensorStatistik()
    @ObservationIgnored private var letzteAnzeige: TimeInterval = 0
    @ObservationIgnored private var ratentest: (statistik: SensorStatistik, startT: TimeInterval?, start: Date, verworfen: Int)?
    @ObservationIgnored private var lauscher: Task<Void, Never>?

    init(quelle: any SensorQuelle, wurzel: URL, geraet: SensorAufnahmeDatei.Geraet,
         einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
         jetzt: @escaping () -> Date = { Date() }) {
        self.quelle = quelle
        self.wurzel = wurzel
        self.geraet = geraet
        self.einstellungen = einstellungen
        self.uhr = uhr
        self.jetzt = jetzt
    }

    /// Einmal beim App-Start. Getrennt vom init, damit Tests `empfangen`
    /// direkt und in fester Reihenfolge rufen koennen.
    func starten() {
        guard lauscher == nil else { return }
        SensorAufnahme.verwaisteNachtragen(wurzel: wurzel)
        let strom = quelle.ereignisse()
        lauscher = Task { [weak self] in
            for await ereignis in strom { self?.empfangen(ereignis) }
        }
    }

    // MARK: - SatzMitschnitt

    func eingabeBegonnen(_ kontext: SatzMitschnittKontext) {
        beenden(.abgebrochen, satz: nil)
        fehler = nil
        offenerKontext = kontext
        if quelle.zustand.istVerbunden { aufnahmeBeginnen() }
    }

    func satzGesichert(_ satz: GesicherterSatz) {
        beenden(.gesichert, satz: satz)
        offenerKontext = nil
    }

    func screenVerlassen() {
        beenden(.abgebrochen, satz: nil)
        offenerKontext = nil
    }

    // MARK: - Eingang

    func empfangen(_ ereignis: SensorEreignis) {
        switch ereignis {
        case .messwert(let messwert): messwertVerarbeiten(messwert)
        case .zustand(let zustand): zustandVerarbeiten(zustand)
        }
    }

    private func messwertVerarbeiten(_ messwert: SensorMesswert) {
        gesamt.erfassen(t: messwert.t)
        if messwert.t - letzteAnzeige >= 1 {
            letzteAnzeige = messwert.t
            anzeigeRateHz = gesamt.rateLetzteSekunde(bis: messwert.t)
            statistik = gesamt.ergebnis(verworfeneBytes: quelle.verworfeneBytes)
            if let test = ratentest, let startT = test.startT {
                ratentestRest = max(0, Int(Self.ratentestDauer - (messwert.t - startT)))
            }
        }

        if let aufnahme {
            aufnahmeStatistik.erfassen(t: messwert.t)
            do { try aufnahme.schreiben(messwert) } catch { abbrechen(wegen: error) }
        }

        if var test = ratentest {
            if test.startT == nil { test.startT = messwert.t }
            test.statistik.erfassen(t: messwert.t)
            ratentest = test
            if let startT = test.startT, messwert.t - startT >= Self.ratentestDauer { ratentestAbschliessen() }
        }
    }

    private func zustandVerarbeiten(_ zustand: SensorZustand) {
        if zustand.istVerbunden {
            if verbundenSeit == nil { verbundenSeit = jetzt() }
            if let aufnahme {
                do { try aufnahme.lueckeEndet(t: uhr()) } catch { abbrechen(wegen: error) }
            } else if offenerKontext != nil {
                aufnahmeBeginnen()
            }
        } else {
            anzeigeRateHz = 0
            if case .getrennt = zustand {
                gesamt.lueckeBegonnen()
                ratentest?.statistik.lueckeBegonnen()
                if let aufnahme {
                    aufnahmeStatistik.lueckeBegonnen()
                    aufnahme.lueckeBeginnt(t: uhr())
                }
            } else {
                verbundenSeit = nil
                gesamt = SensorStatistik()
                statistik = .leer
            }
        }
    }

    // MARK: - Aufnahme

    private func aufnahmeBeginnen() {
        guard aufnahme == nil, let kontext = offenerKontext else { return }
        do {
            aufnahme = try SensorAufnahme(
                wurzel: wurzel, start: jetzt(), startT: uhr(),
                sensor: .init(name: quelle.zustand.name ?? "unbekannt",
                              rateSollHz: quelle.rate.rawValue,
                              akkuProzent: quelle.zustand.akkuProzent),
                geraet: geraet,
                kontext: .init(machineId: kontext.machineId, machineName: kontext.machineName,
                               exerciseId: kontext.exerciseId, exerciseName: kontext.exerciseName,
                               sessionId: nil, setId: nil, setIndex: nil),
                befestigung: gemerkteBefestigung(kontext.machineId))
            aufnahmeStatistik = SensorStatistik()
            verworfenBeiStart = quelle.verworfeneBytes
            aufnahmeLaeuft = true
        } catch {
            abbrechen(wegen: error)
        }
    }

    private func beenden(_ abschluss: SensorAufnahmeDatei.Abschluss, satz: GesicherterSatz?) {
        guard let aufnahme else { return }
        self.aufnahme = nil
        aufnahmeLaeuft = false
        var kontext = aufnahme.datei.kontext
        kontext.sessionId = satz?.sessionId.uuidString
        kontext.setId = satz?.setId.uuidString
        kontext.setIndex = satz?.setIndex
        do {
            try aufnahme.abschliessen(
                abschluss, kontext: kontext,
                label: .init(weightKg: satz?.weightKg, reps: satz?.reps, problemFlag: satz?.problemFlag),
                akkuProzent: quelle.zustand.akkuProzent,
                statistik: aufnahmeStatistik.ergebnis(verworfeneBytes: quelle.verworfeneBytes - verworfenBeiStart),
                ende: jetzt(), endeT: uhr())
        } catch {
            melden(error)
        }
    }

    private func abbrechen(wegen error: Error) {
        melden(error)
        let kaputt = aufnahme
        aufnahme = nil
        aufnahmeLaeuft = false
        // Bester Versuch: der Ordner soll nicht als "laeuft" liegen bleiben.
        if let kaputt {
            try? kaputt.abschliessen(.abgebrochen, kontext: kaputt.datei.kontext, label: .init(),
                                     akkuProzent: nil, statistik: .leer, ende: jetzt(), endeT: uhr())
        }
    }

    private func melden(_ error: Error) {
        fehler = "Aufnahme fehlgeschlagen: \(error.localizedDescription)"
        Self.log.error("Sensoraufnahme: \(error.localizedDescription, privacy: .public)")
    }

    // MARK: - Befestigung

    private func schluessel(_ machineId: String) -> String { "sensor.befestigung.\(machineId)" }

    private func gemerkteBefestigung(_ machineId: String) -> String? {
        let text = einstellungen.string(forKey: schluessel(machineId)) ?? ""
        return text.isEmpty ? nil : text
    }

    func befestigung(fuer machineId: String) -> String { gemerkteBefestigung(machineId) ?? "" }

    func befestigungSetzen(_ text: String, fuer machineId: String) {
        einstellungen.set(text.trimmingCharacters(in: .whitespacesAndNewlines), forKey: schluessel(machineId))
    }

    // MARK: - Ratentest

    func ratentestStarten() {
        ratentest = (SensorStatistik(), nil, jetzt(), quelle.verworfeneBytes)
        ratentestRest = Int(Self.ratentestDauer)
        letzterRatentest = nil
    }

    private func ratentestAbschliessen() {
        guard let test = ratentest else { return }
        ratentest = nil
        ratentestRest = nil
        let datei = SensorRatentestDatei(
            format: SensorRatentestDatei.formatkennung, startedAt: test.start, endedAt: jetzt(),
            sensor: .init(name: quelle.zustand.name ?? "unbekannt", rateSollHz: quelle.rate.rawValue,
                          akkuProzent: quelle.zustand.akkuProzent),
            geraet: geraet,
            statistik: test.statistik.ergebnis(verworfeneBytes: quelle.verworfeneBytes - test.verworfen))
        do {
            try FileManager.default.createDirectory(at: wurzel, withIntermediateDirectories: true)
            let url = wurzel.appendingPathComponent("ratentest-\(Zeitformat.ordnername(test.start, zeitzone: .current)).json")
            try JSONEncoder.testnotiz().encode(datei).write(to: url, options: .atomic)
            letzterRatentest = url
        } catch {
            melden(error)
        }
    }
}
#endif
```

- [ ] **Step 5: Test grün.**

- [ ] **Step 6: Commit** — `feat(sensor): Koordinator zwischen Satzpfad und Aufnahme`

---

## Task 8: `GeraetModel` meldet dem Mitschnitt

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift` (Z. 105–115 Abhängigkeiten, Z. 148–165 `init`, Z. 363 `geraetGeoeffnet`, Z. 460–475 `uebungWechseln`, Z. 477–499 `satzSichern`, Z. 509 `pauseBeenden`)
- Test: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift`

**Interfaces:**
- Consumes: `SatzMitschnitt`, `SatzMitschnittKontext`, `GesicherterSatz` (Task 7).
- Produces: `GeraetModel.init(…, satzZiel:, mitschnitt: (any SatzMitschnitt)? = nil)` und `func screenVerlassen()`.

- [ ] **Step 1: Tests schreiben.** In `GeraetModelTests.swift` den Helfer `modell(…)` um einen Parameter erweitern und unten anhängen. Helfer (ersetzt den vorhandenen, einzige Änderung sind die zwei `mitschnitt`-Zeilen):

```swift
    private func modell(
        maschine: BootstrapResponse.Machine,
        bootstrap: BootstrapResponse,
        sessions: WorkoutSessionStore? = nil,
        loader: FakeGeraetLoader = FakeGeraetLoader(),
        enqueue: @escaping (PendingSetWrite) -> Void = { _ in },
        satzZiel: Int = Einstellungen.satzZielVorgabe,
        mitschnitt: (any SatzMitschnitt)? = nil
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: maschine,
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: bootstrap,
            loader: loader,
            sessions: sessions ?? WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: enqueue,
            satzZiel: { satzZiel },
            mitschnitt: mitschnitt
        )
    }
```

Neue Tests in derselben Suite, dazu die Attrappe auf Dateiebene:

```swift
    // MARK: - Mitschnitt

    @Test func oeffnenMeldetDieEingabeMitGeraetUndUebung() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        #expect(spion.ereignisse == [.eingabe(SatzMitschnittKontext(
            machineId: "m1", machineName: "Beinpresse", exerciseId: "e1", exerciseName: "Beidbeinig"))])
    }

    @Test func sichernMeldetGenauDenGeschriebenenSatz() async throws {
        let spion = MitschnittSpion()
        var geschrieben: [PendingSetWrite] = []
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)]),
                         enqueue: { geschrieben.append($0) }, mitschnitt: spion)
        sut.geraetGeoeffnet()

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        let write = try #require(geschrieben.first)
        #expect(spion.ereignisse.last == .gesichert(GesicherterSatz(
            sessionId: write.sessionId, setId: write.setId, setIndex: 1,
            weightKg: 77.5, reps: 11, problemFlag: false)))
    }

    @Test func nachDerPauseBeginntDieEingabeErneut() async {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(spion.eingaben == 1)          // in der Pause laeuft nichts
        sut.pauseBeenden()
        #expect(spion.eingaben == 2)
    }

    @Test func uebungswechselInDerEingabeMeldetDenNeuenKontext() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        sut.uebungWechseln(zu: "e2")
        #expect(spion.ereignisse.last == .eingabe(SatzMitschnittKontext(
            machineId: "m1", machineName: "Beinpresse", exerciseId: "e2", exerciseName: "Einbeinig")))
        #expect(spion.eingaben == 2)
    }

    @Test func uebungswechselAusDerPauseMeldetGenauEinmal() async {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        sut.uebungWechseln(zu: "e2")
        #expect(spion.eingaben == 2)
    }

    @Test func verlassenWirdWeitergereicht() {
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), mitschnitt: spion)
        sut.geraetGeoeffnet()
        sut.screenVerlassen()
        #expect(spion.ereignisse.last == .verlassen)
    }
```

Auf Dateiebene, neben `GeraetTestdaten`:

```swift
@MainActor
final class MitschnittSpion: SatzMitschnitt {
    enum Ereignis: Equatable {
        case eingabe(SatzMitschnittKontext)
        case gesichert(GesicherterSatz)
        case verlassen
    }
    var ereignisse: [Ereignis] = []
    var eingaben: Int { ereignisse.filter { if case .eingabe = $0 { true } else { false } }.count }

    func eingabeBegonnen(_ kontext: SatzMitschnittKontext) { ereignisse.append(.eingabe(kontext)) }
    func satzGesichert(_ satz: GesicherterSatz) { ereignisse.append(.gesichert(satz)) }
    func screenVerlassen() { ereignisse.append(.verlassen) }
}
```

- [ ] **Step 2: Test laufen lassen, Fehlschlag sehen** (`extra argument 'mitschnitt' in call`).

- [ ] **Step 3: `GeraetModel.swift` ändern.**

Zwei Wege führen zurück zu den Rädern: `pauseBeenden()` und `uebungWechseln(zu:)`. Beide rufen `mitschnittBeginnen()` ausdrücklich. Kein `didSet` auf `phase`: Beobachter an Eigenschaften einer `@Observable`-Klasse sind eine bekannte Stolperstelle des Makros, und zwei Aufrufstellen sind überschaubar.

Bei den Abhängigkeiten (nach `satzZielLesen`):

```swift
    /// Im Release immer nil. Im Debug-Build der Sensor-Koordinator; das
    /// Modell weiss davon nichts ausser diesen drei Aufrufen (Spec
    /// Sensor-Anbindung 7.3).
    private let mitschnitt: (any SatzMitschnitt)?
```

`init` bekommt als letzten Parameter `mitschnitt: (any SatzMitschnitt)? = nil` und die Zuweisung `self.mitschnitt = mitschnitt` direkt nach `satzZielLesen = satzZiel`.

`geraetGeoeffnet()`:

```swift
    func geraetGeoeffnet() {
        rueckblickOffen = rueckblickFaellig
        // Kommt das Mitglied per Zurueck wieder auf den Screen, laeuft .task
        // erneut und der Mitschnitt beginnt neu. In Pause und Abschluss
        // stehen keine Raeder da -- dort laeuft nichts.
        if phase == .eingabe { mitschnittBeginnen() }
    }
```

In `uebungWechseln(zu:)` als letzte Zeile der Funktion (nach `gewichtVomNutzer = false`, also wenn `uebungId` und `phase` schon neu sind):

```swift
        // Ein laufender Mitschnitt gehoert zur alten Uebung;
        // eingabeBegonnen bricht ihn ab und beginnt mit dem neuen Kontext.
        mitschnittBeginnen()
```

`pauseBeenden()` ersetzen:

```swift
    func pauseBeenden() {
        // Ablauf-Task und "Weiter" koennen beide feuern. Der zweite Aufruf
        // wuerde den eben begonnenen Mitschnitt sofort wieder abbrechen.
        guard phase != .eingabe else { return }
        phase = .eingabe
        mitschnittBeginnen()
    }
```

Der Kommentar über `pauseBeenden()` („"Weiter" und der Ablauf der Pause nehmen denselben Weg …") bleibt stehen, er stimmt weiter.

In `satzSichern` nach `gesicherteSaetze += 1`:

```swift
        // Nach dem Schreiben, mit genau den geschriebenen Werten: das ist
        // das Label der Aufnahme. Wirft nicht, wartet nicht.
        mitschnitt?.satzGesichert(GesicherterSatz(
            sessionId: geschrieben.sessionId, setId: geschrieben.setId,
            setIndex: geschrieben.body.setIndex,
            weightKg: gewicht, reps: wiederholungen, problemFlag: problemFlag))
```

Neu unter „Aktionen":

```swift
    private func mitschnittBeginnen() {
        mitschnitt?.eingabeBegonnen(SatzMitschnittKontext(
            machineId: maschine.id, machineName: maschine.equipmentModel.name,
            exerciseId: uebungId, exerciseName: aktiveUebung?.name ?? ""))
    }

    /// GeraetView ruft das aus onDisappear.
    func screenVerlassen() { mitschnitt?.screenVerlassen() }
```

Reihenfolge in `satzSichern` beachten: `mitschnitt?.satzGesichert` steht **vor** der Zeile `phase = …`, damit der Abschluss der Aufnahme nie hinter einem Phasenwechsel liegt.

- [ ] **Step 4: Ganze Suite `GeraetModelTests` grün** — alte Tests unverändert, neue dazu.

- [ ] **Step 5: Commit** — `feat(geraet): GeraetModel meldet Eingabe, Sichern und Verlassen an einen Mitschnitt`

---

## Task 9: `BluetoothSensorQuelle`

Kein Unit-Test: Core Bluetooth lässt sich nicht sinnvoll attrappieren. Geprüft wird durch Bauen hier und am Gerät in Task 11.

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/BluetoothSensorQuelle.swift`
- Modify: `apps/ios-member/project.yml` (Usage-Text)

**Interfaces:**
- Consumes: `SensorQuelle`, `SensorVerteiler`, `WitMotionParser`, `WitMotionBefehl`, `Akkustand`.
- Produces: `@MainActor @Observable final class BluetoothSensorQuelle: NSObject, SensorQuelle` mit `init(einstellungen: UserDefaults = .standard)`.

- [ ] **Step 1: `project.yml`.** Unter `INFOPLIST_KEY_NFCReaderUsageDescription` einfügen:

```yaml
        # Gilt je Target und steht damit auch im Release-Build, obwohl der
        # Code dahinter nur im Debug-Build existiert. Ohne den Schluessel
        # beendet iOS die App beim ersten CBCentralManager.
        INFOPLIST_KEY_NSBluetoothAlwaysUsageDescription: "gymodo verbindet sich mit deinem Bewegungssensor, um Wiederholungen zu erfassen."
```

- [ ] **Step 2: `BluetoothSensorQuelle.swift`.** Hat Task 1 andere UUIDs oder „`FFE5` steht nicht im Advertisement" ergeben, gelten die Werte aus Spec §4; `istSensor` deckt beide Fälle ab.

```swift
#if DEBUG
@preconcurrency import CoreBluetooth
import Foundation
import Observation

/// Die einzige Datei mit Core Bluetooth (Spec 5.3).
///
/// queue: nil -- alle Delegate-Aufrufe kommen auf dem Main Thread. Bei 100 Hz
/// und 20 Byte je Paket ist das keine Last, und es erspart jede Uebergabe
/// zwischen Threads. Die Konformitaeten sind deshalb @preconcurrency: Swift
/// prueft zur Laufzeit, dass der Aufruf wirklich vom MainActor kommt.
@MainActor
@Observable
final class BluetoothSensorQuelle: NSObject, SensorQuelle {
    private static let dienst = CBUUID(string: "FFE5")
    private static let daten = CBUUID(string: "FFE4")
    private static let befehle = CBUUID(string: "FFE9")
    private static let merkSchluessel = "sensor.peripheralId"

    private(set) var zustand: SensorZustand = .aus
    private(set) var rate: SensorRate = .hz50
    var verworfeneBytes: Int { parser.verworfeneBytes }

    @ObservationIgnored private let einstellungen: UserDefaults
    @ObservationIgnored private let verteiler = SensorVerteiler()
    @ObservationIgnored private var parser = WitMotionParser()
    /// Erst beim ersten verbinden() angelegt: der CBCentralManager loest die
    /// Berechtigungsfrage aus, und die soll nicht beim App-Start kommen.
    @ObservationIgnored private var zentrale: CBCentralManager?
    @ObservationIgnored private var peripheral: CBPeripheral?
    @ObservationIgnored private var schreibziel: CBCharacteristic?
    @ObservationIgnored private var funde: [UUID: CBPeripheral] = [:]
    @ObservationIgnored private var fundliste: [SensorFund] = []
    @ObservationIgnored private var sammelfrist: Task<Void, Never>?
    @ObservationIgnored private var akkuTakt: Task<Void, Never>?
    @ObservationIgnored private var akku: Int?
    @ObservationIgnored private var gewollt = false

    init(einstellungen: UserDefaults = .standard) {
        self.einstellungen = einstellungen
    }

    func ereignisse() -> AsyncStream<SensorEreignis> { verteiler.strom() }

    // MARK: - SensorQuelle

    func verbinden() {
        gewollt = true
        if let zentrale {
            zustandPruefen(zentrale)
        } else {
            zentrale = CBCentralManager(delegate: self, queue: nil)
        }
    }

    func waehlen(_ fund: SensorFund) {
        guard let gewaehlt = funde[fund.id] else { return }
        einstellungen.set(fund.id.uuidString, forKey: Self.merkSchluessel)
        verbindeMit(gewaehlt)
    }

    func trennen() {
        gewollt = false
        sammelfrist?.cancel()
        akkuTakt?.cancel()
        zentrale?.stopScan()
        if let peripheral { zentrale?.cancelPeripheralConnection(peripheral) }
        peripheral = nil
        schreibziel = nil
        setze(.aus)
    }

    func vergessen() {
        einstellungen.removeObject(forKey: Self.merkSchluessel)
        trennen()
    }

    func rateSetzen(_ neu: SensorRate) {
        rate = neu
        senden(.rate(neu))
    }

    func akkuLesen() { senden(.akkuLesen) }

    // MARK: - Ablauf

    private var gemerkt: UUID? {
        einstellungen.string(forKey: Self.merkSchluessel).flatMap(UUID.init(uuidString:))
    }

    private func zustandPruefen(_ zentrale: CBCentralManager) {
        guard gewollt else { return }
        switch zentrale.state {
        case .poweredOn: suchen(zentrale)
        case .poweredOff: setze(.bluetoothNichtBereit(.ausgeschaltet))
        case .unauthorized: setze(.bluetoothNichtBereit(.verweigert))
        case .unsupported: setze(.bluetoothNichtBereit(.nichtUnterstuetzt))
        default: break   // .unknown, .resetting: der naechste Aufruf kommt von selbst
        }
    }

    private func suchen(_ zentrale: CBCentralManager) {
        guard peripheral == nil else { return }
        funde = [:]; fundliste = []
        if let gemerkt, let bekannt = zentrale.retrievePeripherals(withIdentifiers: [gemerkt]).first {
            verbindeMit(bekannt)
            return
        }
        setze(.sucht)
        // Ohne Dienstfilter: nicht jeder WitMotion-Sensor nennt FFE5 im
        // Advertisement. Gefiltert wird in istSensor.
        zentrale.scanForPeripherals(withServices: nil)
    }

    nonisolated static func istSensor(name: String?, dienste: [String]) -> Bool {
        dienste.contains("FFE5") || (name?.hasPrefix("WT") ?? false)
    }

    private func verbindeMit(_ ziel: CBPeripheral) {
        sammelfrist?.cancel()
        zentrale?.stopScan()
        peripheral = ziel
        ziel.delegate = self
        setze(.verbindet)
        // Kein Timeout: Core Bluetooth haelt den Versuch, bis der Sensor da
        // ist oder trennen() gerufen wird (Spec 5.3).
        zentrale?.connect(ziel)
    }

    private func senden(_ befehl: WitMotionBefehl) {
        guard let peripheral, let schreibziel else { return }
        let art: CBCharacteristicWriteType =
            schreibziel.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
        peripheral.writeValue(befehl.bytes, for: schreibziel, type: art)
    }

    private func setze(_ neu: SensorZustand) {
        guard neu != zustand else { return }
        zustand = neu
        verteiler.senden(.zustand(neu))
    }

    private func nachDemAbonnieren(_ peripheral: CBPeripheral) {
        setze(.verbunden(name: peripheral.name ?? "WT901BLE", akkuProzent: akku))
        akkuTakt?.cancel()
        akkuTakt = Task { [weak self] in
            // Der Sensor verschluckt Befehle, die zu dicht aufeinander folgen.
            try? await Task.sleep(for: .milliseconds(200))
            guard let self, !Task.isCancelled else { return }
            // Ohne "Konfiguration speichern": ein Fehlversuch verstellt den
            // Sensor so nie dauerhaft (Spec 5.3).
            self.senden(.rate(self.rate))
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                self.senden(.akkuLesen)
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }
}

extension BluetoothSensorQuelle: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        zustandPruefen(central)
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let dienste = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []).map(\.uuidString)
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard Self.istSensor(name: name, dienste: dienste), funde[peripheral.identifier] == nil else { return }

        // Ein gemerkter Sensor, den retrievePeripherals nicht kannte: nur
        // auf ihn warten, keinen fremden nehmen (Spec 8).
        if let gemerkt {
            if peripheral.identifier == gemerkt { verbindeMit(peripheral) }
            return
        }
        funde[peripheral.identifier] = peripheral
        fundliste.append(SensorFund(id: peripheral.identifier, name: name ?? "Sensor", rssi: RSSI.intValue))
        guard sammelfrist == nil else { return }
        // Zwei Sekunden sammeln, damit ein zweiter Sensor in Reichweite die
        // Auswahl oeffnet statt dem ersten still zu unterliegen.
        sammelfrist = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self, !Task.isCancelled else { return }
            self.sammelfrist = nil
            if self.fundliste.count == 1, let einziger = self.fundliste.first {
                self.waehlen(einziger)
            } else {
                self.setze(.mehrereGefunden(self.fundliste.sorted { $0.rssi > $1.rssi }))
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        parser = WitMotionParser()
        peripheral.discoverServices([Self.dienst])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        wiederVerbinden(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        wiederVerbinden(peripheral)
    }

    private func wiederVerbinden(_ peripheral: CBPeripheral) {
        akkuTakt?.cancel()
        schreibziel = nil
        guard gewollt, self.peripheral?.identifier == peripheral.identifier else { return }
        setze(.getrennt(wirdNeuVerbunden: true))
        zentrale?.connect(peripheral)
    }
}

extension BluetoothSensorQuelle: @preconcurrency CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let dienst = peripheral.services?.first(where: { $0.uuid == Self.dienst }) else { return }
        peripheral.discoverCharacteristics([Self.daten, Self.befehle], for: dienst)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for merkmal in service.characteristics ?? [] {
            if merkmal.uuid == Self.befehle { schreibziel = merkmal }
            if merkmal.uuid == Self.daten { peripheral.setNotifyValue(true, for: merkmal) }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == Self.daten, characteristic.isNotifying else { return }
        nachDemAbonnieren(peripheral)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // ZUERST die Uhr: alles, was davor steht, landet als Jitter in den
        // Daten (Spec 5.3).
        let t = ProcessInfo.processInfo.systemUptime
        guard let wert = characteristic.value else { return }
        for paket in parser.lesen(wert) {
            switch paket {
            case .messwert(let beschleunigung, let drehrate, let winkel):
                verteiler.senden(.messwert(SensorMesswert(
                    t: t, beschleunigung: beschleunigung, drehrate: drehrate, winkel: winkel)))
            case .register(let adresse, let werte):
                guard adresse == Akkustand.register, let roh = werte.first else { continue }
                akku = Akkustand.prozent(hundertstelVolt: Int(roh))
                if case .verbunden(let name, _) = zustand { setze(.verbunden(name: name, akkuProzent: akku)) }
            }
        }
    }
}
#endif
```

- [ ] **Step 3: Nur falls Task 1 ein Entsperren verlangt:** in `nachDemAbonnieren` und `rateSetzen` vor `.rate` ein `senden(.entsperren)` mit 100 ms Abstand setzen.

- [ ] **Step 4: `xcodegen generate`, bauen.**
  `xcodebuild build -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → BUILD SUCCEEDED, ohne Concurrency-Fehler. Meldet Swift 6 an den `@preconcurrency`-Konformitäten einen Fehler, ist der Ausweg **nicht** `nonisolated(unsafe)` quer durch die Klasse, sondern `nonisolated` Delegate-Methoden, die ihren Rumpf in `MainActor.assumeIsolated { … }` fassen; die Uhr in `didUpdateValueFor` bleibt dabei die erste Zeile außerhalb des Blocks.

- [ ] **Step 5: Release baut.**
  `xcodebuild build -scheme FitnessMember -configuration Release -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED. Beweist, dass nichts außerhalb von `#if DEBUG` einen Debug-Typ anfasst.

- [ ] **Step 6: Commit** — `feat(sensor): Bluetooth-Anbindung des WitMotion-Sensors`

---

## Task 10: Sensor-Zeile, Diagnose-Blatt, Verdrahtung

**Files:**
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/SensorZeile.swift`
- Create: `apps/ios-member/FitnessMember/Screens/Geraet/SensorDiagnoseBlatt.swift`
- Modify: `apps/ios-member/FitnessMember/FitnessMemberApp.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift` (`modell(machineId:exerciseId:token:)`, Z. 566–580)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (`inhalt`, Modifier am `ScrollView`, `testnotizScreen`)

**Interfaces:**
- Consumes: `SensorAufnahmeKoordinator` (Task 7), `BluetoothSensorQuelle` (Task 9), `GeraetModel.screenVerlassen()` (Task 8).
- Produces: `struct SensorZeile: View { let machineId: String }`, `struct SensorDiagnoseBlatt: View { let machineId: String }`. Beide lesen `@Environment(SensorAufnahmeKoordinator.self)`.

Die reine Ableitung „welcher Text steht in der Zeile" bekommt einen Test, der View nicht.

- [ ] **Step 1: Test für den Zeilentext.** An `SensorAufnahmeKoordinatorTests.swift` anhängen (eigene Suite in derselben Datei):

```swift
#if DEBUG
struct SensorZeilenTextTests {
    @Test func texteJeZustand() {
        #expect(SensorZeile.text(zustand: .aus, rateHz: 0) == "Sensor verbinden")
        #expect(SensorZeile.text(zustand: .sucht, rateHz: 0) == "Sensor wird gesucht …")
        #expect(SensorZeile.text(zustand: .verbindet, rateHz: 0) == "Sensor wird gesucht …")
        #expect(SensorZeile.text(zustand: .verbunden(name: "WT901BLE67", akkuProzent: 82), rateHz: 49.8)
            == "WT901BLE67 · 49,8 Hz · 82 %")
        #expect(SensorZeile.text(zustand: .verbunden(name: "WT901BLE67", akkuProzent: nil), rateHz: 50)
            == "WT901BLE67 · 50,0 Hz")
        #expect(SensorZeile.text(zustand: .getrennt(wirdNeuVerbunden: true), rateHz: 0)
            == "Sensor getrennt, wird neu verbunden …")
        #expect(SensorZeile.text(zustand: .bluetoothNichtBereit(.ausgeschaltet), rateHz: 0)
            == "Bluetooth ist ausgeschaltet")
        #expect(SensorZeile.text(zustand: .bluetoothNichtBereit(.verweigert), rateHz: 0)
            == "Bluetooth ist für gymodo nicht erlaubt")
    }
}
#endif
```

- [ ] **Step 2: Fehlschlag sehen, dann `SensorZeile.swift`:**

```swift
#if DEBUG
import SwiftUI

/// Eine Zeile ueber den Raedern, nur im Debug-Build (Spec 7.1). Kostet 44 pt,
/// die der Satzpfad auf einem 667-pt-iPhone nicht uebrig hat -- im
/// Debug-Build scrollt die Seite dort deshalb. Das ist hingenommen: die
/// Zeile ist Werkzeug, kein Produkt.
struct SensorZeile: View {
    let machineId: String

    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @State private var diagnoseOffen = false

    var body: some View {
        let zustand = koordinator.quelle.zustand
        Button(action: tippen) {
            HStack(spacing: DesignSystem.Spacing.s8) {
                if koordinator.aufnahmeLaeuft {
                    Circle().fill(DesignSystem.Color.danger).frame(width: 8, height: 8)
                        .accessibilityLabel("Aufnahme läuft")
                }
                Text(koordinator.fehler ?? Self.text(zustand: zustand, rateHz: koordinator.anzeigeRateHz))
                    .font(.system(size: 13).monospacedDigit())
                    .foregroundStyle(koordinator.fehler == nil
                        ? DesignSystem.Color.textMuted : DesignSystem.Color.danger)
                    .lineLimit(1)
                Spacer()
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $diagnoseOffen) { SensorDiagnoseBlatt(machineId: machineId) }
        .sheet(isPresented: .constant(auswahl != nil)) { auswahlBlatt }
    }

    private var auswahl: [SensorFund]? {
        if case .mehrereGefunden(let funde) = koordinator.quelle.zustand { return funde }
        return nil
    }

    private var auswahlBlatt: some View {
        NavigationStack {
            List(auswahl ?? []) { fund in
                Button("\(fund.name) · \(fund.rssi) dBm") { koordinator.quelle.waehlen(fund) }
            }
            .navigationTitle("Sensor wählen")
            .toolbar { Button("Abbrechen") { koordinator.quelle.trennen() } }
        }
        .presentationDetents([.medium])
    }

    private func tippen() {
        switch koordinator.quelle.zustand {
        case .aus: koordinator.quelle.verbinden()
        case .sucht, .verbindet: koordinator.quelle.trennen()
        case .bluetoothNichtBereit(.verweigert):
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        case .bluetoothNichtBereit: koordinator.quelle.verbinden()
        case .verbunden, .getrennt: diagnoseOffen = true
        case .mehrereGefunden: break
        }
    }

    static func text(zustand: SensorZustand, rateHz: Double) -> String {
        switch zustand {
        case .aus: "Sensor verbinden"
        case .sucht, .verbindet, .mehrereGefunden: "Sensor wird gesucht …"
        case .verbunden(let name, let akku):
            // Komma wie ueberall in der App; Zahlformat.gewicht laesst ganze
            // Zahlen ohne Nachkommastelle, hier soll die Breite stillstehen.
            [name, String(format: "%.1f Hz", locale: Locale(identifier: "de_DE"), rateHz),
             akku.map { "\($0) %" }].compactMap { $0 }.joined(separator: " · ")
        case .getrennt: "Sensor getrennt, wird neu verbunden …"
        case .bluetoothNichtBereit(.ausgeschaltet): "Bluetooth ist ausgeschaltet"
        case .bluetoothNichtBereit(.verweigert): "Bluetooth ist für gymodo nicht erlaubt"
        case .bluetoothNichtBereit(.nichtUnterstuetzt): "Dieses Gerät hat kein Bluetooth"
        }
    }
}
#endif
```

- [ ] **Step 3: `SensorDiagnoseBlatt.swift`:**

```swift
#if DEBUG
import SwiftUI

/// Diagnose und Ratentest (Spec 7.2). Bewusst eine schlichte Form aus
/// Systembausteinen: das Blatt ist Werkzeug und folgt keinem Artboard.
struct SensorDiagnoseBlatt: View {
    let machineId: String

    @Environment(SensorAufnahmeKoordinator.self) private var koordinator
    @Environment(\.dismiss) private var schliessen
    @State private var befestigung = ""

    var body: some View {
        let s = koordinator.statistik
        NavigationStack {
            Form {
                Section("Verbindung") {
                    zeile("Sensor", koordinator.quelle.zustand.name ?? "–")
                    zeile("Akku", koordinator.quelle.zustand.akkuProzent.map { "\($0) %" } ?? "–")
                    if let seit = koordinator.verbundenSeit {
                        zeile("Verbunden seit", seit.formatted(date: .omitted, time: .standard))
                    }
                }
                Section("Was am iPhone ankommt") {
                    zeile("Ist-Rate (letzte Sekunde)", "\(Int(koordinator.anzeigeRateHz)) Hz")
                    zeile("Ist-Rate (gesamt)", "\(s.rateIstHz) Hz")
                    zeile("Abstand Median", "\(s.abstandMs.median) ms")
                    zeile("Abstand p95", "\(s.abstandMs.p95) ms")
                    zeile("Abstand Maximum", "\(s.abstandMs.max) ms")
                    zeile("Pakete", "\(s.pakete)")
                    zeile("Lücken", "\(s.luecken)")
                    zeile("Verworfene Bytes", "\(s.verworfeneBytes)")
                }
                Section("Rate am Sensor") {
                    Picker("Soll-Rate", selection: Binding(
                        get: { koordinator.quelle.rate },
                        set: { koordinator.quelle.rateSetzen($0) })) {
                        ForEach(SensorRate.allCases, id: \.self) { Text("\($0.rawValue) Hz").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section("5-Minuten-Test") {
                    if let rest = koordinator.ratentestRest {
                        zeile("Läuft", "noch \(rest / 60):\(String(format: "%02d", rest % 60))")
                    } else {
                        Button("Test starten") { koordinator.ratentestStarten() }
                            .disabled(!koordinator.quelle.zustand.istVerbunden)
                    }
                    if let datei = koordinator.letzterRatentest {
                        zeile("Geschrieben", datei.lastPathComponent)
                    }
                }
                Section {
                    TextField("z. B. Gewichtsstapel oben", text: $befestigung)
                        .onSubmit { koordinator.befestigungSetzen(befestigung, fuer: machineId) }
                } header: {
                    Text("Befestigung an diesem Gerät")
                } footer: {
                    Text("Gilt ab der nächsten Aufnahme. Ohne diese Angabe lassen sich die Aufnahmen später nicht gruppieren.")
                }
                Section {
                    Button("Sensor vergessen", role: .destructive) {
                        koordinator.quelle.vergessen()
                        schliessen()
                    }
                }
            }
            .navigationTitle("Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Fertig") { schliessen() } }
            .onAppear { befestigung = koordinator.befestigung(fuer: machineId) }
            // Auch ohne Return: wer das Blatt schliesst, meint den Text so.
            .onDisappear { koordinator.befestigungSetzen(befestigung, fuer: machineId) }
        }
    }

    private func zeile(_ titel: String, _ wert: String) -> some View {
        LabeledContent(titel) { Text(wert).monospacedDigit() }
    }
}
#endif
```

- [ ] **Step 4: `FitnessMemberApp.swift` verdrahten.** Nach `@State private var pendingTagStore`:

```swift
    #if DEBUG
    /// Eine Instanz fuer die ganze App: die Verbindung ueberlebt den Wechsel
    /// zwischen Geraeten (Spec Sensor-Anbindung 5.3). Der CBCentralManager
    /// entsteht erst beim Tap auf "Sensor verbinden".
    @State private var sensorAufnahme = SensorAufnahmeKoordinator(
        quelle: BluetoothSensorQuelle(),
        wurzel: URL.documentsDirectory.appendingPathComponent("Sensoraufnahmen"),
        geraet: .init(
            model: Laufzeitkontext.modellkennung(),
            os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""))
    #endif
```

Im `body` kommt der Environment-Eintrag als eigener Modifier dazu. Weil `#if` mitten in einer Modifier-Kette unleserlich wird, über eine kleine Erweiterung am Dateiende:

```swift
private extension View {
    #if DEBUG
    func sensorInstallieren(_ koordinator: SensorAufnahmeKoordinator) -> some View {
        environment(koordinator).task { koordinator.starten() }
    }
    #endif
}
```

und in der Kette nach `.environment(pendingTagStore)`:

```swift
                #if DEBUG
                .sensorInstallieren(sensorAufnahme)
                #endif
```

Lässt der Compiler `#if` an dieser Stelle der Kette nicht zu (Postfix-`#if` verlangt, dass der Block mit einem Modifier beginnt — das tut er), bleibt es so. `import UIKit` ergänzen, falls `UIDevice` nicht aufgelöst wird.

- [ ] **Step 5: `TrainingRootView.swift`.** Bei den anderen `@Environment`-Zeilen:

```swift
    #if DEBUG
    @Environment(SensorAufnahmeKoordinator.self) private var sensorAufnahme
    #endif
```

In `modell(machineId:exerciseId:token:)` das `return GeraetModel(…)` ersetzen:

```swift
        // Im Release gibt es keinen Mitschnitt; im Debug-Build ist es der
        // Sensor-Koordinator.
        var mitschnitt: (any SatzMitschnitt)?
        #if DEBUG
        mitschnitt = sensorAufnahme
        #endif
        return GeraetModel(
            maschine: maschine, uebungId: gewaehlt, token: token,
            bootstrap: bootstrap, loader: apiClient, sessions: sessions,
            enqueue: { katalog.enqueue($0); Task { await katalog.flushPending() } },
            mitschnitt: mitschnitt
        )
```

Vorher mit `grep -rn "TrainingRootView(" apps/ios-member` prüfen, ob es Previews oder Tests gibt, die `TrainingRootView` ohne das neue Environment aufbauen; sie bekommen im Debug-Build `.environment(SensorAufnahmeKoordinator(…))` mit einer `AbspielSensorQuelle` oder stürzen sonst beim ersten Zugriff ab.

- [ ] **Step 6: `GeraetView.swift`.** In `inhalt`, im letzten `else`-Zweig vor `einstellung`:

```swift
            #if DEBUG
            SensorZeile(machineId: modell.maschine.id)
            #endif
```

Bei den `@Environment`-Zeilen:

```swift
    #if DEBUG
    @Environment(SensorAufnahmeKoordinator.self) private var sensorAufnahme
    #endif
```

Am `ScrollView`, direkt vor `.testnotizScreen(`:

```swift
        // Ein verlassener Screen ohne gesicherten Satz ist ein abgebrochener
        // Mitschnitt. Im Release ist das ein Aufruf auf nil.
        .onDisappear { modell.screenVerlassen() }
        #if DEBUG
        // Ohne Hintergrundmodus reisst der Mitschnitt ab, sobald der
        // Bildschirm sperrt (Spec Sensor-Anbindung 5.3). Zurueck auf false
        // beim Verlassen, sonst bleibt das Telefon in der ganzen App wach.
        .onChange(of: sensorAufnahme.quelle.zustand.istVerbunden, initial: true) { _, verbunden in
            UIApplication.shared.isIdleTimerDisabled = verbunden
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        #endif
```

Den Testnotiz-Kontext erweitern. Weil das Dictionary-Literal kein `#if` verträgt, eine berechnete Eigenschaft:

```swift
    private var testnotizKontext: [String: String] {
        var kontext = [
            "machineId": modell.maschine.id,
            "exerciseId": modell.uebungId,
            // Nur der Fallname: .pause traegt einen Timer, dessen Text sich jede Sekunde aendert.
            "phase": String(String(describing: modell.phase).prefix { $0 != "(" }),
        ]
        #if DEBUG
        kontext["sensor"] = sensorAufnahme.quelle.zustand.istVerbunden ? "verbunden" : "aus"
        #endif
        return kontext
    }
```

und `.testnotizScreen(kontext: testnotizKontext)`.

- [ ] **Step 7: `xcodegen generate`, volle iOS-Suite und Release-Build.**
  `xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` → alle grün.
  `xcodebuild build -scheme FitnessMember -configuration Release -destination 'generic/platform=iOS Simulator'` → BUILD SUCCEEDED.

- [ ] **Step 8: Sichtcheck im Simulator.** App im Debug-Build starten, Training starten, Gerät öffnen. Die Zeile „Sensor verbinden" steht über den Einstellwerten. Tippen: iOS fragt nach Bluetooth; im Simulator steht danach „Dieses Gerät hat kein Bluetooth" oder „Bluetooth ist ausgeschaltet". „Satz sichern" funktioniert wie vorher. Screenshot in den Bericht.

- [ ] **Step 9: Commit** — `feat(sensor): Sensor-Zeile und Diagnose im Geraete-Screen, nur Debug`

---

## Task 11: Am Gerät prüfen, Spec §4 Punkt 7, volles Testset

Braucht Tim, das iPhone und den Sensor. Build aufs Gerät aus Xcode (Debug).

**Files:**
- Modify: `docs/superpowers/specs/2026-09-19-sensor-anbindung-aufzeichnung-design.md` (§4 Punkt 7, Standardrate)
- Eventuell Modify: `apps/ios-member/FitnessMember/Workout/Sensor/BluetoothSensorQuelle.swift` (Standardrate)

- [ ] **Step 1: Checkliste aus Spec §9, Punkte 1–11.** Je Punkt „geht" oder der Fund mit Ordnername. Funde, die Code brauchen, werden als eigener Commit vor Step 3 behoben (`fix(sensor): …`), mit Test, wo die Ursache in einer reinen Schicht liegt.

| # | Prüfung | Erwartet |
|---|---|---|
| 1 | Verbinden | Zeile zeigt Name, Ist-Rate, Akku |
| 2 | Rate 20 / 50 / 100 Hz in der Diagnose | Ist-Rate folgt binnen zwei Sekunden |
| 3 | Drei Sätze sichern | drei Ordner, `gesichert`, Labels stimmen, CSV plausibel (eine Achse ≈ ±1 g in Ruhe) |
| 4 | Screen ohne Sichern verlassen | Ordner mit `abgebrochen`, `reps: null` |
| 5 | Sensor im Satz aus- und einschalten | `# luecke`-Zeile, Aufnahme läuft weiter, Satz lässt sich sichern |
| 6 | Bluetooth am iPhone ausschalten | Klartext in der Zeile, Satz lässt sich sichern |
| 7 | App in den Hintergrund und zurück | Verhalten notieren (Eingang für B) |
| 8 | Bildschirm | bleibt wach, solange verbunden; sperrt normal nach dem Verlassen |
| 9 | 5-Minuten-Test bei 20, 50, 100 Hz | drei `ratentest-*.json` |
| 10 | Finder und Dateien-App | `Sensoraufnahmen/` sichtbar neben `Testnotizen/` |
| 11 | Release-Build aufs Gerät oder in den Simulator | keine Sensor-Zeile, keine Bluetooth-Abfrage |

- [ ] **Step 2: Spec §4 Punkt 7 eintragen.** Aus den drei Ratentest-Dateien: Ist-Rate, Median, p95, Maximum je Soll-Rate, und die Empfehlung für die Standardrate. Ist sie nicht 50 Hz, `rate` in `BluetoothSensorQuelle` und den Satz „Bis dahin gilt 50 Hz" in der Spec anpassen. Die Beobachtung aus Punkt 7 der Checkliste kommt in Spec §11 Punkt 1.

- [ ] **Step 3: Volles Testset.**

```bash
df -h /System/Volumes/Data
pnpm typecheck
pnpm test
pnpm test:integration
cd apps/ios-member && xcodebuild test -scheme FitnessMember -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Alles grün. `pnpm test:integration` braucht das lokale Supabase in Docker und `.env` in der Repo-Wurzel.

- [ ] **Step 4: Commit** — `docs(sensor): Rate am iPhone gemessen, Geraetecheck abgehakt`

- [ ] **Step 5: Bericht an Tim.** Was geht, was offen ist, wo die ersten Aufnahmen liegen. Das Abschlusskriterium 2 der Spec (§10: 20 gesicherte Aufnahmen über drei Befestigungsarten) erfüllt Tim beim Training; es ist kein Schritt dieses Plans. Nicht pushen.

---

## Selbstprüfung gegen die Spec

| Spec | Task |
|---|---|
| §2 Scope, nur Debug, Usage-Text als Ausnahme | Global Constraints, 9 (Release-Build), 10 (Release-Build) |
| §2 kein Kalibrieren/Speichern | 3 (Test hält es fest) |
| §3 Protokoll | 2, 3 |
| §4 Verifikation 1–6 / 7 | 1 / 11 |
| §5.1 Parser | 2 |
| §5.2 `SensorQuelle` | 6 |
| §5.3 Scan, gemerkte ID, Rate ohne Speichern, Akku alle 60 s, Zeitstempel zuerst, Wiederverbinden, späte Berechtigung | 9 |
| §5.3 Bildschirm wach, App-weite Instanz | 10 |
| §6.1–6.3 Ordner, CSV, JSON mit `null` | 5 |
| §6.3 `befestigung` je Gerät | 7, 10 |
| §6.4 Lebenszyklus, Verwaiste | 5 (Nachtrag), 7 (Start/Abschluss/Abbruch), 8 (Aufrufstellen) |
| §7.1 Sensor-Zeile | 10 |
| §7.2 Diagnose, Ratentest, „Sensor vergessen" | 7 (Ratentest-Logik), 10 |
| §7.3 Einbindung, „gefährdet nie den Satz", Testnotiz-Kontext | 7, 8, 10 |
| §8 Fehlerfälle | 2 (Parser), 5 (Absturz), 7 (Abriss, Schreibfehler), 9 (Bluetooth, zwei Sensoren, gemerkter fehlt) |
| §9 Tests und Geräte-Checkliste | 2–8, 10, 11 |
| §10 Abschlusskriterien | 11 (1 und 3), Tim beim Training (2) |
