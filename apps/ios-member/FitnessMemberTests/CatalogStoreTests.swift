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

    @Test("load() persistiert ein repariertes activeStudioId")
    func loadPersistsRepairedActiveStudio() async {
        let defaults = UserDefaults(suiteName: "catalog-store-tests-\(UUID().uuidString)")!
        let directory = tempDirectory()
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s2", name: "Kraftwerk Sued", timezone: "Europe/Berlin")])))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: directory), defaults: defaults)
        store.setActiveStudio("veraltet")
        await store.load()
        #expect(store.activeStudioId == "s2")

        let secondStore = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: directory), defaults: defaults)
        #expect(secondStore.activeStudioId == "s2")
    }

    @Test("reset() raeumt Katalog, Ladezustand, aktives Studio, offene und verworfene Schreibvorgaenge")
    func resetClearsEverything() async {
        let defaults = UserDefaults(suiteName: "catalog-store-tests-\(UUID().uuidString)")!
        let directory = tempDirectory()
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s1", name: "Kraftwerk Nord", timezone: "Europe/Berlin")])))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: directory), defaults: defaults)
        await store.load()

        // Ein dauerhaft abgelehnter Schreibvorgang, damit reset() auch
        // verworfeneWrites raeumen muss -- sonst erbt das naechste Konto auf
        // demselben Geraet die abgelehnten Vorgaenge des vorigen.
        await loader.setPutSetResult(.failure(.notFound(message: "Geraet nicht gefunden.")))
        store.enqueue(PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil)))
        await store.flushPending()
        #expect(store.verworfeneWrites.count == 1)

        store.enqueue(PendingSetWrite(sessionId: UUID(), setId: UUID(), body: SetWrite(machineId: "m2", exerciseId: "ex2", setIndex: 1, weightKg: 60, reps: 8, rir: nil)))

        store.reset()

        #expect(store.bootstrap == nil)
        #expect(store.loadState == .idle)
        #expect(store.activeStudioId == nil)
        #expect(store.pendingWrites.isEmpty)
        #expect(store.verworfeneWrites.isEmpty)
        #expect(defaults.string(forKey: "activeStudioId") == nil)
        // Auch auf Platte, sonst holt der naechste Start alles zurueck.
        #expect(PendingWriteStore(directory: directory).loadAll().isEmpty)
        #expect(PendingWriteStore(directory: directory, filename: "verworfene-writes.json").loadAll().isEmpty)
        let secondStore = CatalogStore(loader: FakeBootstrapLoader(), pendingWriteStore: PendingWriteStore(directory: directory), defaults: defaults)
        #expect(secondStore.activeStudioId == nil)
        #expect(secondStore.verworfeneWrites.isEmpty)
    }

    @Test("nach .failed fuehrt ein erneutes load() wieder zu .loaded")
    func failedStateCanBeRetried() async {
        let loader = FakeBootstrapLoader()
        await loader.setBootstrapResult(.failure(.offline))
        let store = CatalogStore(loader: loader, pendingWriteStore: PendingWriteStore(directory: tempDirectory()))
        await store.load()
        #expect(store.loadState == .failed)

        await loader.setBootstrapResult(.success(emptyBootstrap(studios: [.init(id: "s1", name: "Kraftwerk Nord", timezone: "Europe/Berlin")])))
        await store.load()
        #expect(store.loadState == .loaded(hasStudio: true))
    }
}

struct APIErrorDauerhaftTests {
    @Test func offlineUndServerfehlerSindVoruebergehend() {
        #expect(APIError.offline.istDauerhaft == false)
        #expect(APIError.server(message: "x").istDauerhaft == false)
    }

    // putSet ist ein PUT und damit idempotent: eine 2xx-Antwort, die sich
    // nur nicht parsen liess, bedeutet, dass der Server den Schreibvorgang
    // bereits angenommen hat. Ein Wiederholen ist sicher -- als dauerhaft
    // klassifiziert wuerde ein bereits gespeicherter Satz faelschlich als
    // "nicht gespeichert" gemeldet.
    @Test func antwortNichtLesbarIstVoruebergehend() {
        #expect(APIError.decodingFailed.istDauerhaft == false)
    }

