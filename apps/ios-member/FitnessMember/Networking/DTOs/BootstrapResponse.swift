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

    struct EquipmentModel: Decodable, Hashable, Sendable {
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
        /// Der Katalogtyp, aus dem das Geraet stammt; nil bei einem Modell
        /// ohne Katalogbezug. Als var mit Vorgabe, damit bestehende Aufrufer
        /// des Memberwise-Inits kompilieren.
        var catalogModelId: String? = nil
        /// Die Kachel in "Geraet waehlen" (Testnotiz 12.10., #3), vom Server
        /// aufgeloest. Text statt `Geraetegruppe`: eine Gruppe, die erst ein
        /// spaeterer Server kennt, machte sonst den ganzen Bootstrap
        /// unlesbar. Optional fuer Server vor Migration 0051 und alte Caches.
        var equipmentGroup: String? = nil
        /// In einem anderen Typ aufgegangen (Testnotiz 12.10., #1).
        /// Optional aus denselben Gruenden; gelesen wird `abgeloest`.
        var retired: Bool? = nil
        /// Wo das Rad ohne Historie steht (Testnotiz 12.10. abends, #3), vom
        /// Server aufgeloest. nil: das Minimum -- auch fuer Server vor
        /// Migration 0052 und alte Caches.
        var loadStart: Double? = nil
        /// Roh als Text, damit ein kuenftiger Schluessel nichts bricht; fehlt bei einem Server von vor E2.
        var cardioWerteRoh: [String]? = nil
        var cardioWerte: [CardioWert] { (cardioWerteRoh ?? []).compactMap(CardioWert.init(rawValue:)) }

        var abgeloest: Bool { retired == true }

        private enum CodingKeys: String, CodingKey {
            case id, name, manufacturer, photoPath, category, loadUnit, loadStep, loadMin, loadMax,
                 secondaryUnit, secondaryStep, secondaryMin, secondaryMax, settingDefinitions,
                 catalogModelId, equipmentGroup, retired, loadStart
            case cardioWerteRoh = "cardioWerte"
        }
    }

    /// Der Gymtavo-Katalog des Studios: Geraetetypen mit ihren Uebungen,
    /// auch ohne dass im Studio ein Geraet davon steht.
    struct Catalog: Decodable, Equatable, Sendable {
        struct EquipmentType: Decodable, Equatable, Sendable {
            let id: String
            let name: String
            let manufacturer: String?
            let photoPath: String?
            let category: Kategorie
            let loadUnit: LoadUnit
            let loadStep: Double
            let loadMin: Double
            let loadMax: Double?
            let secondaryUnit: LoadUnit?
            let secondaryStep: Double?
            let secondaryMin: Double?
            let secondaryMax: Double?
            let settingDefinitions: [TagContextResponse.SettingDefinition]
            let exercises: [Exercise]
            /// Siehe `EquipmentModel.equipmentGroup`, `.retired` und `.loadStart`.
            var equipmentGroup: String? = nil
            var retired: Bool? = nil
            var loadStart: Double? = nil
            /// Roh als Text, damit ein kuenftiger Schluessel nichts bricht; fehlt bei einem Server von vor E2.
            var cardioWerteRoh: [String]? = nil
            var cardioWerte: [CardioWert] { (cardioWerteRoh ?? []).compactMap(CardioWert.init(rawValue:)) }

            private enum CodingKeys: String, CodingKey {
                case id, name, manufacturer, photoPath, category, loadUnit, loadStep, loadMin, loadMax,
                     secondaryUnit, secondaryStep, secondaryMin, secondaryMax, settingDefinitions,
                     exercises, equipmentGroup, retired, loadStart
                case cardioWerteRoh = "cardioWerte"
            }
        }
        let studioId: String
        let equipmentTypes: [EquipmentType]
    }

    /// Letzter Satz je Typ und Uebung (nicht je Geraet): speist den Vorschlag
    /// im Freien Training und am Typ ohne Geraet.
    struct LastTypeSet: Decodable, Equatable, Sendable {
        let equipmentModelId: String
        let exerciseId: String
        let load: Double?
        let secondaryLoad: Double?
        let volume: Int?
        let rir: Double?
        let performedAt: String
        var cardio: CardioWerte? = nil
        /// In wie vielen Einheiten die Uebung hier vorkam. Fehlt bei einem
        /// Server von vor dem 14.10. -- dann zaehlt der Satz als eine.
        var sessionCount: Int? = nil
    }

    struct Exercise: Decodable, Hashable, Sendable, Identifiable {
        let id: String
        let name: String
        /// "Worauf du achten musst" -- im Bootstrap, damit die Einweisung offline
        /// lesbar ist (Offline-Spec 3b). Optional mit Default: alte Server und
        /// gespeicherte Bootstraps kennen das Feld nicht, und bestehende
        /// memberwise-Aufrufe bleiben gueltig.
        var description: String? = nil
        /// Was der Korridor zaehlt: Wiederholungen, Sekunden oder Meter.
        /// targetMin/targetMax stehen in genau dieser Einheit.
        let volumeKind: VolumeKind
        let targetMin: Int
        let targetMax: Int
        /// Beanspruchte Muskeln fuer die Muskelkarte. Fehlt das Feld (alter
        /// Server, gespeicherter Bootstrap), ist die Liste leer -- siehe
        /// `init(from:)` unten.
        var muscles: [GeraetMuskel] = []
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
        let load: Double?
        let secondaryLoad: Double?
        let volume: Int?
        let rir: Double?
        let performedAt: String
        var cardio: CardioWerte? = nil
        /// In wie vielen Einheiten die Uebung hier vorkam. Fehlt bei einem
        /// Server von vor dem 14.10. -- dann zaehlt der Satz als eine.
        var sessionCount: Int? = nil
    }

    let member: Member
    let studios: [Studio]
    let machines: [Machine]
    let calibrations: [Calibration]
    let lastSets: [LastSet]
    /// nil, solange der Server keinen Katalog liefert (altes Backend, alter
    /// Cache) oder das Studio keinen hat.
    var catalog: Catalog? = nil
    var lastTypeSets: [LastTypeSet] = []

    /// Ausdruecklich statt synthetisiert: die Tests bauen Bootstrap ohne die
    /// neuen Felder.
    init(
        member: Member, studios: [Studio], machines: [Machine],
        calibrations: [Calibration], lastSets: [LastSet],
        catalog: Catalog? = nil, lastTypeSets: [LastTypeSet] = []
    ) {
        self.member = member
        self.studios = studios
        self.machines = machines
        self.calibrations = calibrations
        self.lastSets = lastSets
        self.catalog = catalog
        self.lastTypeSets = lastTypeSets
    }

    private enum CodingKeys: String, CodingKey {
        case member, studios, machines, calibrations, lastSets, catalog, lastTypeSets
    }

    /// catalog/lastTypeSets mit decodeIfPresent: ein gecachtes Bootstrap von
    /// vor Etappe 3 hat sie nicht und muss lesbar bleiben.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        member = try c.decode(Member.self, forKey: .member)
        studios = try c.decode([Studio].self, forKey: .studios)
        machines = try c.decode([Machine].self, forKey: .machines)
        calibrations = try c.decode([Calibration].self, forKey: .calibrations)
        lastSets = try c.decode([LastSet].self, forKey: .lastSets)
        catalog = try c.decodeIfPresent(Catalog.self, forKey: .catalog)
        lastTypeSets = try c.decodeIfPresent([LastTypeSet].self, forKey: .lastTypeSets) ?? []
    }
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

extension BootstrapResponse.Exercise {
    private enum CodingKeys: String, CodingKey {
        case id, name, description, volumeKind, targetMin, targetMax, muscles
    }

    /// Eigener Decoder, weil die synthetisierte Variante ein fehlendes
    /// nicht-optionales `muscles` ablehnt, auch mit Default. In einer
    /// Extension, damit die memberwise-Initialisierung erhalten bleibt.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        volumeKind = try c.decode(VolumeKind.self, forKey: .volumeKind)
        targetMin = try c.decode(Int.self, forKey: .targetMin)
        targetMax = try c.decode(Int.self, forKey: .targetMax)
        muscles = try c.decodeIfPresent([GeraetMuskel].self, forKey: .muscles) ?? []
    }
}
