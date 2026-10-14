# Sensor E4: Live-Zählen im Debug-Build — Umsetzungsplan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Debug-Build zählt der Zähler jeden Satz live mit: das Rad folgt, je Wiederholung ein haptisches Signal, „Zahl prüfen“ bei Lücke oder Unsicherheit; beim Sichern gehen Herkunft, Zählerstand und `repEvents` an die API und in die Aufnahme.

**Architecture:** Eine immer kompilierte Naht `SatzZaehler` (wie `SatzMitschnitt`) trennt `GeraetModel` vom Debug-Typ `ZaehlerKoordinator`. Der Koordinator hört parallel zum `SensorAufnahmeKoordinator` auf denselben `SensorQuelle`-Strom, baut je Satz einen `Zaehler` aus dem Package `Sensorik` und meldet `bereit` / `stand(n)` / `pruefen` / `zaehltNicht`. Die Befestigungsart wird aus dem Gerätetyp vorgeschlagen oder per Tipp gewählt und je Station + Übung gemerkt.

**Tech Stack:** Swift 6, SwiftUI, Observation, Swift Testing, lokales Package `Sensorik`, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-10-10-sensor-wiederholungszaehler-design.md`, Abschnitte 6.4–6.8, 9 und **Nachtrag vom 14. Oktober 2026** (geht 6.4–6.7 vor, wo sie sich widersprechen).

## Global Constraints

- Arbeit im Worktree `.claude/worktrees/sensor-aufnahmen-1410` auf Branch `claude/sensor-e4` (zweigt von `claude/sensor-aufnahmen-1410` ab, dort liegen Stapel-Profil 2 und die Aufnahmen vom 14.10.). `.env` und `apps/ios-member/Config.xcconfig` liegen schon im Worktree.
- Nur eine Session baut iOS zur selben Zeit: vor jedem `xcodebuild` `pgrep -lx xcodebuild`. Simulator nur per ID: `-destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707'`. Vor iOS-Builds `df -h /` prüfen (am 14.10. nur ~4,5 GB frei); unter 2 GB erst Platz schaffen.
- Nach jeder Änderung an `project.yml` oder an Dateien im App-/Test-Target: `cd apps/ios-member && xcodegen generate`, das erzeugte `project.pbxproj` mit committen.
- Commits deutsch mit ae/oe/ue, Form `feat(sensorik): …` / `test(…)` / `docs(…)`, ein Commit je Task. Trailer exakt: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Nach jedem Commit `git log -1 --format=%B` prüfen.
- Swift-Kommentare ASCII (ae/oe/ue/ss) und mit Begründung. Tests mit Swift Testing (`@Test`, `#expect`, `#require`). Nutzertexte mit echten Umlauten.
- Alles Neue im App-Target außer der Naht (`SatzZaehler.swift`) und den Zustandsfeldern in `GeraetModel` steht in `#if DEBUG`. Der Release-Build darf keinen Debug-Typ referenzieren.
- Befestigungsarten, Rohwerte wörtlich: `stapel, langhantel, kurzhantel, hebelarm, kabelgriff, koerper`. Quelle der Art: `vorschlag, gewaehlt`. Herkunft: `eingegeben, gemessen, korrigiert`. Unsicher-Gründe: `luecke, signalSchwach, taktUnregelmaessig`.
- Der Zähler gefährdet nie den Satz: nichts wirft in den Satzpfad, nichts wird abgewartet, `ergebnis()` ist synchron.
- Volles Testset vor dem Melden: `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `swift test --package-path apps/ios-member/Packages/Sensorik`, `xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707'` (aus `apps/ios-member`).
- Nicht pushen, bis Tim es sagt. Keine Migration in diesem Plan (0049 ist auf Prod).

## Review Focus

1. **Zählung reißt beim Wiederverbinden nicht wieder an:** nach `.pruefen(n, .luecke)` und erneutem `.verbunden` kommen keine `stand`-Meldungen mehr (Spec 9). Test in Task 4.
2. **Befestigung mitten im Satz geändert:** Die Zählung beginnt mit der neuen Art von vorn (`bereit`), alte Wiederholungen fallen weg, die Wahl ist gemerkt. Test in Task 4.
3. **Zählerstand über dem Rad-Maximum (40):** Das Rad rastet auf 40, die Herkunft wird `korrigiert` mit `volumeCounted` = echter Zählerstand, der Satz bleibt speicherbar. Test in Task 5.
4. **Abgelehnter Satz (Ortskonflikt):** `ergebnis()` wird nicht abgeholt, die Zählung läuft weiter, der Mitschnitt hört nichts. Test in Task 5.
5. **Sekunden-/Meterübung mit laufendem Zähler-Double:** Herkunft bleibt `eingegeben`, auch wenn ein Ergebnis da wäre (der Server lehnt Herkunft ≠ eingegeben bei `volume_kind ≠ reps` ab). Test in Task 5.

---

## Dateien

| Datei | Verantwortung |
|---|---|
| `Packages/Sensorik/Sources/Sensorik/Befestigungsart.swift` (ändern) | `BefestigungsartQuelle`, `Befestigungsart.vorschlag(geraetename:istKraft:)` |
| `Packages/Sensorik/Sources/Sensorik/SensorAufnahmeDatei.swift` (ändern) | Felder `befestigungsart`, `befestigungsartQuelle`, `zaehler` |
| `Packages/Sensorik/Sources/Sensorik/SensorAufnahme.swift` (ändern) | `abschliessen` nimmt die drei Felder an |
| `FitnessMember/Workout/SatzZaehler.swift` (neu, immer kompiliert) | Naht: Kontext, Meldung, Ergebnis, Wahl, Protokoll |
| `FitnessMember/Workout/Sensor/Befestigungsspeicher.swift` (neu, DEBUG) | gemerkte Wahl oder Vorschlag je Station + Übung |
| `FitnessMember/Workout/Sensor/ZaehlerKoordinator.swift` (neu, DEBUG) | Strom → `Zaehler` → Meldungen, Ergebnis |
| `FitnessMember/Screens/Geraet/GeraetModel.swift` (ändern) | `zaehler`-Parameter, `zaehlerZustand`, `umfangGedreht`, Herkunft beim Sichern |
| `FitnessMember/Workout/SatzMitschnitt.swift` (ändern) | `GesicherterSatz` trägt Herkunft, Ergebnis, Wahl |
| `FitnessMember/Workout/Sensor/SensorAufnahmeKoordinator.swift` (ändern) | schreibt die drei Felder in `aufnahme.json` |
| `FitnessMember/Screens/Geraet/SensorZeile.swift`, `WertZeile.swift`, `GeraetView.swift` (ändern) | Befestigung + Zählerstatus, „Zahl prüfen“, Haptik, Testnotiz-Kontext |
| `FitnessMember/FitnessMemberApp.swift`, `Screens/Training/TrainingRootView.swift` (ändern) | eine Quelle, zwei Koordinatoren; Zähler ans Modell |
| `FitnessMember/Info-Additions-Debug.plist` (ändern) | `UIBackgroundModes: bluetooth-central` (nur Debug) |
| `FitnessMemberTests/Fixtures/sensoraufnahme-beispiel/aufnahme.json` (ändern) | verbindliches Beispiel mit den neuen Feldern |

---

### Task 1: Vorschlag der Befestigungsart (Package)

**Files:**
- Modify: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/Befestigungsart.swift`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/BefestigungsartTests.swift` (neu)

**Interfaces:**
- Produces: `public enum BefestigungsartQuelle: String, Codable, Sendable { case vorschlag, gewaehlt }`; `public static func Befestigungsart.vorschlag(geraetename: String, istKraft: Bool) -> Befestigungsart?`

- [x] **Step 1: Failing test schreiben**

```swift
import Testing
@testable import Sensorik

/// Spec B, Nachtrag 14.10. Punkt 2: Regel nach dem Namen des Geraetetyps.
struct BefestigungsartTests {
    @Test(arguments: [
        ("Kurzhantel", true, Befestigungsart?.some(.kurzhantel)),
        ("Kurzhantelbank", true, .some(.kurzhantel)),
        ("Langhantel", true, .some(.langhantel)),
        ("SZ-Stange", true, .some(.langhantel)),
        ("Beinpresse", true, .some(.stapel)),
        ("Latzugstation + V-Griff", true, .some(.stapel)),
        ("Ruderergometer mit Rollsitz", false, nil),
        // "SZ" nur als eigenes Wort: sonst traefe es jedes Wort mit "sz".
        ("Schulterpresse", true, .some(.stapel)),
    ])
    func vorschlagNachName(name: String, kraft: Bool, erwartet: Befestigungsart?) {
        #expect(Befestigungsart.vorschlag(geraetename: name, istKraft: kraft) == erwartet)
    }

    /// Kurzhantel vor Langhantel: ein Name mit beiden ist eine Ablage, an der
    /// die Kurzhantel gegriffen wird -- die Reihenfolge der Spec gilt.
    @Test func kurzhantelGehtVor() {
        #expect(Befestigungsart.vorschlag(geraetename: "Kurzhantel- und Langhantelablage", istKraft: true) == .kurzhantel)
    }
}
```

- [x] **Step 2: Test laufen lassen, er scheitert**

Run: `swift test --package-path apps/ios-member/Packages/Sensorik --filter BefestigungsartTests`
Expected: Compile-Fehler „type 'Befestigungsart' has no member 'vorschlag'“.

- [x] **Step 3: Umsetzen** — ans Ende von `Befestigungsart.swift`:

