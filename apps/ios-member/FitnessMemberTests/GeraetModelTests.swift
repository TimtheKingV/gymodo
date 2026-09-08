import Foundation
import Testing
@testable import FitnessMember

/// Nur die Ableitungen werden geprueft -- reine SwiftUI-Views werden laut
/// Spec Abschnitt 10 manuell gegen die Artboards abgenommen.
@MainActor
struct GeraetModelTests {
    private func modell(
        maschine: BootstrapResponse.Machine,
        bootstrap: BootstrapResponse,
        sessions: WorkoutSessionStore? = nil,
        loader: FakeGeraetLoader = FakeGeraetLoader(),
        enqueue: @escaping (PendingSetWrite) -> Void = { _ in }
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: maschine,
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: bootstrap,
            loader: loader,
            sessions: sessions ?? WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: enqueue
        )
    }

    @Test func startetOhneHistorieAmGeraeteminimum() {
        // designsystem.md SS8: "Beim ersten Mal schlaegt gymodo kein Gewicht
        // vor. Das Rad startet am Geraetminimum."
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.gewicht == 5.0)
        #expect(sut.vorschlagText == nil)
    }

    @Test func uebernimmtDenLetztenEigenenWertOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.gewicht == 77.5)
        #expect(sut.wiederholungen == 11)
        #expect(sut.zuletztText?.contains("77,5 kg") == true)
    }

    @Test func rastetEinenVorschlagAufDieSchrittweite() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.gewicht == 80.0)
        #expect(sut.vorschlagText == "Vorschlag · +2,5")
    }

    @Test func kontextUebernehmenUebernimmtDenVorschlagOhneBerührungDesRades() {
        // Unangetastet: kontextLaden() kann jederzeit nach dem initialen
        // Rendern eintreffen -- ohne eigene Eingabe des Mitglieds soll der
        // Vorschlag ganz normal greifen (Review-Fund I2, "unberuehrt").
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.gewicht == 80.0)
    }

    @Test func kontextUebernehmenLaesstEinBereitsGeoeffnetesRadInRuhe() {
        // Ein spaet eintreffender tagContext darf den Wert nicht mehr unter
        // dem Daumen ersetzen, sobald das Mitglied das Rad geoeffnet hat
        // (Review-Fund I2). radOeffnen() ist der einzige Weg dahin.
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [("m1", "e1", 77.5, 11)])
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)
        sut.radOeffnen()

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0))

        #expect(sut.gewicht == 77.5)
        // Der Vorschlag selbst bleibt sichtbar -- nur die Uebernahme in
        // gewicht unterbleibt.
        #expect(sut.vorschlagText == "Vorschlag · +2,5")
    }

    @Test func meldetDenAnschlagNurWennEsEinenGibt() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.anschlagText == "Maximum des Geräts erreicht")

        let ohneGrenze = modell(maschine: GeraetTestdaten.maschineOhneMaximum,
                                bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(ohneGrenze.anschlagText == nil)
    }

    @Test func einstellwerteTragenDieBeschriftungAuchOhneNetz() {
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [], mitKalibrierung: true)
        let sut = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap)

        #expect(sut.einstellwerte.first?.label == "Sitzposition")
        #expect(sut.einstellwerte.first?.anzeige == "4")
    }

    @Test func satzNummerZaehltImBlock() async {
        // Jeder Satz geht durch die Warteschlange, immer -- ein geloeschter
        // enqueue-Aufruf muss hier auffallen, nicht nur satzNummer/pause/
        // radOffen (designsystem.md Konstante "gespeichert, wird gesendet").
        let erfasser = Erfassungswarteschlange()
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
                         sessions: sessions,
                         enqueue: { erfasser.geschriebene.append($0) })
        #expect(sut.satzNummer == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.satzNummer == 2)
        #expect(sut.pause != nil)
        #expect(sut.radOffen == false)

        let laufendeSession = sessions.aktiveSession()
        let gespeicherterSatz = laufendeSession?.bloecke.first?.saetze.first
        #expect(erfasser.geschriebene.count == 1)
        #expect(erfasser.geschriebene.first?.sessionId == laufendeSession?.id)
        #expect(erfasser.geschriebene.first?.setId == gespeicherterSatz?.id)
        #expect(erfasser.geschriebene.first?.body.weightKg == sut.gewicht)
        #expect(erfasser.geschriebene.first?.body.reps == sut.wiederholungen)
    }

    @Test func verwirftKalibrierungUndVorschlagDerVorherigenUebungBeimWechsel() {
        // tag-context.ts berechnet calibration und suggestion serverseitig
        // fuer genau eine Uebung (selectedExerciseId). Nach einem Wechsel
        // muessen Einstellwerte wieder aus bootstrap fuer die NEUE Uebung
        // kommen und der Vorschlag verschwinden -- sonst zeigt der Screen
        // die Sitzposition der vorherigen Uebung unter dem falschen Namen,
        // und das Mitglied stellt das Geraet physisch falsch ein.
        let bootstrap = GeraetTestdaten.bootstrap(
            lastSets: [], mitKalibrierung: true,
            kalibrierungExerciseId: "e2", kalibrierungSitzWert: 6
        )
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap)

        sut.kontextUebernehmen(GeraetTestdaten.kontext(vorschlag: 80.0, kalibrierungSitzWert: 4))
        #expect(sut.einstellwerte.first?.anzeige == "4")
        #expect(sut.vorschlagText != nil)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.vorschlagText == nil)
        #expect(sut.einstellwerte.first?.anzeige == "6")
    }

    @Test func kalibrierungVorbereitenLiestDurchDenselbenUebungsgateWieKalibrierungswerte() {
        // Dieselbe Klammer wie kalibrierungswerte: der Entwurf muss aus der
        // Kalibrierung der AKTUELLEN Uebung entstehen, nicht aus e1, auch
        // wenn der geladene Kontext (falls vorhanden) noch zu e1 gehoert.
        let bootstrap = GeraetTestdaten.bootstrap(
            lastSets: [], mitKalibrierung: true,
            kalibrierungExerciseId: "e2", kalibrierungSitzWert: 6
        )
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap)
        sut.uebungWechseln(zu: "e2")

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfEinstellung["sitz"] == 6)
        #expect(sut.kalibrierungFehler == nil)
    }

    @Test func kalibrierungVorbereitenFaelltOhneVorherigeWerteAufsMinimum() {
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))

        sut.kalibrierungVorbereiten()

        #expect(sut.entwurfEinstellung["sitz"] == 1)
    }

    @Test func kalibrierungSichernSpeichertUndSchliesst() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.success(RecordedCalibration(
            id: "c1", machineId: "m1", exerciseId: "e1",
            settingValues: .number(4), schemaVersion: 1, source: "self",
            createdAt: "2026-09-01T10:00:00Z"
        )))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungOeffnen()
        sut.entwurfEinstellung = ["sitz": 4]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == true)
        #expect(sut.kalibrierungFehler == nil)
        #expect(sut.kalibrierungOffen == false)
    }

    @Test func kalibrierungSichernZeigtDenServertextWoertlichUndSchliesstNicht() async {
        // Der Text kommt vom Server -- nur er kennt die Grenzen des
        // Geraetemodells. Er wird hier NICHT umformuliert.
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.failure(.validation(message: "Sitz darf höchstens 8 sein.")))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.kalibrierungOeffnen()
        sut.entwurfEinstellung = ["sitz": 99]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == false)
        #expect(sut.kalibrierungFehler == "Sitz darf höchstens 8 sein.")
        #expect(sut.kalibrierungOffen == true)
    }

    @Test func erstkontaktLaeuftGenauEinmalJeGeraetUndUebung() {
        // "Der Dreischritt laeuft genau einmal je Geraet und Uebung" --
        // erstkontaktAbschliessen() ist die einzige Stelle, die istErstkontakt
        // fuer die AKTUELLE Uebung nach einem abgeschlossenen Dreischritt
        // korrigiert (Task 16, Step 3 der Aufgabe).
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.istErstkontakt == true)

        sut.erstkontaktAbschliessen()

        #expect(sut.istErstkontakt == false)

        // Der Fluchtweg (ErstkontaktFlow.beiAbbruch, in GeraetScreen auf
        // beiZurueckZumTraining verdrahtet) ruft erstkontaktAbschliessen()
        // NIE auf -- sonst zeigte istErstkontakt beim naechsten Scan
        // faelschlich "erledigt", obwohl das Mitglied den Dreischritt nie zu
        // Ende gebracht hat. Ein frisches Modell im selben Ausgangszustand,
        // ohne den Aufruf, steht dafuer: istErstkontakt bleibt wahr.
        let abgebrochen = modell(maschine: GeraetTestdaten.maschine,
                                 bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(abgebrochen.istErstkontakt == true)
    }

    @Test func istErstkontaktBleibtNachRueckkehrZumGeraetFalschTrotzStalemBootstrap() {
        // Der Zirkelfall aus M1-Spec SS5.3 (Schlusswellen-Fund C2, Faelle 1):
        // Dreischritt an Maschine 7 abgeschlossen, Saetze gemacht, zu einem
        // anderen Geraet gewechselt und ueber die Blockliste zurueck --
        // TrainingRootView.modell(...) baut dabei ein FRISCHES GeraetModel.
        // bootstrap bleibt dabei die alte Momentaufnahme ohne Kalibrierung
        // und ohne lastSet; nur die lokale Session weiss vom Satz.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])

        let erstesModell = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap, sessions: sessions)
        #expect(erstesModell.istErstkontakt == true)
        erstesModell.erstkontaktAbschliessen()
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 40, reps: 10,
                                  rir: nil, problemFlag: false, problemReason: nil)

        // Ein neuer Push: dieselbe sessions-Instanz, aber ein komplett neues
        // GeraetModel -- erledigt der ersten Instanz ist damit weg, nur
        // sessions kennt noch den Satz.
        let zweitesModell = modell(maschine: GeraetTestdaten.maschine, bootstrap: bootstrap, sessions: sessions)
        #expect(zweitesModell.istErstkontakt == false)
    }

    @Test func istErstkontaktGiltFuerEineNieBenutzteUebungAuchNachDemWechsel() {
        // Faelle 2 desselben Funds: uebungWechseln(zu:) darf den Dreischritt
        // einer noch nie benutzten Uebung nicht ueberspringen, nur weil eine
        // ANDERE Uebung am selben Geraet ihn schon hinter sich hat.
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let sessions = WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis))
        let bootstrap = GeraetTestdaten.bootstrap(lastSets: [])
        let sut = modell(maschine: GeraetTestdaten.maschineMitZweiUebungen, bootstrap: bootstrap, sessions: sessions)
        #expect(sut.istErstkontakt == true)

        sut.erstkontaktAbschliessen()
        _ = sessions.satzSichern(machineId: "m1", exerciseId: "e1", weightKg: 40, reps: 10,
                                  rir: nil, problemFlag: false, problemReason: nil)
        #expect(sut.istErstkontakt == false)

        sut.uebungWechseln(zu: "e2")

        #expect(sut.istErstkontakt == true)
    }

    @Test func kalibrierungSichernZeigtEinenEigenenTextOffline() async {
        let loader = FakeGeraetLoader()
        await loader.setCalibration(.failure(.offline))
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []), loader: loader)
        sut.entwurfEinstellung = ["sitz": 4]

        let ergebnis = await sut.kalibrierungSichern()

        #expect(ergebnis == false)
        #expect(sut.kalibrierungFehler?.contains("Ohne Empfang") == true)
    }
}

