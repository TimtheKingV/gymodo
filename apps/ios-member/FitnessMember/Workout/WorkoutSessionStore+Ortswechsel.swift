import Foundation

extension WorkoutSessionStore {
    enum Ortswechselende: Equatable {
        case verworfen
        case abgeschlossen(UUID)
    }

    /// Beendet die Einheit lokal, sofort und ohne Netz: der Ortswechsel darf
    /// nicht auf den Server warten. Ohne Satz wird verworfen wie in
    /// TrainingRootView.beenden (Entschieden 2) -- der Server kennt sie nie.
    func beendenFuerOrtswechsel() -> Ortswechselende {
        guard let session = aktiveSession(), session.hatSaetze else {
            beenden()
            return .verworfen
        }
        beenden()
        return .abgeschlossen(session.id)
    }

    /// Meldet den Abschluss im Hintergrund. Fehler bleiben stumm: der Server
    /// beendet die Einheit nach vier Stunden ohne Satz selbst, und der
    /// Abschluss-Screen mit den Vorschlaegen entfaellt in diesem Pfad.
    static func melden(_ ende: Ortswechselende, loader: any GeraetLoading) async {
        guard case .abgeschlossen(let id) = ende else { return }
        _ = try? await loader.completeSession(sessionId: id)
    }
}