```swift
/// Ob die Art eines Satzes vorgeschlagen oder vom Nutzer gewaehlt ist
/// (Spec B, Nachtrag 14.10. Punkt 3). Beim Einlesen gilt nur eine gewaehlte
/// Art ohne Rueckfrage als Wahrheit.
public enum BefestigungsartQuelle: String, Codable, Sendable {
    case vorschlag, gewaehlt
}

extension Befestigungsart {
    /// Vorschlag aus dem Geraetetyp (Spec B, Nachtrag 14.10. Punkt 2). Nur
    /// der Name taugt dafuer: die Kategorie kennt nur kraft und cardio.
    /// nil an Cardio-Geraeten, dort ist der Umfang keine Wiederholung.
    public static func vorschlag(geraetename: String, istKraft: Bool) -> Befestigungsart? {
        if geraetename.localizedCaseInsensitiveContains("kurzhantel") { return .kurzhantel }
        if geraetename.localizedCaseInsensitiveContains("langhantel") { return .langhantel }
        // Als eigenes Wort und gross geschrieben: "SZ-Stange", nicht "Schulterpresse".
        let woerter = geraetename.split { !$0.isLetter && !$0.isNumber }
        if woerter.contains("SZ") { return .langhantel }
        return istKraft ? .stapel : nil
    }
}
```

- [x] **Step 4: Tests laufen lassen**

Run: `swift test --package-path apps/ios-member/Packages/Sensorik`
Expected: alle grün, `guetebericht.md` unverändert (`git status` zeigt ihn nicht).

- [x] **Step 5: Commit** — `feat(sensorik): Befestigungsart wird aus dem Geraetetyp vorgeschlagen`

---

### Task 2: Befestigungsart und Zählerblock in `aufnahme.json` (Package + Fixture)

**Files:**
- Modify: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/SensorAufnahmeDatei.swift`
- Modify: `apps/ios-member/Packages/Sensorik/Sources/Sensorik/SensorAufnahme.swift:80-98`
- Modify: `apps/ios-member/FitnessMemberTests/Fixtures/sensoraufnahme-beispiel/aufnahme.json`
- Test: `apps/ios-member/Packages/Sensorik/Tests/SensorikTests/SensorAufnahmeTests.swift`

**Interfaces:**
- Consumes: `BefestigungsartQuelle` (Task 1), `RepEvents` (vorhanden)
- Produces:
  - `SensorAufnahmeDatei.Zaehler { algo: String; gezaehlt: Int; herkunft: String; ereignisse: RepEvents }` mit `public init(algo:gezaehlt:herkunft:ereignisse:)`
  - `SensorAufnahmeDatei.befestigungsart: Befestigungsart?`, `.befestigungsartQuelle: BefestigungsartQuelle?`, `.zaehler: Zaehler?` (alle Default `nil`)
  - `SensorAufnahme.abschliessen(_:kontext:label:akkuProzent:statistik:ende:endeT:befestigungsart:befestigungsartQuelle:zaehler:)` — die drei neuen Parameter mit Default `nil`

- [x] **Step 1: Failing tests schreiben** — in `SensorAufnahmeTests.swift` (Package) ergänzen. Den vorhandenen Aufbau einer Aufnahme in dieser Datei als Vorlage nehmen (eine `SensorAufnahme` in einem Temp-Ordner anlegen und abschließen):

```swift
    /// Spec B 6.7 und Nachtrag 14.10. Punkt 3: Art, Quelle und Zaehlerblock
    /// stehen in aufnahme.json und kommen beim Lesen unveraendert zurueck.
    @Test func befestigungsartUndZaehlerblockKommenZurueck() throws {
        let wurzel = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let aufnahme = try SensorAufnahme(
            wurzel: wurzel, start: Date(timeIntervalSince1970: 0), startT: 0,
            sensor: .init(name: "WT901BLE67", rateSollHz: 50, akkuProzent: 90),
            geraet: .init(model: "iPhone14,4", os: "iOS 26", appBuild: "1"),
            kontext: .init(machineId: nil, machineName: "Beinpresse", exerciseId: "e1",
                           exerciseName: "Beidbeinig", sessionId: nil, setId: nil, setIndex: nil),
            befestigung: nil)
        let ereignisse = RepEvents(algo: "stapel/2", befestigungsart: .stapel, ereignisse: [], satzbeginn: 0)
        try aufnahme.abschliessen(.gesichert, kontext: aufnahme.datei.kontext, label: .init(reps: 0),
                                  akkuProzent: nil, statistik: .leer, ende: Date(timeIntervalSince1970: 10), endeT: 10,
                                  befestigungsart: .stapel, befestigungsartQuelle: .vorschlag,
                                  zaehler: .init(algo: "stapel/2", gezaehlt: 0, herkunft: "eingegeben",
                                                 ereignisse: ereignisse))
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: aufnahme.ordner).datei
        #expect(gelesen.befestigungsart == .stapel)
        #expect(gelesen.befestigungsartQuelle == .vorschlag)
        #expect(gelesen.zaehler?.algo == "stapel/2")
        #expect(gelesen.zaehler?.ereignisse == ereignisse)
    }

    /// Aeltere Aufnahmen (alle bis 14.10.) haben die Felder nicht.
    @Test func ohneDieNeuenFelderBleibtEineAufnahmeLesbar() throws {
        let alt = Pfade.aufnahmen.appendingPathComponent("2026-10-14-1747-01")
        let gelesen = try SensorAufnahmeLeser.lesen(ordner: alt).datei
        #expect(gelesen.befestigungsart == nil)
        #expect(gelesen.zaehler == nil)
    }

    /// Die Schluessel stehen immer da, auch als null -- wie befestigung.
    @Test func dieNeuenSchluesselStehenAuchAlsNull() throws {
        let datei = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent("2026-10-14-1747-01")).datei
        let json = String(decoding: try JSONEncoder().encode(datei), as: UTF8.self)
        #expect(json.contains("\"befestigungsart\":null"))
        #expect(json.contains("\"befestigungsartQuelle\":null"))
        #expect(json.contains("\"zaehler\":null"))
    }
```

Passen die Namen der Initialisierer in deiner Version der Datei nicht exakt (z. B. `SensorAufnahme.init`-Parameter), richte dich nach `SensorAufnahme.swift:28-30` — die Prüfungen bleiben dieselben.

- [x] **Step 2: Tests laufen lassen, sie scheitern**

Run: `swift test --package-path apps/ios-member/Packages/Sensorik --filter SensorAufnahmeTests`
Expected: Compile-Fehler „extra arguments … befestigungsart“.

- [x] **Step 3: Umsetzen** — in `SensorAufnahmeDatei` nach `Label`:

```swift
    /// Spec B 6.7: was der Zaehler im Satz gesehen hat. herkunft als Rohwert
    /// (eingegeben/gemessen/korrigiert), weil der Typ dazu im App-Target liegt.
    public struct Zaehler: Codable, Equatable, Sendable {
        public var algo: String
        public var gezaehlt: Int
        public var herkunft: String
        public var ereignisse: RepEvents

        public init(algo: String, gezaehlt: Int, herkunft: String, ereignisse: RepEvents) {
            self.algo = algo; self.gezaehlt = gezaehlt; self.herkunft = herkunft; self.ereignisse = ereignisse
        }
    }
```

Nach `public var befestigung: String?`:

```swift
    // Optional mit Default: aeltere Aufnahmen dekodieren weiter (synthetisiert:
    // decodeIfPresent). Die Formatkennung bleibt /1 (Spec B 6.7).
    public var befestigungsart: Befestigungsart? = nil
    public var befestigungsartQuelle: BefestigungsartQuelle? = nil
    public var zaehler: Zaehler? = nil
```

In `encode(to:)` nach `befestigung`:

```swift
        try c.encode(befestigungsart, forKey: .befestigungsart)
        try c.encode(befestigungsartQuelle, forKey: .befestigungsartQuelle)
        try c.encode(zaehler, forKey: .zaehler)
```

In `SensorAufnahme.abschliessen` drei Parameter mit Default anhängen und vor `try kopfSchreiben()` setzen:

```swift
                      statistik: SensorStatistik.Ergebnis, ende: Date, endeT: TimeInterval,
                      befestigungsart: Befestigungsart? = nil,
                      befestigungsartQuelle: BefestigungsartQuelle? = nil,
                      zaehler: SensorAufnahmeDatei.Zaehler? = nil) throws {
        ...
        datei.befestigungsart = befestigungsart
        datei.befestigungsartQuelle = befestigungsartQuelle
        datei.zaehler = zaehler
        try kopfSchreiben()
```

Fixture `FitnessMemberTests/Fixtures/sensoraufnahme-beispiel/aufnahme.json`: nach `"befestigung"` einfügen (Spec 6.7: „Das verbindliche Beispiel bekommt beide Felder“):

```json
  "befestigungsart" : "stapel",
  "befestigungsartQuelle" : "gewaehlt",
  "zaehler" : {
    "algo" : "stapel/2", "gezaehlt" : 1, "herkunft" : "korrigiert",
    "ereignisse" : {
      "algo" : "stapel/2", "befestigungsart" : "stapel", "unsicher" : null,
      "wiederholungen" : [ { "beginn" : 0.02, "umkehr" : 0.04, "ende" : 0.06, "ausschlag" : 0.31, "sicherheit" : 0.5 } ]
    }
  },
```

(Das Beispiel hat nur fünf Pakete; ein gezählter Wert 1 gegen das Label 11 ist darum `korrigiert` — so steht beides im Beispiel.)

- [x] **Step 4: Tests laufen lassen**

Run: `swift test --package-path apps/ios-member/Packages/Sensorik`
Expected: alle grün, auch `dasVerbindlicheBeispielIstLesbar` und `alleEchtenAufnahmenSindLesbar`; `guetebericht.md` unverändert.

- [x] **Step 5: Commit** — `feat(sensorik): aufnahme.json kennt Befestigungsart, Quelle und Zaehlerblock`

---

### Task 3: Naht `SatzZaehler` und `Befestigungsspeicher` (App)

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/SatzZaehler.swift`
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/Befestigungsspeicher.swift`
- Test: `apps/ios-member/FitnessMemberTests/BefestigungsspeicherTests.swift` (neu)

**Interfaces:**
- Consumes: `Befestigungsart.vorschlag`, `BefestigungsartQuelle` (Task 1); `Station`, `VolumeKind`, `RepEvents`, `UnsicherGrund`
- Produces (exakt so, spätere Tasks rufen sie):

```swift
struct BefestigungsWahl: Equatable, Sendable { let art: Befestigungsart; let quelle: BefestigungsartQuelle }
struct SatzZaehlerKontext: Equatable, Sendable { let station: Station; let exerciseId: String; let volumeKind: VolumeKind }
enum ZaehltNichtGrund: Equatable, Sendable { case keinSensor, keineWiederholungen, keineBefestigung, nichtFreigegeben }
enum ZaehlerMeldung: Equatable, Sendable { case zaehltNicht(ZaehltNichtGrund), bereit, stand(Int), pruefen(Int, UnsicherGrund) }
struct ZaehlerErgebnis: Equatable, Sendable { let gezaehlt: Int; let repEvents: RepEvents }
@MainActor protocol SatzZaehler: AnyObject {
    var befestigung: BefestigungsWahl? { get }
    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void)
    func ergebnis() -> ZaehlerErgebnis?
    func satzVerworfen()
}
struct Befestigungsspeicher { init(einstellungen: UserDefaults); func wahl(fuer: SatzZaehlerKontext) -> BefestigungsWahl?; func merken(_: Befestigungsart, fuer: SatzZaehlerKontext) }  // DEBUG
```

- [x] **Step 1: Failing test schreiben** — `FitnessMemberTests/BefestigungsspeicherTests.swift`:

```swift
#if DEBUG
import Foundation
import Sensorik
import Testing
@testable import FitnessMember

