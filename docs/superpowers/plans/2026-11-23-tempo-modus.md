# Tempo-Modus (E1 + E2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Package `Sensorik` eine Live-Schätzung der Lage der Last im eigenen Bewegungsumfang bauen, sie gegen alle Aufnahmen messen (`tempobericht.md`, Gütetor) und darauf die reine Logik für Soll-Welle und Trefferquote setzen.

**Architecture:** Alles in diesem Plan liegt im Swift-Package `apps/ios-member/Packages/Sensorik` und läuft mit `swift test` auf dem Mac, ohne Simulator. Der `Lageschaetzer` ist wie der `Zaehler` ein reiner Wert ohne Uhr und Nebenläufigkeit; er erkennt seine Umkehrpunkte selbst und rastet daran ein. Die App (Anzeige, Start, Ziel, Satzende, Schalter: Spec-Etappen E3 und E4) bekommt nach dem Gütetor einen eigenen Plan, weil erst der Bericht zeigt, für welche Befestigungsarten weitergebaut wird.

**Tech Stack:** Swift 6, Swift Testing (`import Testing`, `@Test`, `#expect`), keine Abhängigkeiten.

**Spec:** `docs/superpowers/specs/2026-11-23-tempo-modus-design.md`

## Global Constraints

- Arbeitsverzeichnis für alle Befehle: `apps/ios-member/Packages/Sensorik`. Testlauf: `swift test --filter <Name>`; am Ende jeder Aufgabe einmal `swift test` ganz.
- Nur Dateien in `Packages/Sensorik`, `data/sensoraufnahmen/tempobericht.md` und `docs/`. Keine Änderung an App-Target, Migrationen, API, Domänenpaket, Trainerportal.
- Bestehende Typen (`Zaehler`, `Satztakt`, `SatzAutomatik`, `Befestigungsart.freigegeben`) bleiben unverändert. `guetebericht.md` und `taktbericht.md` dürfen sich durch diesen Plan nicht ändern.
- Rein und deterministisch: keine Uhr, kein Zufall, kein `async`. Gefiltert wird mit der Sollrate, nicht mit Zeitstempel-Differenzen, weil gebündelte Messwerte denselben `t` tragen (Spec A 4.7).
- Befestigungsarten in diesem Projekt: `stapel`, `kurzhantel`, `langhantel`. Der Winkel wird nicht genutzt.
- `lage`: 0 = Ruhelage der Last (unten), 1 = oberer Umkehrpunkt; Werte außerhalb sind erlaubt.
- Bahn: halbe Breite 0,2 des Bewegungsumfangs. Standard-Tempo 1,5 s Kraftweg, 2,5 s Ablassen; verstellbar je Weg in Schritten von 0,5 s zwischen 1 und 4 s.
- Trefferquote zählt ab der dritten Wellenperiode und nur Messwerte mit `sicher == true`.
- Gütetor je Befestigungsart: Verzögerung im Median ≤ 150 ms, mittlere Abweichung ≤ 0,15, kein Satz länger als eine Wiederholung außerhalb von −0,25 … 1,25.
- Bezeichner, Kommentare und Commit-Texte deutsch wie im Bestand (Umlaute in Bezeichnern als ae/oe/ue). Commits enden mit `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`.
- Branch von `master`. Spec, Plan und `tools/sensorik-sim/tempo_nachrechnung.py` liegen bisher uncommittet auf `codex/sensor-luecken-2026-10-26` und gehen in den ersten Commit.

## Review Focus

1. Gebündelte Zeitstempel: mehrere Messwerte mit gleichem `t` dürfen weder durch null teilen noch die Lage springen lassen (Task 1).
2. Lange Ruhe vor dem Satz (Vorlauf, Pause): die Lage bleibt auf der Ruhelage und driftet nicht aus der Bahn (Task 2).
3. Stoß beim Absetzen des Stapels (kurze Spitze von mehreren g): die Lage springt nicht dauerhaft weg und der gemerkte Umfang wird nicht verfälscht (Task 3).
4. Halbe Wiederholungen gegen Satzende (Ermüdung, Hub nur 60 %): der Umfang schrumpft nicht mit, die Lage zeigt den kürzeren Weg (Task 4).
5. Mitglied macht Pause mitten im Satz und fällt mehrere Perioden zurück: die Auswertung rechnet weiter in Wellenperioden und liefert keine Division durch null für Perioden ohne sichere Messwerte (Task 8).

---

### Task 1: Künstliche Hubsätze und Lageschätzer für die saubere Bewegung

**Files:**
- Create: `Sources/Sensorik/Lage.swift`, `Sources/Sensorik/Lageschaetzer.swift`
- Modify: `Tests/SensorikTests/Synthetik.swift` (Erweiterung anhängen)
- Test: `Tests/SensorikTests/LageschaetzerTests.swift`

**Interfaces:**
- Produces (`Lage.swift`):

