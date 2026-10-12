import Foundation

/// Die Kacheln in "Geraet waehlen" (Testnotiz 12.10., #3-#5), in ihrer
/// Anzeigereihenfolge -- `allCases` IST die Reihenfolge.
///
/// Wie `Kategorie` nur Anzeige: kein Satzpfad, keine Regel liest sie. Sie
/// ersetzt die Kategorie in der Liste, nicht im Modell -- `category` traegt
/// weiter die Einheiten im Portal, und eine Hantel bleibt dort "kraft".
/// Eigengewicht, Kettlebell und Gummiband sind vorgemerkt (#5); eine
/// Kachel ohne Geraet zeigt die Liste nicht.
enum Geraetegruppe: String, CaseIterable, Hashable, Sendable {
    case geraete, freihantel, kabelzug, cardio, eigengewicht, kettlebell, gummiband

    var titel: String {
        switch self {
        case .geraete: "Geräte"
        case .freihantel: "Freihantel"
        case .kabelzug: "Kabelzug"
        case .cardio: "Cardio"
        case .eigengewicht: "Eigengewicht"
        case .kettlebell: "Kettlebell"
        case .gummiband: "Gummiband"
        }
    }

    /// SF Symbol der Kachel. Sinnbild, keine Aussage ueber ein Geraet.
    var symbol: String {
        switch self {
        case .geraete: "gearshape.2"
        case .freihantel: "dumbbell"
        case .kabelzug: "figure.strengthtraining.functional"
        case .cardio: "figure.run"
        case .eigengewicht: "figure.core.training"
        case .kettlebell: "figure.cross.training"
        case .gummiband: "figure.flexibility"
        }
    }

    /// Die Gruppe loest der Server auf (gruppeDesModells in bootstrap.ts).
    /// Der Rueckfall gilt nur fuer einen Server vor Migration 0051 oder eine
    /// Gruppe, die diese App-Version noch nicht kennt: dann steht die Liste
    /// wie vorher -- Kraft unter Geraete, Cardio unter Cardio.
    static func fuer(_ modell: BootstrapResponse.EquipmentModel) -> Geraetegruppe {
        if let gruppe = modell.equipmentGroup.flatMap(Geraetegruppe.init(rawValue:)) { return gruppe }
        return modell.category == .cardio ? .cardio : .geraete
    }
}
