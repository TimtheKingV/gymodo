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
    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult
    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult
    func leaveStudioMembership(studioId: String) async throws(APIError)
}

extension APIClient: BootstrapLoading {}

/// @MainActor, weil CatalogStore -- wie SessionStore seit Aufgabe 12 -- ueber
/// @Environment direkt in SwiftUI-Views gelesen wird (ab Aufgabe 19); ohne
/// diese Isolation flaggt Swift 6 beim Aufruf von z. B. load() aus einem View
/// heraus einen "sending"-Fehler, weil die Klasse selbst nicht Sendable ist.
@MainActor
@Observable
final class CatalogStore {
    private(set) var bootstrap: BootstrapResponse?
    private(set) var loadState: CatalogLoadState = .idle
    private(set) var pendingWrites: [PendingSetWrite]
    private(set) var activeStudioId: String?

    private let loader: any BootstrapLoading
    private let pendingWriteStore: PendingWriteStore
    private let defaults: UserDefaults
    private static let activeStudioDefaultsKey = "activeStudioId"

    init(loader: any BootstrapLoading, pendingWriteStore: PendingWriteStore, defaults: UserDefaults = .standard) {
        self.loader = loader
        self.pendingWriteStore = pendingWriteStore
        self.defaults = defaults
        pendingWrites = pendingWriteStore.loadAll()
        activeStudioId = defaults.string(forKey: Self.activeStudioDefaultsKey)
    }

    func load() async {
        loadState = .loading
        do {
            let response = try await loader.bootstrap()
            bootstrap = response
            loadState = .loaded(hasStudio: !response.studios.isEmpty)
            if activeStudioId == nil || !response.studios.contains(where: { $0.id == activeStudioId }) {
                activeStudioId = response.studios.first?.id
            }
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

    /// Wechseln ist reiner Client-Zustand -- "Tippen wechselt" (MemberStudios.dc.html)
    /// beschreibt keine Server-Aktion, sondern welches Studio lokal angezeigt wird.
    func setActiveStudio(_ id: String) {
        activeStudioId = id
        defaults.set(id, forKey: Self.activeStudioDefaultsKey)
    }

    func joinStudio(byCode code: String) async throws(APIError) {
        _ = try await loader.joinStudioByCode(code)
        await load()
    }

    func joinStudio(byTag token: String) async throws(APIError) {
        _ = try await loader.joinStudioByTag(token)
        await load()
    }

    func leaveStudio(_ studioId: String) async throws(APIError) {
        try await loader.leaveStudioMembership(studioId: studioId)
        await load()
    }
}
