import Foundation

/// Eine Planposition ist eine Uebungsart, kein Geraet (Spec 5). Jede Station
/// -- ein Studiogeraet oder ein Katalogtyp --, die die Uebung anbietet,
/// startet die Position; ein Satz der Uebung an irgendeinem Geraet hakt sie
/// ab (`TrainingsplanAblauf.nachSatz` rechnet nur ueber die `exerciseId`).
enum PlanStart {
    /// Ob die Station die Uebung kennt. Ein Studiogeraet traegt die Uebungen
    /// seines Katalogmodells, ein Typ seine eigenen.
    static func bietetAn(_ station: Station, uebungId: String) -> Bool {
        station.exercises.contains { $0.id == uebungId }
    }
}