```swift
public enum Wegrichtung: Sendable, Equatable { case hin, rueck, unbekannt }   // hin = Kraftweg, wenn senkrecht
public struct Lage: Sendable, Equatable {
    public let t: TimeInterval
    public let lage: Double
    public let richtung: Wegrichtung
    public let sicher: Bool
}
public struct Umkehrpunkt: Sendable, Equatable { public let t: TimeInterval; public let oben: Bool }
public struct GemerkterUmfang: Codable, Sendable, Equatable {
    public var hub: Double          // interne Einheit des Schaetzers, nur als Verhaeltnis gueltig
    public var startetOben: Bool
    public var senkrecht: Bool
}
```

- Produces (`Lageschaetzer.swift`):

```swift
public struct Lageschaetzer: Sendable {
    public init(rateHz: Double, umfang: GemerkterUmfang? = nil)
    public mutating func verarbeite(_ m: SensorMesswert) -> Lage
    public mutating func luecke(von: TimeInterval, bis: TimeInterval)
    /// Auch das Ende einer Bewegung in Ruhe zaehlt als Umkehrpunkt. Waagerecht ist `oben` das ferne Ende.
    public private(set) var umkehrpunkte: [Umkehrpunkt]
    /// Nach mindestens zwei Wiederholungen der Stand zum Merken, sonst der uebergebene.
    public var umfang: GemerkterUmfang? { get }
}
```

- Produces (Test-Hilfen in `Synthetik.swift`):

```swift
struct Hubsatz { let werte: [SensorMesswert]; let lage: [Double] }   // Wahrheit je Messwert
static func hub(wiederholungen: Int, kraftweg: Double = 1.5, ablassen: Double = 2.5,
                hubMeter: Double = 0.4, hubAnteil: [Int: Double] = [:],
                startetOben: Bool = false, achse: Vektor3 = Vektor3(x: 0, y: 0, z: 1),
                halt: (wiederholung: Int, beiLage: Double, dauer: Double)? = nil,
                biasG: Double = 0, stoss: (bei: Double, g: Double)? = nil,
                ruheVorher: Double = 3, ruheNachher: Double = 2,
                rate: Double = 50, buendel: Int = 2,
                luecke: (ab: Double, dauer: Double)? = nil) -> Hubsatz
```

  Die Schwerkraft liegt immer auf z (1 g). Die Position folgt Kosinus-Flanken (`(1 − cos(π·τ/dauer))/2`), die Beschleunigung ist deren zweite Ableitung, in g entlang `achse` addiert. `hubAnteil[n]` skaliert den Hub der n-ten Wiederholung (1-basiert). `lage` ist auf `hubMeter` normiert.

- [ ] **Step 1: `Synthetik.hub` schreiben** und in `LageschaetzerTests.swift` die Hilfe

```swift
/// Mittlere und groesste Abweichung |Schaetzung − Wahrheit| ab der genannten Wiederholung.
func fehler(_ satz: Hubsatz, ab wiederholung: Int, umfang: GemerkterUmfang? = nil,
            rate: Double = 50) -> (mittel: Double, max: Double, lagen: [Lage])
```

- [ ] **Step 2: Fehlschlagende Tests schreiben**

```swift
@Test func sauberBewegtFolgtDieLageDerWahrheit() {
    let f = fehler(Synthetik.hub(wiederholungen: 12), ab: 3)
    #expect(f.mittel <= 0.08)
    #expect(f.max <= 0.20)
}
@Test func gebuendelteZeitstempelLassenDieLageNichtSpringen() {
    let f = fehler(Synthetik.hub(wiederholungen: 8, buendel: 4), ab: 3)
    let spruenge = zip(f.lagen, f.lagen.dropFirst()).map { abs($1.lage - $0.lage) }
    #expect(spruenge.allSatisfy { $0.isFinite && $0 <= 0.08 })
}
@Test func umkehrpunkteWechselnObenUndUnten() {
    var s = Lageschaetzer(rateHz: 50)
    for m in Synthetik.hub(wiederholungen: 6).werte { _ = s.verarbeite(m) }
    #expect(s.umkehrpunkte.count == 12)
    #expect(s.umkehrpunkte.map(\.oben) == Array(repeating: [true, false], count: 6).flatMap { $0 })
}
```

- [ ] **Step 3: Tests laufen lassen**

Run: `swift test --filter LageschaetzerTests`
Expected: FAIL (Typ `Lageschaetzer` fehlt)

- [ ] **Step 4: `Lage.swift` und `Lageschaetzer` umsetzen**

Ansatz (Spec 6 und 11; der genaue Filter ist frei, die Tests und das Gütetor in Task 5 entscheiden): Schwerkraft als langsamer Tiefpass der Beschleunigung wie im `Zaehler`; Vertikalbeschleunigung = Beschleunigung auf die Schwerkraftrichtung projiziert minus deren Betrag; leckend zu Geschwindigkeit und Weg aufsummiert, Schrittweite `1/rateHz`; Umkehrpunkt = Vorzeichenwechsel der Geschwindigkeit mit Hysterese; am Umkehrpunkt Nullpunkt und Hub neu setzen und die Korrektur über etwa 150 ms einblenden statt zu springen.

- [ ] **Step 5: Tests laufen lassen**

