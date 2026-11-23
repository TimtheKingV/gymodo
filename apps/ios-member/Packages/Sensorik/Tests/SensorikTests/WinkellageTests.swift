import Foundation
import Testing
@testable import Sensorik

struct WinkellageTests {
    /// Mittlere und groesste Abweichung |Lage − Wahrheit| ab der genannten Wiederholung; schlaegt fehl, wenn die Wiederholung nicht existiert.
    func fehler(_ satz: Synthetik.Drehsatz, ab wiederholung: Int, gemerkt: GemerkterWinkel? = nil, rate: Double = 50)
        -> (mittel: Double, max: Double, lagen: [Lage], schaetzer: Winkellage) {
        var schaetzer = Winkellage(rateHz: rate, gemerkt: gemerkt)
        let lagen = satz.werte.map { schaetzer.verarbeite($0) }
        // Eine Wiederholung beginnt, wo die Wahrheit die Ruhelage verlaesst.
        let beginne = satz.lage.indices.dropFirst().filter { abs(satz.lage[$0 - 1]) < 1e-12 && abs(satz.lage[$0]) >= 1e-12 }
        #expect(beginne.count >= wiederholung, "nur \(beginne.count) Wiederholungsbeginne gefunden")
        let ab = wiederholung - 1 < beginne.count ? beginne[wiederholung - 1] : satz.lage.count
        let abweichungen = (ab..<satz.lage.count).map { abs(lagen[$0].lage - satz.lage[$0]) }
        let mittel = abweichungen.isEmpty ? 0 : abweichungen.reduce(0, +) / Double(abweichungen.count)
        return (mittel, abweichungen.max() ?? 0, lagen, schaetzer)
    }

    let bekannt = GemerkterWinkel(achse: .roll, vorzeichen: 1, hubGrad: 140)

    @Test func mitGemerktemWertFolgtDieLageAbDerErstenWiederholung() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 1, gemerkt: bekannt)
        #expect(f.mittel <= 0.02 && f.max <= 0.06)
        #expect(f.lagen.allSatisfy { $0.sicher })
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
        #expect(ohne.lagen.filter { $0.t > ersteVolle + 0.6 }.allSatisfy { $0.sicher })      // auch in der Ruhe danach
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
}
