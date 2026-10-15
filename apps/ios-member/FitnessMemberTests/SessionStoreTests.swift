import Foundation
import Testing
@testable import FitnessMember

/// Testdouble fuer AuthBackend -- SessionStore wird nie gegen den echten
/// SupabaseAuthBackend getestet (siehe Hinweis in Aufgabe 7).
actor FakeAuthBackend: AuthBackend {
    enum Behavior {
        case succeed(Session)
        case fail(Error)
        case requireConfirmation
    }

    var behavior: Behavior = .fail(TestError.notConfigured)
    private(set) var storedSession: Session?
    private(set) var updatePasswordCalls: [String] = []
    private(set) var signInCalls: [(email: String, password: String)] = []

    enum TestError: Error { case notConfigured, invalidCredentials }

    func currentSession() async -> Session? {
        angefragt = true
        guard haengt else { return storedSession }
        return await withCheckedContinuation { wartend = $0 }
    }

    func gespeicherteSession() async -> Session? { storedSession }

    /// Haengender Refresh (Offline-Spec 4a, Abnahme 1): `currentSession()`
    /// kehrt erst mit `freigeben(mit:)` zurueck -- wie supabase-swift bei
    /// 100 % Paketverlust mit seinen Timeouts und Wiederholungen.
    private(set) var haengt = false
    private(set) var angefragt = false
    private var wartend: CheckedContinuation<Session?, Never>?

    func setHaengt(_ wert: Bool) { haengt = wert }

    func freigeben(mit session: Session?) {
        haengt = false
        wartend?.resume(returning: session)
        wartend = nil
    }

    func signIn(email: String, password: String) async throws -> Session {
        signInCalls.append((email, password))
        switch behavior {
        case .succeed(let session): storedSession = session; return session
        case .fail(let error): throw error
        case .requireConfirmation: throw TestError.invalidCredentials
        }
    }

    func signUp(email: String, password: String) async throws -> Session? {
        switch behavior {
        case .succeed(let session): storedSession = session; return session
        case .requireConfirmation: return nil
        case .fail(let error): throw error
        }
    }

    func verifySignupCode(email: String, code: String) async throws -> Session {
        try requireSuccess()
    }

    func resendSignupCode(email: String) async throws {}

    func requestPasswordReset(email: String) async throws {}

    func verifyRecoveryCode(email: String, code: String) async throws -> Session {
        try requireSuccess()
    }

    func updatePassword(_ newPassword: String) async throws {
        updatePasswordCalls.append(newPassword)
        if case .fail(let error) = behavior { throw error }
    }

    func signOut() async throws { storedSession = nil }

    private func requireSuccess() throws -> Session {
        switch behavior {
        case .succeed(let session): storedSession = session; return session
        case .fail(let error): throw error
        case .requireConfirmation: throw TestError.invalidCredentials
        }
    }
}

private let testSession = Session(accessToken: "tok", userId: "u1", email: "lena@example.de", expiresAt: .distantFuture)