    @Test func validierungUndNichtGefundenSindDauerhaft() {
        // Ein Geraet, das stillgelegt wurde, kommt nie zurueck -- der
        // Schreibvorgang darf nicht ewig wiederholt werden.
        #expect(APIError.validation(message: "x").istDauerhaft)
        #expect(APIError.notFound(message: "x").istDauerhaft)
        #expect(APIError.unauthorized(message: "x").istDauerhaft)
        #expect(APIError.conflict(message: "x").istDauerhaft)
        // Anders als .decodingFailed: hier hat die Anfrage das Geraet nie
        // verlassen, ein Wiederholen codiert denselben Body wieder nicht.
        #expect(APIError.encodingFailed.istDauerhaft)
    }
}

/// @MainActor auf Typebene (nicht nur pro Methode): store(loader:) und
/// beispielWrite rufen CatalogStore.init auf, und CatalogStore ist selbst
/// @MainActor -- ohne diese Isolation compiliert der Aufruf aus einem
/// nicht-isolierten Helper heraus nicht.
@MainActor
struct FlushPendingTests {
    private func neuesVerzeichnis() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    /// `directory` ist explizit waehlbar (statt immer neu), damit Tests einen
    /// Neustart simulieren koennen: zwei CatalogStore-Instanzen ueber
    /// demselben Verzeichnis, ohne gemeinsame In-Memory-Referenz.
    ///
    /// `any BootstrapLoading` statt `FakeBootstrapLoader`, damit ein Test
    /// einen eigenen, schmaleren Loader einsetzen kann (siehe
    /// ZweiterAufrufPrueftPlatteLoader unten).
    private func store(loader: any BootstrapLoading, directory: URL? = nil) -> CatalogStore {
        CatalogStore(
            loader: loader,
            pendingWriteStore: PendingWriteStore(directory: directory ?? neuesVerzeichnis()),
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
    }

    private var beispielWrite: PendingSetWrite {
        PendingSetWrite(
            sessionId: UUID(),
            setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "e1", setIndex: 1,
                           weightKg: 80, reps: 10)
        )
    }

