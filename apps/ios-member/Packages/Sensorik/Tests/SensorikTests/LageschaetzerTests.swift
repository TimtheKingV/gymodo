import Foundation
import Testing
@testable import Sensorik

struct LageschaetzerTests {
    /// Mittlere und groesste Abweichung |Schaetzung − Wahrheit| ab der genannten Wiederholung.
    /// `lagen` enthaelt alle Schaetzungen des Satzes, auch die der Ruhe davor.
    func fehler(_ satz: Synthetik.Hubsatz, ab wiederholung: Int, umfang: GemerkterUmfang? = nil,
                rate: Double = 50) -> (mittel: Double, max: Double, lagen: [Lage]) {
        var schaetzer = Lageschaetzer(rateHz: rate, umfang: umfang)
        let lagen = satz.werte.map { schaetzer.verarbeite($0) }
        // Eine Wiederholung beginnt, wo die Wahrheit die Ruhelage verlaesst.
        let ruhelage = satz.lage.first ?? 0
        var beginne: [Int] = []
        for i in satz.lage.indices.dropFirst()
        where abs(satz.lage[i - 1] - ruhelage) < 1e-12 && abs(satz.lage[i] - ruhelage) >= 1e-12 {
            beginne.append(i)
        }
        let ab = wiederholung - 1 < beginne.count ? beginne[wiederholung - 1] : satz.lage.count
        let abweichungen = (ab..<satz.lage.count).map { abs(lagen[$0].lage - satz.lage[$0]) }
        let mittel = abweichungen.isEmpty ? 0 : abweichungen.reduce(0, +) / Double(abweichungen.count)
        return (mittel, abweichungen.max() ?? 0, lagen)
    }

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
}
