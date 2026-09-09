import Foundation
import Testing
@testable import FitnessMember

@Suite("JSONValue")
struct JSONValueTests {
    @Test("dekodiert und kodiert ein gemischtes Objekt verlustfrei")
    func roundTrips() throws {
        let json = #"{"sitz": 3, "aktiv": true, "label": "hoch", "leer": null, "liste": [1, 2]}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        guard case .object(let fields) = value else {
            Issue.record("erwartet .object")
            return
        }
        #expect(fields["sitz"] == .number(3))
        #expect(fields["aktiv"] == .bool(true))
        #expect(fields["label"] == .string("hoch"))
        #expect(fields["leer"] == .null)
        #expect(fields["liste"] == .array([.number(1), .number(2)]))

        let reencoded = try JSONEncoder().encode(value)
        let redecoded = try JSONDecoder().decode(JSONValue.self, from: reencoded)
        #expect(redecoded == value)
    }
}

@Suite("DTOs")
struct DTOTests {
    @Test("dekodiert eine minimale BootstrapResponse")
    func decodesBootstrap() throws {
        let json = """
        {
          "studios": [{"id":"s1","name":"Kraftwerk Nord","timezone":"Europe/Berlin"}],
          "machines": [{
            "id":"m1","studioId":"s1","label":"07","locationNote":null,"status":"active",
            "tokenHashes":["abc"],"visitCount":0,
            "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoPath":null,"weightStepKg":2.5,"minWeightKg":10,"maxWeightKg":200,"settingDefinitions":[]},
            "exercises":[{"id":"ex1","name":"Beidbeinig","targetRepsMin":8,"targetRepsMax":12}]
          }],
          "calibrations": [{"machineId":"m1","exerciseId":"ex1","settingValues":{"sitz":3},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}],
          "lastSets": [{"machineId":"m1","exerciseId":"ex1","weightKg":80,"reps":10,"rir":2,"performedAt":"2026-09-01T10:05:00Z"}]
        }
        """
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        #expect(response.studios.count == 1)
        #expect(response.machines[0].equipmentModel.weightStepKg == 2.5)
        #expect(response.calibrations[0].settingValues == .object(["sitz": .number(3)]))
    }

    @Test func bootstrapDecodiertVisitCount() throws {
        let json = """
        {
          "studios": [],
          "machines": [{
            "id": "m1", "studioId": "s1", "label": "Gerät 7",
            "locationNote": null, "status": "active",
            "tokenHashes": ["abc"], "visitCount": 3,
            "equipmentModel": {
              "id": "em1", "name": "Beinpresse", "manufacturer": null,
              "photoPath": null, "weightStepKg": 2.5,
              "minWeightKg": 5.0, "maxWeightKg": 150.0,
              "settingDefinitions": [{
                "key": "sitz", "label": "Sitzposition", "kind": "number",
                "minValue": 1, "maxValue": 8, "stepValue": 1,
                "unit": null, "allowedValues": null
              }]
            },
            "exercises": []
          }],
          "calibrations": [],
          "lastSets": []
        }
        """.data(using: .utf8)!

        let bootstrap = try JSONDecoder().decode(BootstrapResponse.self, from: json)

        #expect(bootstrap.machines[0].visitCount == 3)
        // Ohne die Beschriftung zeigt der Offline-Zustand "sitz 4" statt "Sitz 4".
        #expect(bootstrap.machines[0].equipmentModel.settingDefinitions.first?.label == "Sitzposition")
    }

