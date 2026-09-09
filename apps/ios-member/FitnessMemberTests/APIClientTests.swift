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

func stubbedClient(tokenProvider: @escaping @Sendable () async -> String? = { "test-token" }) -> APIClient {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: configuration)
    return APIClient(baseURL: URL(string: "https://example.test/api/v1")!, session: session, tokenProvider: tokenProvider)
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
            let json = #"{"member":{"displayName":null},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#
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

    @Test("sendet den Bearer-Token aus dem tokenProvider")
    func sendsBearerToken() async throws {
        var capturedAuthHeader: String?
        StubURLProtocol.handler = { request in
            capturedAuthHeader = request.value(forHTTPHeaderField: "Authorization")
            return (200, Data(#"{"member":{"displayName":null},"studios":[],"machines":[],"calibrations":[],"lastSets":[]}"#.utf8))
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
}