@MainActor
struct BefestigungsspeicherTests {
    static func kontext(_ station: Station = Station(maschine: GeraetTestdaten.maschine),
                        uebung: String = "e1") -> SatzZaehlerKontext {
        SatzZaehlerKontext(station: station, exerciseId: uebung, volumeKind: .reps)
    }

    @Test func ohneWahlKommtDerVorschlag() {
        let sut = Befestigungsspeicher(einstellungen: UserDefaults(suiteName: UUID().uuidString)!)
        // GeraetTestdaten.maschine ist eine Beinpresse (kraft).
        #expect(sut.wahl(fuer: Self.kontext()) == BefestigungsWahl(art: .stapel, quelle: .vorschlag))
    }

    @Test func eineWahlGiltJeStationUndUebung() {
        let einstellungen = UserDefaults(suiteName: UUID().uuidString)!
        let sut = Befestigungsspeicher(einstellungen: einstellungen)
        sut.merken(.hebelarm, fuer: Self.kontext())
        #expect(sut.wahl(fuer: Self.kontext()) == BefestigungsWahl(art: .hebelarm, quelle: .gewaehlt))
        // Andere Uebung an derselben Station: wieder der Vorschlag.
        #expect(sut.wahl(fuer: Self.kontext(uebung: "e2"))?.quelle == .vorschlag)
        // Ein neuer Speicher auf denselben Einstellungen kennt die Wahl.
        #expect(Befestigungsspeicher(einstellungen: einstellungen).wahl(fuer: Self.kontext())?.art == .hebelarm)
    }

    @Test func cardioOhneVorschlag() {
        let sut = Befestigungsspeicher(einstellungen: UserDefaults(suiteName: UUID().uuidString)!)
        #expect(sut.wahl(fuer: Self.kontext(GeraetTestdaten.cardioTyp)) == nil)
    }
}
#endif
```

`GeraetTestdaten.cardioTyp` gibt es noch nicht: in `GeraetModelTests.swift` neben `static var typ: Station` (um Zeile 1322) eine Kopie von `typ` anlegen mit `"id":"em9","name":"Ruderergometer"`, `"category":"cardio"` und einer Übung `{"id":"e9","name":"Rudern","volumeKind":"meters","targetMin":null,"targetMax":null}`. Wie `typ` aufgebaut ist, dort ablesen; die übrigen Felder unverändert übernehmen.

- [x] **Step 2: Test laufen lassen, er scheitert**

Run (aus `apps/ios-member`, nach `pgrep -lx xcodebuild` und `xcodegen generate`): `xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' -only-testing:FitnessMemberTests/BefestigungsspeicherTests -quiet`
Expected: Compile-Fehler „cannot find 'Befestigungsspeicher'“.

- [x] **Step 3: Umsetzen** — `Workout/SatzZaehler.swift` (ohne `#if DEBUG`):

```swift
import Foundation
import Sensorik

/// Naht zwischen Satzpfad und Zaehler (Sensor-Spec B 6.4, Nachtrag 14.10.).
///
/// Immer kompiliert wie SatzMitschnitt: GeraetModel wird auch im Release
/// gebaut und darf keinen Debug-Typ im Konstruktor tragen. Bis E5 ist der
/// Parameter im Release nil.
///
/// Nichts wirft, nichts ist async: der Satz darf am Zaehler weder scheitern
/// noch auf ihn warten.

struct BefestigungsWahl: Equatable, Sendable {
    let art: Befestigungsart
    let quelle: BefestigungsartQuelle
}

struct SatzZaehlerKontext: Equatable, Sendable {
    /// Station statt machineId: am Geraetetyp gibt es keine (Nachtrag 14.10. Punkt 1).
    let station: Station
    let exerciseId: String
    let volumeKind: VolumeKind
}

enum ZaehltNichtGrund: Equatable, Sendable {
    case keinSensor, keineWiederholungen, keineBefestigung
    /// Erst ab E5: im Release zaehlen nur freigegebene Arten.
    case nichtFreigegeben
}

enum ZaehlerMeldung: Equatable, Sendable {
    case zaehltNicht(ZaehltNichtGrund)
    case bereit
    case stand(Int)
    case pruefen(Int, UnsicherGrund)
}

struct ZaehlerErgebnis: Equatable, Sendable {
    let gezaehlt: Int
    let repEvents: RepEvents
}

@MainActor
protocol SatzZaehler: AnyObject {
    /// Die Art des laufenden oder eben beendeten Satzes. Bleibt nach
    /// ergebnis() stehen, damit die Aufnahme sie noch lesen kann.
    var befestigung: BefestigungsWahl? { get }
    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void)
    /// Beim Sichern abgeholt; beendet den Satz. nil, wenn nichts gezaehlt wurde.
    func ergebnis() -> ZaehlerErgebnis?
    func satzVerworfen()
}
```

`Workout/Sensor/Befestigungsspeicher.swift`:

```swift
#if DEBUG
import Foundation
import Sensorik

/// Gemerkte Befestigungsart je Station und Uebung, sonst der Vorschlag aus
/// dem Geraetetyp (Sensor-Spec B, Nachtrag 14.10. Punkte 1 und 2).
///
/// Je Uebung, nicht nur je Station: an der Kombistation haengt der Sensor
/// beim Butterfly anders als beim Reverse Fly.
struct Befestigungsspeicher {
    let einstellungen: UserDefaults

    init(einstellungen: UserDefaults) { self.einstellungen = einstellungen }

    private func schluessel(_ kontext: SatzZaehlerKontext) -> String {
        "sensor.befestigungsart.\(kontext.station.schluessel).\(kontext.exerciseId)"
    }

    func wahl(fuer kontext: SatzZaehlerKontext) -> BefestigungsWahl? {
        if let roh = einstellungen.string(forKey: schluessel(kontext)), let art = Befestigungsart(rawValue: roh) {
            return BefestigungsWahl(art: art, quelle: .gewaehlt)
        }
        let modell = kontext.station.equipmentModel
        return Befestigungsart.vorschlag(geraetename: modell.name, istKraft: modell.category == .kraft)
            .map { BefestigungsWahl(art: $0, quelle: .vorschlag) }
    }

    func merken(_ art: Befestigungsart, fuer kontext: SatzZaehlerKontext) {
        einstellungen.set(art.rawValue, forKey: schluessel(kontext))
    }
}
#endif
```

- [x] **Step 4: `xcodegen generate`, Tests laufen lassen**

Run: wie Step 2.
Expected: 3 Tests grün.

- [x] **Step 5: Commit** (inkl. `project.pbxproj`) — `feat(geraet): Naht SatzZaehler und gemerkte Befestigungsart je Station und Uebung`

---

### Task 4: `ZaehlerKoordinator` (App, DEBUG)

**Files:**
- Create: `apps/ios-member/FitnessMember/Workout/Sensor/ZaehlerKoordinator.swift`
- Test: `apps/ios-member/FitnessMemberTests/ZaehlerKoordinatorTests.swift` (neu)

**Interfaces:**
- Consumes: Task 3 (alle Typen), `SensorQuelle`, `SensorEreignis`, `Zaehler`, `ZaehlerProfil.fuer`, `RepEvents.init(algo:befestigungsart:ereignisse:satzbeginn:)`
- Produces:

```swift
@MainActor @Observable final class ZaehlerKoordinator: SatzZaehler {
    let quelle: any SensorQuelle
    private(set) var meldung: ZaehlerMeldung?          // nil = kein Satz offen
    private(set) var befestigung: BefestigungsWahl?
    init(quelle: any SensorQuelle, einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime })
    func starten()
    func empfangen(_ ereignis: SensorEreignis)
    func befestigungWaehlen(_ art: Befestigungsart)
}
```

- [x] **Step 1: Failing tests schreiben** — `FitnessMemberTests/ZaehlerKoordinatorTests.swift`. `AttrappenQuelle` steht in `SensorAufnahmeKoordinatorTests.swift` und ist im Testziel sichtbar.

