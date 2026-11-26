import Foundation
import Testing
@testable import FitnessMember

/// Nach dem Muster von FakeKurseLoader: ein actor, Ergebnisse vorab programmiert.
actor FakeFlowLoader: FlowLoading {
    private var flowsResultat: Result<[Flow], APIError> = .failure(.offline)
    private var putResultat: Result<Void, APIError> = .success(())
    private(set) var gesendet: [String] = []

    func setFlows(_ r: Result<[Flow], APIError>) { flowsResultat = r }
    func setPut(_ r: Result<Void, APIError>) { putResultat = r }

    func flows() async throws(APIError) -> [Flow] {
        try flowsResultat.get()
    }

    func putFlowRun(_ run: FlowRunEingabe) async throws(APIError) {
        gesendet.append(run.id)
        try putResultat.get()
    }
}

@MainActor
struct FlowStoreTests {
    private func verzeichnis() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("flowstore-\(UUID().uuidString)")
    }

    /// Ein Store, der schon an ein Konto gebunden ist (wie nach der Anmeldung).
    private func angemeldet(_ loader: any FlowLoading, _ dir: URL, user: String = "u1") -> FlowStore {
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
        store.anmelden(userId: user)
        return store
    }

    private func flow(_ id: String = "f1") -> Flow {
        Flow(id: id, studioId: "s1", key: "hiit", titel: "HIIT 20", beschreibung: nil, level: nil,
             schritte: [FlowSchritt(position: 1, name: "A", beschreibung: nil, workS: 30, restS: 10, istWarmup: false)],
             dauerS: 40)
    }

    private func run(_ id: String = "r1") -> FlowRunEingabe {
        FlowRunEingabe(id: id, flowId: "f1", startedAt: "2026-11-26T10:00:00Z",
                       endedAt: "2026-11-26T10:20:00Z", lastStep: 1, outcome: "finished")
    }

    @Test func ladenOhneNetzZeigtGecachteFlows() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setFlows(.success([flow()]))
        let erster = angemeldet(loader, dir)
        await erster.laden()
        #expect(erster.flows == [flow()])

        // Neuer Store, Netz weg: der Cache von der Platte steht sofort da.
        let offline = FakeFlowLoader()
        let zweiter = angemeldet(offline, dir)
        #expect(zweiter.flows == [flow()])
        await zweiter.laden()
        #expect(zweiter.flows == [flow()])
    }

    @Test func ladenErsetztCacheBeiErfolg() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setFlows(.success([flow("a")]))
        let store = angemeldet(loader, dir)
        await store.laden()
        await loader.setFlows(.success([flow("b")]))
        await store.laden()
        #expect(store.flows.map(\.id) == ["b"])
        #expect(FlowFileStore(directory: dir).ladeFlows(userId: "u1").map(\.id) == ["b"])
    }

    @Test func fehlgeschlagenerRunBleibtOffenUndWirdSpaeterGesendet() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let store = angemeldet(loader, dir)
        await store.runAbschliessen(run())
        #expect(store.offeneRuns == [run()])
        #expect(FlowFileStore(directory: dir).ladeOffene(userId: "u1") == [run()])

        await loader.setPut(.success(()))
        await store.offeneRunsSenden()
        #expect(store.offeneRuns.isEmpty)
        #expect(FlowFileStore(directory: dir).ladeOffene(userId: "u1").isEmpty)
    }

    @Test func serverfehlerHaeltDenRunOffen() async {
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.server(message: "x")))
        let store = angemeldet(loader, verzeichnis())
        await store.runAbschliessen(run())
        #expect(store.offeneRuns.count == 1)
    }

    @Test func derselbeRunZweimalErzeugtKeinenZweitenEintrag() async {
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let store = angemeldet(loader, verzeichnis())
        await store.runAbschliessen(run())
        await store.runAbschliessen(run())
        #expect(store.offeneRuns.count == 1)

        await loader.setPut(.success(()))
        async let a: Void = store.offeneRunsSenden()
        async let b: Void = store.offeneRunsSenden()
        _ = await (a, b)
        #expect(store.offeneRuns.isEmpty)
        // Die zwei Fehlversuche (je ein PUT) plus genau EIN Senden danach:
        // der Re-Entrancy-Schutz verhindert das doppelte PUT.
        #expect(await loader.gesendet == ["r1", "r1", "r1"])
    }

    @Test func endgueltigerClientfehlerWirdVerworfen() async {
        for fehler in [APIError.notFound(message: "x"), .validation(message: "x")] {
            let loader = FakeFlowLoader()
            await loader.setPut(.failure(fehler))
            let dir = verzeichnis()
            let store = angemeldet(loader, dir)
            await store.runAbschliessen(run())
            #expect(store.offeneRuns.isEmpty)
            #expect(FlowFileStore(directory: dir).ladeOffene(userId: "u1").isEmpty)
        }
    }

    @Test func anmeldefehlerHaeltDenRunOffen() async {
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.unauthorized(message: "x")))
        let store = angemeldet(loader, verzeichnis())
        await store.runAbschliessen(run())
        #expect(store.offeneRuns.count == 1)
    }

    @Test func offeneRunsUeberlebenEinenNeustart() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let erster = angemeldet(loader, dir)
        await erster.runAbschliessen(run())
        let zweiter = angemeldet(loader, dir)
        #expect(zweiter.offeneRuns == [run()])
    }

    // MARK: - Bindung an das Konto

    @Test func cacheDesEinenKontosIstFuerDasAndereUnsichtbar() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setFlows(.success([flow("a")]))
        let a = angemeldet(loader, dir, user: "userA")
        await a.laden()
        #expect(a.flows.map(\.id) == ["a"])

        let b = angemeldet(FakeFlowLoader(), dir, user: "userB")
        #expect(b.flows.isEmpty)
        await b.laden() // offline: bleibt leer
        #expect(b.flows.isEmpty)
    }

    @Test func offeneRunsDesEinenKontosGehenNieMitDemTokenDesAnderenRaus() async {
        let dir = verzeichnis()
        let offline = FakeFlowLoader()
        await offline.setPut(.failure(.offline))
        let a = angemeldet(offline, dir, user: "userA")
        await a.runAbschliessen(run())
        #expect(a.offeneRuns.count == 1)

        // Nutzer B meldet sich auf demselben Geraet an: A's Run ist weder
        // sichtbar noch wird er gesendet.
        let loaderB = FakeFlowLoader()
        let b = angemeldet(loaderB, dir, user: "userB")
        #expect(b.offeneRuns.isEmpty)
        await b.offeneRunsSenden()
        #expect(await loaderB.gesendet.isEmpty)
    }

    @Test func dasselbeKontoBehaeltCacheUndOffeneRuns() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setFlows(.success([flow()]))
        await loader.setPut(.failure(.offline))
        let erster = angemeldet(loader, dir, user: "userA")
        await erster.laden()
        await erster.runAbschliessen(run())

        let zweiter = angemeldet(loader, dir, user: "userA")
        #expect(zweiter.flows == [flow()])
        #expect(zweiter.offeneRuns == [run()])
    }

    @Test func kontoWechselHinUndZurueckFindetDieEigenenRunsWieder() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let store = angemeldet(loader, dir, user: "userA")
        await store.runAbschliessen(run())
        store.reset()
        #expect(store.offeneRuns.isEmpty)
        #expect(store.flows.isEmpty)
        store.anmelden(userId: "userB")
        #expect(store.offeneRuns.isEmpty)
        store.reset()
        store.anmelden(userId: "userA")
        #expect(store.offeneRuns == [run()])
    }

    @Test func ohneAnmeldungWirdNichtGesendetUndNichtGeladen() async {
        let loader = FakeFlowLoader()
        await loader.setFlows(.success([flow()]))
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: verzeichnis()))
        await store.runAbschliessen(run())
        await store.offeneRunsSenden()
        await store.laden()
        #expect(store.offeneRuns.isEmpty)
        #expect(store.flows.isEmpty)
        #expect(await loader.gesendet.isEmpty)
    }

    @Test func offeneRunsSendenNachDemAnmeldenOhneDassEineListeOffenIst() async {
        // Der App-Start ruft nur offeneRunsSenden(): der alte Run geht raus.
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let alt = angemeldet(loader, dir)
        await alt.runAbschliessen(run())

        await loader.setPut(.success(()))
        let neu = angemeldet(loader, dir)
        await neu.offeneRunsSenden()
        #expect(neu.offeneRuns.isEmpty)
        #expect(FlowFileStore(directory: dir).ladeOffene(userId: "u1").isEmpty)
    }

    // MARK: - Ladezustand

    @Test func ladezustandErfolgFehlerUndCache() async {
        let loader = FakeFlowLoader()
        let store = angemeldet(loader, verzeichnis())
        #expect(store.ladeZustand == .idle)
        await store.laden() // Fake ist offline
        #expect(store.ladeZustand == .fehler)
        await loader.setFlows(.success([]))
        await store.laden()
        #expect(store.ladeZustand == .geladen)
    }

    @Test func listeInhaltUnterscheidetLadenFehlerUndLeer() {
        #expect(FlowListeInhalt.von(flowsLeer: false, ladeZustand: .fehler) == .flows)
        #expect(FlowListeInhalt.von(flowsLeer: true, ladeZustand: .idle) == .laedt)
        #expect(FlowListeInhalt.von(flowsLeer: true, ladeZustand: .laedt) == .laedt)
        #expect(FlowListeInhalt.von(flowsLeer: true, ladeZustand: .fehler) == .fehler)
        #expect(FlowListeInhalt.von(flowsLeer: true, ladeZustand: .geladen) == .leer)
    }
}
