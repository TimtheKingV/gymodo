import Foundation
import Testing
@testable import FitnessMember

/// Geraetefotos fuer die Liste: was ankommt, wird zur Zuordnung Modell -> URL,
/// und jeder Fehler endet in einer Liste ohne Bilder, nie in einer
/// Fehlermeldung.
struct GeraeteFotosTests {

    private struct Fake: GeraetefotosLoading {
        let ergebnis: Result<MachinePhotosResponse, APIError>
        func machinePhotos() async throws(APIError) -> MachinePhotosResponse {
            try ergebnis.get()
        }
    }

    private func antwort(_ fotos: [(String, String)]) -> MachinePhotosResponse {
        MachinePhotosResponse(photos: fotos.map { .init(equipmentModelId: $0.0, url: $0.1) })
    }

    @Test func ordnetUrlDemModellZu() async {
        let fotos = await GeraeteFotos.laden(von: Fake(ergebnis: .success(antwort([("em1", "https://example.test/a.jpg")]))))
        #expect(fotos == ["em1": URL(string: "https://example.test/a.jpg")!])
    }

    @Test func offlineGibtKeineBilderStattEinesFehlers() async {
        // Die Liste funktioniert ohne Netz aus dem Prefetch -- die Fotos
        // sind Zugabe und duerfen daran nichts aendern.
        let fotos = await GeraeteFotos.laden(von: Fake(ergebnis: .failure(.offline)))
        #expect(fotos.isEmpty)
    }

    @Test func eineUnlesbareUrlFaelltWegOhneDieAnderen() {
        // Leerer String: URL(string:) kodiert seit iOS 17 Leerzeichen und
        // Umlaute selbst, "" bleibt der verlaessliche Fall fuer nil.
        let fotos = GeraeteFotos.zuordnung(antwort([("em1", ""), ("em2", "https://example.test/b.jpg")]))
        #expect(fotos.keys.sorted() == ["em2"])
    }
}
