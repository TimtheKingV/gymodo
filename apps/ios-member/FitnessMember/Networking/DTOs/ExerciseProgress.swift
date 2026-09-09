import Foundation

struct ProgressResponse: Codable, Equatable { let exercises: [ExerciseProgress] }

/// Codable statt nur Decodable (Aufgabe 5): VerlaufFileStore schreibt
/// diesen Typ als Teil von GespeicherterVerlauf auf Platte.
struct ExerciseProgress: Codable, Equatable, Identifiable {
    struct Point: Codable, Equatable {
        let performedOn: String
        let topWeightKg: Double
        let reps: Int
    }
    let id: String
    let exerciseName: String
    let machineLabel: String
    let firstWeightKg: Double
    let currentWeightKg: Double
    let changeKg: Double
    let points: [Point]

    private enum CodingKeys: String, CodingKey {
        case id = "exerciseId", exerciseName, machineLabel, firstWeightKg, currentWeightKg,
             changeKg, points
    }
}
