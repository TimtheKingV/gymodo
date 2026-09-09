import Foundation

/// Sendable ist hier EXPLIZIT noetig, nicht nur Dokumentation: EquipmentModel
/// haelt settingDefinitions als TagContextResponse.SettingDefinition -- ein
/// verschachtelter Typ aus einer anderen Datei. Ohne die explizite
/// Deklaration verpasst die implizite Sendable-Herleitung diese
/// datei-uebergreifende Referenz bei einem sauberen Build (nicht bei einem
/// inkrementellen, der die Diagnose aus dem Cache ueberspringt), und
/// APIClient.bootstrap() (actor-isoliert, BootstrapLoading: Sendable)
/// verweigert dann die Rueckgabe.
struct BootstrapResponse: Decodable, Equatable, Sendable {
    struct Member: Decodable, Equatable, Sendable {
        let displayName: String?
    }

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
        /// Derselbe Typ wie in TagContextResponse -- GeraetModel verarbeitet
        /// online und offline dieselbe Liste, statt zwei Formen zu kennen.
        ///
        /// Ohne diese Beschriftungen zeigt der Offline-Zustand den rohen
        /// Schluessel ("sitz 4") statt "Sitz 4".
        let settingDefinitions: [TagContextResponse.SettingDefinition]
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
        /// Unterschiedliche Sessions mit mindestens einem Satz an diesem
        /// Geraet. Traegt die Einstiegsentscheidung aus designsystem.md SS8
        /// und muss deshalb auch offline aus dem Prefetch verfuegbar sein.
        let visitCount: Int
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

    let member: Member
    let studios: [Studio]
    let machines: [Machine]
    let calibrations: [Calibration]
    let lastSets: [LastSet]
}

struct AnzeigenameWrite: Encodable { let displayName: String }

struct ProfilAntwort: Decodable, Equatable { let displayName: String }
