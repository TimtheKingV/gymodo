import Foundation
import Testing
@testable import FitnessMember

/// Nur die Ableitungen werden geprueft -- reine SwiftUI-Views werden laut
/// Spec Abschnitt 10 manuell gegen die Artboards abgenommen.
@MainActor
struct GeraetModelTests {
    private func modell(
        maschine: BootstrapResponse.Machine,
        bootstrap: BootstrapResponse
    ) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: maschine,
            uebungId: maschine.exercises.first?.id ?? "e1",
            token: nil,
            bootstrap: bootstrap,
            loader: FakeGeraetLoader(),
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: { _ in }
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
        let sut = modell(maschine: GeraetTestdaten.maschine,
                         bootstrap: GeraetTestdaten.bootstrap(lastSets: []))
        #expect(sut.satzNummer == 1)

        await sut.satzSichern(problemFlag: false, problemReason: nil)

        #expect(sut.satzNummer == 2)
        #expect(sut.pause != nil)
        #expect(sut.radOffen == false)
    }
}

// MARK: - Testdaten

actor FakeGeraetLoader: GeraetLoading {
    var kontextResult: Result<TagContextResponse, APIError> = .failure(.offline)

    func setKontext(_ value: Result<TagContextResponse, APIError>) { kontextResult = value }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        switch kontextResult {
        case .success(let value): return value
        case .failure(let error): throw error
        }
    }

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        throw APIError.offline
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

    static func bootstrap(
        lastSets: [(String, String, Double, Int)],
        mitKalibrierung: Bool = false
    ) -> BootstrapResponse {
        let saetze = lastSets.map { eintrag in
            """
            {"machineId":"\(eintrag.0)","exerciseId":"\(eintrag.1)",
             "weightKg":\(eintrag.2),"reps":\(eintrag.3),"rir":null,
             "performedAt":"2026-09-01T10:00:00Z"}
            """
        }.joined(separator: ",")
        let kalibrierungen = mitKalibrierung
            ? #"{"machineId":"m1","exerciseId":"e1","settingValues":{"sitz":4},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}"#
            : ""
        return dekodiere("""
        {"studios":[],"machines":[],"calibrations":[\(kalibrierungen)],"lastSets":[\(saetze)]}
        """)
    }

    static func kontext(vorschlag: Double) -> TagContextResponse {
        dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":null,"weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0},
         "settingDefinitions":[{"key":"sitz","label":"Sitzposition","kind":"number",
           "minValue":1,"maxValue":8,"stepValue":1,"unit":null,"allowedValues":null}],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":null,
         "history":[{"performedOn":"2026-09-01","weightKg":77.5,"reps":[11,11,10]}],
         "suggestion":{"algoVersion":"v1","resultWeightKg":\(vorschlag),
           "reasonCode":"steigerung","inputs":{"targetRepsMin":8,"targetRepsMax":12,
             "weightStepKg":2.5,"minWeightKg":5.0,"maxWeightKg":150.0,
             "currentWeightKg":77.5,"consideredBlocks":1}}}
        """)
    }
}