Run: `swift test --filter LageschaetzerTests`, dann `swift test`
Expected: PASS; `git status` zeigt `guetebericht.md` und `taktbericht.md` unverändert

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-11-23-tempo-modus-design.md docs/superpowers/plans/2026-11-23-tempo-modus.md tools/sensorik-sim/tempo_nachrechnung.py apps/ios-member/Packages/Sensorik
git commit -m "feat(sensorik): Lageschaetzer fuer die saubere Bewegung"
```

### Task 2: Einrasten gegen Drift, Stocken und Ruhe

**Files:**
- Modify: `Sources/Sensorik/Lageschaetzer.swift`
- Test: `Tests/SensorikTests/LageschaetzerTests.swift`

**Interfaces:**
- Consumes: `Lageschaetzer`, `Synthetik.hub`, `fehler` aus Task 1.

- [ ] **Step 1: Fehlschlagende Tests schreiben**

```swift
@Test func driftLaesstDenPunktNichtWeglaufen() {
    let f = fehler(Synthetik.hub(wiederholungen: 20, biasG: 0.02), ab: 3)
    #expect(f.lagen.allSatisfy { $0.lage >= -0.25 && $0.lage <= 1.25 })
    #expect(f.mittel <= 0.12)
}
@Test func stockenMittenImWegBleibtStehen() {
    let satz = Synthetik.hub(wiederholungen: 8, halt: (wiederholung: 5, beiLage: 0.5, dauer: 1.5))
    let f = fehler(satz, ab: 3)
    // waehrend des Halts (Wahrheit konstant 0,5) bleibt die Schaetzung in der Naehe
    let imHalt = zip(satz.lage, f.lagen).filter { abs($0.0 - 0.5) < 1e-9 }.map(\.1.lage)
    #expect(imHalt.count >= 60)
    #expect(imHalt.allSatisfy { abs($0 - 0.5) <= 0.2 })
}
@Test func langeRuheVorDemSatzBleibtAufDerRuhelage() {
    let f = fehler(Synthetik.hub(wiederholungen: 6, biasG: 0.01, ruheVorher: 90), ab: 3)
    let ruhe = f.lagen.prefix(90 * 50)
    #expect(ruhe.allSatisfy { abs($0.lage) <= 0.1 && !$0.sicher })
    #expect(f.mittel <= 0.10)
}
@Test func einrastenSpringtNicht() {
    let f = fehler(Synthetik.hub(wiederholungen: 12, biasG: 0.02), ab: 1)
    let spruenge = zip(f.lagen, f.lagen.dropFirst()).map { abs($1.lage - $0.lage) }
    #expect(spruenge.max()! <= 0.08)
}
```

- [ ] **Step 2: Laufen lassen** — `swift test --filter LageschaetzerTests`, Expected: FAIL in mindestens `driftLaesstDenPunktNichtWeglaufen` oder `langeRuheVorDemSatzBleibtAufDerRuhelage` (falls schon grün: weiter zu Step 4)
- [ ] **Step 3: Einrasten, Ruheerkennung und Glättung nachziehen.** In Ruhe (keine Bewegung über der Schwelle) gilt `lage` = Ruhelage und `sicher = false`; vor dem ersten Umkehrpunkt ebenfalls `sicher = false`.
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(sensorik): Lage rastet an Umkehrpunkten ein"`

### Task 3: Lücken, Ratenwechsel und Stöße

**Files:**
- Modify: `Sources/Sensorik/Lageschaetzer.swift`
- Test: `Tests/SensorikTests/LageschaetzerTests.swift`

- [ ] **Step 1: Fehlschlagende Tests schreiben**

```swift
@Test func nachEinerLueckeIstDieLageBisZumNaechstenUmkehrpunktUnsicher() {
    let satz = Synthetik.hub(wiederholungen: 10, luecke: (ab: 12.0, dauer: 1.0))
    var s = Lageschaetzer(rateHz: 50); var lagen: [Lage] = []; var letzteT = 0.0
    for m in satz.werte {
        if m.t - letzteT > 0.5 { s.luecke(von: letzteT, bis: m.t) }
        lagen.append(s.verarbeite(m)); letzteT = m.t
    }
    let nachLuecke = lagen.first { $0.t >= 13.0 }!
    #expect(!nachLuecke.sicher)
    let naechsteUmkehr = s.umkehrpunkte.first { $0.t > 13.0 }!.t
    #expect(lagen.filter { $0.t > naechsteUmkehr + 0.3 && $0.t < naechsteUmkehr + 3 }.allSatisfy(\.sicher))
}
@Test func hundertHertzLiefertDieselbeGuete() {
    let f = fehler(Synthetik.hub(wiederholungen: 10, rate: 100), ab: 3, rate: 100)
    #expect(f.mittel <= 0.08)
}
@Test func stossBeimAbsetzenVerfaelschtWederLageNochUmfang() {
    // Ende der 6. Wiederholung bei 3 + 6 * 4 = 27 s
    let ohne = Synthetik.hub(wiederholungen: 10)
    let mit = Synthetik.hub(wiederholungen: 10, stoss: (bei: 27.0, g: 4))
    var a = Lageschaetzer(rateHz: 50), b = Lageschaetzer(rateHz: 50)
    for m in ohne.werte { _ = a.verarbeite(m) }
    var lagen: [Lage] = []
    for m in mit.werte { lagen.append(b.verarbeite(m)) }
    #expect(lagen.allSatisfy { $0.lage.isFinite && $0.lage >= -0.25 && $0.lage <= 1.25 })
    #expect(abs(b.umfang!.hub / a.umfang!.hub - 1) <= 0.1)
}
```

