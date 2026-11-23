# Tempo-Modus: Winkellage, Bericht, Welle und Trefferquote Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Im Package `Sensorik` die Lage der Last direkt aus dem Winkel des Sensors bestimmen, sie an allen Aufnahmen mit Drehung messen und darauf die reine Logik für Soll-Welle und Trefferquote setzen.

**Architecture:** `Winkellage` ist ein reiner Wert wie `Zaehler`: Messwerte hinein, `Lage` heraus, keine Uhr, keine Nebenläufigkeit. Sie entfaltet Roll und Pitch, wählt die Achse mit dem größeren Ausschlag, normiert auf den eigenen Hub und erkennt Umkehrpunkte am Winkel. Der Tempobericht bekommt einen Abschnitt, der sie über alle Aufnahmen mit mindestens 40° Hub prüft. Soll-Welle und Trefferquote sind die Tasks 7 und 8 des ersten Plans mit kleinen Streichungen. Die App folgt in einem eigenen Plan.

**Tech Stack:** Swift 6, Swift Testing, keine Abhängigkeiten.

**Spec:** `docs/superpowers/specs/2026-11-23-tempo-modus-design.md`, maßgeblich der Nachtrag N1–N8 am Ende. Vorgänger-Plan: `docs/superpowers/plans/2026-11-23-tempo-modus.md` (Tasks 1, 2, 5 umgesetzt; 3, 4, 6 entfallen; 7, 8 hier als Task 3 und 4).

## Global Constraints

- Arbeitsverzeichnis: Arbeitsbaum `.claude/worktrees/tempo-modus`, Branch `claude/tempo-modus`. Befehle laufen in `apps/ios-member/Packages/Sensorik`: `swift test --filter <Name>` beim Arbeiten, einmal `swift test` ganz vor jedem Commit (dauert einige Minuten).
- Nur Dateien in `apps/ios-member/Packages/Sensorik`, `data/sensoraufnahmen/tempobericht.md` und `docs/`. Kein App-Target, keine Migration, keine API.
- `Lageschaetzer`, `Gleichanteil`, `Hilfslage`, `Schwerkraftquelle`, `Lagebezug` und die bestehenden Abschnitte des Tempoberichts bleiben unverändert; ihre Tests bleiben grün. `Zaehler`, `Satztakt`, `SatzAutomatik`, `Befestigungsart` bleiben unverändert. `guetebericht.md` und `taktbericht.md` dürfen sich nicht ändern; `korrekturen.json` wird nicht angefasst.
- Rein und deterministisch: keine Uhr, kein Zufall, kein `async`. Schrittweite ist `1/rateHz`, nie eine Zeitstempel-Differenz (gebündelte Messwerte tragen denselben `t`). Der Bericht ist bei einem zweiten Lauf bytegleich.
- Signal: Roll = `winkel.x`, Pitch = `winkel.y`, in Grad, vom Sensor auf ±180° begrenzt. Yaw wird nicht benutzt.
- `lage`: 0 = Ruhelage, 1 = oberer Umkehrpunkt; `lage = vorzeichen · (winkel − ruhewinkel) / hub`. Werte außerhalb 0…1 sind erlaubt.
- Mindesthub 40°. Hysterese der Umkehrpunkte 10 % des Hubs. Achse steht fest ab 20° Ausschlag.
- Tragfähig heißt: Wiederholungsfehler im Median ≤ 1, Sicher-Anteil im Median ≥ 0,9, kein Satz mit einem Sprung der Lage über 0,2 zwischen zwei Messwerten.
- Bahn: halbe Breite 0,2. Standard-Tempo 1,5 s Kraftweg, 2,5 s Ablassen; je Weg 1…4 s in Schritten von 0,5 s. Die Trefferquote zählt ab der dritten Wellenperiode und nur sichere Messwerte.
- Bezeichner, Kommentare, Commit-Texte deutsch wie im Bestand (ae/oe/ue in Bezeichnern). Commits enden mit `Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>`. Nicht pushen.

