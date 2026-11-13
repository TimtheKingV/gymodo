import Foundation
import Testing
@testable import FitnessMember

/// Suche in der Uebungsliste eines Geraets ab mehr als 3 Uebungen
/// (Testnotiz 10.11., #15).
struct UebungsSucheTests {

    private let liste = ["Kurzhantel-Bankdrücken", "Kurzhantel-Flys – Flachbank", "Kurzhantel-Rudern"]
        .enumerated()
        .map { n, name in
            GeraetUebung(id: "e\(n)", name: name, volumeKind: .reps, targetMin: 8, targetMax: 12, videoURL: nil)
        }

    @Test func schwelle() {
        #expect(!UebungsSuche.bietetSucheAn(uebungsanzahl: 3))
        #expect(UebungsSuche.bietetSucheAn(uebungsanzahl: 4))
    }

    @Test func leerIstKeineSuche() {
        #expect(UebungsSuche.treffer(liste, suchtext: "") == nil)
        #expect(UebungsSuche.treffer(liste, suchtext: "   ") == nil)
    }

    @Test func trifftNamenOhneGrossUndUmlaute() {
        #expect(UebungsSuche.treffer(liste, suchtext: "bankdrucken")?.map(\.id) == ["e0"])
        #expect(UebungsSuche.treffer(liste, suchtext: "FLYS")?.map(\.id) == ["e1"])
        #expect(UebungsSuche.treffer(liste, suchtext: " kurz ")?.map(\.id) == ["e0", "e1", "e2"])
    }

    @Test func keineTreffer() {
        #expect(UebungsSuche.treffer(liste, suchtext: "xyz") == [])
    }
}
