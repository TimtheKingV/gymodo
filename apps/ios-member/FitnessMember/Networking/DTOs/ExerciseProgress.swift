import Foundation

struct ProgressResponse: Decodable, Equatable { let exercises: [ExerciseProgress] }

struct ExerciseProgress: Decodable, Equatable, Identifiable {
    struct Point: Decodable, Equatable {
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
