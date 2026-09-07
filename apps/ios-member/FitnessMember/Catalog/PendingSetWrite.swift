import Foundation

/// Ein noch nicht bestaetigter PUT auf .../sets/{setId}. Persistiert auf
/// Platte statt nur im Speicher, weil der Offline-Zustand "gespeichert,
/// wird gesendet" verspricht (designsystem.md SS5) -- ein App-Kill waehrend
/// einer Offline-Phase darf das nicht brechen. PUT ist idempotent
/// (clientseitige UUID), ein Replay nach Neustart ist sicher.
struct PendingSetWrite: Codable, Equatable, Identifiable {
    var id: UUID { setId }
    let sessionId: UUID
    let setId: UUID
    let body: SetWrite
}
