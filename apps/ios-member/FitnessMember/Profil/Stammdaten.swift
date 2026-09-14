import Foundation

/// Die Enum-Werte des Servers und ihre deutschen Woerter -- an EINER
/// Stelle, damit Onboarding und Profil nicht zwei Listen pflegen.
enum Altersspanne: String, CaseIterable {
    case bis17 = "under_18", bis24 = "18_24", bis34 = "25_34", bis44 = "35_44",
         bis54 = "45_54", bis64 = "55_64", ab65 = "65_plus"

    static let alle = allCases

    var wort: String {
        switch self {
        case .bis17: return "bis 17"
        case .bis24: return "18–24"
        case .bis34: return "25–34"
        case .bis44: return "35–44"
        case .bis54: return "45–54"
        case .bis64: return "55–64"
        case .ab65: return "65+"
        }
    }
}

enum Geschlecht: String, CaseIterable {
    case weiblich = "female", maennlich = "male", divers = "diverse"

    static let alle = allCases

    var wort: String {
        switch self {
        case .weiblich: return "Weiblich"
        case .maennlich: return "Männlich"
        case .divers: return "Divers"
        }
    }
}

/// Die Richtung ist eine Absicht des Mitglieds, keine Bewertung durch die
/// Plattform (Spec Abschnitt 6) -- `zeile` bleibt deshalb bei der
/// Absicht selbst, ohne Kalorien, ohne "gesund".
enum Trainingsrichtung: String, CaseIterable {
    case abnehmen = "lose_weight", muskelnAufbauen = "build_muscle",
         fitBleiben = "stay_fit", staerkerWerden = "get_stronger"

    static let alle = allCases

    var wort: String {
        switch self {
        case .abnehmen: return "Abnehmen"
        case .muskelnAufbauen: return "Muskeln aufbauen"
        case .fitBleiben: return "Fit bleiben"
        case .staerkerWerden: return "Stärker werden"
        }
    }

    var zeile: String {
        switch self {
        case .abnehmen: return "Gewicht runter, Kraft halten"
        case .muskelnAufbauen: return "Muskeln aufbauen, Gewicht kann steigen"
        case .fitBleiben: return "Fit bleiben, ohne Gewichtsziel"
        case .staerkerWerden: return "Kraft steigern, Gewicht ist zweitrangig"
        }
    }
}
