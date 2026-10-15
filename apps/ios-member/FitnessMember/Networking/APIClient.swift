import Foundation

actor APIClient {
    private let baseURL: URL
    private let session: URLSession
    private let tokenProvider: @Sendable () async -> String?
    private let istOnline: @Sendable () async -> Bool
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    /// 10 s statt der 60 s von URLSession.shared: im Keller mit halbem Netz
    /// lief jeder Spinner eine Minute ins Leere (Offline-Spec 2).
    static let standardSession: URLSession = {
        let konfiguration = URLSessionConfiguration.default
        konfiguration.timeoutIntervalForRequest = 10
        konfiguration.waitsForConnectivity = false
        return URLSession(configuration: konfiguration)
    }()

    init(
        baseURL: URL,
        session: URLSession = APIClient.standardSession,
        istOnline: @escaping @Sendable () async -> Bool = { true },
        tokenProvider: @escaping @Sendable () async -> String?
    ) {
        self.baseURL = baseURL
        self.session = session
        self.istOnline = istOnline
        self.tokenProvider = tokenProvider
    }

    // MARK: - Die sechs M1-Endpoints (M1-Spec SS6.3)

    func bootstrap() async throws(APIError) -> BootstrapResponse {
        try await get("me/bootstrap")
    }

    /// Wie `bootstrap()`, aber mit den Bytes der Antwort -- sie landen im
    /// BootstrapFileStore (Offline-Spec 3a).
    func bootstrapMitRohdaten() async throws(APIError) -> GeladenerBootstrap {
        let rohdaten = try await executeRoh(url: baseURL.appendingPathComponent("me/bootstrap"), method: "GET", bodyData: nil)
        do { return GeladenerBootstrap(antwort: try decoder.decode(BootstrapResponse.self, from: rohdaten), rohdaten: rohdaten) }
        catch { throw APIError.decodingFailed }
    }

    func tagContext(token: String) async throws(APIError) -> TagContextResponse {
        try await get("tags/\(token)/context")
    }

    /// Derselbe Kontext ohne Tag -- fuer ein Geraet aus der Liste.
    ///
    /// Liefert dasselbe DTO, weil der Server dieselbe Form liefert. Ein
    /// zweiter Typ mit identischen Feldern waere eine Wahrheit an zwei
    /// Orten.
    func machineContext(machineId: String) async throws(APIError) -> TagContextResponse {
        try await get("machines/\(machineId)/context")
    }

    /// Derselbe Kontext an einem Gymtavo-Geraetetyp ohne Geraet (`machine`
    /// ist dann null). Ohne Studio, im Freien Training, faellt die Query weg
    /// -- der Server liest dann die Saetze ohne Studio.
    func equipmentModelContext(modelId: String, studio: String?) async throws(APIError) -> TagContextResponse {
        let pfad = "equipment-models/\(modelId)/context"
        guard let studio else { return try await get(pfad) }
        // Ueber URLComponents wie bei sessions(studio:): appendingPathComponent
        // kodierte "?" mit.
        var components = URLComponents(
            url: baseURL.appendingPathComponent(pfad), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "studio", value: studio)]
        guard let url = components.url else { throw APIError.encodingFailed }
        return try await execute(url: url, method: "GET", bodyData: nil)
    }

    /// Signierte Geraetefotos fuer die Liste. Eigener Abruf statt eines
    /// Bootstrap-Felds: die URLs leben 15 Minuten, der Prefetch Stunden.
    func machinePhotos() async throws(APIError) -> MachinePhotosResponse {
        try await get("me/machine-photos")
    }

    /// Signierte Uebungsvideos fuer Liste und Uebungszeilen -- aus demselben
    /// Grund ein eigener Abruf wie die Fotos.
    func exerciseVideos() async throws(APIError) -> ExerciseVideosResponse {
        try await get("me/exercise-videos")
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

    func completeSession(sessionId: UUID, pausedSeconds: Int) async throws(APIError) -> CompletedSession {
        try await send("workout-sessions/\(sessionId.uuidString)/complete", method: "POST",
                       body: ["pausedSeconds": pausedSeconds])
    }

    /// Oeffnet eine von Hand beendete Einheit wieder (Testnotiz 14.10.,
    /// 18:45 #3/#4). Die Antwort traegt nichts, was die App braucht.
    func reopenSession(sessionId: String) async throws(APIError) {
        struct Antwort: Decodable { let id: String }
        let _: Antwort = try await postNoBody("workout-sessions/\(sessionId)/reopen")
    }

    /// Eine Einheit, die es nicht (mehr) gibt, ist danach genau das -- kein
    /// Fehler, auch beim zweiten Aufruf (204, siehe Server-Route).
    func deleteSession(sessionId: String) async throws(APIError) {
        try await executeNoContent(path: "workout-sessions/\(sessionId)", method: "DELETE")
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

    // MARK: - Profil, Koerperdaten und Ziele (Sub-Projekt 4, ausserhalb M1-Spec SS6.3)

    /// Der einzige Schreibweg des Profils -- Registrierung (nur der
    /// Name), Onboarding (alles auf einmal), Profil (ein Feld, oder eins
    /// auf `null`). Die Antwort traegt den geputzten Stand zurueck.
    func updateProfile(_ body: ProfilWrite) async throws(APIError) -> ProfilAntwort {
        try await send("me/profile", method: "PUT", body: body)
    }

    /// Bequemlichkeit fuer die Registrierung -- ein Name, kein Teilobjekt
    /// zum Zusammenbauen an der Aufrufstelle.
    func setDisplayName(_ name: String) async throws(APIError) -> ProfilAntwort {
        try await updateProfile(ProfilWrite(displayName: .setzen(name)))
    }

    func measurements() async throws(APIError) -> MeasurementsResponse {
        try await get("me/measurements")
    }

    func putMeasurement(_ body: MesswertWrite) async throws(APIError) -> MesswertAntwort {
        try await send("me/measurements", method: "PUT", body: body)
    }

    /// Ein Tag ohne Eintrag ist danach genau das -- kein Fehler, auch
    /// beim zweiten Aufruf (204, siehe Server-Route).
    func deleteMeasurement(measuredOn: String) async throws(APIError) {
        try await executeNoContent(path: "me/measurements/\(measuredOn)", method: "DELETE")
    }

    func setGoal(_ body: ZielWrite) async throws(APIError) -> Ziel {
        try await send("me/goals", method: "PUT", body: body)
    }

    /// Aufgeben, nicht loeschen -- kein aktives Ziel dieser Sorte ist
    /// kein Fehler, auch beim zweiten Aufruf (204, siehe Server-Route).
    func dropGoal(kind: String) async throws(APIError) {
        try await executeNoContent(path: "me/goals/\(kind)", method: "DELETE")
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
    /// Verallgemeinerung: postNoBody(_:) bleibt fuer reopenSession
    /// aufrufbar, und postNoBody delegiert hierher statt die Anfrage
    /// selbst zu bauen -- kein doppelter Code, kleinster Eingriff.
    private func sendNoBody<T: Decodable>(_ path: String, method: String) async throws(APIError) -> T {
        try await execute(path: path, method: method, bodyData: nil)
    }

    private func execute<T: Decodable>(path: String, method: String, bodyData: Data?) async throws(APIError) -> T {
        try await execute(url: baseURL.appendingPathComponent(path), method: method, bodyData: bodyData)
    }

    private func execute<T: Decodable>(url: URL, method: String, bodyData: Data?) async throws(APIError) -> T {
        let data = try await executeRoh(url: url, method: method, bodyData: bodyData)
        do { return try decoder.decode(T.self, from: data) }
        catch { throw APIError.decodingFailed }
    }

    /// Der Request bis zur 2xx-Antwort, ohne Dekodieren.
    private func executeRoh(url: URL, method: String, bodyData: Data?) async throws(APIError) -> Data {
        var request = try await anfrage(url: url, method: method)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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

        if (200..<300).contains(http.statusCode) { return data }

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: data) {
            throw APIError.map(code: envelope.error.code, message: envelope.error.message)
        }
        throw APIError.server(message: "Unerwarteter Fehler.")
    }

    /// Meldet der Monitor offline, gibt es keinen Versuch -- er endete erst
    /// nach dem Timeout. Ohne Token auch nicht: ein Request ohne
    /// Authorization kaeme als 401 zurueck, und die Warteschlange hielt das
    /// fuer endgueltig (Offline-Spec 4b).
    private func anfrage(url: URL, method: String) async throws(APIError) -> URLRequest {
        guard await istOnline() else { throw APIError.offline }
        guard let token = await tokenProvider() else { throw APIError.offline }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func executeNoContent(path: String, method: String) async throws(APIError) {
        let request = try await anfrage(url: baseURL.appendingPathComponent(path), method: method)

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
