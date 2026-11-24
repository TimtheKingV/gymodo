import Testing
import Foundation
@testable import Sensorik

@Suite struct TempoauswertungTests {
    let welle = Sollwelle(vorgabe: .standard)

    /// 50 Messwerte je Sekunde, `lage = funktion(t)`.
    func lauf(_ funktion: (TimeInterval) -> Double, dauer: Double,
              sicher: (TimeInterval) -> Bool = { _ in true }) -> Tempoauswertung {
        var a = Tempoauswertung(welle: welle)
        for k in 0..<Int(dauer * 50) {
            let t = Double(k) / 50
            a.erfasse(Lage(t: t, lage: funktion(t), richtung: .unbekannt, sicher: sicher(t)), bei: t)
        }
        return a
    }

    @Test func werDerWelleFolgtHatHundertProzent() {
        let e = lauf({ welle.lage(bei: $0) }, dauer: 48).ergebnis()!
        #expect(e.quote == 1)
        #expect(e.perioden.count == 10)                    // 12 Perioden, die ersten zwei zaehlen nicht
        #expect(e.kraftweg == .imTempo && e.ablassen == .imTempo)
    }

    @Test func dieErstenZweiPeriodenZaehlenNicht() {
        let e = lauf({ $0 < 8 ? 5 : welle.lage(bei: $0) }, dauer: 24).ergebnis()!
        #expect(e.quote == 1)
    }

    @Test func zuSchnellesAblassenWirdGezaehlt() {
        // ab Periode 6 faellt die Lage beim Ablassen in 1 s statt 2,5 s
        let e = lauf({ t in
            let p = Int(t / 4), tau = t - Double(p) * 4
            guard p >= 6, tau > 1.5 else { return welle.lage(bei: t) }
            return tau < 2.5 ? (1 + cos(.pi * (tau - 1.5))) / 2 : 0
        }, dauer: 48).ergebnis()!
        #expect(e.kraftweg == .imTempo)
        #expect(e.ablassen == .zuSchnell(6, von: 10))
        #expect(e.quote < 0.9 && e.quote > 0.5)
    }

    @Test func werZurueckfaelltIstZuLangsam() {
        let e = lauf({ welle.lage(bei: $0 - 1.0) }, dauer: 48).ergebnis()!     // eine Sekunde hinterher
        if case .zuLangsam = e.kraftweg {} else { Issue.record("Kraftweg sollte zu langsam sein: \(e.kraftweg)") }
    }

    @Test func unsichereMesswerteZaehlenNicht() {
        let e = lauf({ $0 >= 20 && $0 < 24 ? 9 : welle.lage(bei: $0) }, dauer: 48,
                     sicher: { !($0 >= 20 && $0 < 24) }).ergebnis()!
        #expect(e.quote == 1)
        #expect(e.perioden[3] == nil)                       // Periode 5 ganz ohne sichere Messwerte
    }

    @Test func wenigerAlsDreiPeriodenGibtKeineAuswertung() {
        #expect(lauf({ welle.lage(bei: $0) }, dauer: 7.9).ergebnis() == nil)
        #expect(lauf({ welle.lage(bei: $0) }, dauer: 7.9).laufendeQuote == nil)
    }

    @Test func pauseMittenImSatzRechnetInWellenperiodenWeiter() {
        // 12 s Stillstand unten ab t = 16: drei Perioden ohne Bewegung, danach wieder im Takt
        let e = lauf({ $0 >= 16 && $0 < 28 ? 0 : welle.lage(bei: $0) }, dauer: 48).ergebnis()!
        #expect(e.perioden.count == 10)
        #expect(e.perioden.allSatisfy { $0 == nil || ($0! >= 0 && $0! <= 1) })
        #expect(e.quote.isFinite && e.quote < 1)
    }

    @Test func ueberDasZielHinausZaehltWeiter() {
        let e = lauf({ welle.lage(bei: $0) }, dauer: welle.zielzeit(wiederholungen: 12) + 8).ergebnis()!
        #expect(e.perioden.count == 12)
    }

    @Test func messwerteVorDerLosMarkeWerdenUebergangen() {
        var a = Tempoauswertung(welle: welle)
        a.erfasse(Lage(t: 0, lage: 0.9, richtung: .unbekannt, sicher: true), bei: -1)
        #expect(a.laufendeQuote == nil)
    }

