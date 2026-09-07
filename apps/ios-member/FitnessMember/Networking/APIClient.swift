import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () async -> String?
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        baseURL: URL,
        session: URLSession = .shared,
        tokenProvider: @escaping @Sendable () async -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
    }

    // MARK: - Die sechs M1-Endpoints (M1-Spec SS6.3)

    func bootstrap() async throws(APIError) -> BootstrapResponse {
        try await get("me/bootstrap")
    }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        try await get("tags/\(token)/context")
    }

    func sessions() async throws(APIError) -> [SessionSummary] {
        try await get("me/sessions", as: SessionsResponse.self).sessions
    }

    func progress() async throws(APIError) -> [ExerciseProgress] {
        try await get("me/progress", as: ProgressResponse.self).exercises
    }

    func putSet(sessionId: UUID, setId: UUID, _ body: SetWrite) async throws(APIError) -> RecordedSet {
        try await send("workout-sessions/\(sessionId.uuidString)/sets/\(setId.uuidString)", method: "PUT", body: body)
    }

    func completeSession(sessionId: UUID) async throws(APIError) -> CompletedSession {
        try await postNoBody("workout-sessions/\(sessionId.uuidString)/complete")
    }

    // MARK: - Kalibrierung (Sub-Projekt 2, ausserhalb M1-Spec SS6.3)

    func recordCalibration(_ body: CalibrationWrite) async throws(APIError) -> RecordedCalibration {
        try await send("me/calibrations", method: "POST", body: body)
    }

    // MARK: - Beitritts-/Austritts-Endpoints (Aufgabe 17, ausserhalb M1-Spec SS6.3)

    func joinStudioByCode(_ code: String) async throws(APIError) -> JoinResult {
        try await send("studios/join-by-code", method: "POST", body: JoinByCodeRequest(code: code))
    }

    func joinStudioByTag(_ token: String) async throws(APIError) -> JoinResult {
        try await send("studios/join-by-tag", method: "POST", body: JoinByTagRequest(tagToken: token))
    }

    func leaveStudioMembership(studioId: String) async throws(APIError) {
        try await executeNoContent(path: "studios/\(studioId)/membership", method: "DELETE")
    }

    // MARK: - Hilfsmethoden

    private func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws(APIError) -> T {
        try await execute(path: path, method: "GET", bodyData: nil)
    }

    private func send<Body: Encodable, T: Decodable>(_ path: String, method: String, body: Body) async throws(APIError) -> T {
        let bodyData: Data
        do { bodyData = try encoder.encode(body) }
        catch { throw APIError.decodingFailed }
        return try await execute(path: path, method: method, bodyData: bodyData)
    }

    private func postNoBody<T: Decodable>(_ path: String) async throws(APIError) -> T {
        try await execute(path: path, method: "POST", bodyData: nil)
    }

    private func execute<T: Decodable>(path: String, method: String, bodyData: Data?) async throws(APIError) -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let bodyData {
            request.httpBody = bodyData
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.server(message: "Unerwartete Antwort.") }

        if (200..<300).contains(http.statusCode) {
            do { return try decoder.decode(T.self, from: data) }
            catch { throw APIError.decodingFailed }
        }

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            throw APIError.map(code: envelope.error.code, message: envelope.error.message)
        }
        throw APIError.server(message: "Unerwarteter Fehler.")
    }

    private func executeNoContent(path: String, method: String) async throws(APIError) {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        if let token = await tokenProvider() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.offline
        }

        guard let http = response as? HTTPURLResponse else { throw APIError.server(message: "Unerwartete Antwort.") }
        if (200..<300).contains(http.statusCode) { return }

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            throw APIError.map(code: envelope.error.code, message: envelope.error.message)
        }
        throw APIError.server(message: "Unerwarteter Fehler.")
    }
}
