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

    @Test func einZweiterAbschlussUeberschreibtNichts() throws {
        let sut = try neu(wurzel())
        try sut.abschliessen(.gesichert, kontext: Self.kontext,
                             label: .init(weightKg: 50, reps: 8, problemFlag: false),
                             akkuProzent: nil, statistik: .leer, ende: Self.start, endeT: 100)
        #expect(throws: (any Error).self) {
            try sut.abschliessen(.abgebrochen, kontext: Self.kontext, label: .init(), akkuProzent: nil,
                                 statistik: .leer, ende: Self.start, endeT: 100)
        }
        let datei = try json(sut.ordner)
        #expect(datei.abschluss == .gesichert)
        #expect(datei.label.reps == 8)
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