- [ ] **Step 2: Laufen lassen** — Expected: FAIL (`luecke` wirkt noch nicht bzw. Stoß verfälscht)
- [ ] **Step 3: `luecke(von:bis:)` umsetzen** (Zustand der Integration verwerfen, `sicher = false` bis zum nächsten Umkehrpunkt, Umfang behalten) und Stöße begrenzen (Vertikalbeschleunigung kappen oder Ausreißer beim Hub verwerfen).
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(sensorik): Lage uebersteht Luecken, Ratenwechsel und Stoesse"`

### Task 4: Kraftweg, Start abwärts, waagerechte Bewegung, gemerkter Umfang

**Files:**
- Modify: `Sources/Sensorik/Lageschaetzer.swift`
- Test: `Tests/SensorikTests/LageschaetzerTests.swift`

**Interfaces:**
- Produces: `GemerkterUmfang.startetOben` und `.senkrecht` sind gefüllt; `Lage.richtung` ist `.hin` auf dem Kraftweg (Last hebt sich) und `.rueck` beim Ablassen. Bei waagerechter Bewegung ist `.hin` der erste Weg des Satzes.

- [ ] **Step 1: Fehlschlagende Tests schreiben**

```swift
@Test func hebtSichDieLastIstDasDerKraftweg() {
    let satz = Synthetik.hub(wiederholungen: 8)
    let f = fehler(satz, ab: 3)
    // in der Mitte jedes Aufwaertswegs (Wahrheit steigt, 0,3…0,7) steht .hin
    let auf = zip(zip(satz.lage, satz.lage.dropFirst()), f.lagen).filter { $0.0.1 > $0.0.0 && (0.3...0.7).contains($0.0.0) && $0.1.sicher }
    #expect(auf.count > 100)
    #expect(auf.allSatisfy { $0.1.richtung == .hin })
}
@Test func beginntDieUebungAbwaertsWirdDasGemerkt() throws {
    var s = Lageschaetzer(rateHz: 50)
    let satz = Synthetik.hub(wiederholungen: 6, startetOben: true)
    for m in satz.werte { _ = s.verarbeite(m) }
    let gemerkt = try #require(s.umfang)
    #expect(gemerkt.startetOben && gemerkt.senkrecht)
    #expect(s.umkehrpunkte.first?.oben == false)
    // Erst mit dem gemerkten Umfang kennt der naechste Satz die Ruhelage oben.
    var zweiter = Lageschaetzer(rateHz: 50, umfang: gemerkt)
    let ruhe = satz.werte.prefix(100).map { zweiter.verarbeite($0).lage }
    #expect(ruhe.allSatisfy { abs($0 - 1) <= 0.1 })
}
@Test func waagerechteBewegungWirdErkannt() {
    var s = Lageschaetzer(rateHz: 50)
    for m in Synthetik.hub(wiederholungen: 6, achse: Vektor3(x: 1, y: 0, z: 0)).werte { _ = s.verarbeite(m) }
    #expect(s.umfang?.senkrecht == false)
    #expect(s.umkehrpunkte.count == 12)
}
@Test func mitGemerktemUmfangStimmtSchonDieErsteWiederholung() throws {
    var s = Lageschaetzer(rateHz: 50)
    for m in Synthetik.hub(wiederholungen: 6).werte { _ = s.verarbeite(m) }
    let gemerkt = try #require(s.umfang)
    let f = fehler(Synthetik.hub(wiederholungen: 6), ab: 1, umfang: gemerkt)
    #expect(f.mittel <= 0.10)
}
@Test func geaenderterUmfangWirdInZweiWiederholungenNachgefuehrt() throws {
    var s = Lageschaetzer(rateHz: 50)
    for m in Synthetik.hub(wiederholungen: 6, hubMeter: 0.6).werte { _ = s.verarbeite(m) }
    let f = fehler(Synthetik.hub(wiederholungen: 8, hubMeter: 0.3), ab: 3, umfang: try #require(s.umfang))
    #expect(f.mittel <= 0.10)
}
@Test func halbeWiederholungenAmEndeSchrumpfenDenUmfangNicht() {
    let satz = Synthetik.hub(wiederholungen: 10, hubAnteil: [9: 0.6, 10: 0.6])
    let f = fehler(satz, ab: 3)
    let obenInDerNeunten = f.lagen.filter { $0.t > 3 + 8 * 4 && $0.t < 3 + 9 * 4 }.map(\.lage).max()!
    #expect(abs(obenInDerNeunten - 0.6) <= 0.15)
}
@Test func ohneZweiWiederholungenBleibtDerUebergebeneUmfang() {
    let alt = GemerkterUmfang(hub: 1, startetOben: false, senkrecht: true)
    var s = Lageschaetzer(rateHz: 50, umfang: alt)
    for m in Synthetik.hub(wiederholungen: 1).werte { _ = s.verarbeite(m) }
    #expect(s.umfang == alt)
}
```

