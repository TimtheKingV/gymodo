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
          "member": {"displayName": null, "goals": {"weeklyDays": null, "targetWeight": null}},
          "studios": [{"id":"s1","name":"Kraftwerk Nord","timezone":"Europe/Berlin"}],
          "machines": [{
            "id":"m1","studioId":"s1","label":"07","locationNote":null,"status":"active",
            "tokenHashes":["abc"],"visitCount":0,
            "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoPath":null,"category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":10,"loadMax":200,"secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null,"settingDefinitions":[]},
            "exercises":[{"id":"ex1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]
          }],
          "calibrations": [{"machineId":"m1","exerciseId":"ex1","settingValues":{"sitz":3},"schemaVersion":1,"createdAt":"2026-09-01T10:00:00Z"}],
          "lastSets": [{"machineId":"m1","exerciseId":"ex1","load":80,"secondaryLoad":null,"volume":10,"rir":2,"performedAt":"2026-09-01T10:05:00Z"}]
        }
        """
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        #expect(response.studios.count == 1)
        let modell = response.machines[0].equipmentModel
        #expect(modell.loadStep == 2.5)
        #expect(modell.loadUnit == .kg)
        #expect(modell.category == .kraft)
        // Die Gegenprobe aus Spec Abschnitt 9: an einem Kraftgeraet ist
        // alles, was zur Nebenbelastung gehoert, nil.
        #expect(modell.secondaryUnit == nil)
        #expect(modell.secondaryStep == nil)
        #expect(response.machines[0].exercises[0].volumeKind == .reps)
        #expect(response.lastSets[0].load == 80)
        #expect(response.lastSets[0].secondaryLoad == nil)
        #expect(response.lastSets[0].volume == 10)
        #expect(response.calibrations[0].settingValues == .object(["sitz": .number(3)]))
    }

    @Test func bootstrapDecodiertVisitCount() throws {
        let json = """
        {
          "member": {"displayName": null, "goals": {"weeklyDays": null, "targetWeight": null}},
          "studios": [],
          "machines": [{
            "id": "m1", "studioId": "s1", "label": "Gerät 7",
            "locationNote": null, "status": "active",
            "tokenHashes": ["abc"], "visitCount": 3,
            "equipmentModel": {
              "id": "em1", "name": "Beinpresse", "manufacturer": null,
              "photoPath": null, "category": "kraft", "loadUnit": "kg",
              "loadStep": 2.5, "loadMin": 5.0, "loadMax": 150.0,
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

    @Test("dekodiert ein Bootstrap ohne gesetzten Namen")
    func decodesMemberOhneNamen() throws {
        let json = #"{"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))

        #expect(response.member.displayName == nil)
    }

    @Test("dekodiert ein Member mit gesetzten Stammdaten, Zielen und Gewicht")
    func decodesMemberMitStammdatenUndZielen() throws {
        let json = """
        {
          "member": {
            "displayName": "Mia", "sex": "female", "ageBand": "25_34", "heightCm": 168,
            "trainingGoal": "lose_weight", "onboardingCompletedAt": "2026-09-01T10:00:00Z",
            "goals": {
              "weeklyDays": {"id":"g1","kind":"weekly_days","targetValue":3,"createdAt":"2026-09-01T10:00:00Z"},
              "targetWeight": {"id":"g2","kind":"target_weight","targetValue":75,"createdAt":"2026-09-01T10:00:00Z"}
            },
            "latestWeight": {"measuredOn":"2026-09-10","weightKg":82.5}
          },
          "studios": [], "machines": [], "calibrations": [], "lastSets": []
        }
        """
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))

        #expect(response.member.ageBand == "25_34")
        #expect(response.member.goals.weeklyDays?.targetValue == 3)
        #expect(response.member.latestWeight?.weightKg == 82.5)
    }

    @Test("dekodiert ein Member ohne Stammdaten und ohne Ziele")
    func decodesMemberOhneStammdaten() throws {
        let json = """
        {
          "member": {
            "displayName": null, "sex": null, "ageBand": null, "heightCm": null,
            "trainingGoal": null, "onboardingCompletedAt": null,
            "goals": {"weeklyDays": null, "targetWeight": null},
            "latestWeight": null
          },
          "studios": [], "machines": [], "calibrations": [], "lastSets": []
        }
        """
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))

        #expect(response.member.sex == nil)
        #expect(response.member.goals.weeklyDays == nil)
        #expect(response.member.goals.targetWeight == nil)
        #expect(response.member.latestWeight == nil)
    }

    @Test("dekodiert einen Serienstand ohne weeklyTarget (alter Cache)")
    func decodesSerienstandOhneWeeklyTarget() throws {
        let json = #"{"weeks":2,"weekStart":"2026-09-07","today":"2026-09-14","trainedDays":["2026-09-08"]}"#
        let serienstand = try JSONDecoder().decode(Serienstand.self, from: Data(json.utf8))

        #expect(serienstand.weeklyTarget == nil)
    }

    @Test("kodiert ProfilWrite mit Loeschen und Setzen, ohne unbeteiligte Felder")
    func encodesProfilWrite() throws {
        let write = ProfilWrite(heightCm: .loeschen, ageBand: .setzen("25_34"))
        let data = try JSONEncoder().encode(write)
        let json = String(data: data, encoding: .utf8)!

        #expect(json.contains(#""heightCm":null"#))
        #expect(json.contains(#""ageBand":"25_34""#))
        #expect(!json.contains("displayName"))
    }

    @Test("dekodiert einen TagContextResponse mit leerer Historie")
    func decodesTagContext() throws {
        let json = """
        {
          "machine":{"id":"m1","label":"07","locationNote":null},
          "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoUrl":null,"loadUnit":"kg","loadStep":2.5,"loadMin":10,"loadMax":200,"secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null},
          "settingDefinitions":[],
          "exercises":[{"id":"ex1","name":"Beidbeinig","description":null,"volumeKind":"reps","targetMin":8,"targetMax":12,"instructionVideoUrl":null}],
          "selectedExerciseId":"ex1",
          "calibration":null,
          "history":[],
          "suggestion":{"algoVersion":"2.0.0","resultLoad":null,"resultSecondaryLoad":null,"reasonCode":"kein_verlauf","inputs":{"targetMin":8,"targetMax":12,"loadStep":2.5,"loadMin":10,"loadMax":200,"currentLoad":null,"currentSecondaryLoad":null,"consideredBlocks":0}}
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
            load: 80, volume: 10, rir: 2,
            problemFlag: true, problemReason: .zuSchwer, performedAt: nil
        )
        let data = try JSONEncoder().encode(write)
        let decoded = try JSONDecoder().decode(SetWrite.self, from: data)
        #expect(decoded == write)
        #expect(decoded.problemReason == .zuSchwer)
    }

    @Test("SetWrite schreibt load und volume, nie die alten Namen")
    func setWriteSchreibtDieNeuenNamen() throws {
        let write = SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1, load: 80, volume: 10)
        let json = String(data: try JSONEncoder().encode(write), encoding: .utf8)!

        #expect(json.contains(#""load":80"#))
        #expect(json.contains(#""volume":10"#))
        #expect(!json.contains("weightKg"))
        #expect(!json.contains("reps"))
        // Ohne Nebenbelastung fehlt das Feld ganz: der Server weist ein
        // gesetztes secondaryLoad an einem Kraftgeraet ab (Spec 5.1).
        #expect(!json.contains("secondaryLoad"))
    }

    @Test("SetWrite traegt die Nebenbelastung, wenn es eine gibt")
    func setWriteMitNebenbelastung() throws {
        let write = SetWrite(machineId: "m1", exerciseId: "ex1", setIndex: 1,
                             load: 8.5, volume: 1200, secondaryLoad: 6)
        let json = String(data: try JSONEncoder().encode(write), encoding: .utf8)!

        #expect(json.contains(#""secondaryLoad":6"#))
        #expect(try JSONDecoder().decode(SetWrite.self, from: Data(json.utf8)) == write)
    }

    @Test("SetWrite liest einen Schreibvorgang mit den alten Namen")
    func setWriteLiestAlteNamen() throws {
        // So liegt ein Satz in pending-writes.json, den die Fassung vor
        // Migration 0046 offline gepuffert hat.
        let alt = #"{"machineId":"m1","exerciseId":"ex1","setIndex":2,"weightKg":82.5,"reps":9,"problemFlag":false,"performedAt":"2026-09-20T10:00:00Z"}"#
        let write = try JSONDecoder().decode(SetWrite.self, from: Data(alt.utf8))

        #expect(write.load == 82.5)
        #expect(write.volume == 9)
        #expect(write.secondaryLoad == nil)
        #expect(write.setIndex == 2)
        #expect(write.performedAt == "2026-09-20T10:00:00Z")
    }

    @Test("dekodiert ein Laufband im Bootstrap")
    func decodesBootstrapLaufband() throws {
        let json = """
        {
          "member": {"displayName": null, "goals": {"weeklyDays": null, "targetWeight": null}},
          "studios": [],
          "machines": [{
            "id":"m9","studioId":"s1","label":"Laufband 2","locationNote":null,"status":"active",
            "tokenHashes":[],"visitCount":1,
            "equipmentModel":{"id":"e9","name":"Laufband","manufacturer":null,"photoPath":null,
              "category":"cardio","loadUnit":"kmh","loadStep":0.5,"loadMin":0,"loadMax":20,
              "secondaryUnit":"pct","secondaryStep":0.5,"secondaryMin":0,"secondaryMax":15,
              "settingDefinitions":[]},
            "exercises":[{"id":"ex9","name":"Dauerlauf","volumeKind":"seconds","targetMin":900,"targetMax":1200}]
          }],
          "calibrations": [],
          "lastSets": [{"machineId":"m9","exerciseId":"ex9","load":8.5,"secondaryLoad":6,"volume":1200,"rir":null,"performedAt":"2026-09-20T10:05:00Z"}]
        }
        """
        let response = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        let modell = response.machines[0].equipmentModel

        #expect(modell.category == .cardio)
        #expect(modell.loadUnit == .kmh)
        #expect(modell.loadStep == 0.5)
        #expect(modell.secondaryUnit == .pct)
        #expect(modell.secondaryStep == 0.5)
        #expect(modell.secondaryMin == 0)
        #expect(modell.secondaryMax == 15)
        #expect(response.machines[0].exercises[0].volumeKind == .seconds)
        #expect(response.machines[0].exercises[0].targetMin == 900)
        #expect(response.lastSets[0].load == 8.5)
        #expect(response.lastSets[0].secondaryLoad == 6)
        #expect(response.lastSets[0].volume == 1200)
    }

    @Test("dekodiert ein Laufband im Tag-Kontext")
    func decodesTagContextLaufband() throws {
        let json = """
        {
          "machine":{"id":"m9","label":"Laufband 2","locationNote":null},
          "equipmentModel":{"id":"e9","name":"Laufband","manufacturer":null,"photoUrl":null,
            "loadUnit":"kmh","loadStep":0.5,"loadMin":0,"loadMax":20,
            "secondaryUnit":"pct","secondaryStep":0.5,"secondaryMin":0,"secondaryMax":15},
          "settingDefinitions":[],
          "exercises":[{"id":"ex9","name":"Dauerlauf","description":null,"volumeKind":"seconds","targetMin":900,"targetMax":1200,"instructionVideoUrl":null}],
          "selectedExerciseId":"ex9",
          "calibration":null,
          "history":[{"performedOn":"2026-09-20","load":8.5,"secondaryLoad":6,"volume":[1200]}],
          "suggestion":{"algoVersion":"2.0.0","resultLoad":9,"resultSecondaryLoad":6,"reasonCode":"korridor_oben_erreicht","inputs":{"targetMin":900,"targetMax":1200,"loadStep":0.5,"loadMin":0,"loadMax":20,"currentLoad":8.5,"currentSecondaryLoad":6,"consideredBlocks":2}}
        }
        """
        let response = try JSONDecoder().decode(TagContextResponse.self, from: Data(json.utf8))

        #expect(response.equipmentModel.loadUnit == .kmh)
        #expect(response.equipmentModel.secondaryUnit == .pct)
        #expect(response.exercises[0].volumeKind == .seconds)
        #expect(response.history[0].load == 8.5)
        #expect(response.history[0].secondaryLoad == 6)
        #expect(response.history[0].volume == [1200])
        #expect(response.suggestion.resultLoad == 9)
        #expect(response.suggestion.resultSecondaryLoad == 6)
        #expect(response.suggestion.inputs.currentLoad == 8.5)
        #expect(response.suggestion.inputs.currentSecondaryLoad == 6)
    }

    @Test("eine unbekannte Belastungseinheit laesst das Bootstrap scheitern")
    func bootstrapMitUnbekannterEinheitScheitert() {
        // Kein stilles "kg": ein Rad in der falschen Einheit waere
        // schlimmer als ein Prefetch, der auf das App-Update wartet.
        let json = """
        {"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],
         "machines":[{"id":"m1","studioId":"s1","label":"07","locationNote":null,"status":"active","tokenHashes":[],"visitCount":0,
           "equipmentModel":{"id":"e1","name":"Skierg","manufacturer":null,"photoPath":null,"category":"cardio","loadUnit":"spm","loadStep":1,"loadMin":0,"loadMax":60,"settingDefinitions":[]},
           "exercises":[]}],
         "calibrations":[],"lastSets":[]}
        """
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        }
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
        {"sessions":[{"id":"sess1","startedAt":"2026-09-01T10:00:00Z","completedAt":null,"completedReason":null,"machineCount":1,"setCount":1,"blocks":[{"machineId":"m1","machineLabel":"07","exerciseId":"ex1","exerciseName":"Beidbeinig","loadUnit":"kg","secondaryUnit":null,"volumeKind":"reps","sets":[{"setIndex":1,"load":80,"secondaryLoad":null,"volume":10,"rir":null,"problemFlag":false,"problemReason":null,"performedAt":"2026-09-01T10:05:00Z"}]}]}],"summary":{"totalCount":34,"thisWeekCount":2,"lastSessionAt":"2026-09-01T10:00:00Z"}}
        """
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))
        #expect(response.sessions[0].blocks[0].sets[0].load == 80)
        #expect(response.sessions[0].blocks[0].loadUnit == .kg)
        #expect(response.sessions[0].blocks[0].volumeKind == .reps)
        #expect(response.summary.totalCount == 34)
    }

    @Test("dekodiert eine ProgressResponse mit Geraetelabel")
    func decodesProgress() throws {
        let json = """
        {"exercises":[{"exerciseId":"u1","exerciseName":"Beidbeinig","machineLabel":"Beinpresse","loadUnit":"kg","volumeKind":"reps","firstLoad":65,"currentLoad":80,"changeLoad":15,"points":[{"performedOn":"2026-07-09","topLoad":65,"volume":12},{"performedOn":"2026-08-27","topLoad":80,"volume":10}]}]}
        """
        let response = try JSONDecoder().decode(ProgressResponse.self, from: Data(json.utf8))

        #expect(response.exercises[0].machineLabel == "Beinpresse")
        #expect(response.exercises[0].changeLoad == 15)
        #expect(response.exercises[0].loadUnit == .kg)
        #expect(response.exercises[0].points[0].topLoad == 65)
        #expect(response.exercises[0].points.count == 2)
    }

    @Test("eine Kopfzeile ohne aktives Studio traegt keine Wochenzahl")
    func decodesSummaryOhneWoche() throws {
        let json = #"{"sessions":[],"summary":{"totalCount":0,"thisWeekCount":null,"lastSessionAt":null}}"#
        let response = try JSONDecoder().decode(SessionsResponse.self, from: Data(json.utf8))

        #expect(response.summary.thisWeekCount == nil)
        #expect(response.summary.lastSessionAt == nil)
    }

    @Test func dekodiertGeraetefotos() throws {
        let json = #"{"photos":[{"equipmentModelId":"em1","url":"https://example.test/a.jpg"}]}"#
        let response = try JSONDecoder().decode(MachinePhotosResponse.self, from: Data(json.utf8))

        #expect(response.photos.count == 1)
        #expect(response.photos[0].equipmentModelId == "em1")
        #expect(response.photos[0].url == "https://example.test/a.jpg")

        let leer = try JSONDecoder().decode(MachinePhotosResponse.self, from: Data(#"{"photos":[]}"#.utf8))
        #expect(leer.photos.isEmpty)
    }

    @Test func completedSessionDecodiertVorschlaege() throws {
        let json = """
        {
          "id": "s1", "startedAt": "2026-09-08T18:04:00Z",
          "completedAt": "2026-09-08T18:51:00Z", "completedReason": "manual",
          "vorschlaege": [
            { "machineId": "m1", "exerciseId": "e1", "resultLoad": 82.5,
              "deltaLoad": 2.5, "secondaryLoad": null, "loadUnit": "kg",
              "secondaryUnit": null, "reasonCode": "korridor_oben_erreicht",
              "algoVersion": "2.0.0" },
            { "machineId": "m2", "exerciseId": "e2", "resultLoad": null,
              "deltaLoad": null, "secondaryLoad": null, "loadUnit": "kg",
              "secondaryUnit": null, "reasonCode": "problem_gemeldet",
              "algoVersion": "2.0.0" },
            { "machineId": "m9", "exerciseId": "e9", "resultLoad": 9,
              "deltaLoad": 0.5, "secondaryLoad": 6, "loadUnit": "kmh",
              "secondaryUnit": "pct", "reasonCode": "korridor_oben_erreicht",
              "algoVersion": "2.0.0" }
          ]
        }
        """.data(using: .utf8)!

        let beendet = try JSONDecoder().decode(CompletedSession.self, from: json)

        #expect(beendet.vorschlaege.count == 3)
        #expect(beendet.vorschlaege[0].deltaLoad == 2.5)
        #expect(beendet.vorschlaege[0].loadUnit == .kg)
        // Kein Vorschlag heisst: beide Zahlen fehlen, der Grund bleibt.
        #expect(beendet.vorschlaege[1].deltaLoad == nil)
        #expect(beendet.vorschlaege[1].reasonCode == "problem_gemeldet")
        // Das Laufband bringt seine Einheiten mit -- der Abschluss schreibt
        // "+0,5 km/h bei 6,0 %", ohne das Modell nachzuschlagen.
        #expect(beendet.vorschlaege[2].loadUnit == .kmh)
        #expect(beendet.vorschlaege[2].secondaryLoad == 6)
        #expect(beendet.vorschlaege[2].secondaryUnit == .pct)
    }

    // MARK: - Gymtavo-Katalog (Etappe 4)

    private static let bootstrapRumpf = """
    "member": {"displayName": null, "goals": {"weeklyDays": null, "targetWeight": null}},
    "studios": [], "machines": [], "calibrations": [], "lastSets": []
    """

    @Test("Bootstrap ohne catalog und lastTypeSets (altes JSON) dekodiert")
    func bootstrapOhneKatalog() throws {
        let json = "{\(Self.bootstrapRumpf)}"
        let b = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        #expect(b.catalog == nil)
        #expect(b.lastTypeSets.isEmpty)
    }

    @Test("Bootstrap mit catalog und lastTypeSets dekodiert")
    func bootstrapMitKatalog() throws {
        let json = """
        {
          "member": {"displayName": null, "goals": {"weeklyDays": null, "targetWeight": null}},
          "studios": [], "calibrations": [], "lastSets": [],
          "machines": [{"id":"m1","studioId":"s1","label":"07","locationNote":null,"status":"active","tokenHashes":[],"visitCount":0,
            "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoPath":null,"category":"kraft","loadUnit":"kg","loadStep":2.5,"loadMin":10,"loadMax":200,"secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null,"settingDefinitions":[],"catalogModelId":"t1"},
            "exercises":[]}],
          "catalog": {"studioId":"s1","equipmentTypes":[{
            "id":"t1","name":"Beinpresse","manufacturer":"Gymtavo","photoPath":null,"category":"kraft",
            "loadUnit":"kg","loadStep":2.5,"loadMin":10,"loadMax":200,
            "secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null,
            "settingDefinitions":[],
            "exercises":[{"id":"ex1","name":"Beidbeinig","volumeKind":"reps","targetMin":8,"targetMax":12}]
          }]},
          "lastTypeSets": [{"equipmentModelId":"t1","exerciseId":"ex1","load":80,"secondaryLoad":null,"volume":10,"rir":2,"performedAt":"2026-09-01T10:05:00Z"}]
        }
        """
        let b = try JSONDecoder().decode(BootstrapResponse.self, from: Data(json.utf8))
        #expect(b.catalog?.studioId == "s1")
        #expect(b.catalog?.equipmentTypes[0].exercises[0].targetMax == 12)
        #expect(b.catalog?.equipmentTypes[0].loadUnit == .kg)
        #expect(b.lastTypeSets[0].equipmentModelId == "t1")
        #expect(b.lastTypeSets[0].load == 80)
        #expect(b.machines[0].equipmentModel.catalogModelId == "t1")
    }

    @Test("Typ-Kontext mit machine null dekodiert")
    func typKontextOhneGeraet() throws {
        let json = """
        {
          "machine": null,
          "equipmentModel":{"id":"e1","name":"Beinpresse","manufacturer":null,"photoUrl":null,"loadUnit":"kg","loadStep":2.5,"loadMin":10,"loadMax":200,"secondaryUnit":null,"secondaryStep":null,"secondaryMin":null,"secondaryMax":null},
          "settingDefinitions":[], "exercises":[], "selectedExerciseId":null, "calibration":null, "history":[],
          "suggestion":{"algoVersion":"2.0.0","resultLoad":null,"resultSecondaryLoad":null,"reasonCode":"kein_verlauf","inputs":{"targetMin":8,"targetMax":12,"loadStep":2.5,"loadMin":10,"loadMax":200,"currentLoad":null,"currentSecondaryLoad":null,"consideredBlocks":0}}
        }
        """
        let r = try JSONDecoder().decode(TagContextResponse.self, from: Data(json.utf8))
        #expect(r.machine == nil)
    }

    @Test("SetWrite am Typ kodiert ohne machineId, mit equipmentModelId und studioId")
    func setWriteAmTyp() throws {
        let w = SetWrite(equipmentModelId: "t1", studioId: "s1", exerciseId: "ex1", setIndex: 1, load: 80, volume: 10)
        let json = String(data: try JSONEncoder().encode(w), encoding: .utf8)!
        #expect(!json.contains("machineId"))
        #expect(json.contains(#""equipmentModelId":"t1""#))
        #expect(json.contains(#""studioId":"s1""#))
        #expect(try JSONDecoder().decode(SetWrite.self, from: Data(json.utf8)) == w)
    }

    @Test("SetWrite im Freien Training traegt auch keine studioId")
    func setWriteFreiesTraining() throws {
        let w = SetWrite(equipmentModelId: "t1", exerciseId: "ex1", setIndex: 1, load: 80, volume: 10)
        let json = String(data: try JSONEncoder().encode(w), encoding: .utf8)!
        #expect(!json.contains("machineId"))
        #expect(!json.contains("studioId"))
        #expect(json.contains("equipmentModelId"))
    }

    @Test("Altes PendingSetWrite-JSON mit machineId und weightKg/reps dekodiert weiter")
    func altesPendingJson() throws {
        let alt = #"{"machineId":"m1","exerciseId":"ex1","setIndex":2,"weightKg":82.5,"reps":9,"problemFlag":false}"#
        let w = try JSONDecoder().decode(SetWrite.self, from: Data(alt.utf8))
        #expect(w.machineId == "m1")
        #expect(w.equipmentModelId == nil)
        #expect(w.studioId == nil)
        #expect(w.load == 82.5)
        #expect(w.volume == 9)
    }

    @Test("SessionSummary aus altem verlauf.json ohne equipmentModelId dekodiert")
    func altesVerlaufJson() throws {
        let json = #"{"id":"sess1","startedAt":"2026-09-01T10:00:00Z","completedAt":null,"completedReason":null,"machineCount":1,"setCount":1,"blocks":[{"machineId":"m1","machineLabel":"07","exerciseId":"ex1","exerciseName":"Beidbeinig","loadUnit":"kg","secondaryUnit":null,"volumeKind":"reps","sets":[]}]}"#
        let s = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(s.blocks[0].machineId == "m1")
        #expect(s.blocks[0].equipmentModelId == nil)
    }

    @Test("Block mit machineId null und equipmentModelId dekodiert")
    func blockOhneGeraet() throws {
        let json = #"{"id":"sess1","startedAt":"2026-09-01T10:00:00Z","completedAt":null,"completedReason":null,"machineCount":0,"setCount":1,"blocks":[{"machineId":null,"equipmentModelId":"t1","machineLabel":"Beinpresse","exerciseId":"ex1","exerciseName":"Beidbeinig","loadUnit":"kg","secondaryUnit":null,"volumeKind":"reps","sets":[]}]}"#
        let s = try JSONDecoder().decode(SessionSummary.self, from: Data(json.utf8))
        #expect(s.blocks[0].machineId == nil)
        #expect(s.blocks[0].equipmentModelId == "t1")
    }

    @Test("CompletedSession mit vorschlaege machineId null dekodiert")
    func vorschlagOhneGeraet() throws {
        let json = #"{"id":"s1","startedAt":"2026-09-08T18:04:00Z","completedAt":"2026-09-08T18:51:00Z","completedReason":"manual","vorschlaege":[{"machineId":null,"equipmentModelId":"t1","exerciseId":"e1","resultLoad":82.5,"deltaLoad":2.5,"secondaryLoad":null,"loadUnit":"kg","secondaryUnit":null,"reasonCode":"korridor_oben_erreicht","algoVersion":"2.0.0"}]}"#
        let c = try JSONDecoder().decode(CompletedSession.self, from: Data(json.utf8))
        #expect(c.vorschlaege[0].machineId == nil)
        #expect(c.vorschlaege[0].equipmentModelId == "t1")
    }
}