    @Test func behaeltDenEintragBeiVoruebergehendemFehler() async {
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.offline))
        let catalog = store(loader: loader)
        catalog.enqueue(beispielWrite)

        await catalog.flushPending()

        #expect(catalog.pendingWrites.count == 1)
        #expect(catalog.verworfeneWrites.isEmpty)
    }

    @Test func verwirftDenEintragBeiDauerhaftemFehler() async {
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.notFound(message: "Geraet nicht gefunden.")))
        let catalog = store(loader: loader)
        catalog.enqueue(beispielWrite)

        await catalog.flushPending()

        #expect(catalog.pendingWrites.isEmpty)
        #expect(catalog.verworfeneWrites.count == 1)
    }

    // Die SP1-Zusage lautete "verschwindet nicht stillschweigend" -- ein rein
    // speicherresidentes verworfeneWrites wuerde genau das tun, wenn die App
    // zwischen einem Hintergrund-Reconnect und dem naechsten Screen-Aufruf
    // beendet wird. Deshalb muss der Eintrag einen Neustart ueberstehen, wie
    // pendingWrites es schon tut (PendingWriteStoreTests.survivesRestart).
    @Test func verworfenerEintragUeberstehtEinenNeustart() async {
        let verzeichnis = neuesVerzeichnis()
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.notFound(message: "Geraet nicht gefunden.")))
        let ersterProzess = store(loader: loader, directory: verzeichnis)
        ersterProzess.enqueue(beispielWrite)
        await ersterProzess.flushPending()
        #expect(ersterProzess.verworfeneWrites.count == 1)

        // "Neustart": eine neue Instanz auf demselben Verzeichnis, keine
        // gemeinsame In-Memory-Referenz mit ersterProzess.
        let zweiterProzess = store(loader: FakeBootstrapLoader(), directory: verzeichnis)
        #expect(zweiterProzess.verworfeneWrites == ersterProzess.verworfeneWrites)
    }

    @Test func verworfeneQuittierenLeertSpeicherUndPlatte() async {
        let verzeichnis = neuesVerzeichnis()
        let loader = FakeBootstrapLoader()
        await loader.setPutSetResult(.failure(.notFound(message: "Geraet nicht gefunden.")))
        let catalog = store(loader: loader, directory: verzeichnis)
        catalog.enqueue(beispielWrite)
        await catalog.flushPending()
        #expect(catalog.verworfeneWrites.count == 1)

        catalog.verworfeneQuittieren()
        #expect(catalog.verworfeneWrites.isEmpty)

        // Auch auf Platte, sonst taucht der quittierte Eintrag beim naechsten
        // Start wieder auf.
        let neuerProzess = store(loader: FakeBootstrapLoader(), directory: verzeichnis)
        #expect(neuerProzess.verworfeneWrites.isEmpty)
    }

    // Der urspruengliche Kommentar in flushPending behauptete, ein verworfener
    // Eintrag sei "schon aus pendingWrites/pendingWriteStore raus", sobald er
    // zu verworfeneWrites hinzugefuegt wird -- pendingWriteStore.save(...)
    // lief aber erst NACH der Schleife. Ein Kill zwischen zwei Eintraegen
    // liess den ersten dadurch auf der Platte in BEIDEN Dateien stehen: beim
    // naechsten Start wird er erneut versucht, faellt erneut dauerhaft durch
    // und landet ein zweites Mal in verworfeneWrites. Dieser Test prueft den
    // Zwischenstand waehrend des Laufs, nicht erst danach -- genau die Luecke,
    // die ein Kill mittendrin ausnutzen wuerde.
    @Test func entferntEinenDauerhaftAbgelehntenEintragSofortAusDemPendingWriteStore() async {
        let verzeichnis = neuesVerzeichnis()
        let erste = beispielWrite
        let zweite = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m2", exerciseId: "e2", setIndex: 1, weightKg: 40, reps: 8)
        )
        let loader = ZweiterAufrufPrueftPlatteLoader(verzeichnis: verzeichnis, ersterSetId: erste.setId)
        let catalog = store(loader: loader, directory: verzeichnis)
        catalog.enqueue(erste)
        catalog.enqueue(zweite)

        await catalog.flushPending()

        #expect(await loader.zweiterAufrufSahDenEntferntenEintrag == true)
        #expect(catalog.verworfeneWrites.count == 2)
    }
}

/// Prueft beim ZWEITEN putSet-Aufruf, ob der erste Eintrag zu diesem
/// Zeitpunkt schon aus dem PendingWriteStore auf der Platte verschwunden ist
/// -- also bevor flushPending() insgesamt zurueckkehrt.
private actor ZweiterAufrufPrueftPlatteLoader: BootstrapLoading {
    let verzeichnis: URL
    let ersterSetId: UUID
    private(set) var zweiterAufrufSahDenEntferntenEintrag: Bool?

    init(verzeichnis: URL, ersterSetId: UUID) {
        self.verzeichnis = verzeichnis
        self.ersterSetId = ersterSetId
    }

    func bootstrap() async throws(APIError) -> BootstrapResponse { throw .offline }

    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet {
        if setId != ersterSetId {
            let aufDerPlatte = PendingWriteStore(directory: verzeichnis).loadAll()
            zweiterAufrufSahDenEntferntenEintrag = !aufDerPlatte.contains { $0.setId == ersterSetId }
        }
        throw APIError.notFound(message: "Geraet nicht gefunden.")
    }

    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult { throw .offline }
    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult { throw .offline }
    func leaveStudioMembership(studioId: String) async throws(APIError) { throw .offline }
}