- [ ] **Step 2: Laufen lassen** — Expected: FAIL
- [ ] **Step 3: Umsetzen.** Senkrecht heißt: der Anteil der Bewegung entlang der Schwerkraft überwiegt; die Schwelle anhand der Aufnahmen wählen (Spec 11) und als benannte Konstante mit Begründung ablegen. Der Umfang folgt nach den ersten zwei Wiederholungen nur noch langsam und nur nach oben schnell, damit kurze Wiederholungen ihn nicht verkleinern.
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(sensorik): Kraftweg, Startlage und gemerkter Umfang"`

### Task 5: Bezug, Tempobericht und Gütetor

**Files:**
- Create: `Sources/Sensorik/Tempofreigabe.swift`, `Tests/SensorikTests/Lagebezug.swift`, `Tests/SensorikTests/TempoBericht.swift`
- Test: `Tests/SensorikTests/TempoBerichtTests.swift`
- Erzeugt: `data/sensoraufnahmen/tempobericht.md`

**Interfaces:**
- Consumes: `Lageschaetzer`; `AufnahmeLauf`-Muster, `Korrekturen.laden()`, `Pfade.aufnahmen`, `SensorAufnahmeLeser.lesen(ordner:)`.
- Produces:

```swift
// Sources: eigene Freigabeliste des Tempo-Modus (Spec 7.6), anfangs leer.
public enum Tempofreigabe { public static let arten: Set<Befestigungsart> = [] }

// Tests
enum Lagebezug {
    struct Ergebnis { let lage: [Double]; let aktiv: Range<Int>; let periode: Double }
    /// Nachtraegliche Rechnung wie tools/sensorik-sim/tempo_nachrechnung.py, je Halbwelle auf 0…1 normiert.
    static func berechne(_ werte: [SensorMesswert], rateHz: Double) -> Ergebnis?
}
struct TempoZeile {
    let ordner: String; let art: Befestigungsart
    let verzoegerungMs: Double      // Verschiebung mit der groessten Kreuzkorrelation im aktiven Teil
    let abweichung: Double          // Mittel von |live − bezug| im aktiven Teil, unverschoben
    let ausreisser: Bool            // laenger als eine Periode ausserhalb −0,25…1,25
}
struct TempoTor: Equatable { let saetze: Int; let verzoegerungMs: Double; let abweichung: Double; let ausreisser: Int }
enum TempoBericht {
    static func zeilen() throws -> [TempoZeile]
    static func tor(_ zeilen: [TempoZeile], art: Befestigungsart) -> TempoTor   // Mediane
    static func torErreicht(_ t: TempoTor) -> Bool
    static func markdown(_ zeilen: [TempoZeile]) -> String
}
```

  Auswahl der Aufnahmen wie im Python-Skript: Art `stapel`/`kurzhantel`/`langhantel`, `repsWahr >= 5`, keine Lücken-Zeile, mindestens 300 Messwerte. Der Live-Lauf speist den `Lageschaetzer` ohne gemerkten Umfang.

- [ ] **Step 1: Fehlschlagende Tests schreiben**

```swift
@Test func bezugTrifftDieWahrheitEinesKuenstlichenSatzes() throws {
    let satz = Synthetik.hub(wiederholungen: 12)
    let b = try #require(Lagebezug.berechne(satz.werte, rateHz: 50))
    #expect(abs(b.periode - 4.0) <= 0.2)
    let diff = b.aktiv.map { abs(b.lage[$0] - satz.lage[$0]) }
    #expect(diff.reduce(0, +) / Double(diff.count) <= 0.08)
}
@Test func dasTorHaeltDieDreiSchwellen() {
    #expect(TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.15, ausreisser: 0)))
    #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 151, abweichung: 0.15, ausreisser: 0)))
    #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.16, ausreisser: 0)))
    #expect(!TempoBericht.torErreicht(TempoTor(saetze: 20, verzoegerungMs: 150, abweichung: 0.15, ausreisser: 1)))
    #expect(!TempoBericht.torErreicht(TempoTor(saetze: 0, verzoegerungMs: 0, abweichung: 0, ausreisser: 0)))
}
@Test func verzoegerungEinesVerschobenenSignalsWirdGemessen() {
    // live = bezug um 6 Messwerte (120 ms bei 50 Hz) verzoegert
    #expect(abs(TempoBericht.verzoegerungMs(live: verschoben(um: 6), bezug: sinus(), rateHz: 50) - 120) <= 20)
}
/// Schreibt den Bericht und haelt jede freigegebene Art am Tor fest.
@Test func berichtSchreibenUndFreigegebeneArtenPruefen() throws {
    let zeilen = try TempoBericht.zeilen()
    #expect(zeilen.count >= 120)
    try TempoBericht.markdown(zeilen).write(to: Pfade.aufnahmen.appendingPathComponent("tempobericht.md"),
                                           atomically: true, encoding: .utf8)
    for art in Tempofreigabe.arten {
        let t = TempoBericht.tor(zeilen, art: art)
        #expect(TempoBericht.torErreicht(t), "\(art.rawValue) ist freigegeben, haelt das Tor aber nicht: \(t)")
    }
}
```

  `verzoegerungMs(live:bezug:rateHz:)` ist dafür eine eigene statische Funktion in `TempoBericht`; `sinus()` und `verschoben(um:)` sind kleine Hilfen im Test.