/// Faengt ein, was eine GeraetModel-Instanz einreiht -- damit ein
/// still geloeschter enqueue-Aufruf in einem Test auffaellt statt
/// unbemerkt durchzugehen.
@MainActor
private final class Erfassungswarteschlange {
    var geschriebene: [PendingSetWrite] = []
}

// MARK: - Testdaten

actor FakeGeraetLoader: GeraetLoading {
    var kontextResult: Result<TagContextResponse, APIError> = .failure(.offline)
    var calibrationResult: Result<RecordedCalibration, APIError> = .failure(.offline)

    func setKontext(_ value: Result<TagContextResponse, APIError>) { kontextResult = value }
    func setCalibration(_ value: Result<RecordedCalibration, APIError>) { calibrationResult = value }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        switch calibrationResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        throw APIError.offline
    }
}

enum GeraetTestdaten {
    static func dekodiere<T: Decodable>(_ json: String, as: T.Type = T.self) -> T {
        try! JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static var maschine: BootstrapResponse.Machine { maschine(maxWeightKg: "150.0") }
    static var maschineOhneMaximum: BootstrapResponse.Machine { maschine(maxWeightKg: "null") }

    static func maschine(maxWeightKg: String) -> BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoPath":null,"weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":\(maxWeightKg),
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","targetRepsMin":8,"targetRepsMax":12}]}
        """)
    }

    /// Zwei Uebungen an einem Geraet -- fuer den Uebungswechsel-Test:
    /// tag-context.ts liefert calibration/suggestion nur fuer eine der beiden.
    static var maschineMitZweiUebungen: BootstrapResponse.Machine {
        dekodiere("""
        {"id":"m1","studioId":"s1","label":"Gerät 7","locationNote":"Fensterseite",
         "status":"active","tokenHashes":[],"visitCount":2,
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoPath":null,"weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0,
           "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
             "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}]},
         "exercises":[{"id":"e1","name":"Beidbeinig","targetRepsMin":8,"targetRepsMax":12},
                      {"id":"e2","name":"Einbeinig","targetRepsMin":6,"targetRepsMax":10}]}
        """)
    }

    static func bootstrap(
        lastSets: [(String, String, Double, Int)],
        mitKalibrierung: Bool = false,
        kalibrierungExerciseId: String = "e1",
        kalibrierungSitzWert: Int = 4
    ) -> BootstrapResponse {
        let saetze = lastSets.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "weightKg":\(eintrag.2),"reps":\(eintrag.3),"rir":null,
             "performedAt":"2026-09-01T10:00:00Z"}
            """
        }.joined(separator: ",")
        let kalibrierungen = mitKalibrierung
            ? #"{"machineId":"m1","exerciseId":"\#(kalibrierungExerciseId)","settingValues":{"sitz":\#(kalibrierungSitzWert)},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}"#
            : ""
        return dekodiere("""
        {"studios":[],"machines":[],"calibrations":[\(kalibrierungen)],"lastSets":[\(saetze)]}
        """)
    }

    static func kontext(vorschlag: Double, kalibrierungSitzWert: Int? = nil) -> TagContextResponse {
        let kalibrierung = kalibrierungSitzWert.map {
            #"{"settingValues":{"sitz":\#($0)},"schemaVersion":1,"source":"self","createdAt":"2026-09-01T10:00:00Z"}"#
        } ?? "null"
        return dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":null,"weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0},
         "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
           "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null},
           {"id":"e2","name":"Einbeinig","description":null,
           "targetRepsMin":6,"targetRepsMax":10,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":\(kalibrierung),
         "history":[{"performedOn":"2026-09-01","weightKg":77.5,"reps":[11,11,10]}],
         "suggestion":{"algoVersion":"v1","resultWeightKg":\(vorschlag),
           "reasonCode":"steigerung","inputs":{"targetRepsMin":8,"targetRepsMax":12,
             "weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0,
             "currentWeightKg":77.5,"consideredBlocks":1}}}
        """)
    }
}