    @Test func ruheImSatzZaehltAlsNebenDerBahn() {
        // sichere Messwerte, Lage steht 8 s auf 0: diese zwei Perioden haben einen Anteil deutlich unter 1
        let e = lauf({ $0 >= 16 && $0 < 24 ? 0 : welle.lage(bei: $0) }, dauer: 48).ergebnis()!
        #expect(e.perioden[2]! < 0.6 && e.perioden[3]! < 0.6)
        #expect(e.quote < 0.95)
    }

    // MARK: Eingabeschutz

    @Test func nichtEndlicheOderAbwegigeEingabenWerdenIgnoriert() {
        let basis = lauf({ welle.lage(bei: $0) }, dauer: 24)
        var a = basis
        let t = 12.0, ok = welle.lage(bei: t)
        for schlecht in [Double.nan, .infinity, -.infinity] {
            a.erfasse(Lage(t: t, lage: schlecht, richtung: .unbekannt, sicher: true), bei: t)
            a.erfasse(Lage(t: t, lage: ok, richtung: .unbekannt, sicher: true), bei: schlecht)
        }
        a.erfasse(Lage(t: 1e6, lage: 0.5, richtung: .unbekannt, sicher: true), bei: 1e6)
        a.erfasse(Lage(t: 3601, lage: 0.5, richtung: .unbekannt, sicher: true), bei: 3601)
        #expect(a.laufendeQuote == basis.laufendeQuote)
        #expect(a.ergebnis() == basis.ergebnis())
        #expect(a.ergebnis()?.perioden.count == 4)
    }

    // MARK: Ende des Satzes

    @Test func endetDerSatzMitUnsicherenPeriodenFolgenNilEintraege() {
        let e = lauf({ welle.lage(bei: $0) }, dauer: 48, sicher: { $0 < 40 }).ergebnis()!
        #expect(e.perioden.count == 10)
        #expect(e.perioden[8] == nil && e.perioden[9] == nil)
        #expect(e.perioden[7] == 1)
        #expect(e.quote == 1)
    }

    @Test func quoteIstAnteilUeberMesswerteNichtMittelDerPerioden() {
        // Periode 2 ganz in der Bahn (200 Werte), Periode 3 nur eine Sekunde weit und daneben (50 Werte)
        let e = lauf({ $0 >= 12 ? 5 : welle.lage(bei: $0) }, dauer: 13).ergebnis()!
        #expect(e.perioden == [1, 0])
        #expect(abs(e.quote - 0.8) < 1e-12)                // Mittel der Perioden waere 0,5
    }

    // MARK: Urteile

    /// Anteil der Messwerte eines Wegs in Periode `p`, die ausserhalb der Bahn liegen; die Urteile unten sollen
    /// nicht knapp an der Haelfte haengen.
    func ausserhalb(_ f: (TimeInterval) -> Double, periode p: Int, weg: Weg) -> Double {
        let zeiten = (0..<200).map { Double(p) * 4 + Double($0) / 50 }.filter { welle.weg(bei: $0) == weg }
        return Double(zeiten.filter { !welle.inDerBahn(f($0), bei: $0) }.count) / Double(zeiten.count)
    }