```swift
#if DEBUG
import Foundation
import Sensorik
import Testing
@testable import FitnessMember

@MainActor
struct ZaehlerKoordinatorTests {
    static let verbunden = SensorZustand.verbunden(name: "WT901BLE67", akkuProzent: 82)
    final class Uhr { var t: TimeInterval = 100 }

    private func aufbau(zustand: SensorZustand = verbunden,
                        einstellungen: UserDefaults = UserDefaults(suiteName: UUID().uuidString)!)
        -> (sut: ZaehlerKoordinator, quelle: AttrappenQuelle, uhr: Uhr, meldungen: Meldungen) {
        let quelle = AttrappenQuelle()
        quelle.zustand = zustand
        let uhr = Uhr()
        let sut = ZaehlerKoordinator(quelle: quelle, einstellungen: einstellungen, uhr: { uhr.t })
        return (sut, quelle, uhr, Meldungen())
    }

    final class Meldungen { var liste: [ZaehlerMeldung] = [] }

    private func beginnen(_ sut: ZaehlerKoordinator, _ m: Meldungen,
                          _ kontext: SatzZaehlerKontext = BefestigungsspeicherTests.kontext()) {
        sut.satzBeginnt(kontext) { m.liste.append($0) }
    }

    /// Stapel-Satz wie in Synthetik (Package): 3 s Ruhe, je Wiederholung
    /// 2 s Sinus mit 0,4 m/s Spitze entlang z, 2 s Ruhe. Ab Zeit `ab`.
    static func stapelSatz(wiederholungen: Int, ab: TimeInterval) -> [SensorMesswert] {
        let dt = 1.0 / 50
        var a: [Double] = Array(repeating: 0, count: 150)
        for k in 0..<(wiederholungen * 100) {
            a.append(0.4 * 2 * .pi / 2 * cos(2 * .pi * Double(k) * dt / 2))
        }
        a += Array(repeating: 0, count: 100)
        return a.enumerated().map { i, wert in
            SensorMesswert(t: ab + Double(i) * dt, beschleunigung: Vektor3(x: 0, y: 0, z: 1 + wert / 9.81),
                           drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
    }

    @Test func bereitDannStandJeWiederholung() throws {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        #expect(m.liste == [.bereit])
        for w in Self.stapelSatz(wiederholungen: 5, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit, .stand(1), .stand(2), .stand(3), .stand(4), .stand(5)])
        let ergebnis = try #require(sut.ergebnis())
        #expect(ergebnis.gezaehlt == 5)
        #expect(ergebnis.repEvents.algo == "stapel/2")
        #expect(ergebnis.repEvents.befestigungsart == .stapel)
        // Zeiten relativ zum Satzbeginn: die erste Wiederholung beginnt nach 3 s Ruhe.
        #expect(abs(try #require(ergebnis.repEvents.wiederholungen.first).beginn - 3) <= 0.3)
        #expect(sut.meldung == nil)
    }

    @Test func messwerteVorDemSatzbeginnZaehlenNicht() {
        let (sut, _, uhr, m) = aufbau()
        let frueh = Self.stapelSatz(wiederholungen: 3, ab: uhr.t - 20)
        uhr.t = 100
        beginnen(sut, m)
        for w in frueh { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit])
    }

    /// Spec 9: nach einer Luecke steht die Zahl, und nach dem Wiederverbinden
    /// wird nicht weitergezaehlt.
    @Test func lueckeMachtPruefenUndDanachKommtNichtsMehr() {
        let (sut, quelle, uhr, m) = aufbau()
        beginnen(sut, m)
        let satz = Self.stapelSatz(wiederholungen: 6, ab: uhr.t)
        for w in satz.prefix(150 + 250) { sut.empfangen(.messwert(w)) }
        let vorher = m.liste.last
        sut.empfangen(.zustand(.getrennt(wirdNeuVerbunden: true)))
        guard case .stand(let n)? = vorher else { Issue.record("kein Stand vor der Luecke"); return }
        #expect(m.liste.last == .pruefen(n, .luecke))
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        for w in satz.dropFirst(400) { sut.empfangen(.messwert(w)) }
        #expect(m.liste.last == .pruefen(n, .luecke))
    }

    @Test func sekundenuebungZaehltNicht() {
        let (sut, _, _, m) = aufbau()
        beginnen(sut, m, SatzZaehlerKontext(station: Station(maschine: GeraetTestdaten.maschine),
                                            exerciseId: "e1", volumeKind: .seconds))
        #expect(m.liste == [.zaehltNicht(.keineWiederholungen)])
        #expect(sut.ergebnis() == nil)
    }

    @Test func cardioOhneVorschlagZaehltNicht() {
        let (sut, _, _, m) = aufbau()
        beginnen(sut, m, SatzZaehlerKontext(station: GeraetTestdaten.cardioTyp, exerciseId: "e9", volumeKind: .reps))
        #expect(m.liste == [.zaehltNicht(.keineBefestigung)])
    }

    /// Spec 9: der Sensor verbindet sich mitten in der Eingabe -- ab da zaehlt er.
    @Test func ohneSensorZaehltNichtUndStartetBeimVerbinden() {
        let (sut, quelle, _, m) = aufbau(zustand: .aus)
        beginnen(sut, m)
        #expect(m.liste == [.zaehltNicht(.keinSensor)])
        quelle.zustand = Self.verbunden
        sut.empfangen(.zustand(Self.verbunden))
        #expect(m.liste == [.zaehltNicht(.keinSensor), .bereit])
    }

    /// Review Focus 2: eine neue Art beginnt von vorn und ist gemerkt.
    @Test func befestigungWaehlenStartetNeuUndIstGemerkt() {
        let einstellungen = UserDefaults(suiteName: UUID().uuidString)!
        let (sut, _, uhr, m) = aufbau(einstellungen: einstellungen)
        beginnen(sut, m)
        for w in Self.stapelSatz(wiederholungen: 2, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        sut.befestigungWaehlen(.hebelarm)
        #expect(m.liste.last == .bereit)
        #expect(sut.befestigung == BefestigungsWahl(art: .hebelarm, quelle: .gewaehlt))
        #expect(sut.ergebnis() == nil)
        #expect(Befestigungsspeicher(einstellungen: einstellungen)
            .wahl(fuer: BefestigungsspeicherTests.kontext())?.art == .hebelarm)
    }

    @Test func satzVerworfenSchweigtDanach() {
        let (sut, _, uhr, m) = aufbau()
        beginnen(sut, m)
        sut.satzVerworfen()
        for w in Self.stapelSatz(wiederholungen: 3, ab: uhr.t) { sut.empfangen(.messwert(w)) }
        #expect(m.liste == [.bereit])
        #expect(sut.ergebnis() == nil)
        #expect(sut.meldung == nil)
    }

    @Test func ohneWiederholungIstDasErgebnisNil() {
        let (sut, _, _, m) = aufbau()
        beginnen(sut, m)
        #expect(sut.ergebnis() == nil)
        // Die Art bleibt fuer die Aufnahme lesbar.
        #expect(sut.befestigung?.art == .stapel)
    }
}
#endif
```

- [x] **Step 2: Tests laufen lassen, sie scheitern**

Run: `xcodegen generate`, dann `xcodebuild test … -only-testing:FitnessMemberTests/ZaehlerKoordinatorTests -quiet`
Expected: Compile-Fehler „cannot find 'ZaehlerKoordinator'“.

- [x] **Step 3: Umsetzen** — `Workout/Sensor/ZaehlerKoordinator.swift`:

