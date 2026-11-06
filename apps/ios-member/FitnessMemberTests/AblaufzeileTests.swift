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
}
