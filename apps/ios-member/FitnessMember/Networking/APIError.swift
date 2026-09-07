import Foundation

/// Bildet apps/web/lib/api/respond.ts 1:1 ab: fuenf Codes, feste
/// Status-Zuordnung. .offline ist ein rein clientseitiger Fall (kein
/// HTTP-Response ueberhaupt) und hat kein Server-Gegenstueck.
enum APIError: Error, Equatable {
    case offline
    case unauthorized(message: String)
    case validation(message: String)
    case notFound(message: String)
    case conflict(message: String)
    case server(message: String)
    case decodingFailed

    /// Ob ein Wiederholen aussichtslos ist.
    ///
    /// Die Schreib-Warteschlange behielt bisher bei jedem Fehler. Ein
    /// stillgelegtes Geraet oder eine entfernte Uebung kommt nie zurueck --
    /// der Eintrag wuerde sonst bei jedem Netzwechsel neu versucht, fuer
    /// immer.
    var istDauerhaft: Bool {
        switch self {
        case .offline, .server: false
        case .unauthorized, .validation, .notFound, .conflict, .decodingFailed: true
        }
    }

    static func map(code: String, message: String) -> APIError {
        switch code {
        case "unauthorized": .unauthorized(message: message)
        case "validation_failed": .validation(message: message)
        case "not_found": .notFound(message: message)
        case "conflict": .conflict(message: message)
        default: .server(message: message)
        }
    }
}
