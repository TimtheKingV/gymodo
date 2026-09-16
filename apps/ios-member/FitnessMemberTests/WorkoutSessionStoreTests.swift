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

    // Rueckfall ohne Start: die Einheit laeuft auf dem Satzpfad aus, der
    // naechste Satz legt eine neue an.
    @Test func derErsteSatzLegtDieSessionAn() {
        let (sut, _) = store()
        #expect(sut.aktiveSession() == nil)

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          weightKg: 80, reps: 10,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start)

        #expect(sut.aktiveSession()?.id == geschrieben.sessionId)
        #expect(geschrieben.body.setIndex == 1)
    }

    @Test func setIndexLaeuftInnerhalbDesBlocks() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            problemFlag: false, problemReason: nil, jetzt: start)
        // Anderes Geraet dazwischen -- Zirkeltraining.
        _ = sut.satzSichern(machineId: "m2", exerciseId: "e2", weightKg: 45, reps: 12,
                            problemFlag: false, problemReason: nil,
                            jetzt: start.addingTimeInterval(120))
        let dritter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 9,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(240))

        // Zweiter Satz IM BLOCK, nicht dritter Satz der Session.
        #expect(dritter.body.setIndex == 2)
        #expect(sut.aktiveSession()?.bloecke.count == 2)
    }

    @Test func dieselbeSessionInnerhalbVonVierStunden() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                     problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(3 * 3600))

        #expect(erster.sessionId == zweiter.sessionId)
    }

    @Test func neueSessionNachVierStundenOhneSatz() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                     problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(4 * 3600 + 1))

        // recordSet prueft serverseitig nicht, ob die Session schon
        // auto-beendet ist -- der Client muss die Grenze selbst ziehen.
        #expect(erster.sessionId != zweiter.sessionId)
        #expect(zweiter.body.setIndex == 1)
    }

    @Test func abgelaufeneSessionGiltNichtMehrAlsAktiv() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(3 * 3600)) != nil)
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) == nil)
    }

    @Test func ueberlebtEinenProzessNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let geschrieben = ersterLauf.satzSichern(machineId: "m1", exerciseId: "e1",
                                                 weightKg: 80, reps: 10,
                                                 problemFlag: false, problemReason: nil, jetzt: start)

        let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        #expect(zweiterLauf.aktiveSession()?.id == geschrieben.sessionId)
        #expect(zweiterLauf.naechsterSetIndex(machineId: "m1", exerciseId: "e1",
                                              jetzt: start.addingTimeInterval(60)) == 2)
    }

    @Test func beendenLoeschtDieSessionUndGibtIhreKennungZurueck() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.beenden() == geschrieben.sessionId)
        #expect(sut.aktiveSession() == nil)
        #expect(sut.beenden() == nil)
    }

    // MARK: - Start der Einheit (Sammelstelle Punkt 10, Entschieden 2)

    @Test func trainingStartenLegtEineLeereEinheitAn() {
        let (sut, _) = store()
        #expect(sut.aktiveSession(jetzt: start) == nil)

        let einheit = sut.trainingStarten(jetzt: start)

        // Die Einheit gibt es ab dem Tap -- ohne Satz, mit Uhr.
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(300)) == einheit)
        #expect(einheit.bloecke.isEmpty)
        #expect(einheit.startedAt == start)
        #expect(sut.trainingsbeginn(jetzt: start.addingTimeInterval(300)) == start)
    }

    @Test func einZweiterStartVerschiebtDenBeginnNicht() {
        let (sut, _) = store()
        let erste = sut.trainingStarten(jetzt: start)

        let zweite = sut.trainingStarten(jetzt: start.addingTimeInterval(900))

        #expect(zweite == erste)
        #expect(sut.trainingsbeginn(jetzt: start.addingTimeInterval(900)) == start)
    }

    @Test func derErsteSatzHaengtAnDerGestartetenEinheit() {
        let (sut, _) = store()
        let einheit = sut.trainingStarten(jetzt: start)

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start.addingTimeInterval(600))

        // Sonst spraenge die Uhr beim ersten Satz auf 00:00 zurueck, und
        // "seit 18:04" auf dem Training-Tab meinte den Satz statt den Start.
        #expect(geschrieben.sessionId == einheit.id)
        #expect(geschrieben.body.setIndex == 1)
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(600))?.startedAt == start)
    }

    @Test func derSatzTraegtDenBeginnDerEinheitZumServer() {
        let (sut, _) = store()
        sut.trainingStarten(jetzt: start)

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start.addingTimeInterval(600))

        // Sonst bekaeme die Session beim Server den Zeitpunkt des ersten PUT
        // als Beginn -- nach einem Offline-Training Stunden spaeter.
        #expect(geschrieben.body.sessionStartedAt == ISO8601DateFormatter().string(from: start))
    }

    @Test func eineLeereEinheitLaeuftNachVierStundenAus() {
        let (sut, _) = store()
        sut.trainingStarten(jetzt: start)

        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600)) != nil)
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) == nil)
    }

    @Test func eineAbgelaufeneEinheitOhneSatzWirdStillVerworfen() {
        let (sut, _) = store()
        sut.trainingStarten(jetzt: start)
        let spaeter = start.addingTimeInterval(5 * 3600)

        // Kein "automatisch beendet" fuer ein Training, das nie stattfand.
        #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)

        sut.ausgelaufeneQuittieren(jetzt: spaeter)

        // Geraeumt ist sie trotzdem: der naechste Start ist eine neue Einheit.
        let neue = sut.trainingStarten(jetzt: spaeter)
        #expect(neue.startedAt == spaeter)
    }

    @Test func eineAbgelaufeneEinheitMitSatzWirdGemeldet() {
        let (sut, _) = store()
        sut.trainingStarten(jetzt: start)
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            problemFlag: false, problemReason: nil, jetzt: start)
        let spaeter = start.addingTimeInterval(5 * 3600)

        #expect(sut.abgelaufeneSession(jetzt: spaeter)?.startedAt == start)

        sut.ausgelaufeneQuittieren(jetzt: spaeter)

        #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)
        #expect(sut.trainingsbeginn(jetzt: spaeter) == nil)
    }

    @Test func beendenRaeumtAuchEineLeereEinheit() {
        let (sut, _) = store()
        let einheit = sut.trainingStarten(jetzt: start)

        // Ob daraus ein Abschluss oder ein Verwerfen wird, entscheidet der
        // Training-Tab an der Zusammenfassung -- der Store raeumt nur.
        #expect(sut.beenden() == einheit.id)
        #expect(sut.aktiveSession(jetzt: start) == nil)
        #expect(sut.trainingsbeginn(jetzt: start) == nil)
    }

    @Test func derStartUeberlebtEinenProzessNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let einheit = ersterLauf.trainingStarten(jetzt: start)

        let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        #expect(zweiterLauf.aktiveSession(jetzt: start.addingTimeInterval(60)) == einheit)
    }

    @Test func dieProblemmeldungLandetImSatzRumpf() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                                          problemFlag: true, problemReason: .zuSchwer,
                                          jetzt: start)

        // Die Meldung braucht keinen eigenen Endpoint (M1-Spec SS6.3).
        #expect(geschrieben.body.problemFlag)
        #expect(geschrieben.body.problemReason == .zuSchwer)
        // Die Reserve wird nicht mehr erfasst -- das Feld bleibt im
        // Rumpf, aber es geht nur noch null raus.
        #expect(geschrieben.body.rir == nil)
    }
}