## Review Focus

1. Der Winkel überschreitet mitten im Satz ±180° (Curl): die Lage darf nicht springen (Task 1).
2. Der Sensor zittert in der Ruhe um einige Grad (Hand, Atmung): keine Umkehrpunkte, Lage bleibt bei 0 (Task 1).
3. Das Mitglied bewegt sich schon, bevor der Sensor je still war: Ruhewinkel ist der erste Messwert, die Lage bleibt endlich und begrenzt (Task 1).
4. Halbe Wiederholungen gegen Satzende: der Umfang schrumpft nicht, die Lage zeigt den kürzeren Weg (Task 1).
5. Aufnahmen, in denen die gewählte Achse nahe Pitch ±90° springt: der Bericht zeigt sie als Sprung über 0,2, statt sie zu verschlucken (Task 2).

---

### Task 1: Winkellage

**Files:**
- Create: `Sources/Sensorik/Winkellage.swift`
- Modify: `Tests/SensorikTests/Synthetik.swift` (Erweiterung anhängen)
- Test: `Tests/SensorikTests/WinkellageTests.swift`

**Interfaces:**
- Consumes: `Lage`, `Wegrichtung`, `Umkehrpunkt` aus `Sources/Sensorik/Lage.swift`; `SensorMesswert`.
- Produces:

```swift
public enum Winkelachse: String, Codable, Sendable { case roll, pitch }
public struct GemerkterWinkel: Codable, Sendable, Equatable {
    public var achse: Winkelachse
    public var vorzeichen: Int          // +1 oder −1: Richtung des Kraftwegs in Grad
    public var hubGrad: Double
    public init(achse: Winkelachse, vorzeichen: Int, hubGrad: Double)
}
public struct Winkellage: Sendable {
    public static let mindesthubGrad = 40.0
    public init(rateHz: Double, gemerkt: GemerkterWinkel? = nil)
    public mutating func verarbeite(_ m: SensorMesswert) -> Lage
    public mutating func luecke(von: TimeInterval, bis: TimeInterval)
    /// Auch das Ende einer Bewegung in der Ruhelage zaehlt als Umkehrpunkt (unten).
    public private(set) var umkehrpunkte: [Umkehrpunkt]
    /// Groesster Ausschlag aus der Ruhelage bisher, in Grad (fuer den Abbruch nach N4).
    public var groessterAusschlagGrad: Double { get }
    /// Nach mindestens zwei vollen Wiederholungen der Stand zum Merken, sonst der uebergebene.
    public var gemerkt: GemerkterWinkel? { get }
}
```

  Verhalten (Spec N3, N8):
  - **Ruhewinkel:** solange noch keine Bewegung erkannt ist, der Median der letzten Sekunde stiller Messwerte (alle Drehraten-Beträge unter 5 °/s). Gab es keinen stillen Messwert, der erste Messwert. Mit der ersten Bewegung (Ausschlag über 5°) steht er für den Satz fest.
  - **Achse:** ohne gemerkten Wert die mit dem bisher größeren Ausschlag; fest ab 20°. Mit gemerktem Wert von Anfang an fest.
  - **Maßstab:** mit gemerktem Wert dessen Hub bis zum Ende der zweiten Wiederholung, dann der Mittelwert der ersten beiden. Ohne gemerkten Wert: das Größere aus 40° und dem bisher größten Ausschlag; nach der ersten vollen Wiederholung deren Hub, nach der zweiten der Mittelwert beider. Danach folgt der Hub langsam (je Wiederholung höchstens 10 % Richtung des neuen Werts) und nur, wenn die Wiederholung mindestens 80 % des Hubs erreicht.
  - **Sicher:** wahr, sobald der Hub bekannt ist (gemerkt oder nach der ersten vollen Wiederholung) und ≥ 40°; auch in Ruhe und sofort nach einer Lücke.
  - **Richtung:** `.hin`, solange die Lage steigt, `.rueck`, solange sie fällt, `.unbekannt` vor der ersten Bewegung.

