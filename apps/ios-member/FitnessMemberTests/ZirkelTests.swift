import Foundation
import Testing
@testable import FitnessMember

/// Der Zirkel ist ein reiner Wertetyp: alles hier laeuft ohne Store und UI.
struct ZirkelTests {
    private func uebung(_ i: Int) -> ZirkelUebung {
        ZirkelUebung(station: "geraet:g\(i)", exerciseId: "e\(i)", token: nil)
    }

    private func zirkel(n: Int, runden: Int = 3) -> Zirkel {
        Zirkel(uebungen: (1...n).map(uebung), runden: runden, uebungspause: 30, rundenpause: 90)
    }

    @Test func rundeUndPositionLeitenSichVomSchrittAb() {
        var z = zirkel(n: 3)
        #expect(z.runde == 1)
        #expect(z.position == 0)
        for _ in 0..<4 { z.weiter() }
        #expect(z.runde == 2)
        #expect(z.position == 1)
    }

    @Test func nachDerLetztenUebungDerRundeKommtDieRundenpause() {
        var z = zirkel(n: 3)
        for _ in 0..<3 { z.weiter() }
        #expect(z.naechsterSchrittIstRundenwechsel)
        #expect(z.pausenSekunden == 90)
        #expect(z.naechste == z.uebungen[0])
    }

    @Test func zwischenDenUebungenGiltDieKurzePause() {
        var z = zirkel(n: 3)
        z.weiter()
        #expect(!z.naechsterSchrittIstRundenwechsel)
        #expect(z.pausenSekunden == 30)
    }

    @Test func nachDerLetztenRundeIstDerZirkelFertig() {
        var z = zirkel(n: 2, runden: 2)
        for _ in 0..<4 { z.weiter() }
        #expect(z.istFertig)
        #expect(z.naechste == nil)
        #expect(!z.naechsterSchrittIstRundenwechsel)
        z.weiter()
        #expect(z.schritt == 4)
    }

    @Test func erweiternGehtNurNachRunde1() {
        var z = zirkel(n: 2)
        z.weiter()
        #expect(z.erweitern(um: uebung(3)) == false)
        #expect(z.uebungen.count == 2)
        z.weiter()
        #expect(z.erweitern(um: uebung(3)) == true)
        #expect(z.uebungen.count == 3)
        #expect(z.naechste == uebung(3))
        #expect(z.runde == 1)
        #expect(!z.kannErweitern)
    }

    @Test func ausEinzelsatzStehtNachDemErstenSatz() {
        let z = Zirkel.ausEinzelsatz(uebung(1), zweite: uebung(2), runden: 3, uebungspause: 30, rundenpause: 90)
        #expect(z.schritt == 1)
        #expect(z.naechste == uebung(2))
        #expect(z.runde == 1)
    }

    @Test func ueberspringenRueckt() {
        var z = zirkel(n: 2)
        z.ueberspringen()
        #expect(z.schritt == 1)
    }

    @Test func eineUebungBleibtBedienbar() {
        var z = zirkel(n: 2, runden: 3)
        for _ in 0..<5 { z.ueberspringen() }
        #expect(!z.istFertig)
        #expect(z.naechste != nil)
        z.weiter()
        #expect(z.istFertig)
    }

    @Test func rundenUndSchrittWerdenGeklemmt() {
        #expect(zirkel(n: 2, runden: 1).runden == 2)
        #expect(zirkel(n: 2, runden: 9).runden == 6)
        let z = Zirkel(uebungen: [uebung(1), uebung(2)], runden: 3, uebungspause: 30, rundenpause: 90, schritt: -4)
        #expect(z.schritt == 0)
    }
}
