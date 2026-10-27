import Foundation
import Testing
@testable import FitnessMember

private actor MeldeLoader: GeraetLoading {
    private(set) var abgeschlossen: [UUID] = []
    private(set) var pausen: [Int] = []
    var fehler: APIError?

    func setzeFehler(_ e: APIError?) { fehler = e }
    func tagContext(token: String) async throws(APIError) -> TagContextResponse { throw .offline }
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse { throw .offline }
    func equipmentModelContext(modelId: String, studio: String?) async throws(APIError) -> TagContextResponse { throw .offline }
    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration { throw .offline }
    func completeSession(sessionId: UUID, pausedSeconds: Int) async throws(APIError) -> CompletedSession {
        abgeschlossen.append(sessionId)
        pausen.append(pausedSeconds)
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

        #expect(ausgang == .abgeschlossen(satz.sessionId, pausedSeconds: 0))
        #expect(sessions.aktiveSession() == nil)
        #expect(await loader.abgeschlossen == [satz.sessionId])
    }

    @Test func serverfehlerWirdGeschluckt() async {
        let loader = MeldeLoader()
        await loader.setzeFehler(.offline)
        await WorkoutSessionStore.melden(.abgeschlossen(UUID(), pausedSeconds: 0), loader: loader)
        #expect(await loader.abgeschlossen.count == 1)
    }

    @Test func meldenSchicktDiePausensumme() async {
        let loader = MeldeLoader()
        await WorkoutSessionStore.melden(.abgeschlossen(UUID(), pausedSeconds: 90), loader: loader)
        #expect(await loader.pausen == [90])
    }
    // MARK: - Trainingsplan (Etappe 3, Task 9)

    /// Auch der Ortswechsel beendet die Einheit: sie zaehlt dann fuer die
    /// Folge wie nach "Training beenden", bevor die Kennung weg ist.
    @Test func mitSatzZaehltDieEinheitDesPlans() {
        let sessions = store()
        let ablauf = TrainingsplanAblaufStoreTests.store()
        ablauf.vorbereiten(plan: TrainingsplanAblaufStoreTests.plan(), jetzt: Date())
        let satz = sessions.satzSichern(station: .testGeraet("m1"), exerciseId: "e1",
                                        einheiten: .kilogrammWiederholungen, load: 40, volume: 10,
                                        problemFlag: false, problemReason: nil)
        _ = ablauf.nachSatz(sessionId: satz.sessionId,
                            satz: TrainingsplanAblaufStoreTests.brust, jetzt: Date())

        _ = sessions.beendenFuerOrtswechsel(ablauf: ablauf)

        #expect(ablauf.zustand == nil)
        ablauf.vorbereiten(plan: TrainingsplanAblaufStoreTests.plan(naechste: "A"), jetzt: Date())
        #expect(ablauf.einheitKey == "B")
    }

    @Test func ohneSatzZaehltDieEinheitNicht() {
        let sessions = store()
        _ = sessions.trainingStarten()
        let ablauf = TrainingsplanAblaufStoreTests.store()
        ablauf.vorbereiten(plan: TrainingsplanAblaufStoreTests.plan(), jetzt: Date())

        _ = sessions.beendenFuerOrtswechsel(ablauf: ablauf)

        ablauf.vorbereiten(plan: TrainingsplanAblaufStoreTests.plan(naechste: "A"), jetzt: Date())
        #expect(ablauf.einheitKey == "A")
    }
}
