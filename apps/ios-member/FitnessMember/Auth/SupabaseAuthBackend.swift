import Foundation
import Supabase

final class SupabaseAuthBackend: AuthBackend {
    private let client: SupabaseClient

    /// Kein eigener authLocalStorage-Parameter: SupabaseClient nutzt seinen
    /// Standard (Keychain-gestuetzt). M1-Spec SS9/SS10 verbietet UserDefaults
    /// und SwiftData fuer Sessions -- das ist hier bewusst nicht eigens
    /// gebaut, sondern der SDK-Standard validiert und dokumentiert.
    init() {
        client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
    }

    func currentSession() async -> Session? {
        guard let session = try? await client.auth.session else { return nil }
        return map(session)
    }

    func signIn(email: String, password: String) async throws -> Session {
        let session = try await client.auth.signIn(email: email, password: password)
        return map(session)
    }

    func signUp(email: String, password: String) async throws -> Session? {
        let response = try await client.auth.signUp(email: email, password: password)
        guard let session = response.session else { return nil }
        return map(session)
    }

    func verifySignupCode(email: String, code: String) async throws -> Session {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .signup)
        guard let session = response.session else {
            throw AuthBackendError.noSessionAfterVerification
        }
        return map(session)
    }

    func resendSignupCode(email: String) async throws {
        try await client.auth.resend(email: email, type: .signup)
    }

    func requestPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func verifyRecoveryCode(email: String, code: String) async throws -> Session {
        let response = try await client.auth.verifyOTP(email: email, token: code, type: .recovery)
        guard let session = response.session else {
            throw AuthBackendError.noSessionAfterVerification
        }
        return map(session)
    }

    func updatePassword(_ newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }

    func signOut() async throws {
        try await client.auth.signOut()
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
