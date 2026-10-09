import Foundation
import Testing
@testable import FitnessMember

private actor MeldeLoader: GeraetLoading {
    private(set) var abgeschlossen: [UUID] = []
    var fehler: APIError?

    func setzeFehler(_ e: APIError?) { fehler = e }
    func tagContext(token: String) async throws(APIError) -> TagContextResponse { throw .offline }
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse { throw .offline }
    func equipmentModelContext(modelId: String, studio: String?) async throws(APIError) -> TagContextResponse { throw .offline }
    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration { throw .offline }
    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        abgeschlossen.append(sessionId)
        if let fehler { throw fehler }
        throw .offline
    }
}

@MainActor
struct OrtswechselBeendenTests {
    private func store() -> WorkoutSessionStore {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    }

    @Test func ohneSatzWirdVerworfenUndNichtGemeldet() async {
        let sessions = store()
        _ = sessions.trainingStarten()
        let loader = MeldeLoader()

        let ausgang = sessions.beendenFuerOrtswechsel()
        await WorkoutSessionStore.melden(ausgang, loader: loader)

        #expect(ausgang == .verworfen)
        #expect(sessions.aktiveSession() == nil)
        #expect(await loader.abgeschlossen.isEmpty)
    }

    @Test func mitSatzWirdLokalBeendetUndGemeldet() async {
        let sessions = store()
        let satz = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                        einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                        problemFlag: false, problemReason: nil)
        let loader = MeldeLoader()

        let ausgang = sessions.beendenFuerOrtswechsel()
        await WorkoutSessionStore.melden(ausgang, loader: loader)

        #expect(ausgang == .abgeschlossen(satz.sessionId))
        #expect(sessions.aktiveSession() == nil)
        #expect(await loader.abgeschlossen == [satz.sessionId])
    }

    @Test func serverfehlerWirdGeschluckt() async {
        let loader = MeldeLoader()
        await loader.setzeFehler(.offline)
        await WorkoutSessionStore.melden(.abgeschlossen(UUID()), loader: loader)
        #expect(await loader.abgeschlossen.count == 1)
    }
}
