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
    /// Der erste Geraetekontakt, solange es noch keine Session gibt. Siehe
    /// geraetBetreten(jetzt:).
    private var gemerkterBeginn: Date?
    private let fileStore: SessionFileStore

    init(fileStore: SessionFileStore = SessionFileStore()) {
        self.fileStore = fileStore
        gespeicherteSession = fileStore.load()
        gemerkterBeginn = fileStore.loadBeginn()
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
        beginnVerwerfen()
    }

    /// Die Uhr gehoert zur Einheit: endet sie, endet auch der gemerkte
    /// Beginn. Sonst uebernaehme die naechste Einheit die Startzeit der
    /// vorherigen.
    private func beginnVerwerfen() {
        gemerkterBeginn = nil
        fileStore.saveBeginn(nil)
    }

    /// Das Mitglied steht an einem Geraet -- ab hier laeuft die
    /// Trainingsuhr.
    ///
    /// Die Einheit selbst entsteht weiterhin erst mit dem ersten
    /// gesicherten Satz (M1-Spec SS5.6: es gibt keinen Startknopf). Zwischen
    /// dem Scan des ersten Geraets und diesem Satz liegen aber Einweisung,
    /// Kalibrierung und der erste Anlauf -- Zeit, die zum Training gehoert.
    /// Der Zeitpunkt wird deshalb hier gemerkt und beim Anlegen der Session
    /// als deren `startedAt` uebernommen: beide Screens zeigen dann
    /// dieselbe Zahl, und "seit 18:04" meint den Scan, nicht den ersten
    /// Satz.
    ///
    /// Ruft ein zweites Geraet auf, bleibt der erste Zeitpunkt stehen --
    /// abgesehen von dem Fall, dass er laengst ausgelaufen ist (siehe
    /// trainingsbeginn(jetzt:)); dann beginnt hier eine neue Einheit.
    func geraetBetreten(jetzt: Date = Date()) {
        guard trainingsbeginn(jetzt: jetzt) == nil else { return }
        gemerkterBeginn = jetzt
        fileStore.saveBeginn(jetzt)
    }

    /// Woran die Trainingsuhr haengt: die laufende Einheit, sonst der
    /// gemerkte erste Geraetekontakt.
    ///
    /// Der gemerkte Zeitpunkt verfaellt nach derselben Vier-Stunden-Regel
    /// wie die Session -- sonst zaehlte die Uhr am naechsten Tag noch die
    /// Stunden seit einem Geraet, an dem nie ein Satz gesichert wurde.
    func trainingsbeginn(jetzt: Date = Date()) -> Date? {
        if let session = aktiveSession(jetzt: jetzt) { return session.startedAt }
        guard let gemerkterBeginn,
              jetzt.timeIntervalSince(gemerkterBeginn) <= Self.sessionPause
        else { return nil }
        return gemerkterBeginn
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
        // startedAt ist der erste Geraetekontakt, nicht dieser Satz -- die
        // Uhr auf dem Geraete-Screen laeuft seit dem Scan und darf beim
        // ersten gesicherten Satz nicht zurueckspringen. Ohne gemerkten
        // Beginn (App-Neustart dazwischen, Satz ohne vorherigen Screen im
        // Test) bleibt es beim bisherigen Verhalten.
        var session = aktiveSession(jetzt: jetzt)
            ?? LokaleSession(id: UUID(), startedAt: trainingsbeginn(jetzt: jetzt) ?? jetzt,
                             bloecke: [])

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
        beginnVerwerfen()
        return id
    }

    /// Nach dem Abmelden faellt die laufende Einheit -- ihre Kennungen
    /// gehoeren zum abgemeldeten Konto.
    func reset() { beenden() }
}
