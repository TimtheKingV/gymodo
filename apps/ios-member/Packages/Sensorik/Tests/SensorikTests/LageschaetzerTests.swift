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
        let beginne = wiederholungsbeginne(satz)
        #expect(beginne.count >= wiederholung, "nur \(beginne.count) Wiederholungsbeginne gefunden")
        let ab = wiederholung - 1 < beginne.count ? beginne[wiederholung - 1] : satz.lage.count
        let abweichungen = (ab..<satz.lage.count).map { abs(lagen[$0].lage - satz.lage[$0]) }
        let mittel = abweichungen.isEmpty ? 0 : abweichungen.reduce(0, +) / Double(abweichungen.count)
        return (mittel, abweichungen.max() ?? 0, lagen)
    }

    /// Eine Wiederholung beginnt, wo die Wahrheit die Ruhelage verlaesst.
    func wiederholungsbeginne(_ satz: Synthetik.Hubsatz) -> [Int] {
        let ruhelage = satz.lage.first ?? 0
        return satz.lage.indices.dropFirst().filter {
            abs(satz.lage[$0 - 1] - ruhelage) < 1e-12 && abs(satz.lage[$0] - ruhelage) >= 1e-12
        }
    }

    /// Die vier Grenzen fuer einen Satz mit Gleichanteil: sichere Lage in −0,25…1,25,
    /// jede Lage endlich in −0,5…1,5, mittlerer Fehler ab Wdh. 3 hoechstens 0,12,
    /// kein Schritt ueber 0,08.
    func pruefeGrenzen(_ satz: Synthetik.Hubsatz) -> [Lage] {
        let f = fehler(satz, ab: 3)
        #expect(f.lagen.filter(\.sicher).allSatisfy { $0.lage >= -0.25 && $0.lage <= 1.25 })
        #expect(f.lagen.allSatisfy { $0.lage.isFinite && $0.lage >= -0.5 && $0.lage <= 1.5 })
        #expect(f.mittel <= 0.12)
        let spruenge = zip(f.lagen, f.lagen.dropFirst()).map { abs($1.lage - $0.lage) }
        #expect(spruenge.max()! <= 0.08)
        return f.lagen
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
        var s = Lageschaetzer(rateHz: 50)
        for m in satz.werte { _ = s.verarbeite(m) }
        #expect(s.umkehrpunkte.count == 16)
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

    @Test(arguments: [-0.02, -0.01, -0.005, 0.005, 0.01, 0.02])
    func driftBeiderVorzeichenBleibtInGrenzen(biasG: Double) {
        _ = pruefeGrenzen(Synthetik.hub(wiederholungen: 20, biasG: biasG))
    }

    @Test(arguments: [-0.02, -0.01, 0.01, 0.02])
    func langsamesTempoMitDrift(biasG: Double) {
        // 0,02 g liegt ueber der Spitzenbeschleunigung von 0,12 m/s² bei 4 s je Weg.
        let satz = Synthetik.hub(wiederholungen: 12, kraftweg: 4, ablassen: 4, biasG: biasG)
        let lagen = pruefeGrenzen(satz)
        let ab = wiederholungsbeginne(satz)[4]
        let bewegt = (ab..<satz.lage.count).filter { abs(satz.lage[$0] - satz.lage[$0 - 1]) > 1e-12 }
        let sicher = bewegt.filter { lagen[$0].sicher }.count
        #expect(Double(sicher) >= 0.8 * Double(bewegt.count))
    }

    @Test func schnellerHubOhneKorrektursprung() {
        let satz = Synthetik.hub(wiederholungen: 12, kraftweg: 1, ablassen: 1, biasG: 0.01)
        let f = fehler(satz, ab: 3)
        #expect(f.mittel <= 0.12)
        let abweichung = zip(f.lagen, satz.lage).map { $0.lage - $1 }
        let spruenge = zip(abweichung, abweichung.dropFirst()).map { abs($1 - $0) }
        #expect(spruenge.max()! <= 0.05)
    }

    @Test func pauseUntenZwischenWiederholungen() {
        // Bis 2 s unten gehoert die Pause zum Satz: Das Vertrauen ueberdauert sie.
        let satz = Synthetik.hub(wiederholungen: 10, biasG: 0.01, pausenUnten: [4: 1.5, 8: 1.5])
        let f = fehler(satz, ab: 3)
        #expect(f.mittel <= 0.12)
        var s = Lageschaetzer(rateHz: 50)
        for m in satz.werte { _ = s.verarbeite(m) }
        // Die Umkehrpunkte der 1. Wdh. fehlen: Vor der ersten Schaetzung des
        // Gleichanteils wechselt die Geschwindigkeit nicht das Vorzeichen. Ab der
        // 2. Wdh. je zwei, die Pausen fuegen keine hinzu und verlieren keine.
        #expect(s.umkehrpunkte.map(\.oben) == Array(repeating: [true, false], count: 9).flatMap { $0 })
        let beginne = wiederholungsbeginne(satz)
        for nach in [5, 9] {
            #expect(f.lagen[beginne[nach - 1] + 25].sicher, "Wdh. \(nach): 0,5 s nach der Pause nicht sicher")
        }
    }
}
