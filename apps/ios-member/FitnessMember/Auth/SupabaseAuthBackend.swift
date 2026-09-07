import Foundation
import Auth

final class SupabaseAuthBackend: AuthBackend {
    private let client: AuthClient

    /// Kein eigener authLocalStorage-Parameter, der etwas Eigenes ueber
    /// UserDefaults/SwiftData baut: KeychainLocalStorage ist die Keychain-
    /// gestuetzte Implementierung, die supabase-swifts Auth-Produkt selbst
    /// mitbringt (Sources/Auth/Storage/KeychainLocalStorage.swift) -- dieselbe,
    /// die SupabaseClient per Default verwendet haette. M1-Spec SS9/SS10
    /// verbietet UserDefaults und SwiftData fuer Sessions. Wir konstruieren
    /// AuthClient direkt statt SupabaseClient, weil Letzteres das Supabase-
    /// Umbrella-Paket braucht -- das zieht PostgREST/Realtime/Storage mit rein,
    /// was M1-Spec SS6.1/SS6.2 ausdruecklich verbietet.
    init() {
        client = AuthClient(
            url: AppConfig.supabaseURL.appendingPathComponent("auth/v1"),
            headers: [
                "apikey": AppConfig.supabaseAnonKey,
                "Authorization": "Bearer \(AppConfig.supabaseAnonKey)",
            ],
            localStorage: KeychainLocalStorage()
        )
    }

    func currentSession() async -> Session? {
        guard let session = try? await client.session else { return nil }
        return map(session)
    }

    func signIn(email: String, password: String) async throws -> Session {
        let session = try await client.signIn(email: email, password: password)
        return map(session)
    }

    func signUp(email: String, password: String) async throws -> Session? {
        let response = try await client.signUp(email: email, password: password)
        guard let session = response.session else { return nil }
        return map(session)
    }

    func verifySignupCode(email: String, code: String) async throws -> Session {
        let response = try await client.verifyOTP(email: email, token: code, type: .signup)
        guard let session = response.session else {
            throw AuthBackendError.noSessionAfterVerification
        }
        return map(session)
    }

    func resendSignupCode(email: String) async throws {
        try await client.resend(email: email, type: .signup)
    }

    func requestPasswordReset(email: String) async throws {
        try await client.resetPasswordForEmail(email)
    }

    func verifyRecoveryCode(email: String, code: String) async throws -> Session {
        let response = try await client.verifyOTP(email: email, token: code, type: .recovery)
        guard let session = response.session else {
            throw AuthBackendError.noSessionAfterVerification
        }
        return map(session)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.update(user: UserAttributes(password: newPassword))
    }

    func signOut() async throws {
        try await client.signOut()
    }

    private func map(_ session: Auth.Session) -> Session {
        FitnessMember.Session(
            accessToken: session.accessToken,
            userId: session.user.id.uuidString,
            email: session.user.email ?? "",
            expiresAt: Date(timeIntervalSince1970: session.expiresAt)
        )
    }
}

enum AuthBackendError: Error {
    case noSessionAfterVerification
}
