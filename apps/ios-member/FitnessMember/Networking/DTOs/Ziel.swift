import Foundation

/// Ein aktives Ziel -- Wochentage oder Zielgewicht, unterschieden ueber
/// `kind` ("weekly_days" | "target_weight", derselbe Rohwert wie
/// `GOAL_KINDS` in packages/domain/src/goals.ts). Ein eigenes Enum dafuer
/// waere hier eine zweite Liste neben dem Server -- wie bei
/// `completedReason` bleibt der Rohwert stehen.
///
/// Sendable explizit, wie `BootstrapResponse.Member` -- derselbe Grund:
/// `Ziele` unten und `Member.goals` referenzieren diesen Typ aus einer
/// anderen Datei.
struct Ziel: Decodable, Equatable, Sendable {
    let id: String
    let kind: String
    let targetValue: Double
    let createdAt: String
}

/// Die aktiven Ziele eines Mitglieds -- Teil von `BootstrapResponse.Member`.
struct Ziele: Decodable, Equatable, Sendable {
    let weeklyDays: Ziel?
    let targetWeight: Ziel?
}

/// Anfrage-Rumpf fuer `PUT /me/goals`.
struct ZielWrite: Encodable, Equatable {
    let kind: String
    let targetValue: Double
}