```swift
#if DEBUG
import Foundation
import Observation
import Sensorik

/// Erfuellt die Naht SatzZaehler (Sensor-Spec B 6.4): hoert auf den
/// Messwert-Strom, baut je Satz einen Zaehler mit dem Profil der Art und
/// uebersetzt seine Ereignisse in Meldungen.
///
/// Unabhaengig vom SensorAufnahmeKoordinator; beide hoeren parallel, jeder
/// mit eigenem Strom (SensorVerteiler).
@MainActor
@Observable
final class ZaehlerKoordinator: SatzZaehler {
    let quelle: any SensorQuelle
    /// Fuer die Sensor-Zeile. nil, solange kein Satz offen ist.
    private(set) var meldung: ZaehlerMeldung?
    private(set) var befestigung: BefestigungsWahl?

    @ObservationIgnored private let speicher: Befestigungsspeicher
    @ObservationIgnored private let uhr: () -> TimeInterval
    @ObservationIgnored private var kontext: SatzZaehlerKontext?
    @ObservationIgnored private var melde: (@MainActor (ZaehlerMeldung) -> Void)?
    @ObservationIgnored private var zaehler: Zaehler?
    @ObservationIgnored private var satzbeginn: TimeInterval = 0
    @ObservationIgnored private var ereignisse: [ZaehlerEreignis] = []
    @ObservationIgnored private var lauscher: Task<Void, Never>?

    init(quelle: any SensorQuelle, einstellungen: UserDefaults = .standard,
         uhr: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.quelle = quelle
        self.speicher = Befestigungsspeicher(einstellungen: einstellungen)
        self.uhr = uhr
    }

    /// Einmal beim App-Start; getrennt vom init, damit Tests `empfangen`
    /// direkt und in fester Reihenfolge rufen koennen.
    func starten() {
        guard lauscher == nil else { return }
        let strom = quelle.ereignisse()
        lauscher = Task { [weak self] in
            for await ereignis in strom { self?.empfangen(ereignis) }
        }
    }

    // MARK: - SatzZaehler

    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void) {
        self.kontext = kontext
        self.melde = melde
        befestigung = speicher.wahl(fuer: kontext)
        neuStarten()
    }

    func ergebnis() -> ZaehlerErgebnis? {
        defer { beenden() }
        guard var zaehler, let art = befestigung?.art else { return nil }
        ereignisse += zaehler.abschliessen()
        let gezaehlt = zaehler.anzahl
        guard gezaehlt > 0 else { return nil }
        return ZaehlerErgebnis(
            gezaehlt: gezaehlt,
            repEvents: RepEvents(algo: zaehler.profil.algo, befestigungsart: art,
                                 ereignisse: ereignisse, satzbeginn: satzbeginn))
    }

    func satzVerworfen() { beenden() }

    /// Ein Tipp in der Sensor-Zeile. Mit der neuen Art beginnt die Zaehlung
    /// von vorn: was bisher gezaehlt wurde, lief mit dem falschen Profil.
    func befestigungWaehlen(_ art: Befestigungsart) {
        guard let kontext else { return }
        speicher.merken(art, fuer: kontext)
        befestigung = BefestigungsWahl(art: art, quelle: .gewaehlt)
        neuStarten()
    }

    // MARK: - Eingang

    func empfangen(_ ereignis: SensorEreignis) {
        switch ereignis {
        case .messwert(let messwert):
            // Ein Paket von vor dem Satzbeginn kann noch im Strom stecken;
            // es gehoert nicht zum Satz.
            guard var zaehler, messwert.t >= satzbeginn else { return }
            let neu = zaehler.verarbeite(messwert)
            self.zaehler = zaehler
            weitergeben(neu)
        case .zustand(let zustand):
            if zustand.istVerbunden {
                // Nur wenn der Satz mangels Sensor noch nicht zaehlte (Spec 9).
                // Nach einer Luecke wird nicht weitergezaehlt.
                if zaehler == nil, kontext != nil, meldung == .zaehltNicht(.keinSensor) { neuStarten() }
            } else if var zaehler {
                let jetzt = uhr()
                let neu = zaehler.luecke(von: jetzt, bis: jetzt)
                self.zaehler = zaehler
                weitergeben(neu)
            }
        case .akku:
            break
        }
    }

    // MARK: - Intern

    private func neuStarten() {
        zaehler = nil
        ereignisse = []
        guard let kontext else { return }
        guard kontext.volumeKind == .reps else { return senden(.zaehltNicht(.keineWiederholungen)) }
        guard let art = befestigung?.art else { return senden(.zaehltNicht(.keineBefestigung)) }
        guard quelle.zustand.istVerbunden else { return senden(.zaehltNicht(.keinSensor)) }
        // Debug zaehlt jede Art, auch nicht freigegebene (Nachtrag 14.10. Punkt 4).
        zaehler = Zaehler(profil: .fuer(art), rateHz: Double(quelle.rate.rawValue))
        satzbeginn = uhr()
        senden(.bereit)
    }

    private func weitergeben(_ neu: [ZaehlerEreignis]) {
        for ereignis in neu {
            ereignisse.append(ereignis)
            switch ereignis {
            case .wiederholung(let w): senden(.stand(w.nummer))
            case .unsicher(let grund): senden(.pruefen(zaehler?.anzahl ?? 0, grund))
            case .zuende: break
            }
        }
    }

    private func senden(_ neu: ZaehlerMeldung) {
        meldung = neu
        melde?(neu)
    }

    /// Die Art bleibt stehen: die Aufnahme liest sie nach ergebnis().
    private func beenden() {
        zaehler = nil
        kontext = nil
        melde = nil
        meldung = nil
        ereignisse = []
    }
}
#endif
```

`Zaehler.anzahl` und `Zaehler.profil` sind `public` (`Zaehler.swift`); `SensorRate.rawValue` ist `Int` (so nutzt es `SensorAufnahmeKoordinator`).

- [x] **Step 4: Tests laufen lassen**

Run: wie Step 2.
Expected: 9 Tests grün. Scheitert `bereitDannStandJeWiederholung` an der Zahl, zuerst prüfen, ob `stapelSatz` die gleiche Form hat wie `Synthetik.satz(signal: .geschwindigkeitVertikal…)` im Package (`Packages/Sensorik/Tests/SensorikTests/Synthetik.swift:44-51`); der Koordinator darf für den Test nicht angepasst werden.

- [x] **Step 5: Commit** — `feat(geraet): ZaehlerKoordinator zaehlt live aus dem Sensorstrom (Debug)`

---

### Task 5: `GeraetModel` folgt dem Zähler, Herkunft beim Sichern

**Files:**
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetModel.swift`
- Modify: `apps/ios-member/FitnessMember/Workout/SatzMitschnitt.swift:22-31`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift:135-136`
- Test: `apps/ios-member/FitnessMemberTests/GeraetModelTests.swift`

**Interfaces:**
- Consumes: Task 3 (`SatzZaehler`, `ZaehlerMeldung`, `ZaehlerErgebnis`, `BefestigungsWahl`, `SatzZaehlerKontext`)
- Produces:
  - `GeraetModel.init(…, mitschnitt:, zaehler: (any SatzZaehler)? = nil, startwerte:)` — `zaehler` direkt nach `mitschnitt`
  - `enum GeraetModel.ZaehlerZustand: Equatable { case aus, bereit, zaehlt(Int), pruefen(Int), vonHand(Int) }`, `private(set) var zaehlerZustand`
  - `func umfangGedreht(_ wert: Int)` — der einzige Weg der Oberfläche ans Umfangsrad
  - `static func herkunft(umfang: Int, ergebnis: ZaehlerErgebnis?) -> VolumeSource`
  - `GesicherterSatz` bekommt `var volumeSource: VolumeSource = .eingegeben`, `var zaehler: ZaehlerErgebnis? = nil`, `var befestigung: BefestigungsWahl? = nil`

- [x] **Step 1: Failing tests schreiben** — in `GeraetModelTests.swift`: den Helfer `modell(…)` um `zaehler: (any SatzZaehler)? = nil` ergänzen (nach `mitschnitt`, an `GeraetModel(…)` durchreichen), am Dateiende das Double, und einen neuen Abschnitt `// MARK: - Zaehler`:

```swift
final class ZaehlerDouble: SatzZaehler {
    var kontexte: [SatzZaehlerKontext] = []
    var melde: (@MainActor (ZaehlerMeldung) -> Void)?
    var verworfen = 0
    var ergebnisAufrufe = 0
    var ergebnisWert: ZaehlerErgebnis?
    var befestigung: BefestigungsWahl? = BefestigungsWahl(art: .stapel, quelle: .vorschlag)

    func satzBeginnt(_ kontext: SatzZaehlerKontext, melde: @escaping @MainActor (ZaehlerMeldung) -> Void) {
        kontexte.append(kontext)
        self.melde = melde
    }
    func ergebnis() -> ZaehlerErgebnis? { ergebnisAufrufe += 1; return ergebnisWert }
    func satzVerworfen() { verworfen += 1 }

    static func ergebnis(_ n: Int) -> ZaehlerErgebnis {
        let w = (0..<n).map { i in
            Wiederholung(nummer: i + 1, beginn: Double(i) * 2, umkehr: Double(i) * 2 + 1, ende: Double(i) * 2 + 2,
                         ausschlag: 0.4, sicherheit: 1, pauseDavor: nil)
        }
        return ZaehlerErgebnis(gezaehlt: n, repEvents: RepEvents(
            algo: "stapel/2", befestigungsart: .stapel, ereignisse: w.map(ZaehlerEreignis.wiederholung), satzbeginn: 0))
    }
}
```

`Wiederholung`, `RepEvents`, `ZaehlerEreignis` kommen aus `Sensorik`: `import Sensorik` oben in der Datei ergänzen.

```swift
    // MARK: - Zaehler

    private func mitZaehler(_ double: ZaehlerDouble = ZaehlerDouble(),
                            enqueue: @escaping (PendingSetWrite) -> Void = { _ in },
                            mitschnitt: (any SatzMitschnitt)? = nil,
                            maschine: BootstrapResponse.Machine = GeraetTestdaten.maschine) -> GeraetModel {
        let sut = modell(maschine: maschine, bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         enqueue: enqueue, mitschnitt: mitschnitt, zaehler: double)
        sut.geraetGeoeffnet()
        return sut
    }

    @Test func dasRadFolgtDemZaehler() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        #expect(double.kontexte.count == 1)
        #expect(double.kontexte.first?.volumeKind == .reps)
        double.melde?(.bereit)
        #expect(sut.zaehlerZustand == .bereit)
        double.melde?(.stand(3))
        #expect(sut.umfang == 3)
        #expect(sut.zaehlerZustand == .zaehlt(3))
    }

    @Test func drehenInBereitIstKeineKorrektur() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        double.melde?(.bereit)
        sut.umfangGedreht(12)
        #expect(sut.zaehlerZustand == .bereit)
        double.melde?(.stand(1))
        #expect(sut.umfang == 1)
    }

    @Test func drehenNachDerZaehlungGehoertDerHand() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        double.melde?(.stand(5))
        sut.umfangGedreht(6)
        #expect(sut.zaehlerZustand == .vonHand(5))
        double.melde?(.stand(6))
        double.melde?(.stand(7))
        #expect(sut.umfang == 6)
    }

    @Test func pruefenHaeltDieZahl() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        double.melde?(.stand(4))
        double.melde?(.pruefen(4, .luecke))
        #expect(sut.zaehlerZustand == .pruefen(4))
        #expect(sut.umfang == 4)
        sut.umfangGedreht(5)
        #expect(sut.zaehlerZustand == .vonHand(4))
    }

    @Test(arguments: [(nil as Int?, 8, VolumeSource.eingegeben), (8, 8, .gemessen), (8, 9, .korrigiert)])
    func herkunftBeimSichern(gezaehlt: Int?, umfang: Int, erwartet: VolumeSource) async {
        let double = ZaehlerDouble()
        double.ergebnisWert = gezaehlt.map(ZaehlerDouble.ergebnis)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        if let gezaehlt { double.melde?(.stand(gezaehlt)) }
        if umfang != gezaehlt { sut.umfangGedreht(umfang) }
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        let body = geschrieben.first?.body
        #expect(body?.volume == umfang)
        #expect(body?.volumeSource == erwartet)
        #expect(body?.volumeCounted == gezaehlt)
        #expect(body?.repEvents?.wiederholungen.count == gezaehlt)
        #expect(sut.zaehlerZustand == .aus)
    }

    @Test func zurueckGedrehtIstGemessen() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(5)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(5))
        sut.umfangGedreht(6)
        sut.umfangGedreht(5)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volumeSource == .gemessen)
    }

    /// Review Focus 3: mehr Wiederholungen als das Rad hat (1...40).
    @Test func ueberDemRadmaximumWirdKorrigiert() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(43)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) })
        double.melde?(.stand(43))
        #expect(sut.umfang == 40)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volumeSource == .korrigiert)
        #expect(geschrieben.first?.body.volumeCounted == 43)
    }

    @Test func uebungswechselVerwirftUndBeginntNeu() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double, maschine: GeraetTestdaten.maschineMitZweiUebungen)
        double.melde?(.stand(2))
        sut.uebungWechseln(zu: "e2")
        #expect(double.verworfen == 1)
        #expect(double.kontexte.last?.exerciseId == "e2")
        #expect(sut.zaehlerZustand == .aus)
    }

    @Test func screenVerlassenVerwirft() {
        let double = ZaehlerDouble()
        let sut = mitZaehler(double)
        sut.screenVerlassen()
        #expect(double.verworfen == 1)
    }

    @Test func derMitschnittBekommtHerkunftErgebnisUndArt() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(8)
        let spion = MitschnittSpion()
        let sut = mitZaehler(double, mitschnitt: spion)
        double.melde?(.stand(8))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        guard case .gesichert(let satz)? = spion.ereignisse.last else { Issue.record("nichts gesichert"); return }
        #expect(satz.volumeSource == .gemessen)
        #expect(satz.zaehler?.gezaehlt == 8)
        #expect(satz.befestigung == BefestigungsWahl(art: .stapel, quelle: .vorschlag))
    }
```

