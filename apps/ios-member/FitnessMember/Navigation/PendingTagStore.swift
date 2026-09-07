import Foundation
import Observation

/// Haelt einen ueber Universal Link erfassten Tag-Token, bis er verbraucht
/// wird -- ersetzt die alte Weitergabe direkt an ContentView aus Task 7
/// (M0). In diesem Sub-Projekt nur fuer die Pending-Route-Banner-Anzeige auf
/// LoginMailView genutzt; Sub-Projekt 2 (Geraet-Kernflow) konsumiert token
/// nach dem Login, um direkt zum Geraet zu navigieren.
@Observable
final class PendingTagStore {
    private(set) var token: String?

    func capture(_ token: String) {
        self.token = token
    }

    func consume() -> String? {
        defer { token = nil }
        return token
    }
}
