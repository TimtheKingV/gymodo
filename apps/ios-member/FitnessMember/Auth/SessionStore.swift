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

    /// Der bei der Registrierung genannte Vorname, bis eine Sitzung
    /// besteht. Nur im Speicher: er ueberlebt den Code-Schritt, aber
    /// keinen App-Neustart -- laeuft die Registrierung ins Leere, ist
    /// nichts Halbes gespeichert.
    private(set) var vorgemerkterName: String?

    /// Die Session aus `verifyPasswordResetCode`, bis `completePasswordReset`
    /// sie freigibt oder `cancelPasswordReset` sie verwirft. Privat, und
    /// deshalb liest die Wurzel sie nicht -- genau das ist der Punkt.
    private var offeneWiederherstellung: Session?

    init(backend: AuthBackend) {
        self.backend = backend
    }

    /// false, bis `restoreSession()` einmal gelaufen ist -- und zwar
    /// unabhaengig davon, ob dabei eine Session herauskam.
    ///
    /// Ohne diese Unterscheidung heisst `session == nil` zweierlei: "nicht
    /// angemeldet" UND "wir haben noch nicht nachgesehen". Der zweite Fall
    /// gilt in jedem Kaltstart fuer die ersten Frames -- `restoreSession()`
    /// laeuft in `.task` und damit erst NACH dem ersten body-Durchlauf --,
    /// und die Wurzel zeichnete in dieser Zeit den Anmeldebildschirm, nur
    /// um ihn Sekundenbruchteile spaeter gegen Home zu tauschen. Wer die
    /// App oeffnet, sah sein Passwortfeld aufblitzen, obwohl er angemeldet
    /// war (Testnotiz vom 19. September, Eintrag 1).
    private(set) var wiederhergestellt = false

    func restoreSession() async {
        session = await backend.currentSession()
        // Auch wenn nichts zurueckkam: der Versuch ist gelaufen, und ab
        // jetzt heisst `session == nil` wirklich "nicht angemeldet".
        wiederhergestellt = true
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

    func nameVormerken(_ name: String) {
        let geputzt = name.trimmingCharacters(in: .whitespacesAndNewlines)
        vorgemerkterName = geputzt.isEmpty ? nil : geputzt
    }

    func nameVerbraucht() { vorgemerkterName = nil }

    /// Der eine Konsument von `vorgemerkterName` -- beide Ausstiege aus der
    /// Registrierung rufen das hier auf: der direkte (signUp liefert sofort
    /// eine Session, Bestaetigungspflicht aus) genauso wie der ueber
    /// LoginCodeView (Bestaetigung per Code). Vorher schrieb nur Letzterer,
    /// weshalb der Name bei sofortiger Session kommentarlos verschwand.
    ///
    /// Der Name ist Zierde, kein Trageteil: schlaegt `schreiben` fehl (kein
    /// Netz im Keller), geht es ohne ihn weiter, und das Profil bietet
    /// denselben Weg noch einmal an. Deshalb `try?`, kein
    /// Wiederholungsmechanismus und keine Warteschlange -- die ist fuer
    /// Saetze da -- und `vorgemerkterName` faellt in jedem Fall weg, damit
    /// kein spaeterer Aufruf denselben Namen ein zweites Mal schreibt.
    func vorgemerktenNamenSchreiben(mit schreiben: (String) async throws -> Void) async {
        guard let name = vorgemerkterName else { return }
        try? await schreiben(name)
        vorgemerkterName = nil
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

    /// Der Code-Schritt des Zuruecksetzens: prueft den Code aus der Mail
    /// (MemberPasswortCodeView).
    ///
    /// Die Session, die dabei entsteht, landet bewusst NICHT in `session`,
    /// sondern in `offeneWiederherstellung`. Veroeffentlicht wuerde sie die
    /// Wurzel sofort auf Home umschalten -- mitten im Fluss, mit dem alten
    /// Passwort noch in Kraft und dem Passwort-Screen nie gezeigt.
    func verifyPasswordResetCode(email: String, code: String) async throws(AuthError) {
        do { offeneWiederherstellung = try await backend.verifyRecoveryCode(email: email, code: code) }
        catch { throw AuthError.map(error) }
    }

    /// Der Passwort-Schritt (MemberPasswortNeuView): setzt das neue Passwort
    /// und gibt erst damit die Session frei, die der Code-Schritt
    /// zurueckgehalten hat.
    ///
    /// `currentSession()` statt der zurueckgelegten Session, falls das
    /// Setzen des Passworts einen frischen Token geliefert hat -- die
    /// zurueckgelegte ist nur der Rueckfall.
    func completePasswordReset(newPassword: String) async throws(AuthError) {
        guard let offene = offeneWiederherstellung else { throw AuthError.unknown }
        do {
            try await backend.updatePassword(newPassword)
            offeneWiederherstellung = nil
            session = await backend.currentSession() ?? offene
        } catch { throw AuthError.map(error) }
    }

    /// Verlaesst jemand den Fluss zwischen Code und neuem Passwort -- zurueck
    /// gewischt, App weggelegt --, darf die halbe Wiederherstellung nicht im
    /// Keychain liegen bleiben: `restoreSession()` haette ihn beim naechsten
    /// Start angemeldet, ohne dass je ein Passwort gesetzt wurde. Ein Code
    /// aus einer Mail ist die Erlaubnis, ein Passwort zu setzen, keine
    /// dauerhafte Anmeldung.
    func cancelPasswordReset() async {
        guard offeneWiederherstellung != nil else { return }
        offeneWiederherstellung = nil
        try? await backend.signOut()
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
        // Sonst ueberlebte ein vorgemerkter Name aus einer abgebrochenen
        // Registrierung die Abmeldung und wuerde beim naechsten Konto auf
        // demselben Geraet fuer jemand anderen geschrieben.
        vorgemerkterName = nil
    }
}
