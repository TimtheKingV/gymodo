import Foundation

/// Der Zeitraum-Umschalter des Diagramms -- und der Achsenbereich.
///
/// Gefiltert wird LOKAL aus einem Abruf ohne `since`: drei Umschaltungen
/// waeren sonst drei Netzabrufe, und ohne Netz waeren zwei der drei
/// Knoepfe tot.
enum Fortschrittsfenster: CaseIterable, Identifiable {
    case dreiMonate
    case sechsMonate
    case alles

    var id: Self { self }

    var titel: String {
        switch self {
        case .dreiMonate: "3 Monate"
        case .sechsMonate: "6 Monate"
        case .alles: "Alles"
        }
    }

    private var tage: Int? {
        switch self {
        case .dreiMonate: 92
        case .sechsMonate: 183
        case .alles: nil
        }
    }

    func punkte(_ alle: [ExerciseProgress.Point], jetzt: Date) -> [ExerciseProgress.Point] {
        guard let tage else { return alle }
        let grenze = jetzt.addingTimeInterval(-Double(tage) * 24 * 60 * 60)

        return alle.filter { punkt in
            guard let tag = Zeitpunkt.parse("\(punkt.performedOn)T12:00:00Z") else { return false }
            return tag >= grenze
        }
    }

    /// Die Achse beginnt nicht bei null (designsystem.md SS13):
    /// Trainingsgewichte bewegen sich in einem schmalen Band, und eine
    /// Nullachse machte jeden Fortschritt unsichtbar. Stattdessen ein
    /// Rand von einem Zehntel der Spanne -- mindestens 2,5 kg, damit auch
    /// ein einzelner Punkt eine Achse bekommt.
    static func achsenbereich(_ punkte: [ExerciseProgress.Point]) -> ClosedRange<Double> {
        let gewichte = punkte.map(\.topWeightKg)
        guard let kleinstes = gewichte.min(), let groesstes = gewichte.max() else {
            return 0 ... 10
        }

        let rand = max((groesstes - kleinstes) / 10, 2.5)
        return (kleinstes - rand) ... (groesstes + rand)
    }
}
