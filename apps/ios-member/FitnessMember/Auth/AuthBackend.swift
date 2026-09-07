import Foundation

protocol AuthBackend: Sendable {
    func currentSession() async -> Session?
    func signIn(email: String, password: String) async throws -> Session
    /// nil, wenn Bestaetigungspflicht aktiv ist (Cloud-Standard) und noch
    /// keine Session entsteht -- siehe apps/web/app/registrieren/actions.ts.
    func signUp(email: String, password: String) async throws -> Session?
    func verifySignupCode(email: String, code: String) async throws -> Session
    func resendSignupCode(email: String) async throws
    func requestPasswordReset(email: String) async throws
    func verifyRecoveryCode(email: String, code: String) async throws -> Session
    func updatePassword(_ newPassword: String) async throws
    func signOut() async throws
}