- Produces (Test-Hilfe in `Synthetik.swift`):

```swift
struct Drehsatz { let werte: [SensorMesswert]; let lage: [Double] }   // Wahrheit je Messwert
static func drehsatz(wiederholungen: Int, kraftweg: Double = 1.5, ablassen: Double = 2.5,
                     hubGrad: Double = 140, hubAnteil: [Int: Double] = [:],
                     achse: Winkelachse = .roll, vorzeichen: Int = 1, startGrad: Double = 0,
                     pauseNach: [Int: Double] = [:], zitternGrad: Double = 0,
                     ruheVorher: Double = 3, ruheNachher: Double = 2,
                     rate: Double = 50, buendel: Int = 2,
                     luecke: (ab: Double, dauer: Double)? = nil) -> Drehsatz
```

  Winkel = `startGrad + vorzeichen · hubGrad · lage`, auf ±180° gefaltet; Kosinus-Flanken wie `Synthetik.hub`; Drehrate = Ableitung auf derselben Achse; Beschleunigung (0, 0, 1). `pauseNach[n]` hält nach der n-ten Wiederholung unten an (Sekunden). `zitternGrad` legt in Ruhe und Pausen ein Sinus-Zittern mit 7 Hz und dieser Amplitude auf den Winkel (deterministisch). `ruheVorher: 0` beginnt mitten in der Bewegung.

- [ ] **Step 1: `Synthetik.drehsatz` schreiben** und in `WinkellageTests.swift` die Hilfe

```swift
/// Mittlere und groesste Abweichung |Lage − Wahrheit| ab der genannten Wiederholung; schlaegt fehl, wenn die Wiederholung nicht existiert.
func fehler(_ satz: Drehsatz, ab wiederholung: Int, gemerkt: GemerkterWinkel? = nil, rate: Double = 50)
    -> (mittel: Double, max: Double, lagen: [Lage], schaetzer: Winkellage)
```

- [ ] **Step 2: Fehlschlagende Tests schreiben**