- [ ] **Step 2: Laufen lassen** — `swift test --filter TempoBerichtTests`, Expected: FAIL (Typen fehlen)
- [ ] **Step 3: Umsetzen.** `markdown` nach dem Aufbau von `Guetebericht.markdown`: Kopf mit Datum der jüngsten Aufnahme (nicht „heute“, damit der Bericht deterministisch bleibt), je Art eine Zeile mit Sätzen, Median-Verzögerung, Median-Abweichung, Zahl der Ausreißer, „Tor erreicht: ja/nein“, darunter die zehn schlechtesten Sätze je Art.
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS; `data/sensoraufnahmen/tempobericht.md` existiert; ein zweiter Lauf ändert die Datei nicht (`git diff --stat` nach dem zweiten Lauf leer)
- [ ] **Step 5: Schätzer gegen den Bericht abstimmen.** Erreicht `stapel` oder `kurzhantel` das Tor nicht, Filter in `Lageschaetzer` nachstellen und Step 4 wiederholen. Die Tests aus Task 1–4 bleiben dabei grün; keine Schwelle im Tor und in den Tests ändern. Höchstens drei Abstimmungsrunden, dann mit dem Stand weiter zu Step 6.
- [ ] **Step 6: Commit** — `git add -A apps/ios-member/Packages/Sensorik data/sensoraufnahmen/tempobericht.md && git commit -m "feat(sensorik): Tempobericht und Guetetor der Lageschaetzung"`
- [ ] **Step 7: HALT — Tim den Bericht vorlegen.** Die drei Zahlen je Befestigungsart nennen, dazu was nicht erreicht wurde. Tim bestätigt oder ändert die Schwellen (Spec 6.4) und entscheidet, für welche Arten es weitergeht. Ohne seine Antwort nicht mit Task 6 fortfahren. Besteht keine Art, endet der Plan hier.

### Task 6: Freigabe der bestätigten Befestigungsarten

**Files:**
- Modify: `Sources/Sensorik/Tempofreigabe.swift`
- Test: `Tests/SensorikTests/TempoBerichtTests.swift` (bestehender Test `berichtSchreibenUndFreigegebeneArtenPruefen`)

- [ ] **Step 1:** Jede von Tim bestätigte Art in `Tempofreigabe.arten` eintragen, **eine Art je Commit**, mit den Zahlen aus dem Bericht in der Commit-Nachricht. Hat Tim Schwellen geändert: zuerst `torErreicht`, den Test `dasTorHaeltDieDreiSchwellen` und Spec 6.4 in einem eigenen Commit nachziehen.
- [ ] **Step 2:** `swift test`, Expected: PASS
- [ ] **Step 3: Commit** — z. B. `git commit -am "feat(sensorik): Tempo-Modus fuer stapel freigegeben (Verzoegerung … ms, Abweichung …)"`

### Task 7: Tempovorgabe und Soll-Welle

**Files:**
- Create: `Sources/Sensorik/Tempovorgabe.swift`, `Sources/Sensorik/Sollwelle.swift`
- Test: `Tests/SensorikTests/SollwelleTests.swift`

**Interfaces:**
- Produces:

```swift
public struct Tempovorgabe: Codable, Sendable, Equatable {
    public let kraftweg: Double, ablassen: Double                 // Sekunden
    public static let standard = Tempovorgabe(kraftweg: 1.5, ablassen: 2.5)
    /// Rundet auf 0,5 s und begrenzt auf 1…4 s.
    public init(kraftweg: Double, ablassen: Double)
    /// Beide Wege mit dem Mittel (waagerechte Bewegung, Spec 6.3).
    public var gleichmaessig: Tempovorgabe { get }
    public var periode: Double { get }
}
public enum Weg: Sendable, Equatable { case kraftweg, ablassen }
public struct Taktmarke: Sendable, Equatable { public let t: TimeInterval; public let lage: Double }
public struct Sollwelle: Sendable, Equatable {
    public static let halbeBahnbreite = 0.2
    public init(vorgabe: Tempovorgabe, startetOben: Bool = false)
    /// t in Sekunden seit der Los-Marke; davor die Ruhelage.
    public func lage(bei t: TimeInterval) -> Double
    public func periode(bei t: TimeInterval) -> Int?             // 0-basiert, nil vor der Los-Marke
    public func weg(bei t: TimeInterval) -> Weg?
    public func zielzeit(wiederholungen: Int) -> TimeInterval
    /// Umkehrpunkte und Mitte jedes Wegs im Zeitfenster.
    public func taktmarken(von: TimeInterval, bis: TimeInterval) -> [Taktmarke]
    public func inDerBahn(_ lage: Double, bei t: TimeInterval) -> Bool
}
```

  Mit `startetOben` beginnt die Welle bei 1 und der erste Weg ist `.ablassen` mit der Ablass-Dauer.

- [ ] **Step 1: Fehlschlagende Tests schreiben**