    @Test("dekodiert einen TagContextResponse mit leerer Historie")
    func decodesTagContext() throws {
        let json = """
        {
          "machine":{"id":"m1","label":"07","locationNote":null},
          "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoUrl":null,"weightStepKg":2.5,"minWeightKg":10,"maxWeightKg":200},
          "settingDefinitions":[],
          "exercises":[{"id":"ex1","name":"Beidbeinig","description":null,"targetRepsMin":8,"targetRepsMax":12,"instructionVideoUrl":null}],
          "selectedExerciseId":"ex1",
          "calibration":null,
          "history":[],
          "suggestion":{"algoVersion":"1.0.0","resultWeightKg":null,"reasonCode":"kein_verlauf","inputs":{"targetRepsMin":8,"targetRepsMax":12,"weightStepKg":2.5,"minWeightKg":10,"maxWeightKg":200,"currentWeightKg":null,"consideredBlocks":0}}
        }
        """
        let response = try JSONDecoder().decode(TagContextResponse.self, from: Data(json.utf8))
        #expect(response.suggestion.reasonCode == "kein_verlauf")
        #expect(response.calibration == nil)
    }

    @Test("kodiert SetWrite mit Problemmeldung")
    func encodesSetWriteWithProblem() throws {
        let write = SetWrite(
            machineId: "m1", exerciseId: "ex1", setIndex: 1,
            weightKg: 80, reps: 10, rir: 2,
            problemFlag: true, problemReason: .zuSchwer, performedAt: nil
        )
        let data = try JSONEncoder().encode(write)
        let decoded = try JSONDecoder().decode(SetWrite.self, from: data)
        #expect(decoded == write)
        #expect(decoded.problemReason == .zuSchwer)
    }

    @Test("dekodiert die Fehlerhuelle")
    func decodesErrorEnvelope() throws {
        let json = #"{"error":{"code":"validation_failed","message":"Der Rumpf ist kein gueltiges JSON."}}"#
        let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: Data(json.utf8))
        #expect(envelope.error.code == "validation_failed")
    }

    @Test("dekodiert eine SessionsResponse mit einem Block")
    func decodesSessions() throws {
        let json = """
        {"sessions":[{"id":"sess1","startedAt":"2026-09-01T10:00:00Z","completedAt":null,"completedReason":null,"machineCount":1,"setCount":1,"blocks":[{"machineId":"m1","machineLabel":"07","exerciseId":"ex1","exerciseName":"Beidbeinig","sets":[{"setIndex":1,"weightKg":80,"reps":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:05:00Z"}]}]}],"summary":{"totalCount":34,"thisWeekCount":2,"lastSessionAt":"2026-09-01T10:00:00Z"}}
        """
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))
        #expect(response.sessions[0].blocks[0].sets[0].weightKg == 80)
        #expect(response.summary.totalCount == 34)
    }

    @Test("eine Kopfzeile ohne aktives Studio traegt keine Wochenzahl")
    func decodesSummaryOhneWoche() throws {
        let json = #"{"sessions":[],"summary":{"totalCount":0,"thisWeekCount":null,"lastSessionAt":null}}"#
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))

        #expect(response.summary.thisWeekCount == nil)
        #expect(response.summary.lastSessionAt == nil)
    }

    @Test func completedSessionDecodiertVorschlaege() throws {
        let json = """
        {
          "id": "s1", "startedAt": "2026-09-08T18:04:00Z",
          "completedAt": "2026-09-08T18:51:00Z", "completedReason": "manual",
          "vorschlaege": [
            { "machineId": "m1", "exerciseId": "e1", "resultWeightKg": 82.5,
              "deltaKg": 2.5, "reasonCode": "korridor_oben_erreicht",
              "algoVersion": "v1" },
            { "machineId": "m2", "exerciseId": "e2", "resultWeightKg": null,
              "deltaKg": null, "reasonCode": "problem_gemeldet",
              "algoVersion": "v1" }
          ]
        }
        """.data(using: .utf8)!

        let beendet = try JSONDecoder().decode(CompletedSession.self, from: json)

        #expect(beendet.vorschlaege.count == 2)
        #expect(beendet.vorschlaege[0].deltaKg == 2.5)
        // Kein Vorschlag heisst: beide Zahlen fehlen, der Grund bleibt.
        #expect(beendet.vorschlaege[1].deltaKg == nil)
        #expect(beendet.vorschlaege[1].reasonCode == "problem_gemeldet")
    }
}
