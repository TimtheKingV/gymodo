import Foundation
import Testing
@testable import Sensorik

struct WinkellageTests {
    /// Mittlere und groesste Abweichung |Lage − Wahrheit| ab der genannten Wiederholung; schlaegt fehl, wenn die Wiederholung nicht existiert.
    /// Mit `losBei` wartet der Schaetzer auf `los()`, das beim ersten Messwert mit `t >= losBei` kommt.
    func fehler(_ satz: Synthetik.Drehsatz, ab wiederholung: Int, gemerkt: GemerkterWinkel? = nil, rate: Double = 50,
                losBei: Double? = nil) -> (mittel: Double, max: Double, lagen: [Lage], schaetzer: Winkellage) {
        var schaetzer = Winkellage(rateHz: rate, gemerkt: gemerkt, wartetAufLos: losBei != nil)
        var losGegeben = false
        let lagen = satz.werte.map { m -> Lage in
            if let losBei, !losGegeben, m.t >= losBei { schaetzer.los(); losGegeben = true }
            return schaetzer.verarbeite(m)
        }
        // Eine Wiederholung beginnt, wo die Wahrheit die Ruhelage verlaesst.
        let beginne = satz.lage.indices.dropFirst().filter { abs(satz.lage[$0 - 1]) < 1e-12 && abs(satz.lage[$0]) >= 1e-12 }
        #expect(beginne.count >= wiederholung, "nur \(beginne.count) Wiederholungsbeginne gefunden")
        let ab = wiederholung - 1 < beginne.count ? beginne[wiederholung - 1] : satz.lage.count
        let abweichungen = (ab..<satz.lage.count).map { abs(lagen[$0].lage - satz.lage[$0]) }
        let mittel = abweichungen.isEmpty ? 0 : abweichungen.reduce(0, +) / Double(abweichungen.count)
        return (mittel, abweichungen.max() ?? 0, lagen, schaetzer)
    }

    let bekannt = GemerkterWinkel(hubGrad: 140)