```swift
@Test func standardIstAnderthalbUndZweieinhalb() {
    #expect(Tempovorgabe.standard.periode == 4.0)
}
@Test(arguments: [(0.2, 1.0), (1.7, 1.5), (1.8, 2.0), (9.0, 4.0)])
func vorgabeRundetUndBegrenzt(roh: Double, erwartet: Double) {
    #expect(Tempovorgabe(kraftweg: roh, ablassen: roh).kraftweg == erwartet)
}
@Test func gleichmaessigNimmtDasMittel() {
    #expect(Tempovorgabe.standard.gleichmaessig == Tempovorgabe(kraftweg: 2.0, ablassen: 2.0))
}
@Test func welleLaeuftUntenLosUndIstNachDemKraftwegOben() {
    let w = Sollwelle(vorgabe: .standard)
    #expect(w.lage(bei: -2) == 0)
    #expect(w.lage(bei: 0) == 0)
    #expect(abs(w.lage(bei: 0.75) - 0.5) < 1e-9)
    #expect(abs(w.lage(bei: 1.5) - 1) < 1e-9)
    #expect(abs(w.lage(bei: 2.75) - 0.5) < 1e-9)
    #expect(abs(w.lage(bei: 4.0)) < 1e-9)
    #expect(w.periode(bei: -0.1) == nil)
    #expect(w.periode(bei: 3.9) == 0)
    #expect(w.periode(bei: 4.0) == 1)
    #expect(w.weg(bei: 1.4) == .kraftweg)
    #expect(w.weg(bei: 1.6) == .ablassen)
}
@Test func startetObenBeginntMitDemAblassen() {
    let w = Sollwelle(vorgabe: .standard, startetOben: true)
    #expect(w.lage(bei: -1) == 1)
    #expect(w.weg(bei: 0.1) == .ablassen)
    #expect(abs(w.lage(bei: 2.5)) < 1e-9)
    #expect(abs(w.lage(bei: 4.0) - 1) < 1e-9)
}
@Test func zielUndTaktmarken() {
    let w = Sollwelle(vorgabe: .standard)
    #expect(w.zielzeit(wiederholungen: 12) == 48)
    #expect(w.taktmarken(von: 0, bis: 4).map(\.t) == [0, 0.75, 1.5, 2.75])
    #expect(w.taktmarken(von: 0, bis: 4).map(\.lage).map { ($0 * 100).rounded() / 100 } == [0, 0.5, 1, 0.5])
}
@Test func bahnIstZweiZehntelBreit() {
    let w = Sollwelle(vorgabe: .standard)
    #expect(w.inDerBahn(0.7, bei: 0.75))
    #expect(!w.inDerBahn(0.71, bei: 0.75))
}
```

- [ ] **Step 2: Laufen lassen** — `swift test --filter SollwelleTests`, Expected: FAIL
- [ ] **Step 3: Umsetzen** (Flanke `(1 − cos(π·τ/dauer))/2`, keine Haltezeit an den Umkehrpunkten).
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS
- [ ] **Step 5: Commit** — `git commit -am "feat(sensorik): Tempovorgabe und Soll-Welle"`

### Task 8: Trefferquote und Auswertung je Wellenperiode

**Files:**
- Create: `Sources/Sensorik/Tempoauswertung.swift`
- Test: `Tests/SensorikTests/TempoauswertungTests.swift`

**Interfaces:**
- Consumes: `Sollwelle`, `Weg`, `Lage` (Task 1, 7).
- Produces:

```swift
public enum Wegurteil: Sendable, Equatable {
    case imTempo
    case zuSchnell(Int, von: Int)
    case zuLangsam(Int, von: Int)
}
public struct Tempoergebnis: Sendable, Equatable {
    public let quote: Double                 // 0…1
    public let perioden: [Double?]           // Anteil in der Bahn je gewerteter Periode; nil ohne sichere Messwerte
    public let kraftweg: Wegurteil
    public let ablassen: Wegurteil
}
public struct Tempoauswertung: Sendable {
    public init(welle: Sollwelle)
    /// t in Sekunden seit der Los-Marke. Jeder Messwert zaehlt gleich (Sollrate), nicht nach Zeitstempel-Differenz.
    public mutating func erfasse(_ lage: Lage, bei t: TimeInterval)
    public var laufendeQuote: Double? { get }     // nil, solange nichts Gewertetes da ist
    /// nil bei weniger als drei begonnenen Perioden mit sicheren Messwerten ("Zu kurz fuer eine Auswertung").
    public func ergebnis() -> Tempoergebnis?
}
```

  Regeln (Spec 7.5): Gewertet wird ab Periode 2 (0-basiert) bis zum letzten erfassten Messwert, auch über jede Zielzeit hinaus; nur `sicher == true`. „Voraus“ heißt auf dem Kraftweg `lage > soll`, beim Ablassen `lage < soll` (bei `startetOben` unverändert, weil `Weg` die Richtung trägt). Ein Weg einer Periode gilt als zu schnell, wenn mehr als die Hälfte seiner gewerteten Messwerte außerhalb der Bahn und voraus liegt; zu langsam entsprechend. Das Urteil je Wegart nennt die häufigere Abweichung mit Zahl und Gesamtzahl der gewerteten Perioden; ohne Abweichung `.imTempo`.

