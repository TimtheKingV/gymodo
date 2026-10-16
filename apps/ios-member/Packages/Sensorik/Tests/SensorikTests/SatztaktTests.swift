import Foundation
import Testing
@testable import Sensorik

struct SatztaktTests {
    /// Aufheben, zehn gleichmaessige Wiederholungen, Ablegen, Ruhe.
    private func synthetisch(wiederholungen: Int, takt: Double = 1.9, rate: Double = 50) -> [SensorMesswert] {
        let dt = 1 / rate
        let vorlauf = 2.0, nachlauf = 3.0
        let gesamt = vorlauf + Double(wiederholungen) * takt + nachlauf
        return (0..<Int(gesamt * rate)).map { i in
            let t = Double(i) * dt
            var y = 1.0
            if t < vorlauf { y += 0.8 * sin(t * .pi / vorlauf) } // Aufheben: ein Hub, kein Takt
            else if t < vorlauf + Double(wiederholungen) * takt { y += 0.3 * sin((t - vorlauf) * 2 * .pi / takt) }
            return SensorMesswert(t: 100 + t, beschleunigung: Vektor3(x: 0, y: y, z: 0.05),
                                  drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
    }

    @Test(arguments: [6, 8, 10, 12])
    func zaehltDenTaktOhneAufhebenUndAblegen(n: Int) throws {
        let e = try #require(Satztakt.auswerten(synthetisch(wiederholungen: n)))
        // Auf eins genau: die Zuschlaege sind an echten Saetzen abgestimmt, deren
        // Ausschlag am Rand ausklingt; die Kastenform hier ist haerter.
        #expect(abs(e.anzahl - n) <= 1)
        #expect(abs(e.takt - 1.9) < 0.1)
    }

    @Test func ruheGibtNichts() {
        let still = (0..<500).map { i in
            SensorMesswert(t: Double(i) / 50, beschleunigung: Vektor3(x: 0, y: 1, z: 0),
                           drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: 0, y: 0, z: 0))
        }
        #expect(Satztakt.auswerten(still) == nil)
    }

    @Test func zuKurzGibtNichts() {
        #expect(Satztakt.auswerten(Array(synthetisch(wiederholungen: 10).prefix(100))) == nil)
    }

    /// Die Saetze vom 16.10., fuer die der Takt eindeutig ist. Das Druecken
    /// ueber Kopf (Schulter, Trizeps) steht in `breiteMitToleranz`.
    @Test(arguments: [
        ("2026-10-16-0935-01", 10), ("2026-10-16-0936-02", 8), ("2026-10-16-0937-01", 6),
        ("2026-10-16-0938-01", 10), ("2026-10-16-0939-01", 10), ("2026-10-16-0940-01", 10),
    ])
    func echteSaetzeExakt(name: String, wahr: Int) throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        let e = try #require(Satztakt.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz)))
        #expect(e.anzahl == wahr)
    }

    @Test(arguments: [
        ("2026-10-16-0938-02", 10), ("2026-10-16-0940-02", 10), ("2026-10-16-0942-01", 9),
        ("2026-10-16-0944-01", 8),
    ])
    func echteSaetzeAufEinsGenau(name: String, wahr: Int) throws {
        let (datei, eintraege) = try SensorAufnahmeLeser.lesen(ordner: Pfade.aufnahmen.appendingPathComponent(name))
        let werte = eintraege.compactMap { if case .messwert(let m) = $0 { m } else { nil } }
        let e = try #require(Satztakt.auswerten(werte, rateHz: Double(datei.sensor.rateSollHz)))
        #expect(abs(e.anzahl - wahr) <= 1)
    }
}