```swift
let bekannt = GemerkterWinkel(achse: .roll, vorzeichen: 1, hubGrad: 140)

@Test func mitGemerktemWertFolgtDieLageAbDerErstenWiederholung() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 1, gemerkt: bekannt)
    #expect(f.mittel <= 0.02 && f.max <= 0.06)
    #expect(f.lagen.allSatisfy(\.sicher))
}
@Test func ohneGemerktenWertStimmtDieLageAbDerDritten() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 3)
    #expect(f.mittel <= 0.03)
    #expect(f.schaetzer.gemerkt == GemerkterWinkel(achse: .roll, vorzeichen: 1, hubGrad: f.schaetzer.gemerkt!.hubGrad))
    #expect(abs(f.schaetzer.gemerkt!.hubGrad - 140) <= 3)
}
@Test func vorlaeufigerMassstabLaesstDenPunktNichtUeberschiessen() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 3), ab: 1)
    #expect(f.lagen.allSatisfy { $0.lage >= -0.05 && $0.lage <= 1.05 })
    #expect(f.lagen.map(\.lage).max()! >= 0.95)
}
@Test func ueberPlusMinus180SpringtDieLageNicht() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 8, startGrad: 170), ab: 1, gemerkt: bekannt)
    #expect(f.mittel <= 0.02)
    #expect(zip(f.lagen, f.lagen.dropFirst()).allSatisfy { abs($1.lage - $0.lage) <= 0.06 })
}
@Test func negativeDrehrichtungUndPitchWerdenErkannt() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 6, hubGrad: 60, achse: .pitch, vorzeichen: -1), ab: 3)
    #expect(f.mittel <= 0.03)
    #expect(f.schaetzer.gemerkt?.achse == .pitch && f.schaetzer.gemerkt?.vorzeichen == -1)
}
@Test func umkehrpunkteWechselnObenUndUnten() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 6), ab: 1)
    #expect(f.schaetzer.umkehrpunkte.map(\.oben) == Array(repeating: [true, false], count: 6).flatMap { $0 })
}
@Test func sicherErstMitBekanntemHubUndNurAbVierzigGrad() {
    let ohne = fehler(Synthetik.drehsatz(wiederholungen: 6), ab: 1)
    let ersteVolle = ohne.schaetzer.umkehrpunkte[1].t
    #expect(ohne.lagen.filter { $0.t < ersteVolle }.allSatisfy { !$0.sicher })
    // Der untere Umkehrpunkt wird erst erkannt, wenn die Lage wieder um die Hysterese gestiegen ist.
    #expect(ohne.lagen.filter { $0.t > ersteVolle + 0.6 }.allSatisfy(\.sicher))      // auch in der Ruhe danach
    let klein = fehler(Synthetik.drehsatz(wiederholungen: 6, hubGrad: 30), ab: 1)
    #expect(klein.lagen.allSatisfy { !$0.sicher })
    #expect(abs(klein.schaetzer.groessterAusschlagGrad - 30) <= 2)
}
@Test func zitternInDerRuheIstKeineWiederholung() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 6, pauseNach: [3: 3], zitternGrad: 3, ruheVorher: 6), ab: 1, gemerkt: bekannt)
    #expect(f.schaetzer.umkehrpunkte.count == 12)
    #expect(f.lagen.prefix(250).allSatisfy { abs($0.lage) <= 0.05 })
    #expect(f.mittel <= 0.04)
}
@Test func bewegungOhneRuheDavorBleibtBegrenzt() {
    let f = fehler(Synthetik.drehsatz(wiederholungen: 8, ruheVorher: 0), ab: 3)
    #expect(f.lagen.allSatisfy { $0.lage.isFinite && $0.lage >= -0.25 && $0.lage <= 1.25 })
    #expect(f.mittel <= 0.05)
}
@Test func geaenderterHubWirdNachgefuehrtAberHalbeWiederholungenSchrumpfenIhnNicht() {
    let groesser = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 3, gemerkt: GemerkterWinkel(achse: .roll, vorzeichen: 1, hubGrad: 100))
    #expect(groesser.mittel <= 0.03)
    let satz = Synthetik.drehsatz(wiederholungen: 10, hubAnteil: [9: 0.6, 10: 0.6])
    let f = fehler(satz, ab: 3, gemerkt: bekannt)
    let obenInDerNeunten = f.lagen.filter { $0.t > 3 + 8 * 4 && $0.t < 3 + 9 * 4 }.map(\.lage).max()!
    #expect(abs(obenInDerNeunten - 0.6) <= 0.05)
    #expect(abs(f.schaetzer.gemerkt!.hubGrad - 140) <= 3)
}
@Test func nachEinerLueckeStimmtDieLageSofortWieder() {
    let satz = Synthetik.drehsatz(wiederholungen: 10, luecke: (ab: 12.0, dauer: 1.0))
    var s = Winkellage(rateHz: 50, gemerkt: bekannt); var letzteT = 0.0; var nach: [(Lage, Double)] = []
    for (m, wahr) in zip(satz.werte, satz.lage) {
        if m.t - letzteT > 0.5 { s.luecke(von: letzteT, bis: m.t) }
        let l = s.verarbeite(m); letzteT = m.t
        if m.t >= 13.0 && m.t < 14.0 { nach.append((l, wahr)) }
    }
    #expect(nach.allSatisfy { $0.0.sicher && abs($0.0.lage - $0.1) <= 0.05 })
}
@Test func hundertHertzLiefertDieselbeGuete() {
    #expect(fehler(Synthetik.drehsatz(wiederholungen: 8, rate: 100), ab: 1, gemerkt: bekannt, rate: 100).mittel <= 0.02)
}
@Test func ohneZweiWiederholungenBleibtDerUebergebeneWert() {
    #expect(fehler(Synthetik.drehsatz(wiederholungen: 1), ab: 1, gemerkt: bekannt).schaetzer.gemerkt == bekannt)
}
```

