import Foundation
import Testing
@testable import FitnessMember

/// Welchen der beiden Wege `kontextLaden()` nimmt.
///
/// Bis zur Geraeteauswahl ohne Scan gab es nur einen: ohne Token stieg die
/// Methode in der ersten Zeile aus, und der Screen blieb ohne Foto, Video
/// und Vorschlag stehen. Genau das darf nicht zurueckkommen.
@MainActor
struct GeraetKontextLadenTests {

    private func modell(token: String?, loader: FakeGeraetLoader) -> GeraetModel {
        let verzeichnis = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        return GeraetModel(
            maschine: GeraetTestdaten.maschine,
            uebungId: "e1",
            token: token,
            bootstrap: GeraetTestdaten.bootstrap(lastSets: []),
            loader: loader,
            sessions: WorkoutSessionStore(fileStore: SessionFileStore(directory: verzeichnis)),
            enqueue: { _ in }
        )
    }

    /// Ein Kontext mit Foto -- das Einzige, was die Auswahl ohne ein Wort
    /// bestaetigen wuerde, und ohne Token bisher nie ankam.
    private var kontextMitFoto: TagContextResponse {
        GeraetTestdaten.dekodiere("""
        {"machine":{"id":"m1","label":"Gerät 7","locationNote":"Fensterseite"},
         "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":"Technogym",
           "photoUrl":"https://example.test/foto.jpg","weightStepKg":2.5,
           "minWeightKg":5.0,"maxWeightKg":150.0},
         "settingDefinitions":[],
         "exercises":[{"id":"e1","name":"Beidbeinig","description":null,
           "targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null}],
         "selectedExerciseId":"e1","calibration":null,"history":[],
         "suggestion":{"algoVersion":"v1","resultWeightKg":40.0,"reasonCode":"keine_historie",
           "inputs":{"targetRepsMin":8,"targetRepsMax":12,"weightStepKg":2.5,
             "minWeightKg":5.0,"maxWeightKg":150.0,"currentWeightKg":null,
             "consideredBlocks":0}}}
        """)
    }

    @Test func mitTokenGehtEsUeberDenTagWeg() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.success(kontextMitFoto))

        await modell(token: "abc123", loader: loader).kontextLaden()

        #expect(await loader.tagAufrufe == ["abc123"])
        #expect(await loader.machineAufrufe.isEmpty)
    }

    /// Der Fall, um den es geht: aus der Liste gewaehlt, kein Token.
    @Test func ohneTokenGehtEsUeberDieMachineId() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.success(kontextMitFoto))

        await modell(token: nil, loader: loader).kontextLaden()

        #expect(await loader.machineAufrufe == ["m1"])
        #expect(await loader.tagAufrufe.isEmpty)
    }

    @Test func ohneTokenKommtDasFotoAn() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.success(kontextMitFoto))
        let modell = modell(token: nil, loader: loader)

        await modell.kontextLaden()

        #expect(modell.kontext?.equipmentModel.photoUrl == "https://example.test/foto.jpg")
    }

    /// Ein Fehlschlag bleibt kein Fehlerzustand -- der Screen steht aus
    /// dem Prefetch.
    @Test func einFehlschlagLaesstDenScreenStehen() async {
        let loader = FakeGeraetLoader()
        await loader.setKontext(.failure(.offline))
        let modell = modell(token: nil, loader: loader)

        await modell.kontextLaden()

        #expect(modell.kontext == nil)
    }
}
