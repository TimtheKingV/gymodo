import Testing
@testable import Sensorik

struct SatzAutomatikTests {
    private func wert(_ t: Double) -> SensorMesswert {
        SensorMesswert(t: t, beschleunigung: .init(x: 0, y: 0, z: 1),
                       drehrate: .init(x: 0, y: 0, z: 0), winkel: .init(x: 0, y: 0, z: 0))
    }
    private func rep(_ n: Int, _ von: Double, _ bis: Double) -> Wiederholung {
        Wiederholung(nummer: n, beginn: von, umkehr: (von + bis) / 2, ende: bis,
                      ausschlag: 1, sicherheit: 1, pauseDavor: nil)
    }
    private func empfangen(_ automat: inout SatzAutomatik, von: Int, bis: Int) {
        for tick in von...bis { automat.empfangen(wert(Double(tick) / 10)) }
    }
    @Test func zweiWiederholungenUndGenauAchtSekundenRuhe() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 40)
        let reps = [rep(1, 0, 2), rep(2, 2, 4)]
        #expect(a.wiederholungen(reps).count == 1)
        #expect(a.zustand == .laeuft)
        #expect(a.wiederholungen(reps).isEmpty)
        #expect(a.vorlauf.first?.t == 0)
        empfangen(&a, von: 41, bis: 119)
        #expect(a.ausgewertet(bis: 11.9) == nil)
        a.empfangen(wert(12))
        #expect(a.ausgewertet(bis: 12) == .beendet(kennung: a.kennung, bewegung: 4))
        #expect(a.ausgewertet(bis: 12) == nil)
    }
    @Test func einzelneUndGetrennteBewegungenStartenNicht() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 100)
        #expect(a.wiederholungen([rep(1, 0, 2)]).isEmpty)
        #expect(a.wiederholungen([rep(2, 8, 10)]).isEmpty)
        #expect(a.ausgewertet(bis: 10) == nil)
        #expect(a.zustand == .startkandidat)
    }
    @Test func lueckeErfordertNeueBeobachteteRuhe() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 40)
        _ = a.wiederholungen([rep(1, 0, 2), rep(2, 2, 4)])
        a.luecke()
        empfangen(&a, von: 1000, bis: 1079)
        #expect(a.ausgewertet(bis: 107.9) == nil)
        a.empfangen(wert(108))
        #expect(a.ausgewertet(bis: 108) != nil)
    }
    @Test func langsameBewegungUndVerspaeteteAuswertung() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 40)
        _ = a.wiederholungen([rep(1, 0, 2), rep(2, 2, 4)])
        empfangen(&a, von: 41, bis: 120)
        a.bewegung(bis: 12)
        #expect(a.ausgewertet(bis: 12) == nil)
        empfangen(&a, von: 121, bis: 199)
        #expect(a.ausgewertet(bis: 19.9) == nil)
        #expect(a.ausgewertet(bis: 30) == nil)
        a.empfangen(wert(20))
        #expect(a.ausgewertet(bis: 20) != nil)
    }
    @Test func vorlaufBleibtBegrenztUndLueckeTrenntKandidaten() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 1000)
        #expect(a.vorlauf.count <= 311)
        _ = a.wiederholungen([rep(1, 96, 98)])
        a.luecke()
        a.empfangen(wert(100.1))
        #expect(a.wiederholungen([rep(2, 98, 100)]).isEmpty)
        #expect(a.zustand == .wartet)
    }
    @Test func unveraenderteOderKorrigierteGesamtzahlIstKeineNeueBewegung() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 40)
        _ = a.wiederholungen([rep(1, 0, 2), rep(2, 2, 4)])
        empfangen(&a, von: 41, bis: 119)
        // Dieselben Intervalle mit anderen Nummern und nachtraeglich
        // verschobenen Zeiten duerfen die Acht-Sekunden-Frist nicht erneuern.
        #expect(a.wiederholungen([rep(8, 0, 2), rep(9, 2, 4.1)]).isEmpty)
        #expect(a.wiederholungen([rep(8, 0, 2.5), rep(9, 2.5, 5)]).isEmpty)
        #expect(a.letzteBewegung == 4)
        a.empfangen(wert(12))
        #expect(a.ausgewertet(bis: 12) != nil)
    }

    @Test func neueWiederholungNachAtempauseVerlaengertDenSatz() {
        var a = SatzAutomatik()
        empfangen(&a, von: 0, bis: 40)
        _ = a.wiederholungen([rep(1, 0, 2), rep(2, 2, 4)])
        empfangen(&a, von: 41, bis: 90)
        #expect(a.ausgewertet(bis: 9) == nil)
        #expect(a.wiederholungen([rep(3, 7, 9)]).isEmpty)
        empfangen(&a, von: 91, bis: 169)
        #expect(a.ausgewertet(bis: 16.9) == nil)
        a.empfangen(wert(17))
        #expect(a.ausgewertet(bis: 17) == .beendet(kennung: a.kennung, bewegung: 9))
    }

}
