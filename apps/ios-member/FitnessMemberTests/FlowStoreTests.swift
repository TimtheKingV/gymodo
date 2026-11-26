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
        let erster = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
        await erster.laden()
        #expect(erster.flows == [flow()])

        // Neuer Store, Netz weg: der Cache von der Platte steht sofort da.
        let offline = FakeFlowLoader()
        let zweiter = FlowStore(loader: offline, dateiStore: FlowFileStore(directory: dir))
        #expect(zweiter.flows == [flow()])
        await zweiter.laden()
        #expect(zweiter.flows == [flow()])
    }

    @Test func ladenErsetztCacheBeiErfolg() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setFlows(.success([flow("a")]))
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
        await store.laden()
        await loader.setFlows(.success([flow("b")]))
        await store.laden()
        #expect(store.flows.map(\.id) == ["b"])
        #expect(FlowFileStore(directory: dir).ladeFlows().map(\.id) == ["b"])
    }

    @Test func fehlgeschlagenerRunBleibtOffenUndWirdSpaeterGesendet() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
        await store.runAbschliessen(run())
        #expect(store.offeneRuns == [run()])
        #expect(FlowFileStore(directory: dir).ladeOffene() == [run()])

        await loader.setPut(.success(()))
        await store.offeneRunsSenden()
        #expect(store.offeneRuns.isEmpty)
        #expect(FlowFileStore(directory: dir).ladeOffene().isEmpty)
    }

    @Test func serverfehlerHaeltDenRunOffen() async {
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.server(message: "x")))
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: verzeichnis()))
        await store.runAbschliessen(run())
        #expect(store.offeneRuns.count == 1)
    }

    @Test func derselbeRunZweimalErzeugtKeinenZweitenEintrag() async {
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: verzeichnis()))
        await store.runAbschliessen(run())
        await store.runAbschliessen(run())
        #expect(store.offeneRuns.count == 1)

        await loader.setPut(.success(()))
        async let a: Void = store.offeneRunsSenden()
        async let b: Void = store.offeneRunsSenden()
        _ = await (a, b)
        #expect(store.offeneRuns.isEmpty)
    }

    @Test func endgueltigerClientfehlerWirdVerworfen() async {
        for fehler in [APIError.notFound(message: "x"), .validation(message: "x")] {
            let loader = FakeFlowLoader()
            await loader.setPut(.failure(fehler))
            let dir = verzeichnis()
            let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
            await store.runAbschliessen(run())
            #expect(store.offeneRuns.isEmpty)
            #expect(FlowFileStore(directory: dir).ladeOffene().isEmpty)
        }
    }

    @Test func anmeldefehlerHaeltDenRunOffen() async {
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.unauthorized(message: "x")))
        let store = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: verzeichnis()))
        await store.runAbschliessen(run())
        #expect(store.offeneRuns.count == 1)
    }

    @Test func offeneRunsUeberlebenEinenNeustart() async {
        let dir = verzeichnis()
        let loader = FakeFlowLoader()
        await loader.setPut(.failure(.offline))
        let erster = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
        await erster.runAbschliessen(run())
        let zweiter = FlowStore(loader: loader, dateiStore: FlowFileStore(directory: dir))
        #expect(zweiter.offeneRuns == [run()])
    }
}