    @Test func zuSchnellerKraftwegWirdGezaehlt() {
        // ab Periode 6 ist die Last schon nach 0,1 s oben und wartet (68 % des Kraftwegs ausserhalb und voraus)
        let f: (TimeInterval) -> Double = { t in
            let p = Int(t / 4), tau = t - Double(p) * 4
            guard p >= 6, tau < 1.5 else { return welle.lage(bei: t) }
            return tau < 0.1 ? (1 - cos(.pi * tau / 0.1)) / 2 : 1
        }
        for p in 6...11 { #expect(ausserhalb(f, periode: p, weg: .kraftweg) >= 0.65) }
        let e = lauf(f, dauer: 48).ergebnis()!
        #expect(e.kraftweg == .zuSchnell(6, von: 10))
        #expect(e.ablassen == .imTempo)
    }

    @Test func zuLangsamesAblassenWirdGezaehlt() {
        // ab Periode 4 sinkt die Last ueber 4 s statt 2,5 s
        let e = lauf({ t in
            let p = Int(t / 4), tau = t - Double(p) * 4
            guard p >= 4, tau > 1.5 else { return welle.lage(bei: t) }
            return 1 - (1 - cos(.pi * (tau - 1.5) / 4)) / 2
        }, dauer: 48).ergebnis()!
        #expect(e.kraftweg == .imTempo)
        #expect(e.ablassen == .zuLangsam(8, von: 10))
    }

    @Test func gleichvieleSchnelleUndLangsamePeriodenGebenZuSchnell() {
        // Kraftweg: Perioden 4 und 5 zu schnell (nach 0,1 s oben), Perioden 6 und 7 zu langsam (ueber 6 s statt 1,5 s);
        // je 68 % bzw. 69 % des Kraftwegs ausserhalb
        let f: (TimeInterval) -> Double = { t in
            let p = Int(t / 4), tau = t - Double(p) * 4
            guard (4...7).contains(p), tau < 1.5 else { return welle.lage(bei: t) }
            if p < 6 { return tau < 0.1 ? (1 - cos(.pi * tau / 0.1)) / 2 : 1 }
            return (1 - cos(.pi * tau / 6)) / 2
        }
        for p in 4...7 { #expect(ausserhalb(f, periode: p, weg: .kraftweg) >= 0.65) }
        let e = lauf(f, dauer: 48).ergebnis()!
        #expect(e.kraftweg == .zuSchnell(2, von: 10))
    }

    @Test func eineUnsichereWellenperiodeSenktDieGesamtzahlFuerBeideWege() {
        // ab Periode 6 beide Wege zu schnell (Kraftweg nach 0,1 s oben); Periode 8 (t 32 bis 36) ohne sichere Messwerte
        let schnell: (TimeInterval) -> Double = { t in
            let p = Int(t / 4), tau = t - Double(p) * 4
            guard p >= 6 else { return welle.lage(bei: t) }
            if tau < 0.1 { return (1 - cos(.pi * tau / 0.1)) / 2 }
            if tau < 1.5 { return 1 }
            return tau < 2.5 ? (1 + cos(.pi * (tau - 1.5))) / 2 : 0
        }
        for p in 6...11 { #expect(ausserhalb(schnell, periode: p, weg: .kraftweg) >= 0.65) }
        let mit = lauf(schnell, dauer: 48).ergebnis()!
        let ohne = lauf(schnell, dauer: 48, sicher: { !($0 >= 32 && $0 < 36) }).ergebnis()!
        #expect(mit.kraftweg == .zuSchnell(6, von: 10) && mit.ablassen == .zuSchnell(6, von: 10))
        #expect(ohne.kraftweg == .zuSchnell(5, von: 9) && ohne.ablassen == .zuSchnell(5, von: 9))
    }

    @Test func dieReihenfolgeDerMesswerteSpieltKeineRolle() {
        func lage(_ t: TimeInterval) -> Double {
            let p = Int(t / 4), tau = t - Double(p) * 4
            guard p >= 6, tau > 1.5 else { return welle.lage(bei: t) }
            return tau < 2.5 ? (1 + cos(.pi * (tau - 1.5))) / 2 : 0
        }
        let zeiten = (0..<2400).map { Double($0) / 50 }
        var vor = Tempoauswertung(welle: welle), rueck = Tempoauswertung(welle: welle)
        for t in zeiten { vor.erfasse(Lage(t: t, lage: lage(t), richtung: .unbekannt, sicher: true), bei: t) }
        for t in zeiten.reversed() { rueck.erfasse(Lage(t: t, lage: lage(t), richtung: .unbekannt, sicher: true), bei: t) }
        #expect(vor.ergebnis() != nil)
        #expect(vor.ergebnis() == rueck.ergebnis())
        #expect(vor.laufendeQuote == rueck.laufendeQuote)
    }

    @Test func werDerWelleMitHaltezeitFolgtHatHundertProzent() {
        let mitHalten = Sollwelle(vorgabe: Tempovorgabe(kraftweg: 2, ablassen: 3, halten: 1))
        var a = Tempoauswertung(welle: mitHalten)
        for k in 0..<(72 * 50) {
            let t = Double(k) / 50
            a.erfasse(Lage(t: t, lage: mitHalten.lage(bei: t), richtung: .unbekannt, sicher: true), bei: t)
        }
        let e = a.ergebnis()!
        #expect(e.quote == 1)
        #expect(e.kraftweg == .imTempo && e.ablassen == .imTempo)
    }
}
