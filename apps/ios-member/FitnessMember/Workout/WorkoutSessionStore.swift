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

    private var gespeicherteSession: LokaleSession?
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

    /// Die gespeicherte Einheit, sofern sie NICHT mehr laeuft.
    ///
    /// Vergessenes Beenden ist laut M1-Spec SS5.2 der Regelfall. Ohne diesen
    /// Zugriff saehe das Mitglied am naechsten Tag einen leeren Tab und
    /// wuesste nicht, ob sein Training angekommen ist.
    func abgelaufeneSession(jetzt: Date = Date()) -> LokaleSession? {
        guard let session = gespeicherteSession, aktiveSession(jetzt: jetzt) == nil
        else { return nil }
        return session
    }

    /// Raeumt die abgelaufene Einheit weg, damit der Satz auf dem leeren Tab
    /// einmal steht, nicht bei jedem Oeffnen.
    ///
    /// Kein separates Merker-Bool: das wuerde store-global gelten und damit
    /// jede SPAETERE abgelaufene Einheit stumm halten, sobald einmal
    /// quittiert wurde -- und einen Neustart nicht ueberleben. Die
    /// Sessiondatei traegt nur die oertliche Sicht auf die laufende Einheit;
    /// noch nicht gesendete Schreibvorgaenge liegen in PendingWriteStore.
    /// Loeschen ist hier folgenlos fuer sie.
    ///
    /// Selbstschutz: quittiert wird nur, was WIRKLICH ausgelaufen ist. Der
    /// Name verspricht Selektivitaet -- ohne den Guard wuerde jeder Aufruf
    /// zur falschen Zeit bedingungslos die laufende Einheit des Mitglieds
    /// loeschen, Speicher und Datei. Der Schaden waere maximal unsymmetrisch:
    /// falsch-negativ ist ein Satz zu viel auf dem leeren Tab, falsch-positiv
    /// ist das Training des Mitglieds weg. Der Guard gehoert deshalb hier
    /// hin, nicht nur in die Disziplin der Aufrufer.
    func ausgelaufeneQuittieren() {
        guard abgelaufeneSession() != nil else { return }
        gespeicherteSession = nil
        fileStore.save(nil)
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

        // rir bleibt am Satz und im Schreibvorgang erhalten, wird aber
        // nicht mehr erfasst: die Reserve-Abfrage ist aus dem Satzpfad
        // verschwunden. Das Feld traegt weiterhin Altdaten aus der
        // Sessiondatei und aus der Datenbank -- es zu loeschen hiesse, alte
        // Einheiten nicht mehr dekodieren zu koennen.
        let satz = LokalerSatz(
            id: UUID(), setIndex: setIndex, weightKg: weightKg, reps: reps,
            rir: nil, problemFlag: problemFlag, problemReason: problemReason,
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
            weightKg: weightKg, reps: reps, rir: nil,
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
