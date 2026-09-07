import Foundation

struct SessionsResponse: Decodable, Equatable { let sessions: [SessionSummary] }

struct SessionSummary: Decodable, Equatable, Identifiable {
    struct Block: Decodable, Equatable {
        struct Set: Decodable, Equatable {
            let setIndex: Int
            let weightKg: Double
            let reps: Int
            let rir: Double?
            let problemFlag: Bool
            let problemReason: ProblemReason?
            let performedAt: String
        }
        let machineId: String
        let machineLabel: String
        let exerciseId: String
        let exerciseName: String
        let sets: [Set]
    }

    let id: String
    let startedAt: String
    let completedAt: String?
    let completedReason: String? // "manual" | "auto" | null
    let machineCount: Int
    let setCount: Int
    let blocks: [Block]
}
