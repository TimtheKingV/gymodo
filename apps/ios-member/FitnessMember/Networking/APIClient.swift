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

    /// Liefert die volle Antwort statt nur der Liste: die Kopfzeile von
    /// Home braucht `summary`, und ein zweiter Abruf dafuer waere
    /// derselbe Abruf.
    ///
    /// `studio` ist optional -- ohne aktives Studio faellt serverseitig
    /// nur die Wochenzahl weg (siehe me/sessions/route.ts).
    func sessions(studio: String?) async throws(APIError) -> SessionsResponse {
        guard let studio else { return try await get("me/sessions", as: SessionsResponse.self) }

        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/sessions"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "studio", value: studio)]
        guard let url = components.url else { throw APIError.encodingFailed }
        return try await execute(url: url, method: "GET", bodyData: nil)
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

    // MARK: - Kurse (Sub-Projekt 3, ausserhalb M1-Spec SS6.3)

    func courseWeek(studio: String, from: String, to: String) async throws(APIError) -> CourseWeek {
        // baseURL.appendingPathComponent(path) -- der Weg, den get(_:)
        // unten fuer alle bisherigen Endpoints nimmt -- prozentkodiert "?"
        // und "&" wie jedes andere Pfadzeichen: ein Pfad mit
        // Abfrageparametern kaeme so nie beim Server an, sondern als ein
        // einziges, sinnloses Pfadsegment. Deshalb hier ueber
        // URLComponents, mit denselben Bausteinen (baseURL,
        // appendingPathComponent fuer den festen Teil).
        var components = URLComponents(
            url: baseURL.appendingPathComponent("me/courses"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "studio", value: studio),
            URLQueryItem(name: "from", value: from),
            URLQueryItem(name: "to", value: to),
        ]
        guard let url = components.url else { throw APIError.encodingFailed }
        return try await execute(url: url, method: "GET", bodyData: nil)
    }

    // bookingId kommt vom Aufrufer, nicht von hier: sie ist die
    // clientseitig erzeugte Kennung, die denselben Aufruf zweimal
    // denselben Platz ergeben laesst (Spec 6.3, Routen-Kommentar). Wuerde
    // diese Methode selbst eine UUID erzeugen, waere jeder
    // Wiederholungsversuch nach einem Netzabbruch eine NEUE Buchung --
    // genau die Doppelbuchung, die die Kennung verhindern soll. Aufgabe 8
    // haelt sie deshalb im Store und reicht sie hier nur durch.
    func bookCourse(sessionId: String, bookingId: UUID) async throws(APIError) -> BookOutcome {
        try await send(
            "course-sessions/\(sessionId)/booking", method: "PUT",
            body: BookingWrite(bookingId: bookingId.uuidString))
    }

    func cancelCourse(sessionId: String) async throws(APIError) -> CancelOutcome {
        try await sendNoBody("course-sessions/\(sessionId)/booking", method: "DELETE")
    }

    // MARK: - Profil (Sub-Projekt 4, ausserhalb M1-Spec SS6.3)

    /// Der einzige Schreibweg des Namens -- Registrierung wie spaeteres
    /// Aendern. Die Antwort traegt den geputzten Namen zurueck.
    func setDisplayName(_ name: String) async throws(APIError) -> ProfilAntwort {
        try await send("me/profile", method: "PUT", body: AnzeigenameWrite(displayName: name))
    }

    // MARK: - Hilfsmethoden

    private func get<T: Decodable>(_ path: String, as type: T.Type = T.self) async throws(APIError) -> T {
        try await execute(path: path, method: "GET", bodyData: nil)
    }

    private func send<Body: Encodable, T: Decodable>(_ path: String, method: String, body: Body) async throws(APIError) -> T {
        let bodyData: Data
        do { bodyData = try encoder.encode(body) }
        catch { throw APIError.encodingFailed }
        return try await execute(path: path, method: method, bodyData: bodyData)
    }

    private func postNoBody<T: Decodable>(_ path: String) async throws(APIError) -> T {
        try await sendNoBody(path, method: "POST")
    }

    /// Schwesterliche Hilfsmethode zu postNoBody statt dessen
    /// Verallgemeinerung: postNoBody(_:) bleibt fuer completeSession
    /// unveraendert aufrufbar (keine bestehende Aufrufstelle aendert
    /// sich), und postNoBody delegiert jetzt hierher statt die Anfrage
    /// selbst zu bauen -- kein doppelter Code, kleinster Eingriff.
    private func sendNoBody<T: Decodable>(_ path: String, method: String) async throws(APIError) -> T {
        try await execute(path: path, method: method, bodyData: nil)
    }

    private func execute<T: Decodable>(path: String, method: String, bodyData: Data?) async throws(APIError) -> T {
        try await execute(url: baseURL.appendingPathComponent(path), method: method, bodyData: bodyData)
    }

    private func execute<T: Decodable>(url: URL, method: String, bodyData: Data?) async throws(APIError) -> T {
        var request = URLRequest(url: url)
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
