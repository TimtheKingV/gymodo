import Foundation
import Testing
@testable import FitnessMember

struct TrainingszusammenfassungTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func satz(_ index: Int, _ gewicht: Double, _ minuten: Double,
                      problem: Bool = false) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, weightKg: gewicht, reps: 10,
                    rir: nil, problemFlag: problem, problemReason: problem ? .schmerz : nil,
                    performedAt: start.addingTimeInterval(minuten * 60))
    }

    @Test func rechnetDauerVomErstenBisZumLetztenSatz() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 47)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.dauerMinuten == 47)
        #expect(z.von == start)
        #expect(z.bis == start.addingTimeInterval(47 * 60))
    }

    @Test func zaehltGeraeteUndSaetze() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5), satz(3, 80, 10)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2",
                         saetze: [satz(1, 45, 15)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.geraeteAnzahl == 2)
        #expect(z.satzAnzahl == 4)
    }

    @Test func zaehltZweiUebungenAmSelbenGeraetAlsEinGeraet() throws {
        // "3 Geraete" auf dem Artboard meint Geraete, nicht Bloecke.
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, 80, 0)]),
            LokalerBlock(machineId: "m1", exerciseId: "e2", saetze: [satz(1, 60, 5)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.geraeteAnzahl == 1)
        #expect(z.bloecke.count == 2)
    }

    @Test func nenntDasGewichtNurWennAlleSaetzeSichEinigSind() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5)]),
            LokalerBlock(machineId: "m2", exerciseId: "e2",
                         saetze: [satz(1, 45, 10), satz(2, 47.5, 15)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.bloecke[0].gewichtKg == 80)
        // Uneinheitlich: lieber keine Zahl als eine falsche.
        #expect(z.bloecke[1].gewichtKg == nil)
    }

    @Test func merktSichEinGemeldetesProblemJeBlock() throws {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1",
                         saetze: [satz(1, 80, 0), satz(2, 80, 5, problem: true)]),
        ])

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.bloecke[0].problemGemeldet)
    }

    @Test func eineEinheitOhneSaetzeHatKeineZusammenfassung() {
        let leer = LokaleSession(id: UUID(), startedAt: start, bloecke: [])

        #expect(Trainingszusammenfassung(leer) == nil)
    }
}

@MainActor
struct AbgelaufeneSessionTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func store() -> WorkoutSessionStore {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
    }

    @Test func eineLaufendeEinheitGiltNichtAlsAbgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(600)) == nil)
    }

    @Test func nachVierStundenGiltSieAlsAbgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) != nil)
    }

    @Test func quittierenLaesstSieVerschwinden() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        let spaeter = start.addingTimeInterval(5 * 3600)

        sut.ausgelaufeneQuittieren()

        // Der Satz auf dem leeren Tab steht einmal, nicht fuer immer.
        #expect(sut.abgelaufeneSession(jetzt: spaeter) == nil)
    }

    @Test func eineSpaetereEinheitBekommtIhrenEigenenHinweis() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        sut.ausgelaufeneQuittieren()

        // Ohne "Training beenden" zu druecken: der naechste Satz legt eine
        // neue Einheit an, weit genug hinter der ersten, dass sie eigenstaendig ist.
        let zweiterStart = start.addingTimeInterval(5 * 3600)
        _ = sut.satzSichern(machineId: "m2", exerciseId: "e2", weightKg: 45, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: zweiterStart)

        #expect(sut.abgelaufeneSession(jetzt: zweiterStart.addingTimeInterval(4 * 3600 + 1)) != nil)
    }

    @Test func einManuellBeendetesTrainingGiltNichtAlsAusgelaufen() {
        let sut = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 80, reps: 10,
                            rir: nil, problemFlag: false, problemReason: nil, jetzt: start)
        sut.beenden()

        #expect(sut.abgelaufeneSession(jetzt: start.addingTimeInterval(5 * 3600)) == nil)
    }
}
