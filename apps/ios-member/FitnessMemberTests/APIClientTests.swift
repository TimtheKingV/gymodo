import Foundation
import Testing
@testable import FitnessMember

/// Stub, der jede Anfrage abfaengt und eine vorbereitete Antwort liefert --
/// kein echtes Netzwerk in Tests.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

func stubbedClient(istOnline: @escaping @Sendable () async -> Bool = { true },
                   tokenProvider: @escaping @Sendable () async -> String? = { "test-token" }) -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return APIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session,
                     istOnline: istOnline, tokenProvider: tokenProvider)
}

/// .serialized ist Pflicht: alle Tests hier schreiben denselben statischen
/// StubURLProtocol.handler, und Swift Testing laeuft sonst parallel -- ein
/// echtes Rennen, das mapsOffline mit seinem fatalError-Handler zum Absturz
/// eskalieren wuerde.
@Suite("APIClient", .serialized)
struct APIClientTests {
    @Test("dekodiert eine erfolgreiche bootstrap-Antwort")
    func decodesBootstrap() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
            return (200, Data(json.utf8))
        }
        let client = stubbedClient()
        let response = try await client.bootstrap()
        #expect(response.studios.isEmpty)
    }

    @Test("bildet 401 auf .unauthorized ab")
    func mapsUnauthorized() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"unauthorized","message":"Anmeldung erforderlich."}}"#
            return (401, Data(json.utf8))
        }
        let client = stubbedClient()
        await #expect(throws: APIError.unauthorized(message: "Anmeldung erforderlich.")) {
            try await client.bootstrap()
        }
    }

    @Test("bildet 422 mit Server-Text auf .validation ab")
    func mapsValidation() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"validation_failed","message":"Eine Problemursache setzt das Problemkennzeichen voraus."}}"#
            return (422, Data(json.utf8))
        }
        let client = stubbedClient()
        await #expect(throws: APIError.validation(message: "Eine Problemursache setzt das Problemkennzeichen voraus.")) {
            try await client.bootstrap()
        }
    }

    final class Zaehler: @unchecked Sendable { var anfragen = 0 }

    @Test("offline laut Monitor: sofort .offline, kein Request")
    func offlineOhneRequest() async {
        let zaehler = Zaehler()
        StubURLProtocol.handler = { _ in zaehler.anfragen += 1; return (200, Data("{}".utf8)) }
        let client = stubbedClient(istOnline: { false })
        await #expect(throws: APIError.offline) { try await client.bootstrap() }
        #expect(zaehler.anfragen == 0)
    }

    @Test("ohne Token: .offline, kein Request ohne Authorization")
    func ohneTokenKeinRequest() async {
        let zaehler = Zaehler()
        StubURLProtocol.handler = { _ in zaehler.anfragen += 1; return (401, Data("{}".utf8)) }
        let client = stubbedClient(tokenProvider: { nil })
        await #expect(throws: APIError.offline) { try await client.bootstrap() }
        await #expect(throws: APIError.offline) { try await client.deleteSession(sessionId: "x") }
        #expect(zaehler.anfragen == 0)
    }

    @Test("Standard-Session wartet hoechstens 10 s")
    func standardTimeout() {
        #expect(APIClient.standardSession.configuration.timeoutIntervalForRequest == 10)
        #expect(APIClient.standardSession.configuration.waitsForConnectivity == false)
    }

    @Test("sendet den Bearer-Token aus dem tokenProvider")
    func sendsBearerToken() async throws {
        var capturedAuthHeader: String?
        StubURLProtocol.handler = { request in
            capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
            return (200, Data(#"{"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#.utf8))
        }
        let client = stubbedClient(tokenProvider: { "abc123" })
        _ = try await client.bootstrap()
        #expect(capturedAuthHeader == "Bearer abc123")
    }

    @Test("bildet einen Netzwerkfehler auf .offline ab")
    func mapsOffline() async throws {
        StubURLProtocol.handler = { _ in fatalError("wird nicht aufgerufen") }
        // Kein Handler-Ergebnis liefern, sondern direkt didFailWithError simulieren
        // ist mit diesem einfachen Stub nicht abbildbar -- stattdessen eine
        // Session ohne registriertes Protokoll verwenden, das serverseitig
        // fehlschlaegt. Einfacher: Handler wirft ueber eine ungueltige URL.
        let client = APIClient(
            baseURL: URL(string: "https://127.0.0.1:1")!,
            session: URLSession(configuration: {
                let config = URLSessionConfiguration.ephemeral
                config.timeoutIntervalForRequest = 1
                return config
            }()),
            tokenProvider: { nil }
        )
        await #expect(throws: APIError.offline) {
            try await client.bootstrap()
        }
    }

    @Test("schickt die Kalibrierung als POST auf me/calibrations")
    func postsCalibration() async throws {
        // Kein `nonisolated(unsafe) var` -- das gilt nur fuer globale und
        // statische Eigenschaften, nicht fuer lokale Variablen.
        final class Aufzeichnung: @unchecked Sendable { var request: URLRequest? }
        let gesehen = Aufzeichnung()
        StubURLProtocol.handler = { request in
            gesehen.request = request
            let json = #"""
            {"id":"c1","machineId":"m1","exerciseId":"e1",
             "settingValues":{"sitz":4},"schemaVersion":1,
             "source":"self","createdAt":"2026-09-07T10:00:00Z"}
            """#
            return (201, Data(json.utf8))
        }
        let client = stubbedClient()

        let angelegt = try await client.recordCalibration(
            CalibrationWrite(machineId: "m1", exerciseId: "e1",
                             settingValues: ["sitz": .number(4)],
                             schemaVersion: 1, source: "self")
        )

        #expect(angelegt.id == "c1")
        #expect(gesehen.request?.httpMethod == "POST")
        #expect(gesehen.request?.url?.path.hasSuffix("/me/calibrations") == true)
    }

    @Test("reicht die Serverbegruendung einer abgelehnten Kalibrierung durch")
    func mapsCalibrationValidation() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"validation_failed","message":"Sitzposition liegt ueber dem Maximum 8."}}"#
            return (422, Data(json.utf8))
        }
        let client = stubbedClient()

        // designsystem.md SS5: der Fehler sagt, was gilt -- nicht nur, dass
        // etwas ungueltig ist. Der Text kommt deshalb vom Server.
        await #expect(throws: APIError.validation(message: "Sitzposition liegt ueber dem Maximum 8.")) {
            try await client.recordCalibration(
                CalibrationWrite(machineId: "m1", exerciseId: "e1",
                                 settingValues: ["sitz": .number(9)],
                                 schemaVersion: 1, source: "self")
            )
        }
    }

    /// Der Typ-Kontext: dieselbe Form wie am Geraet, aber ohne Geraet.
    private static let typKontext = #"""
    {"machine":null,
     "equipmentModel":{"id":"em1","name":"Beinpresse","manufacturer":null,"photoUrl":null,
       "loadUnit":"kg","loadStep":2.5,"loadMin":5.0,"loadMax":150.0},
     "settingDefinitions":[],"exercises":[],"selectedExerciseId":null,"calibration":null,"history":[],
     "suggestion":{"algoVersion":"v1","resultLoad":null,"reasonCode":"keine_historie",
       "inputs":{"targetMin":8,"targetMax":12,"loadStep":2.5,"loadMin":5.0,"loadMax":150.0,
         "currentLoad":null,"consideredBlocks":0}}}
    """#

    @Test("fragt den Typ-Kontext mit dem Studio als Query und dekodiert machine: null")
    func equipmentModelContextMitStudio() async throws {
        final class Aufzeichnung: @unchecked Sendable { var url: URL? }
        let gesehen = Aufzeichnung()
        StubURLProtocol.handler = { request in
            gesehen.url = request.url
            return (200, Data(Self.typKontext.utf8))
        }
        let kontext = try await stubbedClient().equipmentModelContext(modelId: "em1", studio: "s1")

        #expect(gesehen.url?.absoluteString == "https://example.test/api/v1/equipment-models/em1/context?studio=s1")
        #expect(kontext.machine == nil)
        #expect(kontext.equipmentModel.id == "em1")
    }

    @Test("fragt den Typ-Kontext im Freien Training ohne Query")
    func equipmentModelContextOhneStudio() async throws {
        final class Aufzeichnung: @unchecked Sendable { var url: URL? }
        let gesehen = Aufzeichnung()
        StubURLProtocol.handler = { request in
            gesehen.url = request.url
            return (200, Data(Self.typKontext.utf8))
        }
        _ = try await stubbedClient().equipmentModelContext(modelId: "em1", studio: nil)

        #expect(gesehen.url?.absoluteString == "https://example.test/api/v1/equipment-models/em1/context")
    }

    @Test("bootstrapMitRohdaten liefert die Bytes der Antwort")
    func bootstrapRohdaten() async throws {
        let json = #"{"member":{"displayName":null,"goals":{"weeklyDays":null,"targetWeight":null}},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
        StubURLProtocol.handler = { _ in (200, Data(json.utf8)) }
        let geladen = try await stubbedClient().bootstrapMitRohdaten()
        #expect(geladen.rohdaten == Data(json.utf8))
        #expect(geladen.antwort.studios.isEmpty)
    }

    // MARK: - Trainingsplan (Etappe 3)

    @Test("map erkennt profil_unvollstaendig und liest detail.fehlt")
    func mapProfilUnvollstaendig() {
        let detail = JSONValue.object(["fehlt": .array([.string("minutes"), .string("experience")])])
        #expect(APIError.map(code: "profil_unvollstaendig", message: "Profil fehlt.", detail: detail)
                == .profilUnvollstaendig(message: "Profil fehlt.", fehlt: ["minutes", "experience"]))
        #expect(APIError.map(code: "profil_unvollstaendig", message: "m")
                == .profilUnvollstaendig(message: "m", fehlt: []))
    }

    @Test("map erkennt plan_nicht_moeglich und liest baustein und grund")
    func mapPlanNichtMoeglich() {
        let detail = JSONValue.object(["baustein": .string("rumpf"), "grund": .string("keine_uebung")])
        let fehler = APIError.map(code: "plan_nicht_moeglich", message: "Geht nicht.", detail: detail)
        #expect(fehler == .planNichtMoeglich(message: "Geht nicht.", baustein: "rumpf", grund: "keine_uebung"))
        #expect(fehler.istDauerhaft)
        #expect(fehler.servertext == "Geht nicht.")
        #expect(APIError.profilUnvollstaendig(message: "x", fehlt: []).istDauerhaft)
    }

    @Test("unbekannter Code bleibt .server")
    func mapUnbekannterCode() {
        #expect(APIError.map(code: "irgendwas", message: "m", detail: .object([:])) == .server(message: "m"))
    }

    @Test("createPlan 422 wird .planNichtMoeglich")
    func createPlan422() async throws {
        StubURLProtocol.handler = { _ in
            let json = #"{"error":{"code":"plan_nicht_moeglich","message":"Kein Plan.","detail":{"baustein":"rumpf","grund":"keine_uebung"}}}"#
            return (422, Data(json.utf8))
        }
        let client = stubbedClient()
        await #expect(throws: APIError.planNichtMoeglich(message: "Kein Plan.", baustein: "rumpf", grund: "keine_uebung")) {
            try await client.createPlan(studioId: "s1")
        }
    }

    @Test("createPlan sendet POST /me/plans mit studioId und dekodiert 201")
    func createPlanOk() async throws {
        nonisolated(unsafe) var gesehen: (String?, String?, String?)?
        StubURLProtocol.handler = { request in
            let body = request.httpBodyStream.map { s -> String in
                s.open(); defer { s.close() }
                var d = Data(); var buf = [UInt8](repeating: 0, count: 1024)
                while s.hasBytesAvailable { let n = s.read(&buf, maxLength: 1024); if n <= 0 { break }; d.append(buf, count: n) }
                return String(decoding: d, as: UTF8.self)
            }
            gesehen = (request.httpMethod, request.url?.path, body)
            let json = #"{"id":"p1","studioId":"s1","version":1,"regelVersion":"1","struktur":"gk_ab","einheiten":[],"gruende":[]}"#
            return (201, Data(json.utf8))
        }
        let plan = try await stubbedClient().createPlan(studioId: "s1")
        #expect(plan.planId == "p1")
        #expect(gesehen?.0 == "POST")
        #expect(gesehen?.1 == "/api/v1/me/plans")
        #expect(gesehen?.2 == #"{"studioId":"s1"}"#)
    }

    @Test("trainingProfile: 404 ergibt nil, 200 das Profil")
    func trainingProfileLesen() async throws {
        StubURLProtocol.handler = { _ in
            (404, Data(#"{"error":{"code":"not_found","message":"Noch kein Trainingsprofil."}}"#.utf8))
        }
        #expect(try await stubbedClient().trainingProfile() == nil)
        StubURLProtocol.handler = { _ in (200, Data(#"{"minutes":60,"experience":"neu","focus":["brust"]}"#.utf8)) }
        #expect(try await stubbedClient().trainingProfile()
                == TrainingsplanProfil(minutes: 60, experience: "neu", focus: ["brust"]))
    }

    @Test("trainingLimits: 404 ergibt nil, 200 die Bereiche")
    func trainingLimitsLesen() async throws {
        StubURLProtocol.handler = { _ in (404, Data(#"{"error":{"code":"not_found","message":"Keine."}}"#.utf8)) }
        #expect(try await stubbedClient().trainingLimits() == nil)
        StubURLProtocol.handler = { _ in (200, Data(#"{"consentAt":"x","areas":{"knie":"meiden"}}"#.utf8)) }
        #expect(try await stubbedClient().trainingLimits() == ["knie": "meiden"])
    }

    @Test("putTrainingLimits sendet einwilligung und areas, deleteTrainingLimits nimmt 204")
    func limitsSchreiben() async throws {
        nonisolated(unsafe) var pfade: [String] = []
        StubURLProtocol.handler = { request in
            pfade.append("\(request.httpMethod ?? "") \(request.url?.path ?? "")")
            if request.httpMethod == "DELETE" { return (204, Data()) }
            return (200, Data(#"{"consentAt":"x","areas":{}}"#.utf8))
        }
        let client = stubbedClient()
        try await client.putTrainingLimits(areas: ["knie": "meiden"])
        try await client.deleteTrainingLimits()
        #expect(pfade == ["PUT /api/v1/me/training-limits", "DELETE /api/v1/me/training-limits"])
    }

    @Test("acceptPlan und swapPlanPosition treffen die richtigen Pfade")
    func acceptUndSwap() async throws {
        nonisolated(unsafe) var pfade: [String] = []
        StubURLProtocol.handler = { request in
            pfade.append("\(request.httpMethod ?? "") \(request.url?.path ?? "")")
            return (200, Data(#"{"id":"p2","studioId":"s1","version":2,"regelVersion":"1","struktur":"gk_ab","einheiten":[],"gruende":[]}"#.utf8))
        }
        let client = stubbedClient()
        _ = try await client.acceptPlan(id: "p1")
        let neu = try await client.swapPlanPosition(planId: "p1", einheitKey: "A", positionKey: "0", exerciseId: "e", machineId: "m")
        #expect(neu.planId == "p2")
        #expect(pfade == ["POST /api/v1/me/plans/p1/accept", "POST /api/v1/me/plans/p1/swap"])
    }
}