- [ ] **Step 3: Laufen lassen** — `swift test --filter WinkellageTests`, Expected: FAIL (Typ `Winkellage` fehlt)
- [ ] **Step 4: `Winkellage` umsetzen** nach dem Verhalten oben. Entfalten: Differenz zum vorigen Messwert auf ±180° falten und aufsummieren, je Achse.
- [ ] **Step 5: Laufen lassen** — `swift test --filter WinkellageTests`, dann `swift test`. Expected: PASS; `git status` zeigt `guetebericht.md`, `taktbericht.md`, `tempobericht.md` unverändert.
- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs docs/superpowers/plans/2026-11-23-tempo-modus-winkellage.md tools/sensorik-aufnahme apps/ios-member/Packages/Sensorik
git commit -m "feat(sensorik): Winkellage – Lage der Last direkt aus dem Sensorwinkel"
```

### Task 2: Abschnitt „Winkellage“ im Tempobericht

**Files:**
- Create: `Tests/SensorikTests/WinkelBericht.swift`
- Modify: `Tests/SensorikTests/TempoBericht.swift` (nur: `markdown` stellt den neuen Abschnitt voran), `Tests/SensorikTests/TempoBerichtTests.swift`
- Test: `Tests/SensorikTests/WinkelBerichtTests.swift`
- Erzeugt: `data/sensoraufnahmen/tempobericht.md`; committet die 11 Aufnahmen `data/sensoraufnahmen/2026-11-23-21*/`

**Interfaces:**
- Consumes: `Winkellage`, `GemerkterWinkel` (Task 1); `Korrekturen.laden()`, `Pfade.aufnahmen`, `SensorAufnahmeLeser.lesen(ordner:)`; die Datumsteilung aus `TempoBericht` (Abstimmung vor 2026-11-01, Prüfung ab dann).
- Produces:

```swift
struct WinkelZeile {
    let ordner: String; let art: Befestigungsart?; let pruefung: Bool
    let repsWahr: Int
    let hubGrad: Double            // gemerkter Hub am Satzende, 0 wenn keiner
    let wdhFehler: Double          // |Umkehrpunkte / 2 − repsWahr|
    let sicherAnteil: Double       // Anteil sicherer Messwerte zwischen dem 3. und dem letzten Umkehrpunkt
    let hubStreuung: Double        // Standardabweichung / Mittel der Hube je Wiederholung
    let groessterSprung: Double    // groesster Schritt der Lage zwischen zwei Messwerten
}
struct WinkelTor: Equatable { let saetze: Int; let wdhFehler: Double; let sicherAnteil: Double; let spruenge: Int }
enum WinkelBericht {
    /// Alle Aufnahmen mit bekannter Wiederholungszahl >= 5, auch solche unter 40° Hub.
    static func zeilen() throws -> [WinkelZeile]
    static func geeignet(_ z: WinkelZeile) -> Bool                    // hubGrad >= 40
    static func tor(_ zeilen: [WinkelZeile]) -> WinkelTor             // Mediane ueber die geeigneten; spruenge = Saetze mit Sprung > 0,2
    static func tragfaehig(_ t: WinkelTor) -> Bool
    static func markdown(_ zeilen: [WinkelZeile]) -> String
}
```

  Auswahl: (a) Ordner mit Eintrag in `korrekturen.json` und `repsWahr >= 5`, gleich welcher Befestigungsart (auch `nil`); (b) Ordner, deren `aufnahme.json` einen Schlüssel `tempo` trägt (Mac-Aufnahmen): Wiederholungen aus `label.reps`, sofern ≥ 5, Art aus `befestigungsart`. Der Schlüssel `tempo` steht nicht in `SensorAufnahmeDatei`; dafür die Datei zusätzlich mit `JSONSerialization` lesen. Lücken-Zeilen werden als `luecke(von:bis:)` an die `Winkellage` gereicht; Aufnahmen mit Lücken bleiben in der Auswertung. Der Live-Lauf speist ohne gemerkten Wert.

  Abschnitt im Bericht (vor den bestehenden): je Teil (Abstimmung, Prüfung) eine Zeile je Befestigungsart mit: Sätze gesamt, davon geeignet (≥ 40°), Median Hub, Median Wiederholungsfehler, Median Sicher-Anteil, Median Hub-Streuung, Sätze mit Sprung, „tragfähig ja/nein“. Darunter die geeigneten Sätze mit Sprung über 0,2 einzeln und die zehn mit dem größten Wiederholungsfehler. Der Kopf sagt in einem Satz, dass der Winkel eine direkte Messung ist und deshalb gegen die gezählten Wiederholungen geprüft wird.

- [ ] **Step 1: Fehlschlagende Tests schreiben**

```swift
@Test func zeileEinesKuenstlichenSatzes() {
    let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 12,
                               eintraege: Synthetik.drehsatz(wiederholungen: 12).werte.map { .messwert($0) }, rateHz: 50)
    #expect(z.wdhFehler == 0)
    #expect(abs(z.hubGrad - 140) <= 3)
    #expect(z.sicherAnteil == 1)
    #expect(z.hubStreuung <= 0.02)
    #expect(z.groessterSprung <= 0.06)
    #expect(WinkelBericht.geeignet(z))
}
@Test func unterVierzigGradIstNichtGeeignet() {
    let z = WinkelBericht.zeile(ordner: "x", art: .stapel, pruefung: false, repsWahr: 10,
                               eintraege: Synthetik.drehsatz(wiederholungen: 10, hubGrad: 25).werte.map { .messwert($0) }, rateHz: 50)
    #expect(!WinkelBericht.geeignet(z))
}
@Test func tragfaehigHaeltDieDreiSchwellen() {
    #expect(WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1, sicherAnteil: 0.9, spruenge: 0)))
    #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1.5, sicherAnteil: 0.9, spruenge: 0)))
    #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1, sicherAnteil: 0.89, spruenge: 0)))
    #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 10, wdhFehler: 1, sicherAnteil: 0.9, spruenge: 1)))
    #expect(!WinkelBericht.tragfaehig(WinkelTor(saetze: 0, wdhFehler: 0, sicherAnteil: 1, spruenge: 0)))
}
@Test func einSprungDerAchseWirdGezaehltNichtVerschluckt() {
    // Ab der 5. Wiederholung springt der Rollwinkel um 180° (wie nahe Pitch ±90°)
    var werte = Synthetik.drehsatz(wiederholungen: 8).werte
    for i in werte.indices where werte[i].t > 3 + 4 * 4 {
        let m = werte[i]; var r = m.winkel.x + 180; if r > 180 { r -= 360 }
        werte[i] = SensorMesswert(t: m.t, beschleunigung: m.beschleunigung, drehrate: m.drehrate, winkel: Vektor3(x: r, y: m.winkel.y, z: m.winkel.z))
    }
    let z = WinkelBericht.zeile(ordner: "x", art: .kurzhantel, pruefung: true, repsWahr: 8, eintraege: werte.map { .messwert($0) }, rateHz: 50)
    #expect(z.groessterSprung > 0.2)
    #expect(WinkelBericht.tor([z]).spruenge == 1)
}
@Test func macAufnahmenVom23NovemberSindDabei() throws {
    let zeilen = try WinkelBericht.zeilen()
    let mac = zeilen.filter { $0.ordner.hasPrefix("2026-11-23-21") }
    #expect(mac.count == 11)
    #expect(mac.allSatisfy(\.pruefung))
    #expect(mac.filter(WinkelBericht.geeignet).count >= 7)
    #expect(zeilen.count >= 150)
}
```

  `WinkelBericht.zeile(ordner:art:pruefung:repsWahr:eintraege:rateHz:)` ist dafür eine eigene statische Funktion; `zeilen()` ruft sie je Aufnahme. In `TempoBerichtTests.berichtSchreibenUndFreigegebeneArtenPruefen` wird nichts geprüft, was vom neuen Abschnitt abhängt.

- [ ] **Step 2: Laufen lassen** — `swift test --filter WinkelBerichtTests`, Expected: FAIL (Typ fehlt)
- [ ] **Step 3: Umsetzen**, `TempoBericht.markdown` stellt `WinkelBericht.markdown(try WinkelBericht.zeilen())` voran.
- [ ] **Step 4: Laufen lassen** — `swift test`, Expected: PASS; `tempobericht.md` enthält den Abschnitt „Winkellage“; ein zweiter Lauf ändert die Datei nicht; `guetebericht.md` und `taktbericht.md` unverändert.
- [ ] **Step 5: Commit**

```bash
git add apps/ios-member/Packages/Sensorik data/sensoraufnahmen/tempobericht.md data/sensoraufnahmen/2026-11-23-21*
git commit -m "feat(sensorik): Tempobericht prueft die Winkellage gegen gezaehlte Wiederholungen"
```

- [ ] **Step 6: HALT — Tim den Abschnitt vorlegen** (führt der Steuernde aus, nicht der Umsetzende): je Befestigungsart und Teil die Zahl der geeigneten Sätze und die drei Kennzahlen, dazu jede Aufnahme mit Sprung. Tim bestätigt oder ändert die Schwellen (Spec N5). Wurde `Winkellage` dafür nachgestellt, bleiben alle Tests aus Task 1 unverändert grün. Ohne Tims Antwort nicht mit Task 3 fortfahren.

### Task 3: Tempovorgabe und Soll-Welle

Wie **Task 7** in `docs/superpowers/plans/2026-11-23-tempo-modus.md` (Dateien, Schnittstellen, Tests, Schritte), mit diesen Streichungen nach Spec N2/N6: `Sollwelle.init(vorgabe:)` hat keinen Parameter `startetOben`; der Test `startetObenBeginntMitDemAblassen` und der Satz „Mit `startetOben` beginnt die Welle bei 1 …“ entfallen. `Tempovorgabe.gleichmaessig` und der Test `gleichmaessigNimmtDasMittel` entfallen ebenfalls (der Sonderfall „waagerecht“ ist gestrichen).

### Task 4: Trefferquote und Auswertung je Wellenperiode

Wie **Task 8** in `docs/superpowers/plans/2026-11-23-tempo-modus.md`, unverändert bis auf: Der Klammersatz „(bei `startetOben` unverändert, weil `Weg` die Richtung trägt)“ entfällt. Zusätzlicher Test, weil die Lage jetzt auch in Ruhe sicher ist (Spec N8):

```swift
@Test func ruheImSatzZaehltAlsNebenDerBahn() {
    // sichere Messwerte, Lage steht 8 s auf 0: diese zwei Perioden haben einen Anteil deutlich unter 1
    let e = lauf({ $0 >= 16 && $0 < 24 ? 0 : welle.lage(bei: $0) }, dauer: 48).ergebnis()!
    #expect(e.perioden[2]! < 0.6 && e.perioden[3]! < 0.6)
    #expect(e.quote < 0.95)
}
```

---

## Danach

Eigener Plan für die App (Spec-Etappen E3 und E4 mit N4): Vollbild-Anzeige, Schalter mit Eignung per Messung, Start, Ziel, Satzende, Speicher für `GemerkterWinkel` und die Ungeeignet-Marke.
