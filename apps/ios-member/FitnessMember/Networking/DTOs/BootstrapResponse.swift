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
        let sex: String?
        let ageBand: String?
        let heightCm: Int?
        let trainingGoal: String?
        let onboardingCompletedAt: String?
        /// Die aktiven Ziele -- weeklyDays und/oder targetWeight, siehe
        /// AktiveZiele im Server.
        let goals: Ziele
        /// Der juengste Gewichtseintrag, damit die Gewichtskarte auf Home
        /// ohne eigenen Verlaufsabruf einen Wert zeigt.
        let latestWeight: Messwert?

        /// Eigener Init mit Vorgaben statt des synthetisierten: bestehende
        /// Testdaten (GeraetEinstiegTests) bauen nur `displayName` und
        /// sollen mit den neuen Feldern weiter kompilieren.
        init(
            displayName: String?, sex: String? = nil, ageBand: String? = nil,
            heightCm: Int? = nil, trainingGoal: String? = nil, onboardingCompletedAt: String? = nil,
            goals: Ziele = Ziele(weeklyDays: nil, targetWeight: nil), latestWeight: Messwert? = nil
        ) {
            self.displayName = displayName
            self.sex = sex
            self.ageBand = ageBand
            self.heightCm = heightCm
            self.trainingGoal = trainingGoal
            self.onboardingCompletedAt = onboardingCompletedAt
            self.goals = goals
            self.latestWeight = latestWeight
        }
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
        /// Nur Anzeige: die Geraetesuche gruppiert danach (Cardio-Spec
        /// Abschnitt 3.5). Der Satzpfad liest sie nie -- deshalb steht sie
        /// auch nur hier und nicht im TagContextResponse.
        let category: Kategorie
        /// Was am Geraet gedreht wird, und in welchen Rasten. Die Einheit
        /// ist ein Wert, den Raeder und Formatierer lesen -- kein Zweig.
        let loadUnit: LoadUnit
        let loadStep: Double
        let loadMin: Double
        let loadMax: Double?
        /// Der zweite Intensitaetsregler (Neigung am Laufband), mit eigener
        /// Rastung. Alle vier gesetzt oder keiner: so erzwingt es der
        /// Constraint aus Migration 0046. Bei einem Kraftgeraet nil.
        let secondaryUnit: LoadUnit?
        let secondaryStep: Double?
        let secondaryMin: Double?
        let secondaryMax: Double?
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
        /// Was der Korridor zaehlt: Wiederholungen, Sekunden oder Meter.
        /// targetMin/targetMax stehen in genau dieser Einheit.
        let volumeKind: VolumeKind
        let targetMin: Int
        let targetMax: Int
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
        /// Zahlen ohne Einheit: was sie bedeuten, sagen loadUnit am Modell
        /// und volumeKind an der Uebung.
        let load: Double
        let secondaryLoad: Double?
        let volume: Int
        let rir: Double?
        let performedAt: String
    }

    let member: Member
    let studios: [Studio]
    let machines: [Machine]
    let calibrations: [Calibration]
    let lastSets: [LastSet]
}

/// Antwort auf `PUT /me/profile` -- die sechs Profilfelder, OHNE `goals`
/// und `latestWeight`: die schreibt dieser Weg nicht mit (R14). Anders
/// als `BootstrapResponse.Member`, deshalb ein eigener Typ statt
/// desselben.
///
/// Sendable explizit, aus demselben Grund wie `Member`: der Rueckgabeweg
/// laeuft ueber den Actor (`APIClient.updateProfile`).
struct ProfilAntwort: Decodable, Equatable, Sendable {
    let displayName: String?
    let sex: String?
    let ageBand: String?
    let heightCm: Int?
    let trainingGoal: String?
    let onboardingCompletedAt: String?
}
