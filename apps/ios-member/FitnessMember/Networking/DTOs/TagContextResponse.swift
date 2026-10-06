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
        let loadUnit: LoadUnit
        let loadStep: Double
        let loadMin: Double
        let loadMax: Double?
        let secondaryUnit: LoadUnit?
        let secondaryStep: Double?
        let secondaryMin: Double?
        let secondaryMax: Double?
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

        /// Die Werteliste einer Auswahl (`kind == "enum"`), sonst nil. Ein
        /// Ort fuer die Unterscheidung, damit Entwurf, Senden und Anzeige
        /// sie nicht je eigens treffen (Testnotiz 06.10., #17).
        var auswahlwerte: [String]? {
            guard kind == "enum", let werte = allowedValues, !werte.isEmpty else { return nil }
            return werte
        }
    }

    struct Exercise: Decodable, Equatable, Identifiable {
        let id: String
        let name: String
        let description: String?
        let volumeKind: VolumeKind
        let targetMin: Int
        let targetMax: Int
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
        let load: Double
        let secondaryLoad: Double?
        /// Der Umfang je Satz dieses Tages, in der Umfangsart der Uebung.
        let volume: [Int]
    }

    struct Suggestion: Decodable, Equatable {
        struct Inputs: Decodable, Equatable {
            let targetMin: Int
            let targetMax: Int
            let loadStep: Double
            let loadMin: Double
            let loadMax: Double
            let currentLoad: Double?
            let currentSecondaryLoad: Double?
            let consideredBlocks: Int
        }
        let algoVersion: String
        let resultLoad: Double?
        /// Die Nebenbelastung, bei der der Vorschlag gilt. Die Regel
        /// steigert sie nie, sie gibt sie nur mit (Cardio-Spec 5.2).
        let resultSecondaryLoad: Double?
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
