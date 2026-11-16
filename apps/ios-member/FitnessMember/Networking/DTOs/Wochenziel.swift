import Foundation

/// Das Wochenziel in `member.wochenziel` des Bootstraps: Kraft-Einheiten,
/// Cardio-Haken und Minuten je Cardio-Haken pro Woche. Beim Bestandskonto ohne
/// gesetztes Kraft-Ziel leitet der Server es ab.
struct Wochenziel: Codable, Equatable, Sendable {
    let kraft: Int
    let cardio: Int
    let cardioMinuten: Int
}

/// Ein Cardio-Haken aus /me/cardio-checks. `minuten` ist nil, wenn er von Hand
/// gesetzt wurde.
struct CardioCheck: Codable, Equatable, Hashable, Sendable {
    let id: String
    /// "YYYY-MM-DD" im Tag des Mitglieds.
    let day: String
    let minuten: Int?
}
