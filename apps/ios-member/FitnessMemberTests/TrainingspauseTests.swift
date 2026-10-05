import Foundation
import Testing
@testable import FitnessMember

/// Pausieren und Fortsetzen einer laufenden Einheit (Testnotiz 05.10.,
/// #7, #11). Die Pause zaehlt nicht als Trainingszeit -- weder auf der Uhr
/// noch im Abschluss.
struct TrainingspauseTests {
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    private func minuten(_ m: Double) -> Date { start.addingTimeInterval(m * 60) }

    private func satz(_ index: Int, _ m: Double) -> LokalerSatz {
        LokalerSatz(id: UUID(), setIndex: index, load: 80, volume: 10,
                    problemFlag: false, problemReason: nil, performedAt: minuten(m))
    }

    @Test func ohnePauseZaehltDieGanzeZeit() {
        let session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])

        #expect(session.trainiert(bis: minuten(30)) == 30 * 60)
        #expect(!session.istPausiert)
    }

    /// Die Uhr bleibt in der Pause stehen.
    @Test func diePauseFriertDieUhrEin() {
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        session.pausieren(jetzt: minuten(10))

        #expect(session.istPausiert)
        #expect(session.trainiert(bis: minuten(10)) == 10 * 60)
        #expect(session.trainiert(bis: minuten(45)) == 10 * 60)
    }

    @Test func fortsetzenZiehtDiePauseAb() {
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        session.pausieren(jetzt: minuten(10))
        session.fortsetzen(jetzt: minuten(25))

        #expect(!session.istPausiert)
        #expect(session.trainiert(bis: minuten(30)) == 15 * 60)
    }

    /// Ein zweiter Tap auf "Pausieren" verschiebt den Pausenbeginn nicht.
    @Test func doppeltPausierenAendertNichts() {
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        session.pausieren(jetzt: minuten(10))
        session.pausieren(jetzt: minuten(20))
        session.fortsetzen(jetzt: minuten(30))
        session.fortsetzen(jetzt: minuten(40))

        #expect(session.trainiert(bis: minuten(40)) == 20 * 60)
    }

    /// Der Abschluss zaehlt die Minuten ohne Pause.
    @Test func derAbschlussZaehltDiePauseNicht() throws {
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, 5)]),
        ])
        session.pausieren(jetzt: minuten(10))
        session.fortsetzen(jetzt: minuten(30))
        session.bloecke[0].saetze.append(satz(2, 47))

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.dauerMinuten == 27)
    }

    /// Pausiert nach dem letzten Satz und dann beendet: die Pause liegt
    /// hinter dem Ende und zaehlt ohnehin nicht.
    @Test func einePauseNachDemLetztenSatzZaehltNicht() throws {
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [
            LokalerBlock(machineId: "m1", exerciseId: "e1", saetze: [satz(1, 20)]),
        ])
        session.pausieren(jetzt: minuten(25))

        let z = try #require(Trainingszusammenfassung(session))

        #expect(z.dauerMinuten == 20)
    }

    /// Eine Sessiondatei von vor dieser Fassung kennt keine Pause --
    /// ein App-Update mitten im Training darf sie nicht unlesbar machen.
    @Test func eineAlteSessiondateiDekodiertOhnePause() throws {
        let alt = """
        {"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","startedAt":0,"bloecke":[]}
        """
        let session = try JSONDecoder().decode(LokaleSession.self, from: Data(alt.utf8))

        #expect(!session.istPausiert)
        #expect(session.pausenDauer == 0)
    }

    @Test func diePauseUeberlebtDasSpeichern() throws {
        var session = LokaleSession(id: UUID(), startedAt: start, bloecke: [])
        session.pausieren(jetzt: minuten(10))

        let wieder = try JSONDecoder().decode(LokaleSession.self, from: JSONEncoder().encode(session))

        #expect(wieder == session)
    }
}
