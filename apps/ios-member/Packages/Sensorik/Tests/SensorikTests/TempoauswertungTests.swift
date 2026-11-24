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
}
