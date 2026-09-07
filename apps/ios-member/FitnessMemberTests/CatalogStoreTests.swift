import Foundation
import Testing
@testable import FitnessMember

actor FakeBootstrapLoader: BootstrapLoading {
    enum Result { case success(BootstrapResponse), failure(APIError) }
    var bootstrapResult: Result = .failure(.offline)
    var putSetResult: Result2 = .failure(.offline)
    private(set) var putSetCalls: [(sessionId: UUID, setId: UUID)] = []
    var joinResult: Result3 = .failure(.offline)
    var leaveResult: Result4 = .failure(.offline)

    enum Result2 { case success(RecordedSet), failure(APIError) }
    enum Result3 { case success(JoinResult), failure(APIError) }
    enum Result4 { case success, failure(APIError) }

    func setBootstrapResult(_ value: Result) { bootstrapResult = value }
    func setPutSetResult(_ value: Result2) { putSetResult = value }
    func setJoinResult(_ value: Result3) { joinResult = value }
    func setLeaveResult(_ value: Result4) { leaveResult = value }

    func bootstrap() async throws(APIError) -> BootstrapResponse {
        switch bootstrapResult {
        case .success(let response): return response
        case .failure(let error): throw error
        }
    }

    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet {
        putSetCalls.append((sessionId, setId))
        switch putSetResult {
        case .success(let recorded): return recorded
        case .failure(let error): throw error
        }
    }

    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult {
        switch joinResult {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }

    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult {
        switch joinResult {
        case .success(let result): return result
        case .failure(let error): throw error
        }
    }

    func leaveStudioMembership(studioId: String) async throws(APIError) {
        switch leaveResult {
        case .success: return
        case .failure(let error): throw error
        }
    }
}

private func emptyBootstrap(studios: [BootstrapResponse.Studio] = []) -> BootstrapResponse {
    BootstrapResponse(studios: studios, machines: [], calibrations: [], lastSets: [])
}

private func tempDirectory() -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("catalog-tests-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

/// @MainActor, weil CatalogStore seit dieser Aufgabe selbst @MainActor ist
/// (siehe Kommentar dort) -- die Suite laeuft deshalb auf demselben Actor wie
/// die getestete Klasse, sonst braeuchte jeder store-Zugriff ein await.
@Suite("CatalogStore")
@MainActor
struct CatalogStoreTests {
    @Test("load() ohne Studios ergibt loaded(hasStudio: false)")
    func loadWithoutStudio() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.success(emptyBootstrap()))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .loaded(hasStudio: false))
    }

    @Test("load() mit einem Studio ergibt loaded(hasStudio: true)")
    func loadWithStudio() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s1", name: "Kraftwerk Nord", timezone: "Europe/Berlin")])))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .loaded(hasStudio: true))
    }

    @Test("ein Netzwerkfehler ergibt .failed")
    func loadFailure() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.failure(.offline))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .failed)
    }

    @Test("enqueue speichert sofort auf Platte")
    func enqueuePersists() {
        let directory = tempDirectory()
        let writeStore = PendingWriteStore(directory: directory)
        let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: writeStore)
        let write = PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil))
        store.enqueue(write)
        #expect(PendingWriteStore(directory: directory).loadAll() == [write])
    }

    @Test("flushPending entfernt erfolgreich gesendete Eintraege")
    func flushRemovesSucceeded() async {
        let directory = tempDirectory()
        let loader = FakeBootstrapLoader()
        let recorded = RecordedSet(id: "r1", studioId: "s1", userId: "u1", sessionId: UUID().uuidString, machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil, problemFlag: false, problemReason: nil, performedAt: "2026-09-01T10:00:00Z")
        await loader.setPutSetResult(.success(recorded))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: directory))
        let write = PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil))
        store.enqueue(write)
        await store.flushPending()
        #expect(store.pendingWrites.isEmpty)
    }

    @Test("flushPending behaelt Eintraege, die weiterhin fehlschlagen")
    func flushKeepsFailed() async {
        let directory = tempDirectory()
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.offline))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: directory))
        let write = PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil))
        store.enqueue(write)
        await store.flushPending()
        #expect(store.pendingWrites == [write])
    }

    @Test("joinStudio(byCode:) laedt danach den Katalog neu")
    func joinByCodeReloads() async {
        let loader = FakeBootstrapLoader()
        await loader.setJoinResult(.success(JoinResult(studioId: "s1", machineId: nil, joined: true)))
        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s1", name: "Kraftwerk Nord", timezone: "Europe/Berlin")])))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        try? await store.joinStudio(byCode: "ABCD1234")
        #expect(store.loadState == .loaded(hasStudio: true))
    }

    @Test("leaveStudio wirft weiter, wenn keine Mitgliedschaft besteht")
    func leaveStudioPropagatesError() async {
        let loader = FakeBootstrapLoader()
        await loader.setLeaveResult(.failure(.notFound(message: "Keine Mitgliedschaft zum Entfernen gefunden.")))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await #expect(throws: APIError.notFound(message: "Keine Mitgliedschaft zum Entfernen gefunden.")) {
            try await store.leaveStudio("s1")
        }
    }

    @Test("setActiveStudio setzt und uebersteht ein neues CatalogStore-Objekt (UserDefaults)")
    func setActiveStudioPersists() {
        let defaults = UserDefaults(suiteName: "catalog-store-tests-\(UUID().uuidString)")!
        let store = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: tempDirectory()), defaults: defaults)
        store.setActiveStudio("s1")
        let secondStore = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: tempDirectory()), defaults: defaults)
        #expect(secondStore.activeStudioId == "s1")
    }
}
