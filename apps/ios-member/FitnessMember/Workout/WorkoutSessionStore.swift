import Foundation
import Observation

@MainActor
@Observable
final class WorkoutSessionStore {
    /// Eine Session ohne neuen Satz seit vier Stunden gilt als beendet
    /// (M1-Spec SS5.2).
    ///
    /// Die Regel gilt bewusst auf BEIDEN Seiten: recordSet upsertet die
    /// Session mit ignoreDuplicates und prueft nicht, ob sie serverseitig
    /// schon auto-beendet ist. Ein Client, der eine fuenf Stunden alte
    /// sessionId weiterbenutzt, haengt Saetze an eine Einheit, die der
    /// Server laengst als abgeschlossen liest.
    static let sessionPause: TimeInterval = 4 * 60 * 60

    private(set) var gespeicherteSession: LokaleSession?
    private let fileStore: SessionFileStore

    init(fileStore: SessionFileStore = SessionFileStore()) {
        self.fileStore = fileStore
        gespeicherteSession = fileStore.load()
    }

    /// Die Session, sofern sie noch laeuft. Ohne Argument gegen die aktuelle
    /// Uhr -- fuer Views; mit Argument fuer Tests.
    ///
    /// Bewusst EINE Methode mit Vorgabewert statt Eigenschaft plus Methode:
    /// derselbe Name in beiden Formen waere in Swift eine ungueltige
    /// Neudeklaration.
    func aktiveSession(jetzt: Date = Date()) -> LokaleSession? {
        guard let session = gespeicherteSession else { return nil }
        let letzte = session.letzterSatzAm ?? session.startedAt
        return jetzt.timeIntervalSince(letzte) > Self.sessionPause ? nil : session
    }

    func naechsterSetIndex(machineId: String, exerciseId: String, jetzt: Date = Date()) -> Int {
        let block = aktiveSession(jetzt: jetzt)?.bloecke
            .first { $0.machineId == machineId && $0.exerciseId == exerciseId }
        return (block?.saetze.count ?? 0) + 1
    }

    func satzSichern(
        machineId: String,
        exerciseId: String,
        weightKg: Double,
        reps: Int,
        rir: Double?,
        problemFlag: Bool,
        problemReason: ProblemReason?,
        jetzt: Date = Date()
    ) -> (sessionId: UUID, setId: UUID, body: SetWrite) {
        var session = aktiveSession(jetzt: jetzt)
            ?? LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [])

        let index = session.bloecke.firstIndex {
            $0.machineId == machineId && $0.exerciseId == exerciseId
        }
        let setIndex = (index.map { session.bloecke[$0].saetze.count } ?? 0) + 1

        let satz = LokalerSatz(
            id: UUID(), setIndex: setIndex, weightKg: weightKg, reps: reps,
            rir: rir, problemFlag: problemFlag, problemReason: problemReason,
            performedAt: jetzt
        )

        if let index {
            session.bloecke[index].saetze.append(satz)
        } else {
            session.bloecke.append(
                LokalerBlock(machineId: machineId, exerciseId: exerciseId, saetze: [satz])
            )
        }

        gespeicherteSession = session
        fileStore.save(session)

        let body = SetWrite(
            machineId: machineId, exerciseId: exerciseId, setIndex: setIndex,
            weightKg: weightKg, reps: reps, rir: rir,
            problemFlag: problemFlag, problemReason: problemReason,
            performedAt: ISO8601DateFormatter().string(from: jetzt)
        )
        return (session.id, satz.id, body)
    }

    /// Gibt die Kennung zurueck, damit der Aufrufer
    /// POST .../complete schicken kann.
    @discardableResult
    func beenden() -> UUID? {
        let id = gespeicherteSession?.id
        gespeicherteSession = nil
        fileStore.save(nil)
        return id
    }

    /// Nach dem Abmelden faellt die laufende Einheit -- ihre Kennungen
    /// gehoeren zum abgemeldeten Konto.
    func reset() { beenden() }
}
