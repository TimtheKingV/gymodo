import Foundation

/// Exakt die vier Werte aus packages/domain/src/workout.ts problemReasonSchema.
enum ProblemReason: String, Codable, Equatable, CaseIterable {
    case schmerz
    case geraetePasstNicht = "geraet_passt_nicht"
    case zuSchwer = "zu_schwer"
    case sonstiges
}

/// Anfrage-Rumpf fuer PUT /workout-sessions/{sessionId}/sets/{setId}.
/// sessionId/setId werden NICHT mitgeschickt -- sie stehen im Pfad und
/// gewinnen serverseitig ohnehin gegen den Rumpf (workout.ts Kommentar).
struct SetWrite: Codable, Equatable {
    var machineId: String
    var exerciseId: String
    var setIndex: Int
    var weightKg: Double
    var reps: Int
    var rir: Double? = nil
    var problemFlag: Bool = false
    var problemReason: ProblemReason? = nil
    var performedAt: String? = nil
}

struct RecordedSet: Decodable, Equatable {
    let id: String
    let studioId: String
    let userId: String
    let sessionId: String
    let machineId: String
    let exerciseId: String
    let setIndex: Int
    let weightKg: Double
    let reps: Int
    let rir: Double?
    let problemFlag: Bool
    let problemReason: ProblemReason?
    let performedAt: String
}

struct CompletedSession: Decodable, Equatable {
    let id: String
    let startedAt: String
    let completedAt: String
    let completedReason: String // "manual" | "auto"
}
