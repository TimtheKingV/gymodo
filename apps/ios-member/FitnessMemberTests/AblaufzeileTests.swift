import Testing
@testable import FitnessMember

/// Die eine Zeile, die am Geraet und in der Pause sagt, wo im Ablauf man
/// steht (UX-Paket 2, Abschnitt 2.4).
struct AblaufzeileTests {
    @Test func planNenntUebungUndSatz() {
        #expect(Ablaufzeile.plan(uebung: 3, von: 6, satz: 2, saetze: 3).text == "Übung 3 von 6 · Satz 2 von 3")
    }

    @Test func zirkelNenntStationUndRunde() {
        #expect(Ablaufzeile.zirkel(station: 2, von: 4, runde: 1, runden: 3).text == "Station 2 von 4 · Runde 1 von 3")
    }

    @Test func freiNenntNurDenSatz() {
        #expect(Ablaufzeile.frei(satz: 2).text == "Satz 2")
    }

    // MARK: Zirkel aus dem Stand

    private func zirkel() -> Zirkel {
        Zirkel(uebungen: (1...3).map { ZirkelUebung(station: "geraet:m\($0)", exerciseId: "e\($0)", token: nil) },
               runden: 3, uebungspause: 20, rundenpause: 90)
    }

    @Test func zirkelMitteDerRunde() {
        var z = zirkel()
        z.weiter()
        // Pause nach Station 1: die Zeile nennt die naechste, Station 2.
        #expect(Ablaufzeile.zirkel(z) == .zirkel(station: 2, von: 3, runde: 1, runden: 3))
    }

    @Test func zirkelRundenpauseNenntSchonDieNeueRunde() {
        var z = zirkel()
        z.weiter(); z.weiter(); z.weiter()
        #expect(Ablaufzeile.zirkel(z) == .zirkel(station: 1, von: 3, runde: 2, runden: 3))
    }

    @Test func zirkelAmGeraetNenntDenSlotDerRoute() {
        // Am Geraet zaehlt der Slot, mit dem der Screen geoeffnet wurde --
        // auch wenn der Zirkel nach dem Sichern schon weiter ist.
        var z = zirkel()
        for _ in 0..<5 { z.weiter() }
        #expect(Ablaufzeile.zirkel(z, schritt: 4) == .zirkel(station: 2, von: 3, runde: 2, runden: 3))
        #expect(Ablaufzeile.zirkel(z, schritt: 4) == Ablaufzeile.zirkel({ var y = zirkel(); for _ in 0..<4 { y.weiter() }; return y }()))
    }
}
