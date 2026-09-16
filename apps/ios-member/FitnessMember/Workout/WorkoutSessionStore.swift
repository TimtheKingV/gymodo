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

    /// Das Mitglied hat "Training starten" gedrueckt -- ab hier gibt es die
    /// Einheit, und mit ihr laeuft die Uhr (Sammelstelle Punkt 10, entschieden
    /// 15. September; hebt M1-Spec SS5.6 auf).
    ///
    /// Der Server erfaehrt davon nichts: er legt die Einheit weiterhin erst
    /// mit dem ersten Satz an (recordSet upsertet workout_sessions), einen
    /// Start-Endpoint gibt es nicht. Genau deshalb kann eine Einheit ohne
    /// Satz nie bei ihm liegen -- "wird verworfen und nie gemeldet"
    /// (Entschieden 2) ist Struktur, nicht Disziplin. Wer einen
    /// Start-Endpoint baut, verliert das.
    ///
    /// Idempotent: laeuft schon eine Einheit, bleibt sie. Der Startscreen
    /// kommt zwar nur ohne laufendes Training (TrainingStart.ziel), aber ein
    /// zweiter Tap darf die Uhr nicht zuruecksetzen.
    @discardableResult
    func trainingStarten(jetzt: Date = Date()) -> LokaleSession {
        if let laufende = aktiveSession(jetzt: jetzt) { return laufende }
        let session = LokaleSession(id: UUID(), startedAt: jetzt, bloecke: [])
        gespeicherteSession = session
        fileStore.save(session)
        return session
    }

    /// Woran die Trainingsuhr haengt: der Beginn der laufenden Einheit --
    /// seit Schnitt 4 nichts daneben. Vorher lief hier ein gemerkter
    /// Geraetekontakt der Einheit voraus, weil die erst mit dem ersten Satz
    /// entstand; jetzt beginnt die Einheit selbst mit dem Tap.
    func trainingsbeginn(jetzt: Date = Date()) -> Date? {
        aktiveSession(jetzt: jetzt)?.startedAt
    }

    /// Die gespeicherte Einheit, sofern sie NICHT mehr laeuft UND einen Satz
    /// hatte.
    ///
    /// Vergessenes Beenden ist laut M1-Spec SS5.2 der Regelfall. Ohne diesen
    /// Zugriff saehe das Mitglied am naechsten Tag einen leeren Tab und
    /// wuesste nicht, ob sein Training angekommen ist.
    ///
    /// Eine abgelaufene Einheit OHNE Satz gibt es hier nicht zu sehen: sie
    /// wird still verworfen (Sammelstelle, Entschieden 2). "Automatisch
    /// beendet" auf dem leeren Tab spraeche von einem Training, das nie
    /// stattgefunden hat -- und beim Server liegt davon ohnehin nichts.
    func abgelaufeneSession(jetzt: Date = Date()) -> LokaleSession? {
        guard let session = gespeicherteSession, session.hatSaetze,
              aktiveSession(jetzt: jetzt) == nil
        else { return nil }
        return session
    }

    /// Raeumt eine ausgelaufene Einheit weg -- mit Satz nach dem Satz auf dem
    /// leeren Tab (abgelaufeneSession), ohne Satz still.
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
    func ausgelaufeneQuittieren(jetzt: Date = Date()) {
        guard gespeicherteSession != nil, aktiveSession(jetzt: jetzt) == nil else { return }
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
        // Ohne laufende Einheit (sie ist auf dem Satzpfad ausgelaufen, oder ein
        // Test sichert ohne Start) entsteht sie hier -- der Rueckfallweg, nicht
        // der Regelfall: den setzt seit Schnitt 4 trainingStarten(jetzt:).
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

    /// Gibt die Kennung zurueck, damit der Aufrufer POST .../complete
    /// schicken kann -- oder, ohne Satz, gar nichts (TrainingRootView.beenden
    /// verwirft dann).
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
