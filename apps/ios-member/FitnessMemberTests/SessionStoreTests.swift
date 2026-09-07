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

    func currentSession() async -> Session? { storedSession }

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

@Suite("SessionStore")
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
}

private extension FakeAuthBackend {
    func setBehavior(_ value: Behavior) { behavior = value }
}
