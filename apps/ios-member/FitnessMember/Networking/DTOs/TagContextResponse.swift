import Foundation

struct TagContextResponse: Decodable, Equatable {
    struct Machine: Decodable, Equatable {
        let id: String
        let label: String
        let locationNote: String?
    }

    struct EquipmentModel: Decodable, Equatable {
        let id: String
        let name: String
        let manufacturer: String?
        let photoUrl: String?
        let weightStepKg: Double
        let minWeightKg: Double
        let maxWeightKg: Double?
    }

    struct SettingDefinition: Decodable, Equatable, Identifiable {
        var id: String { key }
        let key: String
        let label: String
        let kind: String
        let minValue: Double?
        let maxValue: Double?
        let stepValue: Double?
        let unit: String?
        let allowedValues: [String]?
    }

    struct Exercise: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let targetRepsMin: Int
        let targetRepsMax: Int
        let instructionVideoUrl: String?
    }

    struct Calibration: Decodable, Equatable {
        let settingValues: JSONValue
        let schemaVersion: Int
        let source: String
        let createdAt: String
    }

    struct HistoryEntry: Decodable, Equatable {
        let performedOn: String
        let weightKg: Double
        let reps: [Int]
    }

    struct Suggestion: Decodable, Equatable {
        struct Inputs: Decodable, Equatable {
            let targetRepsMin: Int
            let targetRepsMax: Int
            let weightStepKg: Double
            let minWeightKg: Double
            let maxWeightKg: Double
            let currentWeightKg: Double?
            let consideredBlocks: Int
        }
        let algoVersion: String
        let resultWeightKg: Double?
        let reasonCode: String
        let inputs: Inputs
    }

    let machine: Machine
    let equipmentModel: EquipmentModel
    let settingDefinitions: [SettingDefinition]
    let exercises: [Exercise]
    let selectedExerciseId: String?
    let calibration: Calibration?
    let history: [HistoryEntry]
    let suggestion: Suggestion
}
