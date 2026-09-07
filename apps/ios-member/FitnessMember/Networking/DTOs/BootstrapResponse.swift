import Foundation

struct BootstrapResponse: Decodable, Equatable {
    struct Studio: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let timezone: String
    }

    struct EquipmentModel: Decodable, Equatable {
        let id: String
        let name: String
        let manufacturer: String?
        let photoPath: String?
        let weightStepKg: Double
        let minWeightKg: Double
        let maxWeightKg: Double?
    }

    struct Exercise: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let targetRepsMin: Int
        let targetRepsMax: Int
    }

    struct Machine: Decodable, Equatable, Identifiable {
        let id: String
        let studioId: String
        let label: String
        let locationNote: String?
        let status: String
        let tokenHashes: [String]
        let equipmentModel: EquipmentModel
        let exercises: [Exercise]
    }

    struct Calibration: Decodable, Equatable {
        let machineId: String
        let exerciseId: String
        let settingValues: JSONValue
        let schemaVersion: Int
        let createdAt: String
    }

    struct LastSet: Decodable, Equatable {
        let machineId: String
        let exerciseId: String
        let weightKg: Double
        let reps: Int
        let rir: Double?
        let performedAt: String
    }

    let studios: [Studio]
    let machines: [Machine]
    let calibrations: [Calibration]
    let lastSets: [LastSet]
}