- [ ] **Step 1: Fehlschlagende Tests schreiben** — Hilfe `lauf(_ funktion: (TimeInterval) -> Double, dauer: Double, sicher: (TimeInterval) -> Bool = { _ in true }) -> Tempoauswertung` speist 50 Messwerte je Sekunde mit `lage = funktion(t)`, `t = k/50` für `k` in `0..<Int(dauer * 50)`.

```swift
let welle = Sollwelle(vorgabe: .standard)

@Test func werDerWelleFolgtHatHundertProzent() {
    let e = lauf({ welle.lage(bei: $0) }, dauer: 48).ergebnis()!
    #expect(e.quote == 1)
    #expect(e.perioden.count == 10)                    // 12 Perioden, die ersten zwei zaehlen nicht
    #expect(e.kraftweg == .imTempo && e.ablassen == .imTempo)
}
@Test func dieErstenZweiPeriodenZaehlenNicht() {
    let e = lauf({ $0 < 8 ? 5 : welle.lage(bei: $0) }, dauer: 24).ergebnis()!
    #expect(e.quote == 1)
}
@Test func zuSchnellesAblassenWirdGezaehlt() {
    // ab Periode 6 faellt die Lage beim Ablassen in 1 s statt 2,5 s
    let e = lauf({ t in
        let p = Int(t / 4), tau = t - Double(p) * 4
        guard p >= 6, tau > 1.5 else { return welle.lage(bei: t) }
        return tau < 2.5 ? (1 + cos(.pi * (tau - 1.5))) / 2 : 0
    }, dauer: 48).ergebnis()!
    #expect(e.kraftweg == .imTempo)
    #expect(e.ablassen == .zuSchnell(6, von: 10))
    #expect(e.quote < 0.9 && e.quote > 0.5)
}
@Test func werZurueckfaelltIstZuLangsam() {
    let e = lauf({ welle.lage(bei: $0 - 1.0) }, dauer: 48).ergebnis()!     // eine Sekunde hinterher
    if case .zuLangsam = e.kraftweg {} else { Issue.record("Kraftweg sollte zu langsam sein: \(e.kraftweg)") }
}
@Test func unsichereMesswerteZaehlenNicht() {
    let e = lauf({ $0 >= 20 && $0 < 24 ? 9 : welle.lage(bei: $0) }, dauer: 48,
                 sicher: { !($0 >= 20 && $0 < 24) }).ergebnis()!
    #expect(e.quote == 1)
    #expect(e.perioden[3] == nil)                       // Periode 5 ganz ohne sichere Messwerte
}
@Test func wenigerAlsDreiPeriodenGibtKeineAuswertung() {
    #expect(lauf({ welle.lage(bei: $0) }, dauer: 7.9).ergebnis() == nil)
    #expect(lauf({ welle.lage(bei: $0) }, dauer: 7.9).laufendeQuote == nil)
}
@Test func pauseMittenImSatzRechnetInWellenperiodenWeiter() {
    // 12 s Stillstand unten ab t = 16: drei Perioden ohne Bewegung, danach wieder im Takt
    let e = lauf({ $0 >= 16 && $0 < 28 ? 0 : welle.lage(bei: $0) }, dauer: 48).ergebnis()!
    #expect(e.perioden.count == 10)
    #expect(e.perioden.allSatisfy { $0 == nil || ($0! >= 0 && $0! <= 1) })
    #expect(e.quote.isFinite && e.quote < 1)
}
@Test func ueberDasZielHinausZaehltWeiter() {
    let e = lauf({ welle.lage(bei: $0) }, dauer: welle.zielzeit(wiederholungen: 12) + 8).ergebnis()!
    #expect(e.perioden.count == 12)
}
@Test func messwerteVorDerLosMarkeWerdenUebergangen() {
    var a = Tempoauswertung(welle: welle)
    a.erfasse(Lage(t: 0, lage: 0.9, richtung: .unbekannt, sicher: true), bei: -1)
    #expect(a.laufendeQuote == nil)
}
```

- [ ] **Step 2: Laufen lassen** — `swift test --filter TempoauswertungTests`, Expected: FAIL
- [ ] **Step 3: Umsetzen** (Zähler je Periode und Wegart; keine gespeicherten Messwerte).
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS; `git status` zeigt außer den neuen Dateien nur `tempobericht.md` unverändert
- [ ] **Step 5: Commit** — `git commit -am "feat(sensorik): Trefferquote und Auswertung je Wellenperiode"`

---

## Danach

Ein eigener Plan für die App (Spec-Etappen E3 und E4): Vollbild-Anzeige mit `Canvas`/`TimelineView`, Schalter, Start mit flacher Linie, Zielmarke, Satzende über der Pause, gemerkter Umfang nach dem Muster von `Befestigungsspeicher`, Anbindung an `GeraetModel` über eine immer kompilierte Naht. Er setzt auf `Lageschaetzer`, `Tempofreigabe`, `Sollwelle` und `Tempoauswertung` aus diesem Plan auf und wird geschrieben, sobald Task 6 abgeschlossen ist.
