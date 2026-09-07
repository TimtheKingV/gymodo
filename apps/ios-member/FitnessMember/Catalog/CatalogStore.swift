import Foundation
import Observation

/// `APIClient` ist ein `actor` ohne Protokoll-Abstraktion (Aufgabe 5 begruendet
/// das mit YAGNI bei sechs bekannten Endpoints). Fuer `CatalogStore` wird
/// deshalb eine minimale Protokoll-Fassade nur fuer die hier gebrauchten zwei
/// Methoden ergaenzt -- die Deklaration gehoert hierher (nicht ins Testziel),
/// weil spaetere Aufgaben sie ebenfalls erweitern muessen.
protocol BootstrapLoading: Sendable {
    func bootstrap() async throws(APIError) -> BootstrapResponse
    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet
}

extension APIClient: BootstrapLoading {}

@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse?
    private(set) var loadState: CatalogLoadState = .idle
    private(set) var pendingWrites: [PendingSetWrite]

    private let loader: any BootstrapLoading
    private let pendingWriteStore: PendingWriteStore

    init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore) {
        self.loader = loader
        self.pendingWriteStore = pendingWriteStore
        pendingWrites = pendingWriteStore.loadAll()
    }

    func load() async {
        loadState = .loading
        do {
            let response = try await loader.bootstrap()
            bootstrap = response
            loadState = .loaded(hasStudio: !response.studios.isEmpty)
        } catch {
            loadState = .failed
        }
    }

    func enqueue(_ write: PendingSetWrite) {
        pendingWrites.append(write)
        pendingWriteStore.save(pendingWrites)
    }

    func flushPending() async {
        var remaining: [PendingSetWrite] = []
        for write in pendingWrites {
            do {
                _ = try await loader.putSet(sessionId: write.sessionId, setId: write.setId, write.body)
            } catch {
                remaining.append(write)
            }
        }
        pendingWrites = remaining
        pendingWriteStore.save(remaining)
    }
}
