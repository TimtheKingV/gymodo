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
        /// Roh als Text, damit ein kuenftiger Schluessel nichts bricht; fehlt bei einem Server von vor E2.
        var cardioWerteRoh: [String]? = nil
        var cardioWerte: [CardioWert] { (cardioWerteRoh ?? []).compactMap(CardioWert.init(rawValue:)) }

        private enum CodingKeys: String, CodingKey {
            case id, name, manufacturer, photoUrl, loadUnit, loadStep, loadMin, loadMax,
                 secondaryUnit, secondaryStep, secondaryMin, secondaryMax
            case cardioWerteRoh = "cardioWerte"
        }
    }

    struct SettingDefinition: Decodable, Hashable, Sendable, Identifiable {
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
        /// Beanspruchte Muskeln; leer, wenn das Feld fehlt (alter Server).
        var muscles: [GeraetMuskel] = []
    }

    struct Calibration: Decodable, Equatable {
        let settingValues: JSONValue
        let schemaVersion: Int
        let source: String
        let createdAt: String
    }

    struct HistoryEntry: Decodable, Equatable {
        let performedOn: String
        let load: Double?
        let secondaryLoad: Double?
        /// Der Umfang je Satz dieses Tages, in der Umfangsart der Uebung.
        let volume: [Int]
        var cardio: CardioWerte? = nil
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

    /// nil im Typ-Kontext (equipment-models/{id}/context): dort steht kein
    /// einzelnes Geraet.
    let machine: Machine?
    let equipmentModel: EquipmentModel
    let settingDefinitions: [SettingDefinition]
    let exercises: [Exercise]
    let selectedExerciseId: String?
    let calibration: Calibration?
    let history: [HistoryEntry]
    let suggestion: Suggestion
}

extension TagContextResponse.Exercise {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, volumeKind, targetMin, targetMax, instructionVideoUrl, muscles
    }

    /// Wie bei `BootstrapResponse.Exercise`: fehlendes `muscles` wird `[]`.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        volumeKind = try c.decode(VolumeKind.self, forKey: .volumeKind)
        targetMin = try c.decode(Int.self, forKey: .targetMin)
        targetMax = try c.decode(Int.self, forKey: .targetMax)
        instructionVideoUrl = try c.decodeIfPresent(String.self, forKey: .instructionVideoUrl)
        muscles = c.decodeMuskeln(forKey: .muscles)
    }
}
