import Foundation
import Testing
@testable import FitnessMember

@Suite("PendingWriteStore")
struct PendingWriteStoreTests {
    private func makeTempDirectory() -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("pending-write-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test("liefert eine leere Liste, wenn nie gespeichert wurde")
    func startsEmpty() {
        let store = PendingWriteStore(directory: makeTempDirectory())
        #expect(store.loadAll().isEmpty)
    }

    @Test("uebersteht einen simulierten Neustart ohne Datenverlust")
    func survivesRestart() {
        let directory = makeTempDirectory()
        let write = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil)
        )

        let firstProcess = PendingWriteStore(directory: directory)
        firstProcess.save([write])

        // "Neustart": eine neue Instanz auf demselben Verzeichnis, keine
        // gemeinsame In-Memory-Referenz mit firstProcess.
        let secondProcess = PendingWriteStore(directory: directory)
        #expect(secondProcess.loadAll() == [write])
    }

    @Test("speichert eine leere Liste, wenn alles abgearbeitet ist")
    func savingEmptyListClears() {
        let directory = makeTempDirectory()
        let write = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, weightKg: 80, reps: 10, rir: nil)
        )
        let store = PendingWriteStore(directory: directory)
        store.save([write])
        store.save([])
        #expect(PendingWriteStore(directory: directory).loadAll().isEmpty)
    }
}
