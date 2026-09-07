import Foundation
import Observation

/// @MainActor, weil SessionStore ueber @Environment direkt in SwiftUI-Views
/// (ab Aufgabe 12) gelesen wird -- ohne diese Isolation flaggt Swift 6 beim
/// Aufruf von z. B. signIn(...) aus einem View heraus einen "sending"-Fehler,
/// weil die Klasse selbst nicht Sendable ist.
@MainActor
@Observable
final class SessionStore {
    private(set) var session: Session?
    private let backend: AuthBackend

    init(backend: AuthBackend) {
        self.backend = backend
    }

    func restoreSession() async {
        session = await backend.currentSession()
    }

    /// Fuer den tokenProvider des APIClient: fragt immer das Backend, nie die
    /// zwischengespeicherte `session`-Property. Letztere wird nur beim Start
    /// und bei expliziten Anmeldungen geschrieben und waere nach einem
    /// automatischen Token-Refresh im Keychain-Backend veraltet.
    func currentAccessToken() async -> String? {
        await backend.currentSession()?.accessToken
    }

    func signIn(email: String, password: String) async throws(AuthError) {
        do { session = try await backend.signIn(email: email, password: password) }
        catch { throw AuthError.map(error) }
    }

    /// true, wenn signUp sofort eine Session liefert (nur ohne
    /// Bestaetigungspflicht -- Cloud hat sie immer aktiviert, siehe
    /// gesamtfahrplan.md). false heisst: LoginCodeView zeigen.
    func signUp(email: String, password: String) async throws(AuthError) -> Bool {
        do {
            if let newSession = try await backend.signUp(email: email, password: password) {
                session = newSession
                return true
            }
            return false
        } catch { throw AuthError.map(error) }
    }

    func verifySignupCode(email: String, code: String) async throws(AuthError) {
        do { session = try await backend.verifySignupCode(email: email, code: code) }
        catch { throw AuthError.map(error) }
    }

    func resendSignupCode(email: String) async {
        try? await backend.resendSignupCode(email: email)
    }

    /// Fehler werden bewusst verschluckt -- die Antwort ist immer gleich,
    /// egal ob das Konto existiert (spec SS9, AuthCopy.sicherheitshinweisPasswortVergessen).
    func requestPasswordReset(email: String) async {
        try? await backend.requestPasswordReset(email: email)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws(AuthError) {
        do {
            session = try await backend.verifyRecoveryCode(email: email, code: code)
            try await backend.updatePassword(newPassword)
        } catch { throw AuthError.map(error) }
    }

    /// Bestaetigt das aktuelle Passwort durch eine erneute Anmeldung, bevor
    /// das neue gesetzt wird -- Supabases updateUser verlangt keine
    /// Bestaetigung des alten Passworts, MemberPasswortAendernView braucht
    /// aber genau diesen Fehlerfall (spec SS8).
    func changePassword(currentPassword: String, newPassword: String) async throws(AuthError) {
        guard let email = session?.email else { throw AuthError.unknown }
        do {
            // Die erneute Anmeldung liefert eine frische Session -- die alte
            // wuerde sonst weiterhin als aktuell gelten.
            session = try await backend.signIn(email: email, password: currentPassword)
            try await backend.updatePassword(newPassword)
        } catch { throw AuthError.map(error) }
    }

    func signOut() async {
        try? await backend.signOut()
        session = nil
    }
}
