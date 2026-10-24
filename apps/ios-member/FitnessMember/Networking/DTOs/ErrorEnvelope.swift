import Foundation

/// Feste Fehlerhuelle aller /api/v1-Antworten: { "error": { "code", "message" } }.
struct ErrorEnvelope: Decodable, Equatable {
    struct Body: Decodable, Equatable {
        let code: String
        let message: String
        /// Nur bei Codes mit Zusatzangaben (profil_unvollstaendig, plan_nicht_moeglich).
        let detail: JSONValue?
    }
    let error: Body
}
