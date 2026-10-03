import Foundation

struct ProgressResponse: Codable, Equatable { let exercises: [ExerciseProgress] }

/// Codable statt nur Decodable (Aufgabe 5): VerlaufFileStore schreibt
/// diesen Typ als Teil von GespeicherterVerlauf auf Platte.
struct ExerciseProgress: Codable, Equatable, Identifiable {
    struct Point: Codable, Equatable {
        let performedOn: String
        let topLoad: Double
        let volume: Int
    }
    let id: String
    let exerciseName: String
    let machineLabel: String
    let loadUnit: LoadUnit
    let volumeKind: VolumeKind
    let firstLoad: Double
    let currentLoad: Double
    let changeLoad: Double
    let points: [Point]

    private enum CodingKeys: String, CodingKey {
        case id = "exerciseId", exerciseName, machineLabel, loadUnit, volumeKind,
             firstLoad, currentLoad, changeLoad, points
    }
}