Dazu die Review-Focus-Tests 4 und 5:

```swift
    /// Review Focus 4: ein abgelehnter Satz holt kein Ergebnis ab, die
    /// Zaehlung laeuft weiter. Aufbau wie der Ortskonflikt-Test oben
    /// (laufende Einheit in einem anderen Studio).
    @Test func abgelehnterSatzHoltKeinErgebnis() async {
        let verzeichnis = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = sessions.satzSichern(station: .testGeraet("m9", studioId: "s2"), exerciseId: "e1",
                                 einheiten: .kilogrammWiederholungen, load: 50, volume: 10,
                                 problemFlag: false, problemReason: nil)
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(4)
        let spion = MitschnittSpion()
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions, mitschnitt: spion, zaehler: double)
        sut.geraetGeoeffnet()
        double.melde?(.stand(4))
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(sut.satzAbgelehnt != nil)
        #expect(double.ergebnisAufrufe == 0)
        #expect(sut.zaehlerZustand == .zaehlt(4))
        #expect(!spion.ereignisse.contains { if case .gesichert = $0 { true } else { false } })
    }
```

```swift
    /// Review Focus 5: Herkunft nur bei Wiederholungen -- der Server lehnt
    /// sie sonst ab (Spec 6.3).
    @Test func sekundenuebungBleibtEingegeben() async {
        let double = ZaehlerDouble()
        double.ergebnisWert = ZaehlerDouble.ergebnis(3)
        var geschrieben: [PendingSetWrite] = []
        let sut = mitZaehler(double, enqueue: { geschrieben.append($0) }, maschine: GeraetTestdaten.maschineSekunden)
        await sut.satzSichern(problemFlag: false, problemReason: nil)
        #expect(geschrieben.first?.body.volumeSource == .eingegeben)
        #expect(geschrieben.first?.body.repEvents == nil)
    }
```

`GeraetTestdaten.maschineMitZweiUebungen` und `GeraetTestdaten.maschineSekunden`: prüfen, ob es Gleichwertiges schon gibt (`grep -n "static var maschine" FitnessMemberTests/GeraetModelTests.swift`); sonst nach dem Muster von `maschine(loadMax:)` anlegen — zwei Übungen `e1`/`e2` mit `volumeKind` `reps`, bzw. eine Übung `e1` mit `"volumeKind":"seconds","targetMin":60,"targetMax":90`.

- [x] **Step 2: Tests laufen lassen, sie scheitern**

Run: `xcodebuild test … -only-testing:FitnessMemberTests/GeraetModelTests -quiet`
Expected: Compile-Fehler „extra argument 'zaehler'“.

- [x] **Step 3: Umsetzen**

`SatzMitschnitt.swift`, in `GesicherterSatz` nach `problemFlag`:

```swift
    /// Spec B 6.5: damit die Aufnahme Herkunft und Zaehlerblock schreiben
    /// kann, ohne die Koordinatoren zu koppeln. Defaults fuer alle Aufrufer
    /// ohne Zaehler.
    var volumeSource: VolumeSource = .eingegeben
    var zaehler: ZaehlerErgebnis? = nil
    var befestigung: BefestigungsWahl? = nil
```

`GeraetModel.swift`:

1. Unter `private let mitschnitt`:

```swift
    /// Im Release (bis E5) immer nil, im Debug der ZaehlerKoordinator
    /// (Sensor-Spec B 6.5).
    private let zaehler: (any SatzZaehler)?

    /// Spec B 6.5. vonHand traegt den Zaehlerstand nur zur Anzeige mit.
    enum ZaehlerZustand: Equatable {
        case aus, bereit, zaehlt(Int), pruefen(Int), vonHand(Int)
    }
    private(set) var zaehlerZustand: ZaehlerZustand = .aus
```

2. `init`: Parameter `zaehler: (any SatzZaehler)? = nil,` nach `mitschnitt`, `self.zaehler = zaehler` nach `self.mitschnitt = mitschnitt`.

3. `mitschnittBeginnen()` beginnt auch den Zähler (alle vier Aufrufer — `geraetGeoeffnet`, `uebungWechseln`, `countdownBeenden`, `pauseBeenden` — sind genau die Satzanfänge):

```swift
    private func mitschnittBeginnen() {
        mitschnitt?.eingabeBegonnen(SatzMitschnittKontext(
            station: station, exerciseId: uebungId, exerciseName: aktiveUebung?.name ?? ""))
        zaehlerZustand = .aus
        zaehler?.satzBeginnt(SatzZaehlerKontext(station: station, exerciseId: uebungId, volumeKind: volumeKind)) {
            [weak self] meldung in self?.zaehlerMeldung(meldung)
        }
    }

    private func zaehlerMeldung(_ meldung: ZaehlerMeldung) {
        // Nach dem Drehen gehoert das Rad der Hand: keine Spruenge mehr.
        if case .vonHand = zaehlerZustand { return }
        switch meldung {
        case .zaehltNicht: zaehlerZustand = .aus
        case .bereit: zaehlerZustand = .bereit
        case .stand(let n):
            zaehlerZustand = .zaehlt(n)
            // Eigener Weg statt umfangGedreht: das ist keine Korrektur.
            umfang = Rastwerte.naechster(zu: n, in: umfangsWerte)
        case .pruefen(let n, _): zaehlerZustand = .pruefen(n)
        }
    }

    /// Der einzige Weg der Oberflaeche ans Umfangsrad (Spec B 6.5): nach der
    /// ersten Zaehlung schaltet Drehen auf vonHand. In bereit ist Drehen
    /// keine Korrektur, die erste Zaehlung ueberschreibt den Wert.
    func umfangGedreht(_ wert: Int) {
        umfang = wert
        switch zaehlerZustand {
        case .zaehlt(let n), .pruefen(let n): zaehlerZustand = .vonHand(n)
        case .aus, .bereit, .vonHand: break
        }
    }

    /// Spec B 6.5: ohne Ergebnis eingegeben; zurueckgedreht auf den
    /// Zaehlerstand ist gemessen.
    static func herkunft(umfang: Int, ergebnis: ZaehlerErgebnis?) -> VolumeSource {
        guard let ergebnis else { return .eingegeben }
        return umfang == ergebnis.gezaehlt ? .gemessen : .korrigiert
    }
```

4. `uebungWechseln(zu:)`: vor dem bestehenden `mitschnittBeginnen()` ein `zaehler?.satzVerworfen()`.

5. `screenVerlassen()`:

```swift
    func screenVerlassen() {
        mitschnitt?.screenVerlassen()
        zaehler?.satzVerworfen()
        zaehlerZustand = .aus
    }
```

6. `satzSichern`: nach `satzAbgelehnt = nil` und vor `sessions.satzSichern(…)`:

```swift
        // Erst nach der Ortspruefung: ein abgelehnter Satz laeuft weiter und
        // behaelt seine Zaehlung. Die Art vor ergebnis() lesen, das den Satz beendet.
        let befestigung = zaehler?.befestigung
        // Herkunft nur bei Wiederholungen: der Server lehnt sie sonst ab (Spec B 6.3).
        let ergebnis: ZaehlerErgebnis?
        if volumeKind == .reps {
            ergebnis = zaehler?.ergebnis()
        } else {
            zaehler?.satzVerworfen()
            ergebnis = nil
        }
        let herkunft = Self.herkunft(umfang: umfang, ergebnis: ergebnis)
```

`let geschrieben = sessions.satzSichern(…)` wird `var geschrieben`, danach:

```swift
        geschrieben.body.volumeSource = herkunft
        geschrieben.body.volumeCounted = ergebnis?.gezaehlt
        geschrieben.body.repEvents = ergebnis?.repEvents
```

Im `GesicherterSatz(…)`-Aufruf an den Mitschnitt anhängen: `volumeSource: herkunft, zaehler: ergebnis, befestigung: befestigung`. Am Ende von `satzSichern` vor `phase = …`: `zaehlerZustand = .aus`.

