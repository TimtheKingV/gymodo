import Foundation
import Testing
@testable import FitnessMember

/// Offline-Spec 3c: die Kachel sucht selbst in der Ablage. Nur wenn der
/// Kontext feststeht und es nirgends ein Video gibt, kommt die Fotovariante.
struct EinweisungMedienTests {
    private let url = URL(string: "https://example.test/v.mp4")!

    @Test func offlineZeigtDieKachel() {
        #expect(EinweisungMedien.zeigtVideokachel(kontextGeladen: false, kontextVideo: nil, vorratKennt: false))
    }

    @Test func kontextMitVideoZeigtDieKachel() {
        #expect(EinweisungMedien.zeigtVideokachel(kontextGeladen: true, kontextVideo: url, vorratKennt: false))
    }

    @Test func vorratSchlaegtKontextOhneVideo() {
        #expect(EinweisungMedien.zeigtVideokachel(kontextGeladen: true, kontextVideo: nil, vorratKennt: true))
    }

    @Test func ohneVideoNirgendsDieFotovariante() {
        #expect(!EinweisungMedien.zeigtVideokachel(kontextGeladen: true, kontextVideo: nil, vorratKennt: false))
    }
}
