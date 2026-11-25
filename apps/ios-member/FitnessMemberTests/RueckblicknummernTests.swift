import Testing
@testable import FitnessMember

@Suite struct RueckblicknummernTests {
    @Test func gesicherterErsterSatzVonDrei() {
        let n = Rueckblicknummern(anzeigeSatz: 2, gesichert: true, satzZiel: 3)
        #expect(n.kopf == 1 && n.knopf == 2)
        #expect(n.kopfText == "SATZ 1 VON 3")
    }

    @Test func gesicherterLetzterSatz() {
        let n = Rueckblicknummern(anzeigeSatz: 4, gesichert: true, satzZiel: 3)
        #expect(n.kopf == 3 && n.knopf == 4)
        #expect(n.kopfText == "SATZ 3 VON 3")
    }

    @Test func abgelehnterZweiterSatzBleibtDerZweite() {
        let n = Rueckblicknummern(anzeigeSatz: 2, gesichert: false, satzZiel: 3)
        #expect(n.kopf == 2 && n.knopf == 2)
    }

    @Test func zusatzsatzOhneVon() {
        let n = Rueckblicknummern(anzeigeSatz: 5, gesichert: true, satzZiel: 3)
        #expect(n.kopf == 4 && n.knopf == 5)
        #expect(n.kopfText == "SATZ 4")
    }

    @Test func satzkopfDerAblaufSchritte() {
        #expect(Satzkopf.text(satz: 2, ziel: 3) == "SATZ 2 VON 3")
        #expect(Satzkopf.text(satz: 3, ziel: 3) == "SATZ 3 VON 3")
        #expect(Satzkopf.text(satz: 4, ziel: 3) == "SATZ 4")
    }
}
