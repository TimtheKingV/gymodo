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

    // MARK: Fix-Welle nach dem Schlussreview

    /// B.1: Die Last wandert in den letzten 0,5 s vor `los()` schon um 10° (die erste Hebung beginnt vor dem Los).
    /// `los()` nimmt dann das zuletzt stille Mittel statt des bewegten Messwerts.
    @Test func losNimmtDieLetzteStilleRuheWennSchonBewegt() {
        let satz = Synthetik.drehsatz(wiederholungen: 8)
        // Erste Hebung ab 3 s: 140° · (1 − cos(π τ / 1,5)) / 2 erreicht 10° bei τ ≈ 0,26 s; der erste Messwert
        // ab 3,26 s traegt (gebuendelt) t = 3,28 s, dort sind es 11,7°.
        let losBei = 3.26
        let i = satz.werte.firstIndex { $0.t >= losBei }!
        #expect(abs(satz.lage[i] * 140 - 10) <= 2, "Kunstsignal: \(satz.lage[i] * 140)° beim Los")
        let f = fehler(satz, ab: 3, losBei: losBei)
        #expect(f.mittel <= 0.03, "mittlerer Fehler ab Wdh. 3: \(f.mittel)")
        // In Ruhe: die 2 s nach dem Satz (Wahrheit 0), ohne die erste Viertelsekunde.
        let ende = satz.werte.last!.t
        let ruhe = zip(f.lagen, satz.lage).filter { $0.0.t > ende - 1.75 }.map { abs($0.0.lage - $0.1) }
        #expect(!ruhe.isEmpty && ruhe.max()! <= 0.03, "Lagefehler in Ruhe: \(ruhe.max() ?? -1)")
    }

    /// Spielt `werte` durch; vor dem ersten Messwert mit `t >= endeBei` kommt `ende()`.
    func lauf(_ werte: [SensorMesswert], endeBei: Double? = nil, gemerkt: GemerkterWinkel? = nil) -> (lagen: [Lage], schaetzer: Winkellage) {
        var s = Winkellage(rateHz: 50, gemerkt: gemerkt)
        var beendet = false
        let lagen = werte.map { m -> Lage in
            if let endeBei, !beendet, m.t >= endeBei { s.ende(); beendet = true }
            return s.verarbeite(m)
        }
        return (lagen, s)
    }

    /// Ablegen nach dem Satz: in 0,75 s Roll auf 120° und Pitch auf 40°, in 0,75 s zurueck, danach 1 s Ruhe; 50 Hz ab `ab`.
    func ablegen(ab: Double) -> [SensorMesswert] {
        (1...125).map { k in
            let t = ab + Double(k) / 50, w = (1 - cos(2 * Double.pi * min(1, Double(k) / 75))) / 2
            return SensorMesswert(t: t, beschleunigung: Vektor3(x: 0, y: 0, z: 1), drehrate: Vektor3(x: 0, y: 0, z: 0),
                                  winkel: Vektor3(x: 120 * w, y: 40 * w, z: 0))
        }
    }

    /// B.2: Nach `ende()` zaehlt das Ablegen nicht mehr; die Lage steht und ist unsicher.
    @Test func nachDemEndeZaehltDasAblegenNicht() {
        let satz = Synthetik.drehsatz(wiederholungen: 6)
        let endeBei = satz.werte.last!.t + 0.01
        let mitAblegen = satz.werte + ablegen(ab: satz.werte.last!.t)
        let ohne = lauf(satz.werte), mit = lauf(mitAblegen, endeBei: endeBei)
        #expect(mit.schaetzer.umkehrpunkte == ohne.schaetzer.umkehrpunkte)
        #expect(mit.schaetzer.gemerkt == ohne.schaetzer.gemerkt)
        #expect(mit.schaetzer.groessterAusschlagGrad == ohne.schaetzer.groessterAusschlagGrad)
        let letzte = ohne.lagen.last!
        let danach = mit.lagen.filter { $0.t >= endeBei }
        #expect(danach.count == 125)
        #expect(danach.allSatisfy { !$0.sicher && $0.lage == letzte.lage && $0.richtung == letzte.richtung })
        // Ohne `ende()` haette das Ablegen eine weitere Wiederholung ergeben.
        #expect(lauf(mitAblegen).schaetzer.umkehrpunkte.count > ohne.schaetzer.umkehrpunkte.count)
    }

    /// B.2: Eine angefangene Wiederholung (oberer Umkehrpunkt ohne unteren) zaehlt nicht und geht nicht in den Hub ein.
    @Test func eineAngefangeneWiederholungZaehltNichtBeimEnde() {
        // Die sechste Wiederholung hebt nur 85 % (ueber 80 %, sie fuehrte den Hub um 10 % nach): ihr oberer
        // Umkehrpunkt kommt bei rund 25 s, der untere erst nach 27 s.
        let satz = Synthetik.drehsatz(wiederholungen: 6, hubAnteil: [6: 0.85])
        let nachFuenf = lauf(satz.werte, endeBei: 23.5), mitten = lauf(satz.werte, endeBei: 25.5)
        #expect(nachFuenf.schaetzer.umkehrpunkte.count == 10)
        #expect(mitten.schaetzer.umkehrpunkte == nachFuenf.schaetzer.umkehrpunkte)
        #expect(mitten.schaetzer.gemerkt == nachFuenf.schaetzer.gemerkt)
        // Ohne `ende()` stuende der sechste obere Umkehrpunkt schon in der Liste und im Hub.
        let bis = lauf(Array(satz.werte.prefix { $0.t < 25.5 }))
        #expect(bis.schaetzer.umkehrpunkte.count == 11)
        #expect(bis.schaetzer.gemerkt != nachFuenf.schaetzer.gemerkt)
    }

    /// B.3: Winkellage → Tempoauswertung ueber `sekundenSeitLos`; die Sensorzeit beginnt bei 5000 s.
    @Test func zeitSeitLosVerkettetMitDerAuswertung() {
        let satz = Synthetik.drehsatz(wiederholungen: 10)
        let versatz = 5000.0
        let werte = satz.werte.map { SensorMesswert(t: $0.t + versatz, beschleunigung: $0.beschleunigung, drehrate: $0.drehrate, winkel: $0.winkel) }
        // Die erste Hebung beginnt bei 3 s; die Person laeuft genau auf der Welle 1,5 s / 2,5 s ab dort.
        var s = Winkellage(rateHz: 50, wartetAufLos: true)
        var auswertung = Tempoauswertung(welle: Sollwelle(vorgabe: .standard))
        var losGegeben = false
        for m in werte {
            if !losGegeben, m.t >= versatz + 3 { s.los(); losGegeben = true }
            let lage = s.verarbeite(m)
            if let t = s.sekundenSeitLos(m.t) { auswertung.erfasse(lage, bei: t) }
        }
        #expect(s.losZeit.map { abs($0 - (versatz + 3)) < 0.03 } == true, "\(String(describing: s.losZeit))")
        #expect(s.sekundenSeitLos(versatz + 13) .map { abs($0 - 10) < 0.03 } == true)
        let e = auswertung.ergebnis()
        #expect((e?.quote ?? 0) >= 0.95, "Quote \(String(describing: e?.quote))")
    }

    /// B.3: Ohne `wartetAufLos` gilt die erste Bewegung als Los; vorher gibt es keine Zeit seit Los.
    @Test func ohneLosIstDieErsteBewegungDieLosZeit() {
        let satz = Synthetik.drehsatz(wiederholungen: 3)
        var s = Winkellage(rateHz: 50)
        var vorher: [TimeInterval?] = []
        for m in satz.werte {
            _ = s.verarbeite(m)
            if m.t < 3 { vorher.append(s.sekundenSeitLos(m.t)) }
        }
        #expect(vorher.allSatisfy { $0 == nil })
        // Ueber 5° (Bewegungsschwelle) bei rund 3,27 s.
        #expect(s.losZeit.map { $0 > 3.1 && $0 < 3.5 } == true, "\(String(describing: s.losZeit))")
        #expect(s.sekundenSeitLos(.nan) == nil)
    }

    /// B.4: Ohne bekannten Hub ist die Hysterese mindestens 10°: ein Absacken um 6° bei 25° in der ersten Hebung
    /// ist kein Umkehrpunkt.
    @Test func absackenInDerErstenHebungIstKeinUmkehrpunkt() {
        let satz = Synthetik.drehsatz(wiederholungen: 6, absackenErste: (beiGrad: 25, umGrad: 6))
        let f = fehler(satz, ab: 3)
        #expect(f.schaetzer.umkehrpunkte.map(\.oben) == Array(repeating: [true, false], count: 6).flatMap { $0 })
        // Der erste obere Umkehrpunkt ist der echte Gipfel der ersten Wiederholung, nicht das Absacken.
        #expect(f.schaetzer.umkehrpunkte.first.map { $0.t > 4 } == true, "\(String(describing: f.schaetzer.umkehrpunkte.first))")
        #expect(abs((f.schaetzer.gemerkt?.hubGrad ?? 0) - 140) <= 3, "\(String(describing: f.schaetzer.gemerkt))")
    }

    /// B.5: Kippt ĝ nach dem Satz aus der Drehebene bis 100° zur Drehachse hin (und zurueck), ist die Lage dort,
    /// wo ĝ weniger als 20° von der Achse liegt, unsicher und φ gehalten; ĝ = (sin β, 0, cos β), Achse x.
    @Test func naheDerDrehachseUnsicherUndGehalten() {
        let satz = Synthetik.drehsatz(wiederholungen: 4)
        let ab = satz.werte.last!.t
        // β laeuft in 4 s von 0 auf 100° und zurueck: Roll 0, Pitch = −β bis 90°, darueber Roll 180°.
        var kippen: [(m: SensorMesswert, beta: Double)] = []
        for k in 1...200 {
            let beta = 100 * (1 - cos(2 * Double.pi * Double(k) / 200)) / 2, b = beta * .pi / 180
            let g = Vektor3(x: sin(b), y: 0, z: cos(b))
            let roll = atan2(g.y, g.z) * 180 / .pi, pitch = asin(-g.x) * 180 / .pi
            kippen.append((SensorMesswert(t: ab + Double(k) / 50, beschleunigung: Vektor3(x: 0, y: 0, z: 1),
                                          drehrate: Vektor3(x: 0, y: 0, z: 0), winkel: Vektor3(x: roll, y: pitch, z: 0)), beta))
        }
        var s = Winkellage(rateHz: 50, gemerkt: bekannt)
        for m in satz.werte { _ = s.verarbeite(m) }
        let vorher = s.drehwinkelGrad
        var nahe: [(Lage, Double)] = [], fern: [Lage] = []
        for (m, beta) in kippen {
            let l = s.verarbeite(m)
            if sin(beta * .pi / 180) > cos(20 * Double.pi / 180) + 0.01 { nahe.append((l, s.drehwinkelGrad)) }
            else if sin(beta * .pi / 180) < cos(20 * Double.pi / 180) - 0.01 { fern.append(l) }
        }
        #expect(!nahe.isEmpty && nahe.allSatisfy { !$0.0.sicher })
        #expect(nahe.allSatisfy { $0.1 == vorher && $0.0.lage.isFinite && abs($0.0.lage) <= 0.05 },
                "\(nahe.map(\.1).min() ?? 0)…\(nahe.map(\.1).max() ?? 0)")
        #expect(fern.allSatisfy { $0.sicher && abs($0.lage) <= 0.05 })
    }

    /// B.6: Eine unbrauchbare Rate faellt auf 50 Hz zurueck, ohne Absturz.
    @Test(arguments: [Double.nan, .infinity, -.infinity, 0, -50])
    func unbrauchbareRateFaelltAufFuenfzigZurueck(rate: Double) {
        let satz = Synthetik.drehsatz(wiederholungen: 6)
        var mit = Winkellage(rateHz: rate), soll = Winkellage(rateHz: 50)
        let a = satz.werte.map { mit.verarbeite($0) }, b = satz.werte.map { soll.verarbeite($0) }
        #expect(a == b)
        #expect(mit.umkehrpunkte == soll.umkehrpunkte && mit.gemerkt == soll.gemerkt)
    }
}