`SetWrite.volumeSource`-Kommentar (`Networking/DTOs/WorkoutSet.swift:45-47`) anpassen: „Im Debug-Build setzt GeraetModel die Herkunft aus dem Zaehler (Sensor-Spec B E4), sonst eingegeben.“

`WertZeile.swift:136`: `set: { modell.umfang = Int($0) }` → `set: { modell.umfangGedreht(Int($0)) }`.

- [x] **Step 4: Tests laufen lassen**

Run: `xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' -quiet`
Expected: alle grün, auch die bestehenden Mitschnitt-Tests (sie vergleichen `GesicherterSatz` mit Defaults).

- [x] **Step 5: Commit** — `feat(geraet): Rad folgt dem Zaehler, Herkunft geht mit dem Satz`

---

### Task 6: Aufnahme schreibt Befestigungsart und Zählerblock

**Files:**
- Modify: `apps/ios-member/FitnessMember/Workout/Sensor/SensorAufnahmeKoordinator.swift:220-240` (`beenden`)
- Test: `apps/ios-member/FitnessMemberTests/SensorAufnahmeKoordinatorTests.swift`

**Interfaces:**
- Consumes: `GesicherterSatz.volumeSource/.zaehler/.befestigung` (Task 5), `SensorAufnahme.abschliessen(…befestigungsart:befestigungsartQuelle:zaehler:)` (Task 2)

- [x] **Step 1: Failing tests schreiben**

```swift
    @Test func gesicherterSatzSchreibtArtUndZaehlerblock() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        var satz = Self.satz
        let ereignisse = RepEvents(algo: "stapel/2", befestigungsart: .stapel, ereignisse: [], satzbeginn: 0)
        satz.volumeSource = .korrigiert
        satz.zaehler = ZaehlerErgebnis(gezaehlt: 10, repEvents: ereignisse)
        satz.befestigung = BefestigungsWahl(art: .stapel, quelle: .gewaehlt)
        sut.satzGesichert(satz)
        let datei = try datei(ordner(in: wurzel)[0])
        #expect(datei.befestigungsart == .stapel)
        #expect(datei.befestigungsartQuelle == .gewaehlt)
        #expect(datei.zaehler == .init(algo: "stapel/2", gezaehlt: 10, herkunft: "korrigiert", ereignisse: ereignisse))
    }

    /// Ohne Zaehlung (0 Wiederholungen) steht die Art trotzdem drin, der Block ist null.
    @Test func ohneZaehlungNurDieArt() throws {
        let (sut, _, wurzel, _) = aufbau()
        sut.eingabeBegonnen(Self.kontext)
        var satz = Self.satz
        satz.befestigung = BefestigungsWahl(art: .kurzhantel, quelle: .vorschlag)
        sut.satzGesichert(satz)
        let datei = try datei(ordner(in: wurzel)[0])
        #expect(datei.befestigungsart == .kurzhantel)
        #expect(datei.zaehler == nil)
    }
```

`static let satz` ist ein `let` vom Typ `GesicherterSatz`; `var satz = Self.satz` kopiert ihn, die neuen Felder sind `var`.

- [x] **Step 2: Tests laufen lassen, sie scheitern** — Run: `… -only-testing:FitnessMemberTests/SensorAufnahmeKoordinatorTests -quiet`. Expected: FAIL, `befestigungsart` ist `nil`.

- [x] **Step 3: Umsetzen** — in `beenden(_:satz:)` den `abschliessen`-Aufruf ergänzen:

```swift
            try aufnahme.abschliessen(
                abschluss, kontext: kontext,
                label: .init(weightKg: satz?.weightKg, reps: satz?.reps, problemFlag: satz?.problemFlag),
                akkuProzent: quelle.zustand.akkuProzent,
                statistik: aufnahmeStatistik.ergebnis(verworfeneBytes: quelle.verworfeneBytes - verworfenBeiStart),
                ende: jetzt(), endeT: uhr(),
                befestigungsart: satz?.befestigung?.art,
                befestigungsartQuelle: satz?.befestigung?.quelle,
                zaehler: satz.flatMap { satz in
                    satz.zaehler.map { .init(algo: $0.repEvents.algo, gezaehlt: $0.gezaehlt,
                                             herkunft: satz.volumeSource.rawValue, ereignisse: $0.repEvents) }
                })
```

- [x] **Step 4: Tests laufen lassen** — volle iOS-Tests wie in Task 5. Expected: grün.

- [x] **Step 5: Commit** — `feat(sensorik): Aufnahme haelt Befestigungsart und Zaehlerblock fest`

---

### Task 7: Oberfläche, Verdrahtung, Hintergrundmodus

**Files:**
- Modify: `apps/ios-member/FitnessMember/FitnessMemberApp.swift:16-27, 59-61, 88-94`
- Modify: `apps/ios-member/FitnessMember/Screens/Training/TrainingRootView.swift:18-20, 586-599`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/SensorZeile.swift`
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/WertZeile.swift` (`umfangsrad`)
- Modify: `apps/ios-member/FitnessMember/Screens/Geraet/GeraetView.swift` (Haptik, Testnotiz-Kontext)
- Modify: `apps/ios-member/FitnessMember/Info-Additions-Debug.plist`
- Test: `apps/ios-member/FitnessMemberTests/SensorZeileTextTests.swift` (neu, reine Textableitung)

**Interfaces:**
- Consumes: `ZaehlerKoordinator` (Task 4), `GeraetModel.zaehlerZustand` (Task 5)
- Produces: `SensorZeile.zaehlerText(meldung: ZaehlerMeldung?) -> String?`, `SensorZeile.artName(_: Befestigungsart) -> String`, `SensorZeile.befestigungText(_: BefestigungsWahl?) -> String`

- [x] **Step 1: Failing test für die Texte**

```swift
#if DEBUG
import Testing
import Sensorik
@testable import FitnessMember

struct SensorZeileTextTests {
    @Test func zaehlerTexte() {
        #expect(SensorZeile.zaehlerText(meldung: nil) == nil)
        #expect(SensorZeile.zaehlerText(meldung: .bereit) == "zählt")
        #expect(SensorZeile.zaehlerText(meldung: .stand(7)) == "zählt · 7")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(7, .luecke)) == "Zahl prüfen · 7 (Lücke)")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(3, .signalSchwach)) == "Zahl prüfen · 3 (Signal schwach)")
        #expect(SensorZeile.zaehlerText(meldung: .pruefen(3, .taktUnregelmaessig)) == "Zahl prüfen · 3 (Takt unregelmäßig)")
        #expect(SensorZeile.zaehlerText(meldung: .zaehltNicht(.keineWiederholungen)) == "zählt hier nicht: keine Wiederholungen")
        #expect(SensorZeile.zaehlerText(meldung: .zaehltNicht(.keinSensor)) == "zählt nicht: kein Sensor")
        #expect(SensorZeile.zaehlerText(meldung: .zaehltNicht(.keineBefestigung)) == "Befestigung wählen")
    }

    @Test func befestigungTexte() {
        #expect(SensorZeile.befestigungText(BefestigungsWahl(art: .stapel, quelle: .vorschlag)) == "Stapel (Vorschlag)")
        #expect(SensorZeile.befestigungText(BefestigungsWahl(art: .koerper, quelle: .gewaehlt)) == "Körper")
        #expect(SensorZeile.befestigungText(nil) == "Befestigung wählen")
    }
}
#endif
```

- [x] **Step 2: Test scheitert** — `… -only-testing:FitnessMemberTests/SensorZeileTextTests -quiet` → „has no member 'zaehlerText'“.

- [x] **Step 3: Umsetzen**

`FitnessMemberApp.swift`: eine Quelle für beide Koordinatoren.

```swift
    #if DEBUG
    /// Eine Instanz fuer die ganze App: die Verbindung ueberlebt den Wechsel
    /// zwischen Geraeten (Spec Sensor-Anbindung 5.3). Der CBCentralManager
    /// entsteht erst beim Tap auf "Sensor verbinden". Aufnahme und Zaehler
    /// hoeren auf dieselbe Quelle, jeder mit eigenem Strom.
    @State private var sensorAufnahme: SensorAufnahmeKoordinator
    @State private var satzZaehler: ZaehlerKoordinator
    #endif
```

In `init()` vor `let session = …`:

```swift
        #if DEBUG
        let quelle = BluetoothSensorQuelle()
        _sensorAufnahme = State(initialValue: SensorAufnahmeKoordinator(
            quelle: quelle,
            wurzel: URL.documentsDirectory.appendingPathComponent("Sensoraufnahmen"),
            geraet: .init(
                model: Laufzeitkontext.modellkennung(),
                os: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
                appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "")))
        _satzZaehler = State(initialValue: ZaehlerKoordinator(quelle: quelle))
        #endif
```

`.sensorInstallieren(sensorAufnahme)` → `.sensorInstallieren(sensorAufnahme, zaehler: satzZaehler)`, und:

```swift
    func sensorInstallieren(_ koordinator: SensorAufnahmeKoordinator, zaehler: ZaehlerKoordinator) -> some View {
        environment(koordinator).environment(zaehler).task {
            // Zaehler zuerst: verbindet der Aufnahme-Koordinator beim Start
            // den gemerkten Sensor, soll der Zaehler die Kante schon hoeren.
            zaehler.starten()
            koordinator.starten()
        }
    }
```

`TrainingRootView.swift`: neben `sensorAufnahme` `@Environment(ZaehlerKoordinator.self) private var satzZaehler` (in `#if DEBUG`); im Modellaufbau:

```swift
        var mitschnitt: (any SatzMitschnitt)?
        var zaehler: (any SatzZaehler)?
        #if DEBUG
        mitschnitt = sensorAufnahme
        zaehler = satzZaehler
        #endif
        return GeraetModel(
            …,
            mitschnitt: mitschnitt,
            zaehler: zaehler,
            startwerte: startwerte
        )
```

