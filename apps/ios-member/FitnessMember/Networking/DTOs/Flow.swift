import Foundation

/// Deckt FlowSchritt aus packages/domain/src/flows.ts Feld fuer Feld -- ein
/// Tippfehler hier scheitert erst beim Dekodieren zur Laufzeit.
struct FlowSchritt: Codable, Equatable, Identifiable, Sendable {
    var id: Int { position }

    /// 1-basiert.
    let position: Int
    let name: String
    let beschreibung: String?
    let workS: Int
    let restS: Int
    let istWarmup: Bool
}

/// Deckt Flow aus flows.ts.
struct Flow: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let studioId: String
    let key: String
    let titel: String
    let beschreibung: String?
    /// "einsteiger" | "mittel" | "fortgeschritten" | nil.
    let level: String?
    let schritte: [FlowSchritt]
    let dauerS: Int
}

/// Deckt FlowRunEingabe aus flows.ts (PUT /me/flow-runs/{id}).
struct FlowRunEingabe: Codable, Equatable, Sendable {
    let id: String
    let flowId: String
    /// ISO 8601, UTC.
    let startedAt: String
    let endedAt: String
    /// 1-basiert.
    let lastStep: Int
    /// "finished" | "aborted".
    let outcome: String
}