/// @MainActor, weil SessionStore seit Aufgabe 12 selbst @MainActor ist (siehe
/// Kommentar dort) -- die Suite laeuft deshalb auf demselben Actor wie die
/// getestete Klasse, sonst braeuchte jeder store.session-Zugriff ein await.
@Suite("SessionStore")
@MainActor
struct SessionStoreTests {
    @Test("signIn setzt die Session bei Erfolg")
    func signInSucceeds() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try? await store.signIn(email: "lena@example.de", password: "geheim1234")
        #expect(store.session == testSession)
    }

    @Test("signIn wirft AuthError.invalidCredentials bei falschem Passwort")
    func signInFails() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.fail(FakeAuthBackend.TestError.invalidCredentials))
        let store = SessionStore(backend: backend)
        await #expect(throws: AuthError.invalidCredentials) {
            try await store.signIn(email: "lena@example.de", password: "falsch")
        }
        #expect(store.session == nil)
    }

    @Test("signUp liefert false, wenn Bestaetigung noetig ist")
    func signUpRequiresConfirmation() async throws {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.requireConfirmation)
        let store = SessionStore(backend: backend)
        let gotImmediateSession = try await store.signUp(email: "neu@example.de", password: "geheim1234")
        #expect(gotImmediateSession == false)
        #expect(store.session == nil)
    }

    @Test("signOut leert die Session")
    func signOutClearsSession() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try? await store.signIn(email: "lena@example.de", password: "geheim1234")
        await store.signOut()
        #expect(store.session == nil)
    }

    @Test("restoreSession uebernimmt eine vorhandene Backend-Session")
    func restoreSessionLoadsExisting() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        _ = try? await backend.signIn(email: "lena@example.de", password: "geheim1234")
        let store = SessionStore(backend: backend)
        #expect(store.session == nil)
        await store.restoreSession()
        #expect(store.session == testSession)
    }

    @Test("nameVormerken merkt sich einen Namen bis er verbraucht wird")
    func nameVormerkenRemembersName() async {
        let store = SessionStore(backend: FakeAuthBackend())
        store.nameVormerken("Lena")
        #expect(store.vorgemerkterName == "Lena")
        store.nameVerbraucht()
        #expect(store.vorgemerkterName == nil)
    }

    @Test("nameVormerken merkt sich reinen Leerraum nicht")
    func nameVormerkenIgnoresWhitespaceOnly() async {
        let store = SessionStore(backend: FakeAuthBackend())
        store.nameVormerken("   ")
        #expect(store.vorgemerkterName == nil)
    }

    @Test("signOut vergisst einen noch nicht geschriebenen Namen")
    func signOutClearsVorgemerktenNamen() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try? await store.signIn(email: "lena@example.de", password: "geheim1234")
        store.nameVormerken("Lena")
        await store.signOut()
        // Sonst schriebe das naechste Konto auf demselben Geraet Lenas
        // Namen.
        #expect(store.vorgemerkterName == nil)
    }

    @Test("vorgemerktenNamenSchreiben schreibt den Namen und vergisst ihn danach")
    func vorgemerktenNamenSchreibenWritesAndForgets() async {
        let store = SessionStore(backend: FakeAuthBackend())
        store.nameVormerken("Lena")
        var geschrieben: String?
        await store.vorgemerktenNamenSchreiben { name in geschrieben = name }
        #expect(geschrieben == "Lena")
        #expect(store.vorgemerkterName == nil)
    }

    @Test("vorgemerktenNamenSchreiben vergisst den Namen auch, wenn der Schreibvorgang fehlschlaegt")
    func vorgemerktenNamenSchreibenForgetsOnFailure() async {
        let store = SessionStore(backend: FakeAuthBackend())
        store.nameVormerken("Lena")
        await store.vorgemerktenNamenSchreiben { _ in throw FakeAuthBackend.TestError.notConfigured }
        // Der Name ist Zierde, kein Trageteil: ein Fehler bleibt unsichtbar,
        // und das Profil bietet denselben Weg noch einmal an -- kein
        // Wiederholungsmechanismus, keine Warteschlange.
        #expect(store.vorgemerkterName == nil)
    }

    @Test("vorgemerktenNamenSchreiben tut nichts ohne vorgemerkten Namen")
    func vorgemerktenNamenSchreibenNoOpWithoutName() async {
        let store = SessionStore(backend: FakeAuthBackend())
        var aufgerufen = false
        await store.vorgemerktenNamenSchreiben { _ in aufgerufen = true }
        #expect(aufgerufen == false)
    }

    @Test("verifyPasswordResetCode meldet noch niemanden an")
    func verifyPasswordResetCodeHoldsSessionBack() async throws {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try await store.verifyPasswordResetCode(email: "lena@example.de", code: "123456")
        // Waere sie hier veroeffentlicht, schaltete die Wurzel sofort auf
        // Home um -- mitten im Fluss, das neue Passwort noch ungesetzt.
        #expect(store.session == nil)
    }

    @Test("completePasswordReset setzt das Passwort und gibt die Session frei")
    func completePasswordResetPublishesSession() async throws {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try await store.verifyPasswordResetCode(email: "lena@example.de", code: "123456")
        try await store.completePasswordReset(newPassword: "neuesPasswort1")
        #expect(await backend.updatePasswordCalls == ["neuesPasswort1"])
        #expect(store.session == testSession)
    }

    @Test("completePasswordReset ohne geprueften Code schlaegt fehl")
    func completePasswordResetNeedsVerifiedCode() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        await #expect(throws: AuthError.unknown) {
            try await store.completePasswordReset(newPassword: "neuesPasswort1")
        }
        #expect(await backend.updatePasswordCalls.isEmpty)
        #expect(store.session == nil)
    }

    @Test("cancelPasswordReset verwirft die halbe Wiederherstellung im Backend")
    func cancelPasswordResetSignsOut() async throws {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try await store.verifyPasswordResetCode(email: "lena@example.de", code: "123456")
        await store.cancelPasswordReset()
        // Sonst meldete der naechste Kaltstart jemanden an, der nie ein
        // Passwort gesetzt hat -- der Code aus der Mail ist die Erlaubnis,
        // eines zu setzen, keine dauerhafte Anmeldung.
        #expect(await backend.currentSession() == nil)
        await #expect(throws: AuthError.unknown) {
            try await store.completePasswordReset(newPassword: "neuesPasswort1")
        }
    }

    @Test("changePassword meldet aktuelles Passwort falsch als eigenen Fehler")
    func changePasswordWrongCurrent() async {
        let backend = FakeAuthBackend()
        await backend.setBehavior(.succeed(testSession))
        let store = SessionStore(backend: backend)
        try? await store.signIn(email: "lena@example.de", password: "geheim1234")
        await backend.setBehavior(.fail(FakeAuthBackend.TestError.invalidCredentials))
        await #expect(throws: AuthError.invalidCredentials) {
            try await store.changePassword(currentPassword: "falsch", newPassword: "neuesPasswort1")
        }
    }
    @Test("abgelaufener Token wird nicht verwendet")
    func abgelaufenerTokenWirdNichtVerwendet() async {
        let backend = FakeAuthBackend()
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        await backend.setStoredSession(Session(accessToken: "alt", userId: "u1", email: "a@b.de",
                                               expiresAt: jetzt.addingTimeInterval(-1)))
        let store = SessionStore(backend: backend, jetzt: { jetzt })
        #expect(await store.currentAccessToken() == nil)
    }

    @Test("gueltiger Token wird verwendet")
    func gueltigerTokenWirdVerwendet() async {
        let backend = FakeAuthBackend()
        let jetzt = Date(timeIntervalSince1970: 1_000_000)
        await backend.setStoredSession(Session(accessToken: "neu", userId: "u1", email: "a@b.de",
                                               expiresAt: jetzt.addingTimeInterval(600)))
        let store = SessionStore(backend: backend, jetzt: { jetzt })
        #expect(await store.currentAccessToken() == "neu")
    }

    /// Offline-Start (Offline-Spec 4a): eine abgelaufene Session aus der
    /// Keychain meldet trotzdem an -- der Login-Screen kommt nur bei echtem
    /// Auth-Fehler.
    @Test("restoreSession uebernimmt auch eine abgelaufene Session")
    func restoreMitAbgelaufenerSession() async {
        let backend = FakeAuthBackend()
        let alt = Session(accessToken: "alt", userId: "u1", email: "a@b.de", expiresAt: .distantPast)
        await backend.setStoredSession(alt)
        let store = SessionStore(backend: backend)
        await store.restoreSession()
        #expect(store.session == alt)
    }

    /// Abnahme 1 (Offline-Spec 4a): abgelaufener Token bei 100 % Verlust --
    /// der Refresh haengt bis zu ~30 s, die gespeicherte Session muss nach
    /// der kurzen Frist trotzdem da sein.
    @Test("restoreSession nimmt nach der Frist die gespeicherte Session, ein spaeteres nil meldet ab",
          .timeLimit(.minutes(1)))
    func restoreNachFristMitGespeicherterSession() async throws {
        let backend = FakeAuthBackend()
        let alt = Session(accessToken: "alt", userId: "u1", email: "a@b.de", expiresAt: .distantPast)
        await backend.setStoredSession(alt)
        await backend.setHaengt(true)
        let store = SessionStore(backend: backend, restoreFrist: .milliseconds(50))
        await store.restoreSession()
        #expect(store.session == alt)
        #expect(store.wiederhergestellt)

        // Der Refresh laeuft weiter und endet mit echtem Auth-Fehler.
        while await !backend.angefragt { await Task.yield() }
        await backend.freigeben(mit: nil)
        let frist = ContinuousClock.now + .seconds(2)
        while store.session != nil, ContinuousClock.now < frist {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.session == nil)
    }

    @Test("restoreSession uebernimmt einen spaeten frischen Token", .timeLimit(.minutes(1)))
    func restoreNachFristMitSpaeterFrischerSession() async throws {
        let backend = FakeAuthBackend()
        let alt = Session(accessToken: "alt", userId: "u1", email: "a@b.de", expiresAt: .distantPast)
        let frisch = Session(accessToken: "frisch", userId: "u1", email: "a@b.de", expiresAt: .distantFuture)
        await backend.setStoredSession(alt)
        await backend.setHaengt(true)
        let store = SessionStore(backend: backend, restoreFrist: .milliseconds(50))
        await store.restoreSession()
        #expect(store.session == alt)

        while await !backend.angefragt { await Task.yield() }
        await backend.freigeben(mit: frisch)
        let frist = ContinuousClock.now + .seconds(2)
        while store.session != frisch, ContinuousClock.now < frist {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(store.session == frisch)
    }

    @Test("restoreSession wartet nicht auf die Frist, wenn das Backend sofort antwortet",
          .timeLimit(.minutes(1)))
    func restoreOhneWartenAufFrist() async {
        let backend = FakeAuthBackend()
        let store = SessionStore(backend: backend, restoreFrist: .seconds(30))
        let start = ContinuousClock.now
        await store.restoreSession()
        #expect(ContinuousClock.now - start < .seconds(5))
        #expect(store.session == nil)
        #expect(store.wiederhergestellt)
    }

    @Test("Refresh: keine Antwort und 5xx sind voruebergehend, 4xx nicht",
          arguments: [(Int?.none, true), (503, true), (500, true), (400, false), (401, false)])
    func refreshFehler(_ fall: (Int?, Bool)) {
        #expect(RefreshFehler.istVoruebergehend(status: fall.0) == fall.1)
    }
}

private extension FakeAuthBackend {
    func setBehavior(_ value: Behavior) { behavior = value }
    func setStoredSession(_ session: Session?) { storedSession = session }
}
