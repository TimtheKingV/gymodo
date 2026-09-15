import Foundation

/// Was "Geraet waehlen" vom Netz braucht -- eine schmale Fassade wie
/// GeraetLoading, damit die Zuordnung ohne APIClient pruefbar bleibt.
protocol GeraetefotosLoading: Sendable {
    func machinePhotos() async throws(APIError) -> MachinePhotosResponse
}

extension APIClient: GeraetefotosLoading {}

enum GeraeteFotos {
    /// Modell -> URL. Je Modell, weil der Server je Modell signiert:
    /// zwei Geraete desselben Modells tragen dasselbe Foto.
    static func zuordnung(_ antwort: MachinePhotosResponse) -> [String: URL] {
        var fotos: [String: URL] = [:]
        for foto in antwort.photos {
            guard let url = URL(string: foto.url) else { continue }
            fotos[foto.equipmentModelId] = url
        }
        return fotos
    }

    /// Jeder Fehler endet leer: die Liste rechnet auf dem Prefetch und
    /// funktioniert im Keller ohne Empfang -- ein fehlendes Foto ist dort
    /// kein Zustand, den das Mitglied erklaert bekommen muss.
    static func laden(von loader: any GeraetefotosLoading) async -> [String: URL] {
        guard let antwort = try? await loader.machinePhotos() else { return [:] }
        return zuordnung(antwort)
    }
}
