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
