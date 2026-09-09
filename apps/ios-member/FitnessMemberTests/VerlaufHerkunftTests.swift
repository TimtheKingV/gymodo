import Foundation
import Testing
@testable import FitnessMember

/// Der Verlauf veraltet anders als eine Belegungszahl -- er aendert sich
/// ausschliesslich durch das eigene Tun. Deshalb hat dieser Typ keine
/// Frischegrenze und keinen Zustand `veraltet`.
struct VerlaufHerkunftTests {
    private let stand = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func einGelungenerAbrufIstFrisch() {
        #expect(VerlaufHerkunft.bilden(ladeZustand: .geladen) == .frisch)
    }

    @Test func einAlterStandOhneFehlschlagBleibtFrisch() {
        // Kein Gegenstueck zu KurseHerkunft.veraltet: ein Training von
        // gestern ist morgen noch genau so gewesen.
        #expect(VerlaufHerkunft.bilden(ladeZustand: .geladen).satz(stand: stand) == nil)
    }

    @Test func waehrendDesErstenLadensStehtKeinHinweis() {
        #expect(VerlaufHerkunft.bilden(ladeZustand: .laedt) == .frisch)
        #expect(VerlaufHerkunft.bilden(ladeZustand: .bereit) == .frisch)
    }

    @Test func ohneEmpfangIstNichtDasselbeWieEinServerfehler() {
        #expect(VerlaufHerkunft.bilden(ladeZustand: .fehlgeschlagen(.offline)) == .ohneEmpfang)
        #expect(VerlaufHerkunft.bilden(ladeZustand: .fehlgeschlagen(.server(message: ""))) == .serverfehler)
    }

    @Test func derSatzNenntDenStand() {
        let satz = VerlaufHerkunft.ohneEmpfang.satz(stand: stand)

        #expect(satz?.hasPrefix("Ohne Empfang.") == true)
        #expect(satz?.contains(Zahlformat.stand(stand)) == true)
    }

    /// "Kein Empfang" waere hier eine falsche Aussage ueber das Geraet --
    /// dieselbe Unterscheidung wie bei den Kursen.
    @Test func einServerfehlerSchicktNiemandenWLANSuchen() {
        let satz = VerlaufHerkunft.serverfehler.satz(stand: stand)

        #expect(satz?.contains("Ohne Empfang") == false)
        #expect(satz?.hasPrefix("Diese Angaben stammen vom letzten Abruf.") == true)
    }
}
