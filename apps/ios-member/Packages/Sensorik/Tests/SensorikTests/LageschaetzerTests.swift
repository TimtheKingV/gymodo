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
        #expect(beginne.count >= wiederholung, "nur \(beginne.count) Wiederholungsbeginne gefunden")
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

    @Test func langsamesTempoVierSekundenJeWeg() {
        let satz = Synthetik.hub(wiederholungen: 8, kraftweg: 4, ablassen: 4)
        #expect(fehler(satz, ab: 3).mittel <= 0.08)
        var s = Lageschaetzer(rateHz: 50)
        for m in satz.werte { _ = s.verarbeite(m) }
        #expect(s.umkehrpunkte.count == 16)
        #expect(s.umkehrpunkte.map(\.oben) == Array(repeating: [true, false], count: 8).flatMap { $0 })
    }
}