    @Test func mitGemerktemWertFolgtDieLageAbDerErstenWiederholung() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 1, gemerkt: bekannt)
        #expect(f.mittel <= 0.02 && f.max <= 0.06)
        #expect(f.lagen.allSatisfy { $0.sicher })
    }
    @Test func ohneGemerktenWertStimmtDieLageAbDerDritten() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 3)
        #expect(f.mittel <= 0.03)
        #expect(abs(f.schaetzer.gemerkt!.hubGrad - 140) <= 3)
    }
    @Test func vorlaeufigerMassstabLaesstDenPunktNichtUeberschiessen() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 3), ab: 1)
        #expect(f.lagen.allSatisfy { $0.lage >= -0.05 && $0.lage <= 1.05 })
        #expect(f.lagen.map(\.lage).max()! >= 0.95)
    }
    @Test func ueberPlusMinus180SpringtDieLageNicht() {
        // Roll laeuft von 170° ueber ±180° hinaus bis −50°.
        let f = fehler(Synthetik.drehsatz(wiederholungen: 8, startRoll: 170), ab: 1, gemerkt: bekannt)
        #expect(f.mittel <= 0.02)
        #expect(zip(f.lagen, f.lagen.dropFirst()).allSatisfy { abs($1.lage - $0.lage) <= 0.06 })
    }
    @Test func gegenrichtungUndAndereAchse() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 6, hubGrad: 60, drehachse: Vektor3(x: 0, y: -1, z: 0)), ab: 3)
        #expect(f.mittel <= 0.03)
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
        let groesser = fehler(Synthetik.drehsatz(wiederholungen: 12), ab: 3, gemerkt: GemerkterWinkel(hubGrad: 100))
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

    // MARK: Nachbesserung 1

    @Test func massstabWechseltOhneSprung() {
        let satz = Synthetik.drehsatz(wiederholungen: 6)
        // Ohne gemerkten Wert gilt auf dem ersten Kraftweg (bis 4,5 s) der vorlaeufige Massstab von mindestens
        // 40°; dort ist schon die Steigung (2,9° je Schritt) ueber 0,06 und kein Wechsel. Gemessen wird danach.
        for (gemerkt, ab) in [(GemerkterWinkel(hubGrad: 100), 0.0), (nil, 4.5)] {
            let f = fehler(satz, ab: 1, gemerkt: gemerkt)
            let sprung = zip(f.lagen, f.lagen.dropFirst()).filter { $0.0.t >= ab }.map { abs($1.lage - $0.lage) }.max()!
            #expect(sprung <= 0.06, "groesster Schritt \(sprung)")
        }
    }
    @Test func richtungFolgtDerBewegung() {
        let satz = Synthetik.drehsatz(wiederholungen: 12)
        let f = fehler(satz, ab: 1, gemerkt: bekannt)
        var gezaehlt = 0, richtig = 0
        for i in 1..<(satz.lage.count - 1) where satz.lage[i] >= 0.2 && satz.lage[i] <= 0.8 {
            gezaehlt += 1
            let steigt = satz.lage[i + 1] > satz.lage[i - 1]
            if f.lagen[i].richtung == (steigt ? .hin : .rueck) { richtig += 1 }
        }
        #expect(Double(richtig) >= 0.98 * Double(gezaehlt), "\(richtig) von \(gezaehlt)")
        #expect(f.lagen.prefix(100).allSatisfy { $0.richtung == .unbekannt })
    }

    // MARK: Nachbesserung 2

    @Test func zitternAuchAnDerDrehrate() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 8, zitternGrad: 1.5), ab: 3)
        #expect(f.schaetzer.umkehrpunkte.count == 16)
        #expect(f.mittel <= 0.04)
        #expect(f.lagen.suffix(100).allSatisfy { abs($0.lage) <= 0.05 })
    }
    @Test func unbrauchbarerGemerkterWertGiltAlsNichtGemerkt() {
        for ungueltig in [GemerkterWinkel(hubGrad: 0), GemerkterWinkel(hubGrad: -50),
                          GemerkterWinkel(hubGrad: .nan), GemerkterWinkel(hubGrad: .infinity)] {
            let f = fehler(Synthetik.drehsatz(wiederholungen: 6), ab: 3, gemerkt: ungueltig)
            #expect(f.lagen.allSatisfy { $0.lage.isFinite })
            #expect(f.mittel <= 0.03)
            #expect(f.schaetzer.gemerkt?.hubGrad.isFinite == true)
        }
    }

    // MARK: Neigung statt Roll/Pitch (Task 2b)

    /// Groesster Schritt der Lage zwischen zwei Messwerten.
    func groessterSchritt(_ lagen: [Lage]) -> Double {
        zip(lagen, lagen.dropFirst()).map { abs($1.lage - $0.lage) }.max() ?? 0
    }

    @Test func ueberDenPolSpringtDieLageNicht() {
        // Pitch laeuft von 30° durch 90°, Roll springt dort um 180°.
        let satz = Synthetik.drehsatz(wiederholungen: 8, drehachse: Vektor3(x: 0, y: 1, z: 0), startPitch: 30)
        let rollSprung = zip(satz.werte, satz.werte.dropFirst()).map { abs($1.winkel.x - $0.winkel.x) }.max()!
        #expect(rollSprung >= 170, "das Kunstsignal soll den Euler-Sprung enthalten (\(rollSprung))")
        let f = fehler(satz, ab: 1, gemerkt: bekannt)
        #expect(f.mittel <= 0.03)
        #expect(groessterSchritt(f.lagen) <= 0.06, "groesster Schritt \(groessterSchritt(f.lagen))")
        #expect(f.schaetzer.umkehrpunkte.count == 16)
    }
    @Test func hubUeberEinhundertachtzigGrad() {
        let f = fehler(Synthetik.drehsatz(wiederholungen: 6, hubGrad: 200), ab: 3)
        #expect(f.mittel <= 0.04)
        #expect(abs((f.schaetzer.gemerkt?.hubGrad ?? 0) - 200) <= 5)
    }
    @Test func drehungUmDieSenkrechteIstNichtGeeignet() {
        // Die Drehachse ist die Schwerkraftachse: ĝ aendert sich nicht.
        let f = fehler(Synthetik.drehsatz(wiederholungen: 6, drehachse: Vektor3(x: 0, y: 0, z: 1)), ab: 1)
        #expect(f.lagen.allSatisfy { !$0.sicher })
        #expect(f.schaetzer.groessterAusschlagGrad < 5)
        #expect(f.schaetzer.umkehrpunkte.isEmpty)
    }

    // MARK: Ausdruecklicher Start (Task 2b)

    /// Aufnehmen: 60° hin, zurueck auf 25° neben der alten Ruhelage, dort die neue Ruhelage; dann 8 Wiederholungen.
    let mitVorbewegung = Synthetik.drehsatz(wiederholungen: 8, vorbewegung: Synthetik.Vorbewegung())

    @Test func vorDemLosZaehltNichts() {
        let satz = mitVorbewegung
        let f = fehler(satz, ab: 3, losBei: satz.losT)
        #expect(f.schaetzer.umkehrpunkte.count == 16)
        #expect(f.schaetzer.umkehrpunkte.allSatisfy { $0.t > satz.losT })
        #expect(f.mittel <= 0.03)
        #expect(abs((f.schaetzer.gemerkt?.hubGrad ?? 0) - 140) <= 3)
        let vorher = f.lagen.filter { $0.t < satz.losT }
        #expect(!vorher.isEmpty && vorher.allSatisfy { $0.lage == 0 && $0.richtung == .unbekannt })
    }
    @Test func ohneLosWieBisher() {
        // Bekannter Unterschied: ohne `los()` gilt das Aufnehmen als erste Bewegung und wird als Wiederholung gezaehlt.
        let f = fehler(mitVorbewegung, ab: 1)
        #expect(f.schaetzer.umkehrpunkte.count == 18)
        #expect(f.schaetzer.umkehrpunkte.prefix(1).allSatisfy { $0.oben && $0.t < mitVorbewegung.losT })
    }
}
