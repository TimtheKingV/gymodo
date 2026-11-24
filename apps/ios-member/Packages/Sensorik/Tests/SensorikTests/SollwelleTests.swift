import Testing
import Foundation
@testable import Sensorik

@Suite struct SollwelleTests {
    @Test func standardIstAnderthalbUndZweieinhalb() {
        #expect(Tempovorgabe.standard.periode == 4.0)
    }

    @Test(arguments: [(0.2, 1.0), (1.7, 1.5), (1.8, 2.0), (9.0, 4.0)])
    func vorgabeRundetUndBegrenzt(roh: Double, erwartet: Double) {
        #expect(Tempovorgabe(kraftweg: roh, ablassen: roh).kraftweg == erwartet)
    }

    @Test func welleLaeuftUntenLosUndIstNachDemKraftwegOben() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.lage(bei: -2) == 0)
        #expect(w.lage(bei: 0) == 0)
        #expect(abs(w.lage(bei: 0.75) - 0.5) < 1e-9)
        #expect(abs(w.lage(bei: 1.5) - 1) < 1e-9)
        #expect(abs(w.lage(bei: 2.75) - 0.5) < 1e-9)
        #expect(abs(w.lage(bei: 4.0)) < 1e-9)
        #expect(w.periode(bei: -0.1) == nil)
        #expect(w.periode(bei: 3.9) == 0)
        #expect(w.periode(bei: 4.0) == 1)
        #expect(w.weg(bei: 1.4) == .kraftweg)
        #expect(w.weg(bei: 1.6) == .ablassen)
    }

    @Test func zielUndTaktmarken() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.zielzeit(wiederholungen: 12) == 48)
        #expect(w.taktmarken(von: 0, bis: 4).map(\.t) == [0, 0.75, 1.5, 2.75])
        #expect(w.taktmarken(von: 0, bis: 4).map(\.lage).map { ($0 * 100).rounded() / 100 } == [0, 0.5, 1, 0.5])
    }

    @Test func bahnIstZweiZehntelBreit() {
        let w = Sollwelle(vorgabe: .standard)
        #expect(w.inDerBahn(0.7, bei: 0.75))
        #expect(!w.inDerBahn(0.71, bei: 0.75))
    }
}
