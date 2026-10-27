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

    @Test("liest nach schnell aufeinanderfolgenden Speichern immer den letzten Stand")
    func letzterStandNachSchnellemSpeichern() {
        let store = PendingWriteStore(directory: makeTempDirectory())
        var letzte: [PendingSetWrite] = []
        for i in 1...50 {
            letzte.append(PendingSetWrite(
                sessionId: UUID(), setId: UUID(),
                body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: i, load: 80, volume: 10, rir: nil)))
            store.save(letzte)
        }
        #expect(store.loadAll() == letzte)
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
            body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, load: 80, volume: 10, rir: nil)
        )

        let firstProcess = PendingWriteStore(directory: directory)
        firstProcess.save([write])

        // "Neustart": eine neue Instanz auf demselben Verzeichnis, keine
        // gemeinsame In-Memory-Referenz mit firstProcess.
        let secondProcess = PendingWriteStore(directory: directory)
        #expect(secondProcess.loadAll() == [write])
    }

    @Test("liest eine Warteschlange, die die Fassung vor Migration 0046 geschrieben hat")
    func liestAlteWarteschlange() throws {
        // Wer vor dem App-Update offline trainiert hat, traegt seine Saetze
        // als weightKg/reps in der Datei. Dekodierte sie nicht mehr, gaebe
        // loadAll() eine leere Liste -- und die Saetze waeren still weg.
        let directory = makeTempDirectory()
        let sessionId = UUID()
        let setId = UUID()
        let alt = """
        [{"sessionId":"\(sessionId.uuidString)","setId":"\(setId.uuidString)",
          "body":{"machineId":"m1","exerciseId":"ex1","setIndex":1,"weightKg":80,"reps":10,
                  "problemFlag":false,"performedAt":"2026-09-20T10:00:00Z",
                  "sessionStartedAt":"2026-09-20T09:50:00Z"}}]
        """
        try Data(alt.utf8).write(to: directory.appendingPathComponent("pending-writes.json"))

        let geladen = PendingWriteStore(directory: directory).loadAll()

        #expect(geladen.count == 1)
        #expect(geladen.first?.setId == setId)
        #expect(geladen.first?.body.load == 80)
        #expect(geladen.first?.body.volume == 10)
        #expect(geladen.first?.body.secondaryLoad == nil)
        #expect(geladen.first?.body.sessionStartedAt == "2026-09-20T09:50:00Z")
    }

    @Test("ein Laufband-Satz uebersteht den Neustart mit seiner Nebenbelastung")
    func nebenbelastungUeberstehtNeustart() {
        let directory = makeTempDirectory()
        let write = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m9", exerciseId: "ex9", setIndex: 1,
                           load: 8.5, volume: 1200, secondaryLoad: 6)
        )
        PendingWriteStore(directory: directory).save([write])

        #expect(PendingWriteStore(directory: directory).loadAll() == [write])
    }

    @Test("speichert eine leere Liste, wenn alles abgearbeitet ist")
    func savingEmptyListClears() {
        let directory = makeTempDirectory()
        let write = PendingSetWrite(
            sessionId: UUID(), setId: UUID(),
            body: SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, load: 80, volume: 10, rir: nil)
        )
        let store = PendingWriteStore(directory: directory)
        store.save([write])
        store.save([])
        #expect(PendingWriteStore(directory: directory).loadAll().isEmpty)
    }
}

#if os(iOS)
extension PendingWriteStoreTests {
    private static var dateischutzAttributeVerfuegbar: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        true
        #endif
    }

    @Test(.enabled(if: Self.dateischutzAttributeVerfuegbar,
                   "Der Simulator liefert keine Dateischutzattribute; auf echtem iPhone pruefen."))
    func bestehendeDateienUndAtomareSchreibvorgaengeBleibenNachEntsperrenZugaenglich() throws {
        let directory = makeTempDirectory()
        let datei = directory.appendingPathComponent("pending-writes.json")
        try Data("[]".utf8).write(to: datei, options: .completeFileProtection)
        let store = PendingWriteStore(directory: directory)
        let erwarteterSchutz = FileProtectionType.completeUntilFirstUserAuthentication
        let alterSchutz = try FileManager.default.attributesOfItem(atPath: datei.path)[.protectionKey]
        #expect(alterSchutz as? String == erwarteterSchutz.rawValue, "Dateischutzattribute: \(String(describing: alterSchutz))")
        store.save([])
        store.abwarten()
        #expect(try FileManager.default.attributesOfItem(atPath: datei.path)[.protectionKey] as? String == erwarteterSchutz.rawValue)
        #expect(try FileManager.default.attributesOfItem(atPath: directory.path)[.protectionKey] as? String == erwarteterSchutz.rawValue)
    }
}
#endif
