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

    /// Wohin ein Tipp auf eine Planzeile fuehrt.
    enum Ziel: Equatable {
        /// Genau ein Geraet bietet die Uebung an: ohne Auswahl starten.
        case direkt(Station)
        /// Mehrere Geraete bieten sie an: Auswahl mit Scan/QR zeigen.
        case auswahl([Station])
        /// Kein Geraet bietet die Uebung an.
        case keine
    }

    /// Startregel: nur Stationen, die die Uebung anbieten, zaehlen. Eine
    /// einzige startet direkt, mehrere fuehren in die Auswahl.
    static func ziel(stationen: [Station], uebungId: String) -> Ziel {
        let passend = stationen.filter { bietetAn($0, uebungId: uebungId) }
        switch passend.count {
        case 0: return .keine
        case 1: return .direkt(passend[0])
        default: return .auswahl(passend)
        }
    }
}
