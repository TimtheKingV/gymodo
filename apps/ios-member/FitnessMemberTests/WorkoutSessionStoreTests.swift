import Foundation
import Testing
@testable import FitnessMember

@MainActor
struct WorkoutSessionStoreTests {
    private func store() -> (WorkoutSessionStore, URL) {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return (WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)), verzeichnis)
    }

    // Kein fester Epoch-Wert: drei Tests rufen aktiveSession() absichtlich
    // ohne Argument auf und pruefen damit den echten Date()-Vorgabewert
    // gegen die Uhrzeit -- ein fixer Zeitstempel aus der Vergangenheit
    // wuerde diese Tests nach Ablauf der Vier-Stunden-Regel dauerhaft
    // fehlschlagen lassen, unabhaengig von der Implementierung.
    private let start = Date()

    @Test func derErsteSatzLegtDieSessionAn() {
        let (sut, _) = store()
        #expect(sut.aktiveSession() == nil)

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          weightKg: 80, reps: 10, rir: nil,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start)

        #expect(sut.aktiveSession()?.id == geschrieben.sessionId)
        #expect(geschrieben.body.setIndex == 1)
    }

    @Test func setIndexLaeuftInnerhalbDesBlocks() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        // Anderes Geraet dazwischen -- Zirkeltraining.
        _ = sut.satzSichern(machineId: "m2", exerciseId: "e2", weightKg: 45, reps: 12,
                            rir: nil, problemFlag: false, problemReason: nil,
                            jetzt: start.addingTimeInterval(120))
        let dritter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 9,
                                      rir: nil, problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(240))

        // Zweiter Satz IM BLOCK, nicht dritter Satz der Session.
        #expect(dritter.body.setIndex == 2)
        #expect(sut.aktiveSession()?.bloecke.count == 2)
    }

    @Test func dieselbeSessionInnerhalbVonVierStunden() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                     rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      rir: nil, problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(3 * 3600))

        #expect(erster.sessionId == zweiter.sessionId)
    }

    @Test func neueSessionNachVierStundenOhneSatz() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                     rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      rir: nil, problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(4 * 3600 + 1))

        // recordSet prueft serverseitig nicht, ob die Session schon
        // auto-beendet ist -- der Client muss die Grenze selbst ziehen.
        #expect(erster.sessionId != zweiter.sessionId)
        #expect(zweiter.body.setIndex == 1)
    }

    @Test func abgelaufeneSessionGiltNichtMehrAlsAktiv() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(3 * 3600)) != nil)
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) == nil)
    }

    @Test func ueberlebtEinenProzessNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let geschrieben = ersterLauf.satzSichern(machineId: "m1", exerciseId: "e1",
                                                 weightKg: 80, reps: 10, rir: nil,
                                                 problemFlag: false, problemReason: nil, jetzt: start)

        let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        #expect(zweiterLauf.aktiveSession()?.id == geschrieben.sessionId)
        #expect(zweiterLauf.naechsterSetIndex(machineId: "m1", exerciseId: "e1",
                                              jetzt: start.addingTimeInterval(60)) == 2)
    }

    @Test func beendenLoeschtDieSessionUndGibtIhreKennungZurueck() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.beenden() == geschrieben.sessionId)
        #expect(sut.aktiveSession() == nil)
        #expect(sut.beenden() == nil)
    }

    @Test func dieProblemmeldungLandetImSatzRumpf() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          rir: 2, problemFlag: true, problemReason: .zuSchwer,
                                          jetzt: start)

        // Die Meldung braucht keinen eigenen Endpoint (M1-Spec SS6.3).
        #expect(geschrieben.body.problemFlag)
        #expect(geschrieben.body.problemReason == .zuSchwer)
        #expect(geschrieben.body.rir == 2)
    }
}
