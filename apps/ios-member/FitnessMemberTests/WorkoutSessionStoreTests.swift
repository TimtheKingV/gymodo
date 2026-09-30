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
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start)

        #expect(sut.aktiveSession()?.id == geschrieben.sessionId)
        #expect(geschrieben.body.setIndex == 1)
    }

    @Test func setIndexLaeuftInnerhalbDesBlocks() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                            einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                            problemFlag: false, problemReason: nil, jetzt: start)
        // Anderes Geraet dazwischen -- Zirkeltraining.
        _ = sut.satzSichern(machineId: "m2", exerciseId: "e2",
                            einheiten: .kilogrammWiederholungen, load: 45, volume: 12,
                            problemFlag: false, problemReason: nil,
                            jetzt: start.addingTimeInterval(120))
        let dritter = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                      einheiten: .kilogrammWiederholungen, load: 80, volume: 9,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(240))

        // Zweiter Satz IM BLOCK, nicht dritter Satz der Session.
        #expect(dritter.body.setIndex == 2)
        #expect(sut.aktiveSession()?.bloecke.count == 2)
    }

    @Test func dieselbeSessionInnerhalbVonVierStunden() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                     einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                     problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                      einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(3 * 3600))

        #expect(erster.sessionId == zweiter.sessionId)
    }

    @Test func neueSessionNachVierStundenOhneSatz() {
        let (sut, _) = store()
        let erster = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                     einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                     problemFlag: false, problemReason: nil, jetzt: start)
        let zweiter = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                      einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                      problemFlag: false, problemReason: nil,
                                      jetzt: start.addingTimeInterval(4 * 3600 + 1))

        // recordSet prueft serverseitig nicht, ob die Session schon
        // auto-beendet ist -- der Client muss die Grenze selbst ziehen.
        #expect(erster.sessionId != zweiter.sessionId)
        #expect(zweiter.body.setIndex == 1)
    }

    @Test func abgelaufeneSessionGiltNichtMehrAlsAktiv() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                            einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                            problemFlag: false, problemReason: nil, jetzt: start)

        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(3 * 3600)) != nil)
        #expect(sut.aktiveSession(jetzt: start.addingTimeInterval(4 * 3600 + 1)) == nil)
    }

    @Test func ueberlebtEinenProzessNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let geschrieben = ersterLauf.satzSichern(machineId: "m1", exerciseId: "e1",
                                                 einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                                 problemFlag: false, problemReason: nil, jetzt: start)

        let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        #expect(zweiterLauf.aktiveSession()?.id == geschrieben.sessionId)
        #expect(zweiterLauf.naechsterSetIndex(machineId: "m1", exerciseId: "e1",
                                              jetzt: start.addingTimeInterval(60)) == 2)
    }

    // MARK: - Belastung, Nebenbelastung, Umfang (Cardio Schnitt 3)

    private let laufband = Blockeinheiten(loadUnit: .kmh, secondaryUnit: .pct, volumeKind: .seconds)

    @Test func einLaufbandSatzTraegtNebenbelastungUndEinheitenDesBlocks() {
        let (sut, _) = store()

        let geschrieben = sut.satzSichern(machineId: "m9", exerciseId: "e9", einheiten: laufband,
                                          load: 8.5, secondaryLoad: 6, volume: 1200,
                                          problemFlag: false, problemReason: nil, jetzt: start)

        #expect(geschrieben.body.load == 8.5)
        #expect(geschrieben.body.secondaryLoad == 6)
        #expect(geschrieben.body.volume == 1200)
        let block = sut.aktiveSession(jetzt: start)?.bloecke.first
        #expect(block?.einheiten == laufband)
        #expect(block?.saetze.first?.secondaryLoad == 6)
    }

    @Test func einKraftsatzSchicktKeineNebenbelastung() {
        // Der Server weist ein gesetztes secondaryLoad an einem Modell ohne
        // Nebenbelastung ab (Spec 5.1) -- nil heisst: das Feld fehlt.
        let (sut, _) = store()

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                          problemFlag: false, problemReason: nil, jetzt: start)

        #expect(geschrieben.body.secondaryLoad == nil)
        #expect(sut.aktiveSession(jetzt: start)?.bloecke.first?.einheiten == .kilogrammWiederholungen)
    }

    @Test func dieEinheitenDesBlocksStehenAbDemErstenSatzFest() {
        let (sut, _) = store()
        _ = sut.satzSichern(machineId: "m9", exerciseId: "e9", einheiten: laufband,
                            load: 8.5, secondaryLoad: 6, volume: 1200,
                            problemFlag: false, problemReason: nil, jetzt: start)
        // Ein zweiter Satz mit anderen Einheiten (das Studio hat das Modell
        // mitten in der Einheit geaendert) deutet den ersten nicht um.
        _ = sut.satzSichern(machineId: "m9", exerciseId: "e9", einheiten: .kilogrammWiederholungen,
                            load: 9, secondaryLoad: 6, volume: 600,
                            problemFlag: false, problemReason: nil, jetzt: start.addingTimeInterval(60))

        let block = sut.aktiveSession(jetzt: start.addingTimeInterval(60))?.bloecke.first
        #expect(block?.saetze.count == 2)
        #expect(block?.einheiten == laufband)
    }

    @Test func dieEinheitenUeberlebenEinenProzessNeustart() {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let ersterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        _ = ersterLauf.satzSichern(machineId: "m9", exerciseId: "e9", einheiten: laufband,
                                   load: 8.5, secondaryLoad: 6, volume: 1200,
                                   problemFlag: false, problemReason: nil, jetzt: start)

        let zweiterLauf = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        let block = zweiterLauf.aktiveSession(jetzt: start)?.bloecke.first
        #expect(block?.einheiten == laufband)
        #expect(block?.saetze.first?.load == 8.5)
        #expect(block?.saetze.first?.secondaryLoad == 6)
        #expect(block?.saetze.first?.volume == 1200)
    }

    @Test func eineSessiondateiImAltenFormatLaedtWeiter() throws {
        // So schrieb die Fassung vor Migration 0045: weightKg/reps am Satz,
        // keine Einheiten am Block. Das App-Update kann mitten in einer
        // offenen Einheit kommen -- die darf dabei nicht verloren gehen.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: verzeichnis, withIntermediateDirectories: true)
        let sekunden = start.timeIntervalSinceReferenceDate
        let alt = """
        {"id":"6F0E6E0E-52A8-4B0D-9C54-1D0C0D8F3A11","startedAt":\(sekunden),
         "bloecke":[{"machineId":"m1","exerciseId":"e1","saetze":[
           {"id":"0B1C2D3E-0000-4000-8000-000000000001","setIndex":1,"weightKg":80,"reps":10,
            "problemFlag":false,"performedAt":\(sekunden + 60)},
           {"id":"0B1C2D3E-0000-4000-8000-000000000002","setIndex":2,"weightKg":82.5,"reps":9,"rir":2,
            "problemFlag":true,"problemReason":"zu_schwer","performedAt":\(sekunden + 240)}
         ]}]}
        """
        try Data(alt.utf8).write(to: verzeichnis.appendingPathComponent("laufende-session.json"))

        let session = try #require(SessionFileStore(directory: verzeichnis).load())

        let block = try #require(session.bloecke.first)
        #expect(block.einheiten == .kilogrammWiederholungen)
        #expect(block.saetze.map(\.load) == [80, 82.5])
        #expect(block.saetze.map(\.volume) == [10, 9])
        #expect(block.saetze.map(\.secondaryLoad) == [nil, nil])
        #expect(block.saetze[1].rir == 2)
        #expect(block.saetze[1].problemReason == .zuSchwer)

        // Und der Store zaehlt an ihr weiter: der naechste Satz ist Satz 3.
        let sut = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        #expect(sut.naechsterSetIndex(machineId: "m1", exerciseId: "e1",
                                      jetzt: start.addingTimeInterval(300)) == 3)
    }

    @Test func nachDemNaechstenSatzIstEineAlteDateiUmgezogen() throws {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: verzeichnis, withIntermediateDirectories: true)
        let sekunden = start.timeIntervalSinceReferenceDate
        let alt = """
        {"id":"6F0E6E0E-52A8-4B0D-9C54-1D0C0D8F3A11","startedAt":\(sekunden),
         "bloecke":[{"machineId":"m1","exerciseId":"e1","saetze":[
           {"id":"0B1C2D3E-0000-4000-8000-000000000001","setIndex":1,"weightKg":80,"reps":10,
            "problemFlag":false,"performedAt":\(sekunden + 60)}]}]}
        """
        let datei = verzeichnis.appendingPathComponent("laufende-session.json")
        try Data(alt.utf8).write(to: datei)
        let sut = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))

        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                            einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                            problemFlag: false, problemReason: nil, jetzt: start.addingTimeInterval(120))

        let geschrieben = try String(contentsOf: datei, encoding: .utf8)
        #expect(!geschrieben.contains("weightKg"))
        // Als Schluessel: "reps" als WERT von volumeKind steht zu Recht da.
        #expect(!geschrieben.contains("\"reps\":"))
        #expect(geschrieben.contains("\"load\""))
        #expect(geschrieben.contains("\"volumeKind\""))
    }

    @Test func beendenLoeschtDieSessionUndGibtIhreKennungZurueck() {
        let (sut, _) = store()
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
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

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
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

        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                          problemFlag: false, problemReason: nil,
                                          jetzt: start.addingTimeInterval(600))

        // Sonst bekaeme die Session beim Server den Zeitpunkt des ersten PUT
        // als Beginn -- nach einem Offline-Training Stunden spaeter.
        #expect(geschrieben.body.sessionStartedAt == ISO8601DateFormatter().string(from: start))
    }

    @Test func derFallbackSatzOhneTrainingStartenTraegtEbenfallsDenBeginnZumServer() {
        let (sut, _) = store()

        // Ohne vorheriges trainingStarten() (z.B. nach einem Vier-Stunden-
        // Ablauf) legt satzSichern die Session selbst an -- ihr Beginn ist
        // dann der Satz selbst (startedAt == jetzt, derErsteSatzLegtDieSessionAn).
        // Genau den muss der Body auch als sessionStartedAt tragen, sonst
        // faellt der Server auf diesem Pfad auf now() zurueck.
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
                                          problemFlag: false, problemReason: nil, jetzt: start)

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

    @Test func ausgelaufeneQuittierenRaeumtEineNochLaufendeEinheitNicht() {
        let (sut, _) = store()
        sut.trainingStarten(jetzt: start)
        let nochInnerhalbDerFrist = start.addingTimeInterval(3 * 3600)

        // Die Guard-Bedingung in ausgelaufeneQuittieren() lautet
        // gespeicherteSession != nil && aktiveSession(jetzt:) == nil -- hier
        // ist aktiveSession noch da, der Aufruf darf also nichts raeumen.
        sut.ausgelaufeneQuittieren(jetzt: nochInnerhalbDerFrist)

        #expect(sut.aktiveSession(jetzt: nochInnerhalbDerFrist) != nil)
    }

    @Test func eineAbgelaufeneEinheitMitSatzWirdGemeldet() {
        let (sut, _) = store()
        sut.trainingStarten(jetzt: start)
        _ = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                            einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
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
        let geschrieben = sut.satzSichern(machineId: "m1", exerciseId: "e1",
                                          einheiten: .kilogrammWiederholungen, load: 80, volume: 10,
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
