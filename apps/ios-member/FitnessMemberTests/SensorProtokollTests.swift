#if DEBUG
import Foundation
import Testing
@testable import FitnessMember

struct SensorProtokollTests {
    private func wurzel() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    private func zeilen(_ sut: SensorProtokoll) throws -> [String] {
        try String(contentsOf: sut.datei, encoding: .utf8).split(separator: "\n").map(String.init)
    }

    @Test func schreibtZeilenMitOrtszeit() throws {
        let sut = SensorProtokoll(wurzel: wurzel(), jetzt: { SensorAufnahmeTests.start },
                                  zeitzone: SensorAufnahmeTests.berlin)
        sut.schreiben("app gestartet")
        sut.schreiben("sensor verbunden")
        #expect(try zeilen(sut) == ["2026-09-19T14:12:03+02:00 app gestartet",
                                    "2026-09-19T14:12:03+02:00 sensor verbunden"])
        #expect(sut.datei.lastPathComponent == "protokoll.log")
    }

    @Test func legtDieAlteDateiBeiseiteStattEndlosZuWachsen() throws {
        let w = wurzel()
        let sut = SensorProtokoll(wurzel: w, jetzt: { SensorAufnahmeTests.start }, grenzeBytes: 100)
        for n in 0..<5 { sut.schreiben("zeile \(n) mit etwas text") }
        let alt = w.appendingPathComponent("protokoll-alt.log")
        #expect(FileManager.default.fileExists(atPath: alt.path))
        #expect(try zeilen(sut).last?.hasSuffix("zeile 4 mit etwas text") == true)
        #expect(try zeilen(sut).count < 5)
    }

    @Test func zustandstexte() {
        #expect(SensorProtokoll.text(.aus) == "aus")
        #expect(SensorProtokoll.text(.verbunden(name: "WT901BLE67", akkuProzent: 60)) == "verbunden WT901BLE67, 60 %")
        #expect(SensorProtokoll.text(.getrennt(wirdNeuVerbunden: true)) == "getrennt, wird neu verbunden")
        #expect(SensorProtokoll.text(.bluetoothNichtBereit(.ausgeschaltet)) == "bluetooth nicht bereit: ausgeschaltet")
    }

    @Test func spannungMitPunktUndZweiStellen() {
        #expect(SensorProtokoll.akkuText(hundertstelVolt: 382) == "akku 3.82 V (60 %)")
        #expect(SensorProtokoll.akkuText(hundertstelVolt: 0) == "akku 0.00 V (0 %)")
    }
}
#endif