Alle weiteren Stellen, die `.environment(SensorAufnahmeKoordinator…)` setzen (Previews, UI-Tests), mit `grep -rn "SensorAufnahmeKoordinator" apps/ios-member --include='*.swift'` suchen und dort den `ZaehlerKoordinator` mit derselben Quelle dazugeben.

`SensorZeile.swift`: `@Environment(ZaehlerKoordinator.self) private var zaehler` ergänzen. `body` wird ein `VStack(alignment: .leading, spacing: 0)` aus der bestehenden Zeile und darunter, nur wenn ein Satz offen ist (`zaehler.meldung != nil`):

```swift
            if let text = Self.zaehlerText(meldung: zaehler.meldung) {
                HStack(spacing: DesignSystem.Spacing.s8) {
                    Menu {
                        ForEach(Befestigungsart.allCases, id: \.self) { art in
                            Button(Self.artName(art)) { zaehler.befestigungWaehlen(art) }
                        }
                    } label: {
                        Text(Self.befestigungText(zaehler.befestigung))
                            .font(.system(size: 13).weight(.semibold))
                            .foregroundStyle(DesignSystem.Color.text)
                    }
                    // Ohne Art sagt das Menue schon "Befestigung wählen"; doppelt waere Rauschen.
                    if zaehler.meldung != .zaehltNicht(.keineBefestigung) {
                        Text(text)
                            .font(.system(size: 13).monospacedDigit())
                            .foregroundStyle(Self.istPruefen(zaehler.meldung)
                                ? DesignSystem.Color.danger : DesignSystem.Color.textMuted)
                    }
                    Spacer()
                }
                .frame(minHeight: 44)
            }
```

Ableitungen (`nonisolated static`, wie `text(zustand:rateHz:)`):

```swift
    nonisolated static func artName(_ art: Befestigungsart) -> String {
        switch art {
        case .stapel: "Stapel"
        case .langhantel: "Langhantel"
        case .kurzhantel: "Kurzhantel"
        case .hebelarm: "Hebelarm"
        case .kabelgriff: "Kabelgriff"
        case .koerper: "Körper"
        }
    }

    nonisolated static func befestigungText(_ wahl: BefestigungsWahl?) -> String {
        guard let wahl else { return "Befestigung wählen" }
        return wahl.quelle == .vorschlag ? "\(artName(wahl.art)) (Vorschlag)" : artName(wahl.art)
    }

    nonisolated static func zaehlerText(meldung: ZaehlerMeldung?) -> String? {
        switch meldung {
        case nil: nil
        case .bereit: "zählt"
        case .stand(let n): "zählt · \(n)"
        case .pruefen(let n, let grund): "Zahl prüfen · \(n) (\(grundText(grund)))"
        case .zaehltNicht(.keinSensor): "zählt nicht: kein Sensor"
        case .zaehltNicht(.keineWiederholungen): "zählt hier nicht: keine Wiederholungen"
        case .zaehltNicht(.keineBefestigung): "Befestigung wählen"
        case .zaehltNicht(.nichtFreigegeben): "zählt hier noch nicht"
        }
    }

    nonisolated static func istPruefen(_ meldung: ZaehlerMeldung?) -> Bool {
        if case .pruefen? = meldung { return true }
        return false
    }

    private nonisolated static func grundText(_ grund: UnsicherGrund) -> String {
        switch grund {
        case .luecke: "Lücke"
        case .signalSchwach: "Signal schwach"
        case .taktUnregelmaessig: "Takt unregelmäßig"
        }
    }
```

`SensorZeile.swift` braucht `import Sensorik`.

`WertZeile.swift`, in `umfangsrad` unter dem `HStack` mit dem `RastRad` (innerhalb des `VStack`):

```swift
            // Spec B 6.5: Luecke oder Unsicherheit -- die Zahl steht, das
            // Mitglied soll sie ansehen, bevor es sichert.
            if case .pruefen = modell.zaehlerZustand {
                Text("Zahl prüfen")
                    .font(.system(size: 13).weight(.semibold))
                    .foregroundStyle(DesignSystem.Color.danger)
            }
```

`GeraetView.swift`:
- Haptik je Wiederholung, ohne `#if DEBUG` (im Release ändert sich `zaehlerZustand` nie), an derselben Stelle wie die übrigen Modifier am Screen:

```swift
        // Spec B 6.5: ein kurzes Signal je gezaehlter Wiederholung, nicht
        // beim Wechsel nach bereit, pruefen oder vonHand.
        .sensoryFeedback(trigger: modell.zaehlerZustand) { _, neu in
            if case .zaehlt = neu { return .increase }
            return nil
        }
```

- `testnotizKontext`, im `#if DEBUG`-Block: `kontext["zaehler"] = String(describing: modell.zaehlerZustand)`.

`Info-Additions-Debug.plist`, vor `</dict>`:

```xml
	<!-- Sensor-Spec B 6.6: der Zaehler hoert weiter, wenn der Bildschirm
	     sperrt oder das Handy in der Tasche steckt. Nur Debug bis E5. -->
	<key>UIBackgroundModes</key>
	<array>
		<string>bluetooth-central</string>
	</array>
```

- [x] **Step 4: `xcodegen generate`, volle Tests, Release-Build, Sichtprüfung**

Run (aus `apps/ios-member`, nach `pgrep -lx xcodebuild` und `df -h /`):
1. `xcodebuild test -scheme FitnessMember -destination 'id=A2FB7461-E303-4CFE-AA08-9AC1B8C41707' -quiet` → grün.
2. `xcodebuild build -scheme FitnessMember -configuration Release -destination 'generic/platform=iOS Simulator' -quiet` → baut; das zeigt, dass kein Debug-Typ im Release referenziert wird.
3. `plutil -p` auf die gebaute Debug-`Info.plist` → enthält `UIBackgroundModes`; die Release-`Info.plist` nicht.
4. Sichtprüfung im Simulator per ID: Gerät öffnen, Sensor-Zeile zeigt „Sensor verbinden“; ohne Sensor erscheint die zweite Zeile erst mit einem offenen Satz und zeigt „Stapel (Vorschlag)“ und „zählt nicht: kein Sensor“; das Menü listet die sechs Arten. Screenshot ablegen.

- [x] **Step 5: Commit** (inkl. `project.pbxproj`) — `feat(geraet): Sensor-Zeile zeigt Befestigung und Zaehlerstand, Rad mit Haptik (Debug)`

---

### Task 8: Gerätebuild für Tim, Docs, Abschluss

**Files:**
- Modify: `docs/superpowers/specs/2026-10-10-sensor-wiederholungszaehler-design.md` (Status-Kopf)
- Modify: `data/sensoraufnahmen/README.md` (neue Felder beim Einlesen)
- Modify: dieser Plan (Häkchen)

- [x] **Step 1: README ergänzen** — unter „Felder in `korrekturen.json`“ einen Absatz:

```markdown
Ab E4 (14. Oktober 2026) schreibt die App `befestigungsart`, `befestigungsartQuelle` (`vorschlag` oder `gewaehlt`) und den `zaehler`-Block (live gezählt, Herkunft, Ereignisse) in `aufnahme.json`. Beim Einlesen: eine gewählte Art gilt; eine vorgeschlagene nur, wenn Notiz und Signal nicht widersprechen, sonst Tim fragen. `zaehler.gezaehlt` gegen das Label zeigt, wie der Live-Zähler mit dem Profil seines Builds lag; der Gütebericht rechnet trotzdem immer mit dem aktuellen Profil neu.
```

- [x] **Step 2: Spec-Kopf** — `**Umgesetzt:**`-Zeile um „E4 auf Branch `claude/sensor-e4` (14. Oktober 2026), Abschnitt 6.6 wartet auf die Messung am iPhone.“ ergänzen.

- [x] **Step 3: Volles Testset** — `pnpm typecheck`, `pnpm test`, `pnpm test:integration`, `swift test --package-path apps/ios-member/Packages/Sensorik` (Gütebericht unverändert), `xcodebuild test …`. Alle grün, Ausgaben im Bericht nennen.

- [x] **Step 4: Gerätebuild auf Just4Us** (nach `pgrep -lx xcodebuild`):

```bash
cd apps/ios-member
xcodebuild build -scheme FitnessMember -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/claude-e4-dd -allowProvisioningUpdates -quiet
xcrun devicectl device install app --device 9945091B-EC2C-5649-8159-54D2547F99EF /tmp/claude-e4-dd/Build/Products/Debug-iphoneos/FitnessMember.app
```

Expected: „App installed“. `derivedDataPath` danach wieder löschen (`rm -rf /tmp/claude-e4-dd`), der Platz ist knapp.

- [x] **Step 5: Commit** — `docs(sensorik): E4 umgesetzt, Einlesen kennt Befestigungsquelle und Zaehlerblock`

- [x] **Step 6: Geräte-Checkliste für Tim** (Spec 6.8) in den Bericht, nicht abhaken — Tim prüft am iPhone:
  1. Befestigung wählen bzw. Vorschlag prüfen, Sätze je verfügbarer Art; Rad folgt, Haptik je Wiederholung
  2. Drehen nach der ersten Zählung → keine Sprünge mehr; gesicherter Satz hat `korrigiert`
  3. Handy in der Tasche (gesperrt) während des Satzes; Zahl beim Zurückkommen — dabei die 60-s-Messungen aus 6.6 (gesperrt, Tasche) als Aufnahmen
  4. Sensor im Satz aus → „Zahl prüfen“, Satz lässt sich sichern
  5. Bluetooth aus → „zählt nicht: kein Sensor“, Satzpfad wie heute
  6. Sekunden-/Meterübung → „zählt hier nicht: keine Wiederholungen“
  7. Release-Build: kein Zähler, keine Sensor-Zeile (in Task 7 Step 4 per Build geprüft)
